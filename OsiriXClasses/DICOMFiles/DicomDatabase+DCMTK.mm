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

#undef verify
#include "dcmtk/config/osconfig.h" /* make sure OS specific configuration is included first */

#import "DicomDatabase+DCMTK.h"
#import <DCM/DCMObject.h>
#import <DCM/DCM.h>
#import <DCM/DCMTransferSyntax.h>
#import <DCM/DCMAbstractSyntaxUID.h>
#import "DCMPix.h"
#import "AppController.h"
#import "BrowserController.h"
#import "SRAnnotation.h"
#import "NSThread+N2.h"
#import "N2Debug.h"
#import "WaitRendering.h"

#include "dcmtk/dcmjpeg/djdecode.h"  /* for dcmjpeg decoders */
#include "dcmtk/dcmjpeg/djencode.h"  /* for dcmjpeg encoders */
#include "dcmtk/dcmdata/dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcmtk/dcmdata/dcrleerg.h"  /* for DcmRLEEncoderRegistration */
#include "dcmtk/dcmjpeg/djrploss.h"
#include "dcmtk/dcmjpeg/djrplol.h"
#include "dcmtk/dcmdata/dcpixel.h"
#include "dcmtk/dcmdata/dcrlerp.h"

#include "dcmtk/dcmdata/dcdatset.h"
#include "dcmtk/dcmdata/dcmetinf.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmdata/dcuid.h"
#include "dcmtk/dcmdata/dcdict.h"
#include "dcmtk/dcmdata/dcdeftag.h"

#import "tmp_locations.h"

#define CHUNK_SUBPROCESS    200
#define TIMEOUT             20UL

// Maximum of 200 files: no more than 10 min...

@implementation DicomDatabase (DCMTK)

+(BOOL)fileNeedsDecompression:(NSString*)path
{
	DcmFileFormat fileformat;
	OFCondition cond = fileformat.loadFile( [path UTF8String]);
	if (cond.bad())
        return NO;

    DcmDataset *dataset = fileformat.getDataset();
//	DcmItem *metaInfo = fileformat.getMetaInfo();
    DcmXfer original_xfer(dataset->getOriginalXfer());
    if (original_xfer.isEncapsulated())
        return NO;

    const char *string = NULL;
    NSString *modality = @"OT";
    if (dataset->findAndGetString(DCM_Modality, string, OFFalse).good() && string != NULL)
        modality = [NSString stringWithCString:string encoding: NSASCIIStringEncoding];
    
    NSString *SOPClassUID = @"";
    if (dataset->findAndGetString(DCM_SOPClassUID, string, OFFalse).good() && string != NULL)
        SOPClassUID = [NSString stringWithCString:string encoding: NSASCIIStringEncoding];
    
    // See Decompress.mm for these exceptions
    if ([DCMAbstractSyntaxUID isImageStorage: SOPClassUID] == YES &&
       [SOPClassUID isEqualToString:[DCMAbstractSyntaxUID pdfStorageClassUID]] == NO &&
       [SOPClassUID isEqualToString:[DCMAbstractSyntaxUID EncapsulatedCDAStorage]] == NO &&
       [DCMAbstractSyntaxUID isStructuredReport: SOPClassUID] == NO)
    {
        int resolution = 0;
        unsigned short rows = 0;
        if (dataset->findAndGetUint16( DCM_Rows, rows, OFFalse).good())
        {
            if (resolution == 0 || resolution > rows)
                resolution = rows;
        }

        unsigned short columns = 0;
        if (dataset->findAndGetUint16( DCM_Columns, columns, OFFalse).good())
        {
            if (resolution == 0 || resolution > columns)
                resolution = columns;
        }
        
        int quality, compression = [BrowserController compressionForModality: modality quality: &quality resolution: resolution];
        
        if (compression == compression_none)
            return NO;
        
        return YES;
    }
	
	return NO;
}


+(BOOL)compressDicomFilesAtPaths:(NSArray*)paths {
	return [self compressDicomFilesAtPaths:paths intoDirAtPath:nil];
}

+(BOOL)decompressDicomFilesAtPaths:(NSArray*)paths {
	return [self decompressDicomFilesAtPaths:paths intoDirAtPath:nil];
}

+(BOOL)compressDicomFilesAtPaths:(NSArray*)paths intoDirAtPath:(NSString*)dest
{
	if (dest == nil)
		dest = @"sameAsDestination";
	
	int total = [paths count];
	NSThread* thread = [NSThread currentThread];
	[thread enterOperation];
	
	for( int i = 0; i < total;)
	{
		int no;
		if (i + CHUNK_SUBPROCESS >= total)
            no = total - i;
		else
            no = CHUNK_SUBPROCESS;
		
		if (i || i+no<total)
			thread.progress = 1.0*i/total;
		
		NSRange range = NSMakeRange( i, no);
		
		id *objs = (id*) malloc( no * sizeof( id));
		if (objs)
		{
			[paths getObjects: objs range: range];
			
			NSArray *subArray = [NSArray arrayWithObjects: objs count: no];
			
			NSTask *theTask = [[NSTask alloc] init];
			@try
            {
                NSString *launchPath = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"Decompress"] path];
				[theTask setLaunchPath:launchPath];
				[theTask setArguments:[[NSArray arrayWithObjects: dest, @"compress", nil] arrayByAddingObjectsFromArray: subArray]];
				[theTask launch];
                
                NSTimeInterval timeout = TIMEOUT * subArray.count;
                if (timeout < 600)
                    timeout = 600;
                NSTimeInterval taskStart = [NSDate timeIntervalSinceReferenceDate];
				while( [theTask isRunning])
                {
                    [NSThread sleepForTimeInterval: 0.1];
                    if ([NSDate timeIntervalSinceReferenceDate] - taskStart > timeout)
                        break;
                }
                
                if ([theTask isRunning])
                {
                    N2LogStackTrace( @"***** task timeout reached -> terminate the NSTask : %@", paths);
                    [theTask terminate];
                }
                else if ([theTask terminationReason] == NSTaskTerminationReasonUncaughtSignal)
                {
                    N2LogStackTrace( @"***** Decompress process crashed.");
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"DELETEFILELISTENER"])
                    {
                        for( NSString *path in paths)
                            [[NSFileManager defaultManager] moveItemAtPath: path toPath: [[[DicomDatabase defaultDatabase] errorsDirPath] stringByAppendingPathComponent: [path lastPathComponent]] error: nil];
                    }
                }
                
			} @catch (NSException *e) {
				N2LogExceptionWithStackTrace(e);
			}
			
			[theTask release];
			free( objs);
		}
		
		i += no;
	}
	
	[thread exitOperation];
	return YES;
	
//    #ifndef MIELE_LIGHT
//	@synchronized( [BrowserController currentBrowser])
//	{
//		for( NSString *path in paths)
//		{
//			DcmFileFormat fileformat;
//			OFCondition cond = fileformat.loadFile( [path UTF8String]);
//			
//			if (cond.good())
//			{
//				DJ_RPLossy lossyParams( DCMHighQuality);
//				DJ_RPLossless losslessParams(6,0);
//				
//				DcmDataset *dataset = fileformat.getDataset();
//				DcmItem *metaInfo = fileformat.getMetaInfo();
//				DcmXfer original_xfer(dataset->getOriginalXfer());
//				
//				DcmRepresentationParameter *params = &lossyParams;
//				E_TransferSyntax tSyntax = EXS_JPEG2000;	// EXS_JPEGLSLossless;
//				
////				DcmRepresentationParameter *params = &losslessParams;
////				E_TransferSyntax tSyntax = EXS_JPEGProcess14TransferSyntax;	//EXS_JPEG2000; //EXS_JPEG2000LosslessOnly
//				
//				DcmXfer oxferSyn( tSyntax);
//				dataset->chooseRepresentation(tSyntax, params);
//				
//				fileformat.loadAllDataIntoMemory();
//				
//				// check if everything went well
//				if (dataset->canWriteXfer(tSyntax))
//				{
//					// store in lossless JPEG format
//					//fileformat.loadAllDataIntoMemory();
//					
//					[[NSFileManager defaultManager] removeItemAtPath: [path stringByAppendingString: @"cc.dcm"] error:nil];
//					cond = fileformat.saveFile( [[path stringByAppendingString: @"cc.dcm"] UTF8String], tSyntax);
//					BOOL status = (cond.good()) ? YES : NO;
//					
//					if (status == NO)
//						NSLog( @"failed to compress file: %@", [paths lastObject]);
//				}
//				else NSLog( @"err");
//			}
//			else NSLog( @"err");
//		}
//	}
//    #endif
//	return YES;
//
//	@synchronized( [BrowserController currentBrowser])
//	{
//		for( int i = DCMLosslessQuality ; i <= DCMLowQuality ; i++)
//		{
//			DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile: [paths lastObject] decodingPixelData: NO];
//									
//			BOOL succeed = NO;
//			
//			@try
//			{
//				DCMTransferSyntax *tsx = [DCMTransferSyntax JPEG2000LossyTransferSyntax]; // JPEG2000LosslessTransferSyntax];
//				
//				succeed = [dcmObject writeToFile:[NSString stringWithFormat: @"/tmp/testjp-%d.dcm", i]
//                              withTransferSyntax:tsx
//                                         quality:i
//                                             AET:@OUR_AET
//                                      atomically:YES];
//			}
//			@catch (NSException *e)
//			{
//				NSLog( @"dcmObject writeToFile failed: %@", e);
//			}
//			[dcmObject release];
//		}
//		return YES;
//	}

// ********

//	NSLog( @"** START");
//	NSString *dest2 = [paths lastObject];
//	
//	DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile: [paths lastObject] decodingPixelData: NO];
//	
//	BOOL succeed = NO;
//	
//	@try
//	{
//		succeed = [dcmObject writeToFile:[dest2 stringByAppendingString: @" temp"]
//                      withTransferSyntax:[DCMTransferSyntax JPEG2000LossyTransferSyntax]
//                                 quality:0
//                                     AET:@OUR_AET
//                              atomically:YES];
//	}
//	@catch (NSException *e)
//	{
//		NSLog( @"dcmObject writeToFile failed: %@", e);
//	}
//	[dcmObject release];
//	
//	if (succeed)
//	{
//		if (dest2 == [paths lastObject])
//			[[NSFileManager defaultManager] removeItemAtPath: [paths lastObject] error: nil];
//		[[NSFileManager defaultManager] moveItemAtPath: [dest2 stringByAppendingString: @" temp"] toPath: dest2 error: nil];
//	}
//	else
//	{
//		NSLog( @"failed to compress file: %@", [paths lastObject]);
//		[[NSFileManager defaultManager] removeItemAtPath: [dest2 stringByAppendingString: @" temp"] error: nil];
//	}
//	NSLog( @"** END");
}

+(BOOL)decompressDicomFilesAtPaths:(NSArray*)files intoDirAtPath:(NSString*)dest
{
	if (dest == nil)
		dest = @"sameAsDestination";
	
	int total = [files count];
	NSThread* thread = [NSThread currentThread];
	[thread enterOperation];
	
	for (int i = 0; i < total;)
	{
		int no;
		if (i + CHUNK_SUBPROCESS >= total)
            no = total - i;
		else
            no = CHUNK_SUBPROCESS;
		
		if (i || i+no<total)
			thread.progress = 1.0*i/total;
		
		NSRange range = NSMakeRange( i, no);
		
		id *objs = (id*) malloc( no * sizeof( id));
		if (objs)
		{
			[files getObjects: objs range: range];
			
			NSArray* subArray = [NSArray arrayWithObjects:objs count:no];
			
			NSTask* theTask = [[NSTask alloc] init];
			@try
            {
                NSString *launchPath = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"Decompress"] path];
				[theTask setLaunchPath:launchPath];
				[theTask setArguments:[[NSArray arrayWithObjects: dest, @"decompressList", nil] arrayByAddingObjectsFromArray: subArray]];
				[theTask launch];
				
                NSTimeInterval timeout = TIMEOUT * subArray.count;
                if (timeout < 600)
                    timeout = 600;

                NSTimeInterval taskStart = [NSDate timeIntervalSinceReferenceDate];
				while( [theTask isRunning])
                {
                    [NSThread sleepForTimeInterval: 0.1];
                    if ([NSDate timeIntervalSinceReferenceDate] - taskStart > timeout)
                        break;
                }
                
                if ([theTask isRunning])
                {
                    N2LogStackTrace( @"***** task timeout reached -> terminate the NSTask : %@", files);
                    [theTask terminate];
                }
			}
            @catch (NSException *e)
            {
				N2LogExceptionWithStackTrace(e);
			}
			
			[theTask release];
			free(objs);
		}
		
		i += no;
	}
	
	[thread exitOperation];
	return YES;
	
//	OFCondition cond;
//	
//	@synchronized( [BrowserController currentBrowser])
//	{
//		for( NSString *file in files)
//		{
//			const char *fname = (const char *)[file UTF8String];
//			const char *destination = (const char *)[[file stringByAppendingString:@"bb.dcm"] UTF8String];
//			
//			DcmFileFormat fileformat;
//			cond = fileformat.loadFile(fname);
//			
//			if (cond.good())
//			{
//				DcmXfer filexfer(fileformat.getDataset()->getOriginalXfer());
//				
//				if (filexfer.getXfer() != EXS_LittleEndianExplicit || filexfer.getXfer() != EXS_LittleEndianImplicit)
//				{
//					DcmDataset *dataset = fileformat.getDataset();
//					
//					// decompress data set if compressed
//					dataset->chooseRepresentation(EXS_LittleEndianExplicit, NULL);
//					
//					// check if everything went well
//					if (dataset->canWriteXfer(EXS_LittleEndianExplicit))
//					{
//						fileformat.loadAllDataIntoMemory();
//						cond = fileformat.saveFile(destination, EXS_LittleEndianExplicit);
//					}
//					else NSLog( @"err");
//				}
//				else NSLog( @"err");
//			}
//			else NSLog( @"err");
//		}
//	}
//	return YES;

//	DCMObject *dcmObject = [[DCMObject alloc] initWithContentsOfFile: [files lastObject] decodingPixelData: NO];
//							
//	BOOL succeed = NO;
//	
//	@try
//	{
//		DCMTransferSyntax *tsx = [DCMTransferSyntax ExplicitVRLittleEndianTransferSyntax]; // JPEG2000LosslessTransferSyntax];
//		succeed = [dcmObject writeToFile: [[files lastObject] stringByAppendingString:@"bb.dcm"]
//                      withTransferSyntax:tsx
//                                 quality:1
//                                     AET:@OUR_AET
//                              atomically:YES];
//	}
//	@catch (NSException *e)
//	{
//		NSLog( @"dcmObject writeToFile failed: %@", e);
//	}
//	[dcmObject release];
//	
//	return YES;
}

+(NSString*)extractReportSR:(NSString*)dicomSR contentDate:(NSDate*)date
{
    NSString *pathSlash = NSTemporaryDirectory();
    NSString *pathZippedSlash = [NSTemporaryDirectory() stringByAppendingPathComponent: @"zippedFile/"];
	NSString* destPath = nil;
	NSString* uidName = [SRAnnotation getReportFilenameFromSR: dicomSR];
	if ([uidName length] > 0)
	{
 		NSString *zipFile = [pathSlash stringByAppendingPathComponent: uidName];
		
		// Extract the CONTENT to the REPORTS folder
		SRAnnotation *r = [[[SRAnnotation alloc] initWithContentsOfFile: dicomSR] autorelease];
		[[NSFileManager defaultManager] removeItemAtPath: zipFile error: nil];
		
		// Check for http/https !
		if ([[r reportURL] length] > 8 && ([[r reportURL] hasPrefix: @"http://"] || [[r reportURL] hasPrefix: @"https://"]))
			destPath = [[[r reportURL] copy] autorelease];
		else
		{
			if ([[r dataEncapsulated] length] > 0)
			{
				[[r dataEncapsulated] writeToFile: zipFile atomically: YES];

				[[NSFileManager defaultManager] removeItemAtPath: pathZippedSlash error: nil];
				[BrowserController unzipFile: zipFile withPassword: nil destination: pathZippedSlash showGUI: NO];
				[[NSFileManager defaultManager] removeItemAtPath: zipFile error: nil];
				
				for( NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: pathZippedSlash error: nil])
				{
					if ([f hasPrefix: @"."] == NO)
					{
						if (destPath)
							NSLog( @"*** multiple files in Report decompression ?");
						
						destPath = [pathSlash stringByAppendingPathComponent: f];
						if (destPath)
						{
							[[NSFileManager defaultManager] removeItemAtPath: destPath error: nil];
							[[NSFileManager defaultManager] moveItemAtPath: [pathZippedSlash stringByAppendingPathComponent: f] toPath: destPath error: nil];
						}
					}
				}
			}
		}
	}
	
	[[NSFileManager defaultManager] removeItemAtPath: pathZippedSlash error: nil];
	
	if (destPath)
		[[NSFileManager defaultManager] setAttributes: [NSDictionary dictionaryWithObjectsAndKeys: date, NSFileModificationDate, nil] ofItemAtPath: destPath error: nil];
	
	return destPath;
}

+(BOOL)testFiles:(NSArray*)files
{
    NSString *launchPath = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"Decompress"] path];
    if ([[NSFileManager defaultManager] fileExistsAtPath: launchPath] == NO)
        return YES;
    
	WaitRendering *splash = nil;
	NSMutableArray *tasksArray = [NSMutableArray array];
	int CHUNK_SIZE;
	
	if ([NSThread isMainThread]) {
		splash = [[WaitRendering alloc] init: NSLocalizedString( @"Validating files...", nil)];
		[splash showWindow:self];
		[splash setCancel: YES];
		[splash start];
	}
	
	BOOL succeed = YES;
	
	int total = [files count];
	
	CHUNK_SIZE = total / [[NSProcessInfo processInfo] processorCount];
	if (CHUNK_SIZE > 500)
		CHUNK_SIZE = 500;
	else
		CHUNK_SIZE += 20;
	
	@try
	{
		for( int i = 0; i < total;)
		{
			int no;
			
			if (i + CHUNK_SIZE >= total)
                no = total - i;
			else
                no = CHUNK_SIZE;
			
			NSRange range = NSMakeRange( i, no);
			
			id *objs = (id*) malloc( no * sizeof( id));
			if (objs)
			{
				[files getObjects: objs range: range];
				
				NSArray *subArray = [NSArray arrayWithObjects: objs count: no];
				
				NSTask *theTask = [[[NSTask alloc] init] autorelease];
				
				[tasksArray addObject: theTask];
				
				NSArray *parameters = [[NSArray arrayWithObjects: @"unused", @"testFiles", nil] arrayByAddingObjectsFromArray: subArray];
				
				[theTask setArguments: parameters];
                NSString *launchPath = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"Decompress"] path];
				[theTask setLaunchPath:launchPath];
				[theTask launch];
				
				free( objs);
			}
			
			i += no;
		}
	}
	@catch ( NSException *e)
	{
		NSLog( @"***** testList exception : %@", e);
		succeed = NO;
	}
	
	@try
	{
		for( NSTask *t in tasksArray)
		{
			while( [t isRunning] && [splash aborted] == NO)
			{
				[NSThread sleepForTimeInterval: 0.05];
				[splash run];
			}
			
			if ([splash aborted])
				break;
			
			if ([t terminationStatus] != EXIT_SUCCESS)
				succeed = NO;
		}
		
		if ([splash aborted])
		{
			for( NSTask *t in tasksArray)
				[t interrupt];
		}
	}
	@catch (NSException * e)
	{
		NSLog( @"***** testList exception 2 : %@", e);
	}
	[splash end];
	[splash close];
	[splash autorelease];
	
	if (succeed == NO)
		NSLog( @"******* test Files FAILED : one of more of these files are corrupted : %@", files);
	
	return succeed;
	
}


@end
