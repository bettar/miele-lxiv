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

#import "NSMutableString+N2.h"
#import "NSString+N2.h"

@implementation NSMutableString (N2)

-(NSUInteger)replaceOccurrencesOfString:(NSString*)target withString:(NSString*)replacement {
	return [self replaceOccurrencesOfString:target withString:replacement options:NSLiteralSearch range:self.range];
}

@end
