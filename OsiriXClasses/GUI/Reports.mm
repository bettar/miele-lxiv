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

#import "Reports.h"
#import "DICOMFiles/dicomFile.h"
#import <DCM/DCM.h>
#import "BrowserController.h"
#import "NSString+N2.h"
#import "NSFileManager+N2.h"
#import "NSAppleScript+N2.h"
#import "DicomDatabase.h"
#import "N2Debug.h"
#import "AppDefaults.h"

static NSString *templatePrefix = @"OsiriX ";  // TODO: change to "Bundle-ID "

// if you want check point log info, define CHECK to the next line, uncommented:
#define CHECK NSLog(@"Applescript result code = %d", ok);

#define COMPILED_APPLESCRIPT_IN_BUNDLE
// Why is that the .applescript files in the project become .scpt files in the bundle ?
#ifdef COMPILED_APPLESCRIPT_IN_BUNDLE
#define APPLESCRIPT_EXTENSION   @"scpt"             // binary
#else
#define APPLESCRIPT_EXTENSION   @"applescript"      // text
#endif

// This converts an AEDesc into a corresponding NSValue.

//static id aedesc_to_id(AEDesc *desc)
//{
//	OSErr ok;
//
//	if (desc->descriptorType == typeChar)
//	{
//		NSMutableData *outBytes;
//		NSString *txt;
//
//		outBytes = [[NSMutableData alloc] initWithLength:AEGetDescDataSize(desc)];
//		ok = AEGetDescData(desc, [outBytes mutableBytes], [outBytes length]);
//		CHECK;
//
//		txt = [[NSString alloc] initWithData:outBytes encoding: NSUTF8StringEncoding];
//		[outBytes release];
//		[txt autorelease];
//
//		return txt;
//	}
//
//	if (desc->descriptorType == typeSInt16)
//	{
//		SInt16 buf;
//		AEGetDescData(desc, &buf, sizeof(buf));
//		return [NSNumber numberWithShort:buf];
//	}
//
//	return [NSString stringWithFormat:@"[unconverted AEDesc, type=\"%c%c%c%c\"]", ((char *)&(desc->descriptorType))[0], ((char *)&(desc->descriptorType))[1], ((char *)&(desc->descriptorType))[2], ((char *)&(desc->descriptorType))[3]];
//}

@interface Reports ()

@property (nonatomic, copy) NSMutableString *templateName;

- (void)runScript:(NSString*)txt;
- (BOOL)createNewWordReportForStudy:(NSManagedObject*)study toDestinationPath:(NSString*)destinationFile;

@end

#pragma mark -

@implementation Reports

+ (NSString*) getUniqueFilename:(id) study
{
	NSString *s = [study valueForKey:@"accessionNumber"];
	
	if( [s length] > 0)
		return [DicomFile NSreplaceBadCharacter: [[study valueForKey:@"patientUID"] stringByAppendingFormat:@"-%@", [study valueForKey:@"accessionNumber"]]];
	else
		return [DicomFile NSreplaceBadCharacter: [[study valueForKey:@"patientUID"] stringByAppendingFormat:@"-%@", [study valueForKey:@"studyInstanceUID"]]];
}

+ (NSString*) getOldUniqueFilename:(NSManagedObject*) study
{
	return [DicomFile NSreplaceBadCharacter: [[study valueForKey:@"patientUID"] stringByAppendingFormat:@"-%@", [study valueForKey:@"id"]]];
}

- (NSString *) HFSStyle: (NSString*) string
{
	return [[(NSURL *)CFURLCreateWithFileSystemPath( kCFAllocatorDefault, (CFStringRef)string, kCFURLHFSPathStyle, NO) autorelease] path];
}

- (NSString *) HFSPathFromPOSIXPath: (NSString*) p
{
    // thanks to stone.com for the pointer to  CFURLCreateWithFileSystemPath()

    CFURLRef    url;
    CFStringRef hfsPath = NULL;

    BOOL isDirectoryPath = [p hasSuffix:@"/"];
    // Note that for the usual case of absolute paths,  isDirectoryPath is
    // completely ignored by CFURLCreateWithFileSystemPath.
    // isDirectoryPath is only considered for relative paths.
    // This code has not really been tested relative paths...

    url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                          (CFStringRef)p,
                                          kCFURLPOSIXPathStyle,
                                          isDirectoryPath);
    if (NULL != url) {

        // Convert URL to a colon-delimited HFS path
        // represented as Unicode characters in an NSString.

        hfsPath = CFURLCopyFileSystemPath(url, kCFURLHFSPathStyle);
        if (NULL != hfsPath) {
            [(NSString *)hfsPath autorelease];
        }
        CFRelease(url);
    }

    return (NSString *) hfsPath;
}

- (NSString*) getDICOMStringValueForField: (NSString*) rawField inDICOMFile: (NSString*) path
{
#ifndef NDEBUG
    NSLog( @"Report: DICOM_Field: %@", rawField);
#endif
    @try {
        NSArray *dicomFields = [rawField componentsSeparatedByString: @":"];
        
        DCMObject *dcmObject = [DCMObject objectWithContentsOfFile: path decodingPixelData:NO];
        if( dcmObject)
        {
            id lastObj = nil;
            for( NSString *dicomField in dicomFields)
            {
                dicomField = [dicomField stringByReplacingOccurrencesOfString:@" " withString:@""];
                
                if( lastObj == nil)
                    lastObj = [dcmObject attributeWithName: dicomField];
                
                if( lastObj == nil)
                    lastObj = [dcmObject attributeForTag: [DCMAttributeTag tagWithTagString: dicomField]];
                
                if( lastObj == nil)
                    break;
                
                if( [lastObj isKindOfClass: [DCMSequenceAttribute class]] == NO)
                    break;
                else
                {
                    dcmObject = [[lastObj sequence] objectAtIndex: 0]; // Read only first item...
                    
                    if( [dicomFields lastObject] != dicomField)
                        lastObj = 0;
                }
            }
            
            if( [lastObj isKindOfClass: [DCMSequenceAttribute class]])
                lastObj = [lastObj readableDescription];
            
            if( [lastObj isKindOfClass: [DCMAttribute class]])
                lastObj = [lastObj value];
            
            if( [lastObj isKindOfClass: [NSString class]])
                return lastObj;
        }
    }
    @catch ( NSException *e) {
        N2LogException( e);
    }
    
#ifndef NDEBUG
    NSLog( @"Dicom field not found: %@ in %@", rawField, path);
#endif
    return nil;
}

- (BOOL) createNewReport:(NSManagedObject*) study destination:(NSString*) path type:(ReportType) type
{
	NSString *uniqueFilename = [Reports getUniqueFilename: study];
	
	switch (type)
	{
		case REPORT_TYPE_MS_WORD:
		{
			NSString *destinationFile = [NSString stringWithFormat:@"%@%@.%@", path, uniqueFilename, @"doc"];
			[[NSFileManager defaultManager] removeItemAtPath: destinationFile error: nil];
			
            [self createNewWordReportForStudy:study toDestinationPath:destinationFile];
        }
            break;
		
		case REPORT_TYPE_RTF:
		{
			NSString *destinationFile = [NSString stringWithFormat:@"%@%@.%@", path, uniqueFilename, @"rtf"];
			[[NSFileManager defaultManager] removeItemAtPath: destinationFile error: nil];

            NSString *srcPath = BrowserController.currentBrowser.database.rtfTemplatesDirPath;
            srcPath = [srcPath stringByAppendingPathComponent:@"ReportTemplate.rtf"];
			[[NSFileManager defaultManager] copyItemAtPath: srcPath
                                                    toPath: destinationFile
                                                     error: nil];
			
			NSDictionary *attr;
			NSMutableAttributedString *rtf = [[NSMutableAttributedString alloc] initWithRTF: [NSData dataWithContentsOfFile:destinationFile] documentAttributes:&attr];
			NSString *rtfString = [rtf string];
			NSRange	range;
			
			// SCAN FIELDS
			
			NSManagedObjectModel *model = [[[study managedObjectContext] persistentStoreCoordinator] managedObjectModel];
			NSArray *properties = [[[[model entitiesByName] objectForKey:@"Study"] attributesByName] allKeys];
			
			
			NSDateFormatter	*date = [[[NSDateFormatter alloc] init] autorelease];
			[date setDateStyle: NSDateFormatterShortStyle];
			
			for (NSString *name in properties)
			{
				NSString *string;
				
				if( [[study valueForKey: name] isKindOfClass: [NSDate class]])
					string = [date stringFromDate: [study valueForKey: name]];
				else
                    string = [[study valueForKey: name] description];
				
				NSRange	searchRange = rtf.range;
				
				do
				{
					range = [rtfString rangeOfString: [NSString stringWithFormat:@"«%@»", name] options:0 range:searchRange];
					
					if( range.length > 0)
					{
						if( string)
							[rtf replaceCharactersInRange:range withString:string];
						else
                            [rtf replaceCharactersInRange:range withString:@""];
						
						searchRange = NSMakeRange( range.location, [rtf length]-(range.location+1));
					}
				}while( range.length != 0);
			}
			
			// TODAY
			
			NSRange	searchRange = rtf.range;
			
			range = [rtfString rangeOfString: @"«today»" options:0 range: searchRange];
			if( range.length > 0)
			{
				[rtf replaceCharactersInRange:range withString:[date stringFromDate: [NSDate date]]];
			}
			
			// DICOM Fields
			NSArray	*seriesArray = [[BrowserController currentBrowser] childrenArray: study];
			if( [seriesArray count] > 0)
			{
				NSArray	*imagePathsArray = [[BrowserController currentBrowser] imagesPathArray: [seriesArray objectAtIndex: 0]];
				BOOL moreFields = NO;
				do
				{
					NSRange firstChar = [rtfString rangeOfString: @"«DICOM_FIELD:"];
					if( firstChar.location != NSNotFound)
					{
						NSRange secondChar = [rtfString rangeOfString: @"»"];
						
						if (secondChar.location != NSNotFound)
						{
                            NSString *rawField = [rtfString substringWithRange: NSMakeRange( firstChar.location+firstChar.length, secondChar.location - (firstChar.location+firstChar.length))];
                            NSString *v = [self getDICOMStringValueForField: rawField inDICOMFile: [imagePathsArray objectAtIndex: 0]];
                            if (v)
                                [rtf replaceCharactersInRange:NSMakeRange(firstChar.location, secondChar.location-firstChar.location+1) withString: v];
                            else
                                [rtf replaceCharactersInRange:NSMakeRange(firstChar.location, secondChar.location-firstChar.location+1) withString:@""];
                            
                            moreFields = YES;
						}
						else
                            moreFields = NO;
					}
					else
                        moreFields = NO;
				}
                
				while (moreFields)
                    ;
			}
			
			[[rtf RTFFromRange:rtf.range documentAttributes:attr] writeToFile:destinationFile atomically:YES];
			
			[rtf release];
			[study setValue: destinationFile forKey:@"reportURL"];
			
			[[NSWorkspace sharedWorkspace] openFile:destinationFile withApplication:@"TextEdit" andDeactivate: YES];
			[NSThread sleepForTimeInterval: 1];
		}
            break;
		
		case REPORT_TYPE_PAGES:
            {
			NSString *destinationFile = [NSString stringWithFormat:@"%@%@.%@", path, uniqueFilename, @"pages"];
			[[NSFileManager defaultManager] removeItemAtPath: destinationFile error: nil];
			
			[self createNewPagesReportForStudy:study toDestinationPath:destinationFile];
            }
            break;
		
		case REPORT_TYPE_LIBRE_OFFICE:
		{
			NSString *destinationFilename = [NSString stringWithFormat:@"%@%@.%@", path, uniqueFilename, @"odt"];
			[[NSFileManager defaultManager] removeItemAtPath: destinationFilename error: nil];
			
            NSString *srcPath = BrowserController.currentBrowser.database.odtTemplatesDirPath;
            srcPath = [srcPath stringByAppendingPathComponent:@"ReportTemplate.odt"];
            [[NSFileManager defaultManager] copyItemAtPath: srcPath
                                                    toPath: destinationFilename
                                                     error: NULL];

			[self createNewOpenDocumentReportForStudy:study
                                    toDestinationPath:destinationFilename];
			
		}
            break;
	}

    return YES;
}

// initialize it in your init method:

- (void) dealloc
{
	[_templateName release];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self)
	{
		_templateName = [NSMutableString string];
	}
	return self;
}

// do the grunge work -

// the sweetly wrapped method is all we need to know:

- (void)runScript:(NSString *)txt
{
    NSAppleScript* as = [[[NSAppleScript alloc] initWithSource:txt] autorelease];
    NSDictionary* errs = nil;
    [as runWithArguments:nil error:&errs];
    if ([errs count])
        NSLog(@"Error: AppleScript execution failed: %@", errs);
}

+(id)_runAppleScript:(NSString*)source
       withArguments:(NSArray*)args
{
    NSDictionary* errs = nil;
    
    if (!source)
        [NSException raise:NSGenericException format:@"Couldn't read script source"];
    
    NSAppleScript* script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
    if (!script)
        [NSException raise:NSGenericException format:@"Invalid script source"];
    
    id r = [script runWithArguments:args error:&errs];
    if (errs)
        [NSException raise:NSGenericException format:@"%@", errs];
    
    return r;
}

#pragma mark -

- (void)searchAndReplaceFieldsFromStudy:(NSManagedObject*)aStudy
                               inString:(NSMutableString*)aString;
{
	if (aString == nil)
		return;
		
	NSManagedObjectModel *model = [[[aStudy managedObjectContext] persistentStoreCoordinator] managedObjectModel];
	NSArray *properties = [[[[model entitiesByName] objectForKey:@"Study"] attributesByName] allKeys];
	
	NSDateFormatter *date = [[[NSDateFormatter alloc] init] autorelease];
	[date setDateStyle: NSDateFormatterShortStyle];
    
    NSDateFormatter *longDate = [[[NSDateFormatter alloc] init] autorelease];
	[longDate setDateStyle: NSDateFormatterLongStyle];
	
	for( NSString *propertyName in properties)
	{
		NSString *propertyValue;
		
		if ([[aStudy valueForKey:propertyName] isKindOfClass:[NSDate class]])
			propertyValue = [date stringFromDate: [aStudy valueForKey:propertyName]];
		else
			propertyValue = [[aStudy valueForKey:propertyName] description];
			
		if (!propertyValue)
			propertyValue = @"";
			
		//		« is encoded as &#xAB;
		//      » is encoded as &#xBB;
		[aString replaceOccurrencesOfString:[NSString stringWithFormat:@"&#xAB;%@&#xBB;", propertyName] withString:propertyValue options:NSLiteralSearch range:aString.range];
		[aString replaceOccurrencesOfString:[NSString stringWithFormat:@"«%@»", propertyName] withString:propertyValue options:NSLiteralSearch range:aString.range];
	}
	
	// "today"
	[aString replaceOccurrencesOfString:@"&#xAB;today&#xBB;" withString:[date stringFromDate: [NSDate date]] options:NSLiteralSearch range:aString.range];
	[aString replaceOccurrencesOfString:@"«today»" withString:[date stringFromDate: [NSDate date]] options:NSLiteralSearch range:aString.range];
    
    [aString replaceOccurrencesOfString:@"&#xAB;longtoday&#xBB;" withString:[longDate stringFromDate: [NSDate date]] options:NSLiteralSearch range:aString.range];
	[aString replaceOccurrencesOfString:@"«longtoday»" withString:[longDate stringFromDate: [NSDate date]] options:NSLiteralSearch range:aString.range];
	
	NSArray	*seriesArray = [[BrowserController currentBrowser] childrenArray: aStudy];
	NSArray	*imagePathsArray = [[BrowserController currentBrowser] imagesPathArray: [seriesArray objectAtIndex: 0]];
	
	// DICOM Fields
	BOOL moreFields = NO;
	do
	{
		NSRange firstChar = [aString rangeOfString: @"&#xAB;DICOM_FIELD:"];
		
		if( firstChar.location == NSNotFound)
			firstChar = [aString rangeOfString: @"«DICOM_FIELD:"];
		
		if( firstChar.location != NSNotFound)
		{
			NSRange secondChar = [aString rangeOfString: @"&#xBB;" options: 0 range: NSMakeRange( firstChar.location+firstChar.length, aString.length - (firstChar.location+firstChar.length)) locale: nil];
			if( secondChar.location == NSNotFound)
				secondChar = [aString rangeOfString: @"»"];
			
			if( secondChar.location != NSNotFound)
			{
				NSString *dicomField = [aString substringWithRange: NSMakeRange( firstChar.location+firstChar.length, secondChar.location - (firstChar.location+firstChar.length))];
				
                if( dicomField.length) // delete the <blabla> strings
                {
                    dicomField = [dicomField stringByReplacingOccurrencesOfString:@" " withString:@""];
                    
                    NSRange sChar;
                    do
                    {
                        sChar = [dicomField rangeOfString: @"<"];
                        if( sChar.location != NSNotFound)
                        {
                            NSRange sChar2 = [dicomField rangeOfString: @">"];
                            
                            if( sChar2.location != NSNotFound)
                                dicomField = [dicomField stringByReplacingCharactersInRange:NSMakeRange( sChar.location, sChar2.location + sChar2.length - sChar.location) withString:@""];
                        }
                    }
                    while( sChar.location != NSNotFound);
				}
                
                NSString *s = [self getDICOMStringValueForField: dicomField inDICOMFile: [imagePathsArray objectAtIndex: 0]];
                
				if( s)
                    [aString replaceCharactersInRange:NSMakeRange(firstChar.location, secondChar.location-firstChar.location+secondChar.length) withString: s];
                else
                    [aString replaceCharactersInRange:NSMakeRange(firstChar.location, secondChar.location-firstChar.location+secondChar.length) withString:@""];
                
				moreFields = YES;
			}
			else
                moreFields = NO;
		}
		else
            moreFields = NO;
	}
    
	while( moreFields)
        ;
}

#pragma mark - Word

+(void)checkForWordTemplates
{
#ifndef MIELE_LIGHT
    @try {
        NSString *path = BrowserController.currentBrowser.database.baseDirPath;
        
        if (path == nil)
            path = DicomDatabase.defaultBaseDirPath;
        
        // previously, we had a single word template in the Data folder
        NSString* oldReportFilePath = [path stringByAppendingPathComponent:TEMPLATES_PATH @"/ReportTemplate.doc"];
        
        // today, we use a dir in the database folder, which contains the templates
        NSString* templatesDirPath1 = [Reports databaseWordTemplatesDirPath];
        if (templatesDirPath1 == nil)
            return;
        
        NSUInteger templatesCount = 0;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:templatesDirPath1])
        {
            for (NSString* filename in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatesDirPath1 error:NULL])
            {
                if( [filename.pathExtension isEqualToString: @"doc"])
                    ++templatesCount;
            }
        }
        
        if (!templatesCount) // templatesCount == 0 ?
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath: oldReportFilePath])
            {
                [[NSFileManager defaultManager] moveItemAtPath: oldReportFilePath
                                                        toPath: [templatesDirPath1 stringByAppendingPathComponent: [oldReportFilePath lastPathComponent]]
                                                         error: nil];
            }
            else
            {
                NSString *srcPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"ReportTemplate.doc"];
                NSString *dstPath = [templatesDirPath1 stringByAppendingPathComponent:@"Basic Report Template.doc"];
                [[NSFileManager defaultManager] copyItemAtPath:srcPath
                                                        toPath:dstPath
                                                         error:NULL];
            }
        }
    }
    @catch (NSException *exception) {
        N2LogException( exception);
    }
#endif
}

+(NSString*)databaseWordTemplatesDirPath {
    
    NSString *path = BrowserController.currentBrowser.database.baseDirPath;
    
    if (path == nil)
        path = DicomDatabase.defaultBaseDirPath;
    
    path = [path stringByAppendingPathComponent:TEMPLATES_PATH];
    NSString *folder = [path stringByAppendingPathComponent:@"WORD"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([fm fileExistsAtPath: folder isDirectory: &isDirectory] && isDirectory) {
        return folder;
    }
    
    NSError *error = nil;
    
    if ([fm fileExistsAtPath:folder]) {
        [fm removeItemAtPath: folder error: &error];
        if (error)
            NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, error.localizedDescription);
    }

    [[NSFileManager defaultManager] createDirectoryAtPath: folder
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
    if (error)
        NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, error.localizedDescription);

    return folder;
}

+(NSString*)resolvedDatabaseWordTemplatesDirPath {
    return [[NSFileManager defaultManager] destinationOfAliasOrSymlinkAtPath:[self databaseWordTemplatesDirPath]];
}

+ (NSMutableArray*)wordTemplatesList
{
	NSMutableArray* templatesArray = [NSMutableArray array];
    
	NSDirectoryEnumerator* directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self resolvedDatabaseWordTemplatesDirPath]];
	NSString* filename;
	while ((filename = [directoryEnumerator nextObject]))
	{
		[directoryEnumerator skipDescendents];
        
        if( [filename.pathExtension hasPrefix: @"doc"]) //hasPrefix: compatible with .doc and .docx
            [templatesArray addObject: filename];
	}
	
	return templatesArray;
}

- (NSString*) generateWordReportMergeDataForStudy:(NSManagedObject*) study
{
	NSManagedObjectModel *model = [[[study managedObjectContext] persistentStoreCoordinator] managedObjectModel];
    
	NSArray *properties = [[[[model entitiesByName] objectForKey:@"Study"] attributesByName] allKeys];
	
	NSMutableString	*file = [NSMutableString stringWithString:@""];
	
	for (long x = 0; x < [properties count]; x++)
	{
		NSString *name = [properties objectAtIndex: x];
		[file appendString:name];
		[file appendFormat: @"%c", NSTabCharacter];
	}
	
	[file appendString:@"\r"];
	
	NSDateFormatter *date = [[[NSDateFormatter alloc] init] autorelease];
	[date setDateStyle: NSDateFormatterShortStyle];
	
	for (long x = 0; x < [properties count]; x++)
	{
		NSString *name = [properties objectAtIndex: x];
		NSString *string;
		
		if( [[study valueForKey: name] isKindOfClass: [NSDate class]])
			string = [date stringFromDate: [study valueForKey: name]];
		else
            string = [[study valueForKey: name] description];
		
		if( string)
			[file appendString: [DicomFile NSreplaceBadCharacter:string]];
		else
			[file appendString: @""];
		
		[file appendFormat: @"%c", NSTabCharacter];
	}
	
	NSString *path = [BrowserController.currentBrowser.database.baseDirPath stringByAppendingFormat:@"/%@/Report.rtf", TEMP_PATH];
	
	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
	
	NSMutableAttributedString *rtf = [[[NSMutableAttributedString alloc] initWithString: file] autorelease];
	
    [[rtf RTFFromRange:rtf.range documentAttributes:@{}] writeToFile: path atomically:YES]; // To support full encoding in MicroSoft Word
	
	return path;
}

- (BOOL)createNewWordReportForStudy:(NSManagedObject*)study toDestinationPath:(NSString*)destinationFile
{
    // Applescript doesn't support UTF-8 encoding
    
//    NSString* tempPath = [[[destinationFile stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"MSTempReport"] stringByAppendingPathExtension:[destinationFile pathExtension]];
  //  [[NSFileManager defaultManager] removeItemAtPath: tempPath error: nil];
    
    [[NSFileManager defaultManager] removeItemAtPath:destinationFile error: nil];
    
    NSString* inTemplateName = _templateName;
    
    if( inTemplateName.length == 0 && [[Reports wordTemplatesList] count])
        inTemplateName = [[Reports wordTemplatesList] objectAtIndex: 0];
    
    NSString* sourceData = [self generateWordReportMergeDataForStudy:study];
    NSString* templatePath = nil;
    
    NSString* templatesDirPath2 = [[self class] resolvedDatabaseWordTemplatesDirPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:templatesDirPath2])
    {
        for( NSString *filename in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:templatesDirPath2 error:NULL])
        {
            if( [filename.pathExtension hasPrefix: @"doc"] && [filename.stringByDeletingPathExtension isEqualToString: inTemplateName.stringByDeletingPathExtension])
                templatePath = [templatesDirPath2 stringByAppendingPathComponent: filename];
        }
    }
    
    if( templatePath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:templatePath])
    {
        NSRunCriticalAlertPanel(NSLocalizedString( @"Microsoft Word", nil),
                                NSLocalizedString(@"I cannot find the OsiriX Word Template doc file.", nil),
                                NSLocalizedString(@"OK", nil),
                                nil,
                                nil);
        return NO;
    }
    
	NSString* source =
    @"on run argv\n"
    @"  set dataSourceFileUnix to (item 1 of argv)\n"
	@"  set outFilePathUnix to (item 2 of argv)\n"
	@"  set templatePathUnix to (item 3 of argv)\n"
	@"  set dataSourceFile to POSIX file dataSourceFileUnix\n"
    @"  set outFilePath to POSIX file outFilePathUnix\n"
    @"  set templatePath to POSIX file templatePathUnix\n"
    @"  tell application \"Microsoft Word\"\n"
    @"    open templatePath\n"
    @"    open data source data merge of document 1 name dataSourceFile\n"
    @"    set myMerge to data merge of document 1\n"
    @"    set destination of myMerge to send to new document\n"
    @"    execute data merge myMerge\n"
    @"    save as document 1 file name (outFilePath as string)\n"
    @"    close document 2 saving no\n" // close the non-merged file
    @"  end tell\n"
    @"end run\n";
	
//	NSLog(@"%@", source);
    
    @try {
        [[self class] _runAppleScript:source
                        withArguments:[NSArray arrayWithObjects: sourceData, destinationFile, templatePath, nil]];
    }
    @catch( NSException* e) {
        NSLog( @"Exception: %@", e.reason);
        return NO;
    }
    
    [study setValue:destinationFile forKey: @"reportURL"];
    
    [[NSWorkspace sharedWorkspace] openFile:destinationFile withApplication:@"Microsoft Word" andDeactivate:YES]; // it's already open, but we're making it come to foreground
    [NSThread sleepForTimeInterval:1]; // why?
    
    return YES;
}

#pragma mark - OpenDocument

- (BOOL) createNewOpenDocumentReportForStudy:(NSManagedObject*)aStudy toDestinationPath:(NSString*)aPath;
{
	// decompress the gzipped index.xml.gz file in the .pages bundle
	NSTask *unzip = [[[NSTask alloc] init] autorelease];
	[unzip setLaunchPath:@"/usr/bin/unzip"];
	[unzip setCurrentDirectoryPath: [aPath stringByDeletingLastPathComponent]];
	
	[[NSFileManager defaultManager] removeItemAtPath: [[aPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"OOOsiriX"] error: nil];
	[unzip setArguments: [NSArray arrayWithObjects: aPath, @"-d", @"OOOsiriX", nil]];
	[unzip launch];

	while( [unzip isRunning])
        [NSThread sleepForTimeInterval: 0.1];
    
    //[aTask waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
	int status = [unzip terminationStatus];
 
	if (status != EXIT_SUCCESS)	{
        NSLog(@"OO Report creation. Error: unzip -d failed.");
		return NO;
	}

#ifndef NDEBUG
    NSLog(@"OO Report creation. unzip -d succeeded.");
#endif

    // Read the XML file, then find and replace templated string with patient's data
	NSString *indexFilePath = [NSString stringWithFormat:@"%@/OOOsiriX/content.xml", [aPath stringByDeletingLastPathComponent]];
	NSError *xmlError = nil;
	NSStringEncoding xmlFileEncoding = NSUTF8StringEncoding;
	NSMutableString *xmlContentString = [NSMutableString stringWithContentsOfFile:indexFilePath encoding:xmlFileEncoding error:&xmlError];
	
	[self searchAndReplaceFieldsFromStudy:aStudy inString:xmlContentString];
	
	if (![xmlContentString writeToFile:indexFilePath atomically:YES encoding:xmlFileEncoding error:&xmlError])
		return NO;
	
	// zip back the index.xml file
	unzip = [[[NSTask alloc] init] autorelease];
	[unzip setLaunchPath:@"/usr/bin/zip"];
	[unzip setCurrentDirectoryPath: [[aPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"OOOsiriX"]];
	[unzip setArguments: [NSArray arrayWithObjects: @"-q", @"-r", aPath, @"content.xml", nil]];
	[unzip launch];

	while( [unzip isRunning])
        [NSThread sleepForTimeInterval: 0.1];
    
    //[aTask waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
	status = [unzip terminationStatus];
 
	if (status == EXIT_SUCCESS)
		NSLog(@"OO Report creation. zip succeeded.");
	else
	{
		NSLog(@"OO Report creation. Error: zip failed.");
		// we don't need to return NO, because the xml has been modified. Thus, even if the file is not compressed, the report is valid...
	}
	
	[[NSFileManager defaultManager] removeItemAtPath: [[aPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"OOOsiriX"] error: nil];
	
	[aStudy setValue:aPath forKey:@"reportURL"];
	
	// open the modified .odt file
	if ([[NSWorkspace sharedWorkspace] openFile:aPath withApplication: @"LibreOffice" andDeactivate: YES] == NO)
    {
        if ([[NSWorkspace sharedWorkspace] openFile:aPath withApplication: @"OpenOffice" andDeactivate: YES] == NO)
            [[NSWorkspace sharedWorkspace] openFile:aPath withApplication: nil andDeactivate: YES];
	}
    [NSThread sleepForTimeInterval: 1];

	return YES;
}

#pragma mark - Pages.app

static BOOL Pages5orHigher = FALSE;

+(NSString*)databasePagesTemplatesDirPath
{
    NSString *path = BrowserController.currentBrowser.database.baseDirPath;
    
    if (path == nil)
        path = DicomDatabase.defaultBaseDirPath;
    
    path = [path stringByAppendingPathComponent:TEMPLATES_PATH];
    return [path stringByAppendingPathComponent:@"PAGES"];
}

// Called from AppController initialize
// Called again from DicomDatabase initiWithPath
+ (void)checkForPagesTemplate;
{
#ifndef MIELE_LIGHT
	NSString* templatesDirPath3 = [Reports databasePagesTemplatesDirPath];

#ifndef NDEBUG
    NSLog(@"%s templatesDirPath:%@", __FUNCTION__, templatesDirPath3);
#endif

    if ([[NSFileManager defaultManager] fileExistsAtPath:templatesDirPath3] == NO)
        [[NSFileManager defaultManager] createDirectoryAtPath:templatesDirPath3
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    
	// Pages template
    NSString *defaultReport = [templatesDirPath3 stringByAppendingPathComponent:@"Basic Report.pages"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: defaultReport] == NO)
		[[NSFileManager defaultManager] copyItemAtPath: [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Report.pages"]
                                                toPath: defaultReport
                                                 error:nil];
	
#endif
}

+ (BOOL) Pages5orHigher
{
    if (Pages5orHigher)
        return TRUE;
    
    // Pages 09 (4.0) or 2013 (5.0) ??
    NSString *appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iWork.Pages"];
    if (appPath.length > 0)
    {
        // Example: 0700 for version 5.6.2
        // Example: 1110 for version 8.2
        NSString *version = [[[NSBundle bundleWithPath: appPath] infoDictionary] objectForKey:@"DTXcode"];
        if (version.integerValue >= 500)
            Pages5orHigher = YES;
    }
    
    return Pages5orHigher;
}

- (void) decompressPagesFileIfNecessary: (NSString*) aPath
{
#ifndef NDEBUG
    NSLog(@"%s:%d path:\n\t%@", __FUNCTION__, __LINE__, aPath);
#endif

    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath: aPath isDirectory: &isDirectory] && isDirectory == NO)
    {
#define UNZIPPEDNAME @"unzipped"
        
        // Decompress .pages file because they actually are zip files (starting with "PK")
        NSTask *unzip = [[[NSTask alloc] init] autorelease];
        [unzip setLaunchPath:@"/usr/bin/unzip"];
        [unzip setCurrentDirectoryPath:aPath.stringByDeletingLastPathComponent];
        [unzip setArguments:[NSArray arrayWithObjects:
                             @"-qq",    // quiet
                             @"-o",     // overwrite existing files without prompting
                             @"-d", UNZIPPEDNAME, // An optional directory to which to extract files
                             aPath,
                             nil]];
        [unzip launch];
        
        while( [unzip isRunning])
            [NSThread sleepForTimeInterval: 0.1];
        
        //[aTask waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
        int status = [unzip terminationStatus];
        
        if (status != EXIT_SUCCESS) {
            NSLog(@"Pages Report creation. Error: unzip -d failed.");
            return;
        }

#ifndef NDEBUG
        NSLog(@"Pages Report creation. unzip -d succeeded.");
#endif

        [[NSFileManager defaultManager] removeItemAtPath: aPath error: nil];

        [[NSFileManager defaultManager] moveItemAtPath: [aPath.stringByDeletingLastPathComponent stringByAppendingPathComponent: UNZIPPEDNAME]
                                                toPath: aPath
                                                 error: nil];
    }
}

- (BOOL)createNewPagesReportForStudy:(NSManagedObject*)aStudy toDestinationPath:(NSString*)aPath;
{	
	// create the Pages file, using the template (not filling the patient's data yet)
	
	[[NSFileManager defaultManager] removeItemAtPath:aPath error:NULL];
    
    NSString* templatePath = [[self class] pathForPagesTemplate: _templateName];

#ifndef NDEBUG
    //NSLog(@"%s:%d copy templatePath:\n\t%@ to\n\t%@", __FUNCTION__, __LINE__, templatePath, aPath);
#endif
    if (templatePath) {
        [[NSFileManager defaultManager] copyItemAtPath: templatePath
                                                toPath: aPath
                                   byReplacingExisting: YES
                                                 error: nil];
    }
    else {
		NSRunCriticalAlertPanel(NSLocalizedString(@"Pages", nil),
                                NSLocalizedString(@"Failed to create the report with Pages.", nil),
                                NSLocalizedString(@"OK", nil),
                                nil,
                                nil);
        return NO;
	}
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:aPath] == NO) {
		NSRunCriticalAlertPanel(NSLocalizedString(@"Pages", nil),
                                NSLocalizedString(@"Failed to create the report with Pages.", nil),
                                NSLocalizedString(@"OK", nil),
                                nil,
                                nil);
        return NO;
	}

    [self decompressPagesFileIfNecessary: aPath];
    
	// Read the xml file, then find and replace templated string with patient's data
    NSString *indexFilePath = [aPath stringByAppendingPathComponent:@"index.xml"];

#ifndef MACAPPSTORE
    if ([[NSFileManager defaultManager] fileExistsAtPath:indexFilePath] == NO)
    {
        // Old pages format don't have index.xml try to convert it with AppleScript
        // Problem: "Not authorized to send Apple events to Pages."

        NSString* path = [[NSBundle mainBundle] pathForResource:@"pages2pages09" ofType:APPLESCRIPT_EXTENSION];
  #ifndef NDEBUG
        //NSLog(@"%s:%d, conversion script exists:%@, at path:\n\t%@", __FUNCTION__, __LINE__, [[NSFileManager defaultManager] fileExistsAtPath:path] ? @"Y" : @"N", path);
  #endif
        if (path.length > 0) {
            //NSLog(@"Try to convert template <%@> to Pages 09 format", templateName);
            @try
            {
                NSDictionary* errs = nil;
                NSArray *args = [NSArray arrayWithObjects:
                                 templatePath,  // input file
                                 [templatePath stringByAppendingString: @"09.pages"], // output file
                                 nil];

#ifdef COMPILED_APPLESCRIPT_IN_BUNDLE
                NSAppleScript* script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&errs];
                if (errs)
                    NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, errs);
#else
                NSError *error = nil;
                NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
                if (error)
                    NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, error.localizedDescription);

                NSAppleScript* script = [[[NSAppleScript alloc] initWithSource:source] autorelease];
#endif
                //id r =
                [script runWithArguments:args error:&errs];  // N2 category
                //NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, r);
                if (errs)
                    NSLog(@"%s:%d %@", __FUNCTION__, __LINE__, errs); // Not authorized to send Apple events to Pages
            }
            @catch (NSException *e)
            {
                NSLog(@"Error running AppleScript: %@", e);
            }
        }

        // Retry with a template ending in "09.pages"
        if( [[NSFileManager defaultManager] fileExistsAtPath: [templatePath stringByAppendingString: @"09.pages"]])
        {
            [[NSFileManager defaultManager] removeItemAtPath: templatePath error: nil];

            [[NSFileManager defaultManager] moveItemAtPath: [templatePath stringByAppendingString: @"09.pages"]
                                                    toPath:templatePath
                                                     error: nil];

            [[NSFileManager defaultManager] removeItemAtPath: aPath error: nil];

            [[NSFileManager defaultManager] copyItemAtPath: templatePath
                                                    toPath: aPath
                                       byReplacingExisting: YES
                                                     error: nil];
            
            [self decompressPagesFileIfNecessary: aPath];
        }

        if( [[NSFileManager defaultManager] fileExistsAtPath:indexFilePath] == NO)
        {
            NSRunCriticalAlertPanel(NSLocalizedString(@"Pages", nil),
                                    NSLocalizedString(@"OsiriX requires templates files in Pages '09 format. Open your template in Pages, select File menu and Export to Pages '09 format.", nil),
                                    NSLocalizedString(@"OK", nil),
                                    nil,
                                    nil);
            return NO;
        }
    }
#endif // MACAPPSTORE

	NSError *xmlError = nil;
	NSStringEncoding xmlFileEncoding = NSUTF8StringEncoding;
	NSMutableString *xmlContentString = [NSMutableString stringWithContentsOfFile:indexFilePath encoding:xmlFileEncoding error:&xmlError];

	[self searchAndReplaceFieldsFromStudy:aStudy inString:xmlContentString];
	
	if(![xmlContentString writeToFile:indexFilePath atomically:YES encoding:xmlFileEncoding error:&xmlError])
		return NO;
	
	[aStudy setValue: aPath forKey:@"reportURL"];
	
	// open the modified .pages file
	[[NSWorkspace sharedWorkspace] openFile:aPath withApplication:@"Pages" andDeactivate: YES];
	[NSThread sleepForTimeInterval: 1];
	
	// end
	return YES;
}

+ (NSString*) pathForPagesTemplate: (NSString*) templateName
{
    if (templateName.length == 0 &&
       [[Reports pagesTemplatesList] count])
    {
        templateName = [[Reports pagesTemplatesList] objectAtIndex: 0];
    }
    
    if ([Reports Pages5orHigher])
    {
        NSString *templateDirectory = [self databasePagesTemplatesDirPath];
        NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:templateDirectory];
        
        NSString *file;
        while ((file = [directoryEnumerator nextObject]))
        {
            [directoryEnumerator skipDescendents];
            if( [file.stringByDeletingPathExtension isEqualToString: templateName.stringByDeletingPathExtension])
            {
                if( [file.pathExtension isEqualToString: @"pages"])
                    return [templateDirectory stringByAppendingPathComponent: file];
            }
        }
    }
    else
    {
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        NSArray *templateDirectoryPathArray = [NSArray arrayWithObjects:
                                               NSHomeDirectory(),
                                               @"Library",
                                               @"Application Support",
                                               @"iWork",
                                               @"Pages",
                                               @"Templates",
                                               bundleName,
                                               nil];
        NSString *templateDirectory = [NSString pathWithComponents:templateDirectoryPathArray];
        NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:templateDirectory];
        
        id file;
        while (file = [directoryEnumerator nextObject])
        {
            [directoryEnumerator skipDescendents];
            
            if ([file isEqualToString: templateName] ||
                [file isEqualToString: [NSString stringWithFormat: @"%@%@", templatePrefix, templateName]])
                return [templateDirectory stringByAppendingPathComponent: file];
        }
    }
    
    return nil;
}

+ (void) copyPages4templatesToPages5: (NSString*) newDirectory
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    //NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *templateDirectoryPathArray = [NSArray arrayWithObjects:
                                           NSHomeDirectory(),
                                           @"Library",
                                           @"Application Support",// TODO: use appSupportDir
                                           @"iWork",
                                           @"Pages",
                                           @"Templates",
                                           bundleName,
                                           nil];
    NSString *templateDirectory = [NSString pathWithComponents:templateDirectoryPathArray];
    NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:templateDirectory];

    id file;
    while ((file = [directoryEnumerator nextObject]))
    {
        [directoryEnumerator skipDescendents];
        NSRange rangeOfOsiriX = [file rangeOfString:templatePrefix];
        if (rangeOfOsiriX.location == 0 &&
            rangeOfOsiriX.length == templatePrefix.length)
        {
            NSString *fromPath = [templateDirectory stringByAppendingPathComponent: file];
            NSString *toPath = [newDirectory stringByAppendingPathComponent: file];
            
            toPath = [[toPath stringByDeletingPathExtension] stringByAppendingPathExtension: @"pages"];
            
            [[NSFileManager defaultManager] copyItemAtPath: fromPath toPath: toPath byReplacingExisting: NO error: nil];
        }
    }
}

+ (NSMutableArray*)pagesTemplatesList;
{
    NSMutableArray *templatesArray = [NSMutableArray array];

    if ([Reports Pages5orHigher])
    {
        NSString *templateDirectory = [self databasePagesTemplatesDirPath];
        
        static BOOL firstTime = YES;
        if (firstTime)
        {
            firstTime = NO;
            [Reports copyPages4templatesToPages5: templateDirectory];
        }
        
        NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:templateDirectory];
        NSString *file;
        while ((file = [directoryEnumerator nextObject]))
        {
            [directoryEnumerator skipDescendents];
            if ([file.pathExtension isEqualToString: @"pages"])
                [templatesArray addObject: file];
        }
    }
    else {    // System is running Pages 4 or older
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        //NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        NSArray *templateDirectoryPathArray = [NSArray arrayWithObjects:
                                               NSHomeDirectory(),
                                               @"Library",
                                               @"Application Support", // TODO: use appSupportDir
                                               @"iWork",
                                               @"Pages",
                                               @"Templates",
                                               bundleName,
                                               nil];
        NSString *templateDirectory = [NSString pathWithComponents:templateDirectoryPathArray];
        NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:templateDirectory];
        
        id file;
        while ((file = [directoryEnumerator nextObject]))
        {
            [directoryEnumerator skipDescendents];
            NSRange rangeOfOsiriX = [file rangeOfString:templatePrefix];
            if (rangeOfOsiriX.location == 0 &&
                rangeOfOsiriX.length == templatePrefix.length)
            {
                // this is a template for us (we should maybe verify that it is a valid Pages template... but what ever...)
                [templatesArray addObject:[file substringFromIndex:templatePrefix.length]];
            }
        }
    }

    return templatesArray;
}

#pragma mark - setters / getters

//- (NSMutableString *)templateName;
//{
//	return templateName;
//}

- (void)setTemplateName:(NSString *)aName;
{
	[_templateName setString:aName];
	[_templateName replaceOccurrencesOfString:@".pages" withString:@"" options:NSLiteralSearch range:_templateName.range];
    [_templateName replaceOccurrencesOfString:@".docx" withString:@"" options:NSLiteralSearch range:_templateName.range];
    [_templateName replaceOccurrencesOfString:@".doc" withString:@"" options:NSLiteralSearch range:_templateName.range];
}

@end
