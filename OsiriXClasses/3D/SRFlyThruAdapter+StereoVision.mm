//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:

//
// Program:   OsiriX
// 
// Created by Silvan Widmer on 8/25/09.
// 
// Copyright (c) LIB-EPFL
// All rights reserved.
// Distributed under GNU - GPL
// 
// See http://www.osirix-viewer.com/copyright.html for details.
// 
// This software is distributed WITHOUT ANY WARRANTY; without even
// the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE.
// =========================================================================

#ifdef _STEREO_VISION_

#import "SRFlyThruAdapter+StereoVision.h"

#import "SRController.h"
#import "SRView.h"
#import "SRView+StereoVision.h"

@implementation SRFlyThruAdapter (StereoVision)

- (void) endMovieGenerating
{	// Added SilvanWidmer 20-08-09
	
	if ([[(SRController*)controller view] StereoVisionOn])
		[[(SRController*)controller view] disableStereoModeLeftRight];
	else
        [[(SRController*)controller view] restoreViewSizeAfterMatrix3DExport];
}

@end
#endif
