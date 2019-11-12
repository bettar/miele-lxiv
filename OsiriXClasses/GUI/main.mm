//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

//#import "mgl.h" // include first

#import <Cocoa/Cocoa.h>
#import "NSFont_OpenGL/NSFont_OpenGL.h"

#include "options.h"

#ifndef OSIRIX_LIGHT
#include "FVTiff.h"
#endif

int main(int argc, const char *argv[])
{	
#ifndef OSIRIX_LIGHT
    FVTIFFInitialize();
#endif
   
    return NSApplicationMain(argc, argv);
}
