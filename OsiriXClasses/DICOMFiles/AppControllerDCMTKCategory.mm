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
#include "dcmtk/config/osconfig.h"

#import "AppControllerDCMTKCategory.h"

#include "dcmtk/dcmjpeg/djdecode.h"  /* for dcmjpeg decoders */
#include "dcmtk/dcmjpeg/djencode.h"  /* for dcmjpeg encoders */
#include "dcmtk/dcmdata/dcrledrg.h"  /* for DcmRLEDecoderRegistration */
#include "dcmtk/dcmdata/dcrleerg.h"  /* for DcmRLEEncoderRegistration */

#include "dcmtk/dcmjpls/djdecode.h" //JPEG-LS
#include "dcmtk/dcmjpls/djencode.h" //JPEG-LS

extern int gPutSrcAETitleInSourceApplicationEntityTitle, gPutDstAETitleInPrivateInformationCreatorUID;

@implementation AppController (AppControllerDCMTKCategory)

- (void)initDCMTK
{
#ifndef MIELE_LIGHT
    // register global JPEG codecs
    DJDecoderRegistration::registerCodecs();
    DJEncoderRegistration::registerCodecs(
	 	ECC_lossyRGB,
		EUC_never,
		//OFFalse,
		OFFalse,
		0,
		0,
		0,
		OFTrue,
		ESS_444,
		OFFalse,
		OFFalse,
		0,
		0,
		0.0,
		0.0,
		0,
		0,
		0,
		0,
		OFTrue,
		OFTrue,
		OFFalse,
		OFFalse,
		OFTrue);
    
    // register RLE codecs
    DcmRLEDecoderRegistration::registerCodecs();
    DcmRLEEncoderRegistration::registerCodecs();
    
    // register global JPEG-LS codecs
    DJLSDecoderRegistration::registerCodecs();
    DJLSEncoderRegistration::registerCodecs();
    
#if 0 // TODO
    gPutSrcAETitleInSourceApplicationEntityTitle = [[NSUserDefaults standardUserDefaults] boolForKey: @"putSrcAETitleInSourceApplicationEntityTitle"];
    gPutDstAETitleInPrivateInformationCreatorUID = [[NSUserDefaults standardUserDefaults] boolForKey: @"putDstAETitleInPrivateInformationCreatorUID"];
#endif
#endif
}
- (void)destroyDCMTK
{
#ifndef MIELE_LIGHT
    // deregister JPEG codecs
    DJDecoderRegistration::cleanup();
    DJEncoderRegistration::cleanup();

    // deregister RLE codecs
    DcmRLEDecoderRegistration::cleanup();
    DcmRLEEncoderRegistration::cleanup();

    // deregister JPEG-LS codecs
    DJLSDecoderRegistration::cleanup();
    DJLSEncoderRegistration::cleanup();
#endif
}

@end
