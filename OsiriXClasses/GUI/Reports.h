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

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import <CoreData/CoreData.h>

typedef NS_ENUM(NSUInteger, ReportType) {
    REPORT_TYPE_MS_WORD = 0,
    REPORT_TYPE_RTF = 1,  // TextEdit
    REPORT_TYPE_PAGES = 2,
    REPORT_TYPE_PLUGIN = 3,
    REPORT_TYPE_DICOM_SR = 4,
    REPORT_TYPE_LIBRE_OFFICE = 5
};

/** \brief reports */
@interface Reports : NSObject
{
	NSMutableString *templateName;
}

+ (NSString*) getUniqueFilename:(id) study;
+ (NSString*) getOldUniqueFilename:(NSManagedObject*) study;

- (BOOL)createNewReport:(NSManagedObject*)study destination:(NSString*)path type:(ReportType)type;

+(NSString*)databaseWordTemplatesDirPath;
+(NSString*)resolvedDatabaseWordTemplatesDirPath;

- (void)searchAndReplaceFieldsFromStudy:(NSManagedObject*)aStudy inString:(NSMutableString*)aString;
- (BOOL) createNewPagesReportForStudy:(NSManagedObject*)aStudy toDestinationPath:(NSString*)aPath;
- (BOOL) createNewOpenDocumentReportForStudy:(NSManagedObject*)aStudy toDestinationPath:(NSString*)aPath;
+ (NSMutableArray*)pagesTemplatesList;
+ (NSMutableArray*)wordTemplatesList;
- (NSMutableString *)templateName;
- (void)setTemplateName:(NSString *)aName;
+ (BOOL) Pages5orHigher;
+ (void)checkForPagesTemplate;
+ (void)checkForWordTemplates;

@end
