#!/bin/bash
set -e

helper="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/dsr2html"
rpath="@executable_path/../Frameworks"
architectures=$(lipo -archs "$helper")
present=0
missing=0

for arch in $architectures; do
    load_commands=$(otool -arch "$arch" -l "$helper")
    if printf '%s\n' "$load_commands" | awk -v rpath="$rpath" '
        $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
        in_rpath && $1 == "path" {
            if ($2 == rpath) found = 1
            in_rpath = 0
        }
        END { exit !found }
    '; then
        present=$((present + 1))
    else
        missing=$((missing + 1))
    fi
done

if [ "$present" -gt 0 ] && [ "$missing" -gt 0 ]; then
    echo "error: dsr2html has inconsistent rpaths across architectures" >&2
    exit 1
fi

if [ "$missing" -gt 0 ]; then
    install_name_tool -add_rpath "$rpath" "$helper"
fi
