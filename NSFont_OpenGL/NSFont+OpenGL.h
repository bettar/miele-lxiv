//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
// NSFont+OpenGL.h
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#include "options.h"

#import <Cocoa/Cocoa.h>

#include "mieleTypes.h"

@interface NSFont (with_OpenGL)

+ (void) setOpenGLLogging:(BOOL)logEnabled;
+ (void) resetFont: (int) preview;

+ (void) initFontImage:(unichar) first
                 count:(int) count
                  font:(NSFont*) font
              fontType:(FontType) preview
               scaling:(float) scaling;

- (BOOL) makeGLDisplayListFirst:(unichar)first
                          count:(int)count
                           base:(GLint)base
                               :(long*) charSizeArrayIn
                               :(FontType) fontType
                               :(float) scaling;
@end

