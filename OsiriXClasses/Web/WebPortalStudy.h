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

#import <Cocoa/Cocoa.h>

@class DicomStudy, WebPortalUser;

@interface WebPortalStudy : NSManagedObject

@property (readonly) DicomStudy* study;

@end

NS_ASSUME_NONNULL_BEGIN

@interface WebPortalStudy (CoreDataProperties)

+ (NSFetchRequest<WebPortalStudy *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic, retain) NSDate * dateAdded;
@property (nonatomic, retain) NSString * patientUID;
@property (nonatomic, retain) NSString * studyInstanceUID;
@property (nonatomic, retain) WebPortalUser * user;

@end

NS_ASSUME_NONNULL_END
