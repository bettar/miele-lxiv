//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#include "options.h"

#import <Cocoa/Cocoa.h>

@interface NSFont (withay_OpenGL)

+ (void) setOpenGLLogging:(BOOL)logEnabled;
+ (void) resetFont: (int) preview;
+ (void) initFontImage:(unichar)first count:(int)count font:(NSFont*) font fontType:(int) preview  scaling: (float) scaling;
- (BOOL) makeGLDisplayListFirst:(unichar)first count:(int)count base:(GLint)base :(long*) charSizeArrayIn :(int) fontType : (float) scaling;
+ (unsigned char*) createCharacterWithImage:(NSBitmapImageRep *)bitmap;
@end
