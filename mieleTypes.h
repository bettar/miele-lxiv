//
//  mieleTypes.h
//  Miele_LXIV
//
//  Created by Alex Bettarini on 2 Oct 2019
//  Copyright © 2019 bettar. All rights reserved.
//  License GPLv3.0 -- see License File
//

#ifndef mieleTypes_h
#define mieleTypes_h

#import <AppKit/AppKit.h>

typedef NS_ENUM(NSUInteger, EngineType) {
    ENGINE_CPU = 0,             // RAY CAST
    ENGINE_GPU_OPEN_GL = 1,
    ENGINE_BOTH = 2             // For Stereo, see also MAPPERMODEVR
};

#endif /* mieleTypes_h */
