#!/bin/bash
#test with codesign -vvv

source $PROJECT_DIR/doc/build-steps/identity.conf

chmod -R 777 "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/"

echo "=== $(basename $0) === $BUILT_PRODUCTS_DIR/$WRAPPER_NAME"

function cs {
  echo "~~~ Codesign <$1>"
  codesign --timestamp --force --sign "$IDENTITY" "$1"
}

function cse {
  echo "~~~ Codesign $IDENTITY with entitlements <$1>"
  codesign --timestamp --force \
    --sign "$IDENTITY" \
    --options runtime \
    --entitlements "$PROJECT_DIR/cli.entitlements" \
    "$1"
}

# TODO: Clear extended attributes, which can cause codesign to fail
#/usr/bin/xattr -cr "$TARGET_BUILD_DIR"

#if [[ ${CONFIGURATION} != "Development" ]] ; then
#cs  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/MieleAPI.framework"
#cs  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libpng16.16.37.0.dylib"
#cs  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libjpeg.9.dylib"
#cse  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libiconv.2.dylib"
cse  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libtiff.6.dylib"

# We link with static libraries instead of the following two:
#cs  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libcrypto.1.1.dylib" # It gets codesigned on copy. Check with `codesign -vv -d <file>`
#cs  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libssl.1.1.dylib"

#cse "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/odt2pdf.zip"
#cse "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/odt2pdf"

# Signing is already done automatically by Xcode, but the important step here is Sandboxing
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/dciodvfy"
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/dcmdump"
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/dsr2html"
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/echoscu"
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/Decompress"
cse "$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/DICOMPrint"

# TBC: maybe the Plugins directory doesn't require to contain signed files 
#cse "$TARGET_BUILD_DIR/$BUNDLE_PLUGINS_FOLDER_PATH/JPEGtoDICOM.mieleplugin/Contents/MacOS/JPEGtoDICOM"

#cse "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/miele-lxiv-lite.zip"
#cse "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/LXIV Launcher.zip"

#codesign --resource-rules Rules.plist -f -s "$IDENTITY" "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/"
echo "=== code signed"
#fi
