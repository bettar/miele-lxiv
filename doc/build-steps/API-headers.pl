#!/usr/bin/perl

use strict;
use File::Copy;
use File::Basename;
my $destination = "$ENV{TARGET_BUILD_DIR}/$ENV{PUBLIC_HEADERS_FOLDER_PATH}";

mkdir $destination unless -d $destination;
open Miele_h, ">", "$destination/Miele.h" or die $!;

print Miele_h "#ifndef __Miele_API\n#define __Miele_API\n\n";
print Miele_h "// Created from project: $ENV{PROJECT_NAME} target: $ENV{TARGET_NAME} version: $ENV{MARKETING_VERSION} build: $ENV{CURRENT_PROJECT_VERSION}\n\n";

my @fromdirs = ("$ENV{PROJECT_DIR}/cocoahttpserver",
    "$ENV{PROJECT_DIR}/OsiriXClasses/2D",
    "$ENV{PROJECT_DIR}/OsiriXClasses/DICOMFiles",
    "$ENV{PROJECT_DIR}/OsiriXClasses/GUI",
    "$ENV{PROJECT_DIR}/OsiriXClasses/models",
    "$ENV{PROJECT_DIR}/OsiriXClasses/OSI",
    "$ENV{PROJECT_DIR}/OpenGL",
    "$ENV{PROJECT_DIR}/OsiriXClasses/ROI",
    "$ENV{PROJECT_DIR}/Nitrogen/Sources",
    "$ENV{PROJECT_DIR}/Nitrogen/Sources/JSON",
    $ENV{PROJECT_DIR});

foreach my $root (@fromdirs) {
    opendir(DIR, $root);
    
    my @files = readdir(DIR);
    foreach (@files) {
        my $filename = $_;
        next unless -f "$root/$filename" && $filename =~ /\.h$/s;
        my @args = ( "cp", "-fp", "$root/$filename", "$destination/".(basename $filename) );
        system(@args) == 0 or die "Copy failed: $?";
        print Miele_h "#include <MieleAPI/$filename>\n";
    }
    
    closedir(DIR);
}

print Miele_h "\n#endif\n";
close Miele_h;

chdir "$ENV{TARGET_BUILD_DIR}/$ENV{FULL_PRODUCT_NAME}";
symlink "Versions/Current/Headers", "Headers";

exit 0;
