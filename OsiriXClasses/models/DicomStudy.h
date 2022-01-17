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

@class DicomSeries, Dicom_Image, DicomAlbum;

/** \brief  Core Data Entity for a Study */
@interface DicomStudy : NSManagedObject
{
	BOOL isHidden;
	NSNumber *dicomTime;
    NSUInteger _numberOfImagesWhenCachedModalities;
	NSString *cachedModalites;
    BOOL reentry;
}

+ (NSRecursiveLock*) dbModifyLock;
+ (NSString*) soundex: (NSString*) s;
- (NSString*) soundex;
+ (NSString*) yearOldFromDateOfBirth: (NSDate*) dateOfBirth;
+ (NSString*) yearOldAcquisition:(NSDate*) acquisitionDate FromDateOfBirth: (NSDate*) dateOfBirth;
+ (BOOL) displaySeriesWithSOPClassUID: (NSString*) uid andSeriesDescription: (NSString*) description;
- (NSNumber*) noFiles;
- (NSSet*) paths;
- (NSSet*) keyImages;
- (NSSet*) images;
- (NSNumber*) rawNoFiles;
- (NSString*) modalities;
+ (NSString*) displayedModalitiesForSeries: (NSArray*) seriesModalities;
- (NSArray*) imageSeries;
- (NSArray*) imageSeriesContainingPixels:(BOOL) pixels;
- (NSArray*) keyObjectSeries;
- (NSArray*) keyObjects;
- (NSArray*) presentationStateSeries;
- (NSArray*) waveFormSeries;
- (NSString*) roiPathForImage: (Dicom_Image*) image inArray: (NSArray*) roisArray;
- (NSString*) roiPathForImage: (Dicom_Image*) image;
- (Dicom_Image*) roiForImage: (Dicom_Image*) image inArray: (NSArray*) roisArray;
- (DicomSeries*) roiSRSeries;
- (DicomSeries*) reportSRSeries;
- (Dicom_Image*) windowsStateImage;
- (DicomSeries*) windowsStateSRSeries;
- (Dicom_Image*) reportImage;
- (Dicom_Image*) annotationsSRImage;
- (void) archiveReportAsDICOMSR;
- (void) archiveAnnotationsAsDICOMSR;
- (void) archiveWindowsStateAsDICOMSR;
- (NSArray*) allWindowsStateSRSeries;
- (BOOL) isHidden;
- (BOOL) isDistant;
- (void) setHidden: (BOOL) h;
- (NSNumber*) noFilesExcludingMultiFrames;
- (NSDictionary*) annotationsAsDictionary;
- (void) applyAnnotationsFromDictionary: (NSDictionary*) rootDict;
- (void) reapplyAnnotationsFromDICOMSR;
- (NSComparisonResult) compareName:(DicomStudy*)study;
- (NSArray*) roiImages;
- (NSNumber*) dicomTime;
- (NSArray*) generateDICOMSCImagesForKeyImages: (BOOL) keyImages andROIImages: (BOOL) ROIImages;

- (NSArray*) imagesForKeyImages:(BOOL) keyImages andForROIs:(BOOL)alsoImagesWithROIs;

+ (NSString*) scrambleString: (NSString*) t;
@end

NS_ASSUME_NONNULL_BEGIN

@interface DicomStudy (CoreDataProperties)

@property(nonatomic, retain) NSString* accessionNumber;
@property(nonatomic, retain) NSString* comment;
@property(nonatomic, retain) NSString* comment2;
@property(nonatomic, retain) NSString* comment3;
@property(nonatomic, retain) NSString* comment4;
@property(nonatomic, retain) NSDate* date;
@property(nonatomic, retain) NSDate* dateAdded;
@property(nonatomic, retain) NSDate* dateOfBirth;
@property(nonatomic, retain) NSDate* dateOpened;
@property(nonatomic, retain) NSString* dictateURL;
@property(nonatomic, retain) NSNumber* expanded;
@property(nonatomic, retain) NSNumber* hasDICOM;
@property(nonatomic, retain) NSString* id;
@property(nonatomic, retain) NSString* institutionName;
@property(nonatomic, retain) NSNumber* lockedStudy;
@property(nonatomic, retain) NSString* modality;
@property(nonatomic, retain) NSString* name;
@property(nonatomic, retain) NSNumber* numberOfImages;
@property(nonatomic, retain) NSString* patientID;
@property(nonatomic, retain) NSString* patientSex;
@property(nonatomic, retain) NSString* patientUID;
@property(nonatomic, retain) NSString* performingPhysician;
@property(nonatomic, retain) NSString* referringPhysician;
@property(nonatomic, retain) NSString* reportURL;
@property(nonatomic, retain) NSNumber* stateText;
@property(nonatomic, retain) NSString* studyInstanceUID;
@property(nonatomic, retain) NSString* studyName;
@property(nonatomic, retain) NSData* windowsState;
@property(nonatomic, retain) NSSet<DicomAlbum *> *albums;
@property(nonatomic, retain) NSSet<DicomSeries *> *series;

@end

@interface DicomStudy (CoreDataGeneratedAccessors)

- (void) addAlbumsObject:(DicomAlbum *)value;
- (void) removeAlbumsObject:(DicomAlbum *)value;
- (void) addAlbums:(NSSet<DicomAlbum *> *)values;
- (void) removeAlbums:(NSSet<DicomAlbum *> *)values;

- (void) addSeriesObject:(DicomSeries *)value;
- (void) removeSeriesObject:(DicomSeries *)value;
- (void) addSeries:(NSSet<DicomSeries *> *)values;
- (void) removeSeries:(NSSet<DicomSeries *> *)values;

@end

NS_ASSUME_NONNULL_END

