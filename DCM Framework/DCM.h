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

#import <DCM/DCMValueRepresentation.h>
#import <DCM/DCMAttributeTag.h>
#import <DCM/DCMAttribute.h>
#import <DCM/DCMSequenceAttribute.h>
#import <DCM/DCMDataContainer.h>
#import <DCM/DCMObject.h>
#import <DCM/DCMTransferSyntax.h>
#import <DCM/DCMTagDictionary.h>
#import <DCM/DCMTagForNameDictionary.h>
#import <DCM/DCMCharacterSet.h>
#import <DCM/DCMPixelDataAttribute.h>
#import <DCM/DCMCalendarDate.h>
#import <DCM/DCMLimitedObject.h>
#import <DCM/DCMNetServiceDelegate.h>
#import <DCM/DCMEncapsulatedPDF.h>

#define DCMDEBUG 0
#define DCMFramework_compile YES

#import <Accelerate/Accelerate.h>

enum DCM_CompressionQuality {
    DCMLosslessQuality = 0,
    DCMHighQuality,
    DCMMediumQuality,
    DCMLowQuality};

@protocol MoveStatusProtocol
	- (void)setStatus:(unsigned short)moveStatus  numberSent:(int)numberSent numberError:(int)numberErrors;
@end
