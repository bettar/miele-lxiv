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

@class DicomStudy;

/** \brief  Core Data Entity for an Album */

@interface DicomAlbum : NSManagedObject {
    int numberOfStudies;
}

//@property(nonatomic, retain) NSDictionary *correspondingDICOMNodeQuery;
@property int numberOfStudies;

@end

NS_ASSUME_NONNULL_BEGIN

@interface DicomAlbum (CoreDataProperties)

@property(nonatomic, retain) NSNumber* smartAlbum;
@property(nonatomic, retain) NSNumber* index;
@property(nonatomic, retain) NSString* name;
@property(nonatomic, retain) NSString* predicateString;
@property(nonatomic, retain) NSSet<DicomStudy *> *studies;

@end

@interface DicomAlbum (CoreDataGeneratedAccessors)

- (void)addStudiesObject:(DicomStudy *)value;
- (void)removeStudiesObject:(DicomStudy *)value;
- (void)addStudies:(NSSet<DicomStudy *> *)values;
- (void)removeStudies:(NSSet<DicomStudy *> *)values;

@end

NS_ASSUME_NONNULL_END
