//
//  DICOMPrint.mm
//  Miele-LXIV
//
//  Created by Alessandro Bettarini on 22 Dec 2018
//  Copyright © 2018 bettar. All rights reserved.
//
//  This file is licensed under GNU - GPL v3 license.
//  See file LICENCE for details.
//

#include <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#include "AYDcmPrintSCU.h"

//    argv[ 1] : logPath
//    argv[ 2] : baseName
//    argv[ 3] : jsonPath
int main(int argc, const char *argv[])
{
	int status = EXIT_SUCCESS;

    if (argc < 4) {
        NSLog(@"DICOMPrint %s %d", __FUNCTION__, __LINE__);
        return EXIT_FAILURE;
    }

#ifndef NDEBUG
    //NSString *executablePath = [[[NSBundle mainBundle] executableURL] path];
    //NSLog(@"DICOMPrint.mm EXE %@", executablePath);

    NSLog(@"DICOMPrint.mm JSON %s", argv[3]);
#endif
  
    NSLog(@"DICOM Print Process Start");

    NSString *filename;
    NSError *error = nil;
    NSString *jsonStr = [NSString stringWithContentsOfFile:@(argv[3])
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:NSJSONReadingMutableContainers
                                                               error:&error];

    ///
    NSString *host = [jsonDict valueForKeyPath:@"association.host"];
    NSString *portString = [jsonDict valueForKeyPath:@"association.port"];
    NSString *aeTitle = [jsonDict valueForKeyPath:@"association.aetitle_receiver"];
    NSString *aeTitleSender = [jsonDict valueForKeyPath:@"association.aetitle_sender"];

#if 0 //ndef NDEBUG
    // in configuration file: GENERAL NETWORK AETITLE, otherwise
#undef PSTAT_AETITLE
#define PSTAT_AETITLE                     "MIELE-PSTAT"
    NSLog(@"Line %d, getNetworkAETitle: %s", __LINE__, dvi.getNetworkAETitle()); // DCMPSTAT
#endif

    AYDcmPrintSCU printerSCU([host UTF8String], [portString intValue], [aeTitle UTF8String], [aeTitleSender UTF8String]);
    std::list<std::string> images;
    // See GingkoCAD pacscontroller.cpp line 459 PACSController::Print()


    NSDictionary *filmSessionDict = [jsonDict valueForKeyPath:@"association.filmsession"];
    //NSLog(@"film session Dict: %@", filmSessionDict);

    // (2000,0010)
    NSString *numCopies = [filmSessionDict valueForKeyPath:@"number_of_copies"];
    printerSCU.printerNumberOfCopies = [numCopies intValue];

    // (2000,0020)
    NSString *priority = [filmSessionDict valueForKeyPath:@"print_priority"];
    if ([priority length] > 0)
        printerSCU.printerPriority = [priority UTF8String];

    // (2000,0030)
    NSString *mediumType = [filmSessionDict valueForKeyPath:@"medium_type"];
    if ([mediumType length] > 0)
        printerSCU.printerMediumType = [mediumType UTF8String];
    
    // (2000,0040)
    NSString *filmDestination = [filmSessionDict valueForKeyPath:@"film_destination"];
    if ([filmDestination length] > 0)
        printerSCU.printerFilmDestination = [filmDestination UTF8String];

    // There is an array of film-boxes
    NSArray *filmboxArray = [filmSessionDict valueForKeyPath:@"filmbox"];
    //NSLog(@"Line %d, film box count: %lu", __LINE__, (unsigned long)[filmboxArray count]);
    for (NSDictionary *fb in filmboxArray) {

        // (2010,0010)
        NSString *displayFormat = [fb valueForKeyPath:@"image_display_format"];
        if ([displayFormat length] > 0)
            printerSCU.imageDisplayFormat.putString([displayFormat UTF8String]);
        
        // (2010,0040)
        NSString *orientation = [fb valueForKeyPath:@"film_orientation"];
        if ([orientation length] > 0)
            printerSCU.filmOrientation.putString([orientation UTF8String]);
        
        // (2010,0050)
        NSString *size_id = [fb valueForKeyPath:@"film_size_id"];
        if ([size_id length] > 0)
            printerSCU.filmSizeID.putString([size_id UTF8String]);

        // (2010,0060)
        NSString *mType = [fb valueForKeyPath:@"magnification_type"];
        if ([mType length] > 0)
            printerSCU.magnificationType.putString([mType UTF8String]);
        
        // (2010,0080)
        printerSCU.smoothingType.clear();

        // (2010,0100)
        NSString *bDensity = [fb valueForKeyPath:@"border_density"];
        if ([bDensity length] > 0)
            printerSCU.borderDensity.putString([bDensity UTF8String]);

        // (2010,0110)
        NSString *eDensity = [fb valueForKeyPath:@"empty_image_density"];
        if ([eDensity length] > 0)
            printerSCU.emptyImageDensity.putString([eDensity UTF8String]);
        
        // (2010,0140)
        NSString *trimString = [fb valueForKeyPath:@"trim"];
        if ([trimString isEqualToString:@"ON"])
            printerSCU.trim.putString("YES");
        else if ([trimString isEqualToString:@"OFF"])
            printerSCU.trim.putString("NO");

        // (2010,0150)
        NSString *configInfo = [fb valueForKeyPath:@"configuration_information"];
        if ([configInfo length] > 0)
            printerSCU.configurationInformation.putString([configInfo UTF8String]);
        
        // There is an array of image-boxes
        NSArray *imageboxArray = [fb valueForKeyPath:@"imagebox"];
#ifndef NDEBUG
        NSLog(@"Line %d, image box count: %lu", __LINE__, (unsigned long)[imageboxArray count]);
#endif
        for (NSDictionary *ib in imageboxArray) {
            //NSLog(@"Line %d, image box: %@", __LINE__, ib);
            filename = [ib valueForKeyPath:@"image_file"];
            if ([filename length] == 0) {
                NSLog(@"%s %d, filename not specified", __FUNCTION__, __LINE__);
                continue;
            }

            images.push_back(std::string([filename UTF8String]));
        }

        OFCondition cond;
        @try {
            cond = printerSCU.sendPrintjob(images);
            if (cond.bad())
                status = EXIT_FAILURE;
        }
        @catch (NSException* e) {
            NSLog(@"%s %d Exception: %@", __FUNCTION__, __LINE__, e.reason);
            status = EXIT_FAILURE;
        }
    }  // filmBoxArray

	NSLog(@"DICOM Print Process End");
	
	return status;
}
