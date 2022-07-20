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

#define THUMBNAILSIZE 70

// Used in series descriptions, series name
#define APP_SR_ROI                  @"OsiriX ROI SR"  // series number: 5002
#define OSIRIX_SR_REPORT            @"OsiriX Report SR" // 5003
#define OSIRIX_SR_ANNOTATION        @"OsiriX Annotations SR" // series id: 5004
#define OSIRIX_SR_NO_AUTODELETION   @"OsiriX No Autodeletion" // 5005
#define OSIRIX_SR_WINDOW_STATE      @"OsiriX WindowsState SR" // 5006

@class DicomStudy, Dicom_Image;

/** \brief  Core Data Entity for a Series */

@interface DicomSeries : NSManagedObject
{
	NSNumber *dicomTime;
}

@property(nonatomic, retain, readonly) NSNumber* dicomTime;

- (NSSet*) paths;
- (NSSet*) keyImages;
- (NSArray*) sortedImages;
- (NSComparisonResult) compareName:(DicomSeries*)series;
- (NSNumber*) noFilesExcludingMultiFrames;
- (NSNumber*) rawNoFiles;
- (DicomSeries*) previousSeries;
- (DicomSeries*) nextSeries;
- (NSArray*) sortDescriptorsForImages;
- (NSString*) uniqueFilename;

@end

NS_ASSUME_NONNULL_BEGIN

@interface DicomSeries (CoreDataProperties)

@property (nonatomic, retain) NSString* comment;
@property (nonatomic, retain) NSString* comment2;
@property (nonatomic, retain) NSString* comment3;
@property (nonatomic, retain) NSString* comment4;
@property (nonatomic, retain) NSDate* date;
@property (nonatomic, retain) NSDate* dateAdded;
@property (nonatomic, retain) NSDate* dateOpened;
@property (nonatomic, retain) NSNumber* displayStyle;
@property (nonatomic, retain) NSNumber *id;
@property (nullable, nonatomic, copy) NSNumber *keySeries; // new !
@property (nonatomic, retain) NSString *modality;
@property (nonatomic, retain) NSNumber *mountedVolume __deprecated;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSNumber *numberOfImages;
@property (nonatomic, retain) NSNumber *numberOfKeyImages;
@property (nonatomic, retain) NSNumber *rotationAngle;
@property (nonatomic, retain) NSNumber *scale;
@property (nonatomic, retain) NSString *seriesDescription;
@property (nonatomic, retain) NSString *seriesDICOMUID;
@property (nonatomic, retain) NSString *seriesInstanceUID;
@property (nonatomic, retain) NSString *seriesSOPClassUID;
@property (nonatomic, retain) NSNumber *stateText;
@property (nonatomic, retain) NSData *thumbnail;
@property (nonatomic, retain) NSNumber *xFlipped;
@property (nonatomic, retain) NSNumber *xOffset;
@property (nonatomic, retain) NSNumber *yFlipped;
@property (nonatomic, retain) NSNumber *yOffset;
@property (nonatomic, retain) NSNumber *windowLevel;
@property (nonatomic, retain) NSNumber *windowWidth;
@property (nonatomic, retain) NSSet<Dicom_Image *> *images;
@property (nonatomic, retain) DicomStudy *study;

@end

@interface DicomSeries (CoreDataGeneratedAccessors)

- (void) addImagesObject:(Dicom_Image *)value;
- (void) removeImagesObject:(Dicom_Image *)value;
- (void) addImages:(NSSet<Dicom_Image *> *)values;
- (void) removeImages:(NSSet<Dicom_Image *> *)values;

@end

NS_ASSUME_NONNULL_END
