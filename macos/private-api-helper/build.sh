#!/bin/zsh
# Rebuilds packages/server/appResources/private-api/macos11/BlueBubblesHelper.dylib from
# BlueBubblesApp/bluebubbles-helper with emoji-tapback.patch applied.
# Only needs the Xcode Command Line Tools (no full Xcode).
set -e

HELPER_REPO=https://github.com/BlueBubblesApp/bluebubbles-helper
HELPER_COMMIT=df40280e0ae30c42cd45d0bab838dcc2d64c4c7a

HERE=${0:a:h}
OUT=$HERE/../../packages/server/appResources/private-api/macos11/BlueBubblesHelper.dylib
WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT

git clone -q $HELPER_REPO $WORK/helper
git -C $WORK/helper checkout -q $HELPER_COMMIT
git -C $WORK/helper apply $HERE/emoji-tapback.patch

H=$WORK/helper/Messages/MacOS-11+
SDK=$(xcrun --sdk macosx --show-sdk-path)
SRC=(
    $H/BlueBubblesHelper/BlueBubblesHelper.m
    $H/BlueBubblesHelper/NetworkController.m
    $H/BlueBubblesHelper/CTBlockDescription.m
    $H/BlueBubblesHelper/ZKSwizzle/ZKSwizzle.m
    $H/Pods/CocoaAsyncSocket/Source/GCD/GCDAsyncSocket.m
)
INC=(
    -I$H/BlueBubblesHelper
    -I$H/BlueBubblesHelper/ZKSwizzle
    -I$H/BlueBubblesHelper/SocialAppsCore
    -I$H/Pods/CocoaAsyncSocket/Source/GCD
)

slices=()
for arch in x86_64 arm64 arm64e; do
    clang -arch $arch -mmacosx-version-min=11.5 -dynamiclib -fobjc-arc -fmodules -O2 \
        -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types -Wno-error=incompatible-pointer-types \
        -include $H/BlueBubblesHelper/PrefixHeader.pch $INC \
        -F$SDK/System/Library/PrivateFrameworks \
        -framework Foundation -framework AppKit -framework CoreServices -framework Security \
        -framework IMCore -framework IMSharedUtilities -framework IMDPersistence -framework IDS -framework FMF \
        -ObjC -undefined dynamic_lookup -install_name @rpath/BlueBubblesHelper.dylib \
        $SRC -o $WORK/BlueBubblesHelper.$arch 2> $WORK/build-$arch.log
    slices+=$WORK/BlueBubblesHelper.$arch
done

lipo -create $slices -output $OUT
codesign -f -s - $OUT
md5 -q $OUT | tr -d '\n' > $OUT.md5
lipo -info $OUT
