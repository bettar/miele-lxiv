#!/bin/bash

cd "${BUILT_PRODUCTS_DIR}"


dest="${UNLOCALIZED_RESOURCES_FOLDER_PATH}/miele-lxiv-lite.zip"

if true; then
PREZIPPED="${PROJECT_DIR}/Binaries/miele-lxiv-lite.zip"
cp ${PREZIPPED} "${UNLOCALIZED_RESOURCES_FOLDER_PATH}/"

else

product="miele-lxiv-lite.app"
rm -f "${dest}"
zip -qr "${dest}" . -i "${product}"
fi
