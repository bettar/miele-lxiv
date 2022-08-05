#!/bin/bash

SRCROOT="$(pwd)/../.."

cd "$SRCROOT/Binaries"
unzip -uo DB_Previous_Models.zip
unzip -uo PAGES.zip
unzip -uo OsiriXReport.template.zip
unzip -uo ILCrashReporter.framework.zip
unzip -uo Growl.framework.zip
unzip -uo 3DconnexionClient.framework.zip
unzip -uo dciodvfy.zip
unzip -uo libPapyrusToolkit.a.zip
unzip -uo -d weasis weasis-portable.zip
#chmod -R 755 weasis
#cd "$SRCROOT/Binaries/weasis"
#if [ -d "weasis-portable" ]; then
#    cd "weasis-portable"
#    for f in *; do
#        rm -Rf "../$f"
#        mv "$f" ..
#    done
#    cd ..
#    rm -Rf weasis-portable
#fi
#find . -name __MACOSX | xargs rm -Rf

cd "$SRCROOT/Binaries/ReportsToPDF/odt2pdf/build"
unzip -uo odt2pdf.zip

cd "$SRCROOT/Binaries/Icons"
unzip -uo Logo.tif.zip

cd "$SRCROOT/Binaries/PAGES"
rm ._*

#cd "$SRCROOT/AYDicomPrint"
#unzip -uo libdcmprintscu.dylib.zip
#unzip -uo libxerces-c.27.dylib.zip
#unzip -uo xercesc.zip

exit 0

