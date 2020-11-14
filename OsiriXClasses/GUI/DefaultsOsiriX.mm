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

#import "mgl.h" // include first

#import "DefaultsOsiriX.h"
#import "PluginManager.h"
#import "NSUserDefaults+OsiriX.h"
#import <DCM/DCMAbstractSyntaxUID.h>
#import <AVFoundation/AVFoundation.h>

#ifdef OSIRIX_VIEWER
#import <DCM/DCMNetServiceDelegate.h>
#endif

#include <IOKit/graphics/IOGraphicsLib.h>

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

#import "Reports.h"     // for ReportType
#import "mieleTypes.h"  // for ENGINE_CPU
#import "url.h"

//static BOOL isHcugeCh = NO, isUnigeCh = NO, testIsHugDone = NO, testIsUniDone = NO;
//static NSString *hostName = @"";
static NSHost *currentHost = nil;

@implementation DefaultsOsiriX

+(NSHost*) currentHost
{
	@synchronized( NSApp)
	{
		if (currentHost == nil)
			currentHost = [[NSHost currentHost] retain];
	}
	return currentHost;
}

// Test if the computer is in the HUG (domain name == hcuge.ch)
//+ (NSString*) hostName
//{
//	return hostName;
//}

//+ (BOOL) isHUG
//{
//	if (testIsHugDone == NO)
//	{
////		NSArray	*names = [[DefaultsOsiriX currentHost] names];
////		for (int i = 0; i < [names count] && !isHcugeCh; i++)
////		{
////			int len = [[names objectAtIndex: i] length];
////			if ( len < 8 ) continue;  // Fixed out of bounds error in following line when domainname is short.
////			NSString *domainName = [[names objectAtIndex: i] substringFromIndex: len - 8];
////
////			if ([domainName isEqualToString: @"hcuge.ch"])
////			{
////				isHcugeCh = YES;
////				hostName = [[names objectAtIndex: i] retain];
////			}
////		}
//		
//		char s[_POSIX_HOST_NAME_MAX+1];
//		gethostname(s,_POSIX_HOST_NAME_MAX);
//		NSString *c = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
//		
//		if ([c length] > 8 )
//		{
//			NSString *domainName = [c substringFromIndex: [c length] - 8];
//
//			if ([domainName isEqualToString: @"hcuge.ch"])
//			{
//				isHcugeCh = YES;
//				hostName = [c retain];
//			}
//		}
//		
//		testIsHugDone = YES;
//	}
//	return isHcugeCh;
//}

//+ (BOOL) isUniGE
//{
//	if (testIsUniDone == NO)
//	{
////		NSArray	*names = [[DefaultsOsiriX currentHost] names];
////		for (int i = 0; i < [names count] && !isUnigeCh; i++)
////		{
////			int len = [[names objectAtIndex: i] length];
////			if ( len < 8 ) continue;  // Fixed out of bounds error in following line when domainname is short.
////			NSString *domainName = [[names objectAtIndex: i] substringFromIndex: len - 8];
////
////			if ([domainName isEqualToString: @"unige.ch"])
////			{
////				isUnigeCh = YES;
////				hostName = [[names objectAtIndex: i] retain];
////			}
////		}
//		
//		char s[_POSIX_HOST_NAME_MAX+1];
//		gethostname(s,_POSIX_HOST_NAME_MAX);
//		NSString *c = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
//		
//		if ([c length] > 8 )
//		{
//			NSString *domainName = [c substringFromIndex: [c length] - 8];
//
//			if ([domainName isEqualToString: @"unige.ch"])
//			{
//				isUnigeCh = YES;
//				hostName = [c retain];
//			}
//		}
//		
//		testIsUniDone = YES;
//	}
//	return isUnigeCh;
//}

//+ (BOOL) isLAVIM
//{
//	#ifdef OSIRIX_VIEWER
//	if ([self isHUG])
//	{
//		for (int i = 0; i < [[PluginManager preProcessPlugins] count]; i++)
//		{
//			id filter = [[PluginManager preProcessPlugins] objectAtIndex:i];
//			
//			if ([[filter className] isEqualToString:@"LavimAnonymize"]) return YES;
//		}
//	}
//	else if ([self isUniGE])
//	{
//		if ([hostName isEqualToString:@"lavimcmu1.unige.ch"]) return YES;
//	}
//	#endif
//	
//	return NO;
//}

+ (void) addCLUT: (NSString*) filename dictionary: (NSMutableDictionary*) clutValues
{
	NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource:filename ofType:@"plist"]];
	
	if (d)
		[clutValues setObject: d forKey: filename];
	else
		NSLog(@"CLUT plist not found: %@", filename);
}

+ (void) addConvolutionFilter:(short) size
                             :(short*) vals
                             :(NSString*) name
                             :(NSMutableDictionary*) convValues
{
	NSMutableDictionary *aConvFilter = [NSMutableDictionary dictionary];

	[aConvFilter setObject:[NSNumber numberWithLong:size] forKey:@"Size"];
	
	long norm = 0;
	for (long i = 0; i < size*size; i++)
        norm += vals[i];

    [aConvFilter setObject:[NSNumber numberWithLong:norm] forKey:@"Normalization"];
	
    NSMutableArray *valArray = [NSMutableArray array];
	for (long i = 0; i < size*size; i++)
        [valArray addObject:[NSNumber numberWithLong:vals[i]]];

    [aConvFilter setObject:valArray forKey:@"Matrix"];
	[convValues setObject:aConvFilter forKey:name];
}

+ (mach_vm_size_t) GPUModelVRAMInfo
{
    io_iterator_t Iterator;
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &Iterator);
    if (err != KERN_SUCCESS)
    {
        NSLog(@"IOServiceGetMatchingServices failed: %u\n", err);
        return 0;
    }
    
    for (io_service_t Device;
         IOIteratorIsValid(Iterator) && (Device = IOIteratorNext(Iterator));
         IOObjectRelease(Device))
    {
        CFStringRef Name = (CFStringRef)IORegistryEntrySearchCFProperty(Device,
                                                                        kIOServicePlane,
                                                                        CFSTR("IOName"),
                                                                        kCFAllocatorDefault,
                                                                        kNilOptions);
        if (Name)
        {
            if (CFStringCompare(Name, CFSTR("display"), 0) == kCFCompareEqualTo)
            {
                CFDataRef Model = (CFDataRef)IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("model"), kCFAllocatorDefault, kNilOptions);
                if (Model)
                {
                    _Bool ValueInBytes = TRUE;
                    CFTypeRef VRAMSize = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("VRAM,totalsize"), kCFAllocatorDefault, kIORegistryIterateRecursively); //As it could be in a child

                    if (!VRAMSize)
                    {
                        ValueInBytes = FALSE;
                        VRAMSize = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("VRAM,totalMB"), kCFAllocatorDefault, kIORegistryIterateRecursively); //As it could be in a child
                    }
                    
                    if (VRAMSize)
                    {
                        mach_vm_size_t Size = 0;
                        CFTypeID Type = CFGetTypeID(VRAMSize);
                        if (Type == CFDataGetTypeID())
                            Size = (CFDataGetLength((CFDataRef)VRAMSize) == sizeof(uint32_t) ?
                                    (mach_vm_size_t)*(const uint32_t*)CFDataGetBytePtr((CFDataRef)VRAMSize) :
                                    *(const uint64_t*)CFDataGetBytePtr((CFDataRef)VRAMSize));
                        else if (Type == CFNumberGetTypeID())
                            CFNumberGetValue((CFNumberRef)VRAMSize, kCFNumberSInt64Type, &Size);
                        
                        if (ValueInBytes)
                            Size >>= 20;
                        
                        NSLog(@"Graphics: %s, %llu MB", CFDataGetBytePtr(Model), Size);
                        
                        CFRelease(Model);
                        return Size;
                    }

                    NSLog(@"%s : Unknown VRAM Size\n", CFDataGetBytePtr(Model));
                    CFRelease(Model);
                } // if Model
            }
            
            CFRelease(Name);
        } // if Name
    } // for
    
    return 0;
}

// 'CGDisplayIOServicePort' is deprecated: first deprecated in macOS 10.9 - No longer supported
+ (unsigned long) vramSizeMB
{
//    const short MAXDISPLAYS = 8;
//    io_service_t		dspPorts[MAXDISPLAYS];
//    CGDirectDisplayID displays[MAXDISPLAYS];
//    CGDisplayCount    displayCount = 0;
//
//    // First we're going to grab the online displays
//    CGGetOnlineDisplayList(MAXDISPLAYS, displays, &displayCount);
//
//    if (displayCount <= 0)
//        return 0L;
//
//    // Now we iterate through them
//    for (int i = 0; i < displayCount; i++)
//        dspPorts[i] = CGDisplayIOServicePort(displays[i]);
//
//    // Ask for the physical size of VRAM of the primary display
//    CFTypeRef typeCode;
//    typeCode = IORegistryEntryCreateCFProperty(dspPorts[0], CFSTR("IOFBMemorySize"), kCFAllocatorDefault, kNilOptions);
//
//    // Validate our data and make sure we're getting the right type
//    if (typeCode)
//    {
//        SInt32 vramStorage = 0;
//        // Convert this to a useable number
//
//        if (CFGetTypeID(typeCode) == CFNumberGetTypeID())
//            CFNumberGetValue((CFNumberRef)typeCode, kCFNumberSInt32Type, &vramStorage);
//
//        CFRelease(typeCode);
//
//      vramStorage /= (1024L * 1024L);
//        return vramStorage;
//    }

	return 0L;
}

#pragma mark -

+ (NSMutableDictionary*) getDefaults
{
	NSMutableDictionary *defaultValuesDic = [NSMutableDictionary dictionary];
	
#pragma mark WLWW PRESETS

    float iww, iwl;
	
	NSMutableDictionary *wlwwValuesDic = [NSMutableDictionary dictionary];
	
	iww = 1400;
    iwl = -500;
	[wlwwValuesDic setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], nil]
                   forKey:@"CT - Pulmonary"];
	
	iww = 1500;
    iwl = 300;
	[wlwwValuesDic setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], nil]
                   forKey:@"CT - Bone"];
	
	iww = 100;
    iwl = 50;
	[wlwwValuesDic setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], nil]
                   forKey:@"CT - Brain"];
	
	iww = 350;
    iwl = 40;
	[wlwwValuesDic setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], nil]
                   forKey:@"CT - Abdomen"];
	
	iww = 700;
    iwl = -300;
	[wlwwValuesDic setObject:[NSArray arrayWithObjects:[NSNumber numberWithFloat:iwl], [NSNumber numberWithFloat:iww], nil]
                   forKey:@"VR - Endoscopy"];
	
	[defaultValuesDic setObject:wlwwValuesDic
                      forKey:@"WLWW3"];
	
#pragma mark CONVOLUTION PRESETS
	
	NSMutableDictionary *convValues = [NSMutableDictionary dictionary];
	
	// --
	{
		NSMutableDictionary *aConvFilter = [NSMutableDictionary dictionary];
		NSMutableArray *valArray = [NSMutableArray array];
		short vals[9] = {-1, -1, -1, -1, 9, -1, -1, -1, -1};
		
		[aConvFilter setObject:[NSNumber numberWithLong:3] forKey:@"Size"];
		[aConvFilter setObject:[NSNumber numberWithLong:1] forKey:@"Normalization"];
		for (int i = 0; i < 9; i++)
            [valArray addObject: [NSNumber numberWithLong:vals[i]]];

        [aConvFilter setObject:valArray forKey:@"Matrix"];
		[convValues setObject:aConvFilter forKey:@"Bone Filter 3x3"];
	}
	// --
	// --
	{
		NSMutableDictionary *aConvFilter = [NSMutableDictionary dictionary];
		NSMutableArray *valArray = [NSMutableArray array];
		short vals[25] = {
            1, 1, 1, 1, 1,
			1, 4, 4, 4, 1,
			1, 4, 12, 4, 1,
			1, 4, 4, 4, 1,
			1, 1, 1, 1, 1};
		
		[aConvFilter setObject:[NSNumber numberWithLong:5] forKey:@"Size"];
		[aConvFilter setObject:[NSNumber numberWithLong:60] forKey:@"Normalization"];
		for (int i = 0; i < 25; i++)
            [valArray addObject:[NSNumber numberWithLong:vals[i]]];

        [aConvFilter setObject:valArray forKey:@"Matrix"];
		[convValues setObject:aConvFilter forKey:@"Basic Smooth 5x5"];
	}
	{
		short vals[9] = {1, 2, 1, 2, 4, 2, 1, 2, 1};
		[self addConvolutionFilter:3 :vals :@"Blur 3x3" :convValues];
	}
	{
		short vals[25] = {1, 1, 2, 1, 1, 1, 2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 2, 3, 2, 1, 1, 1, 2, 1, 1};
		[self addConvolutionFilter:5 :vals :@"Blur 5x5" :convValues];
	}
	{
		short vals[25] = {3, 3, 2, 3, 3, 3, 2, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1, 2, 3, 3, 3, 2, 3, 3};
		[self addConvolutionFilter:5 :vals :@"Inverted blur" :convValues];
	}
	{
		short vals[25] = {0, 0, -1, 0, 0, 0, -1, -2, -1, 0, -1, -2, -3, -2, -1, 0, -1, -2, -1, 0, 0, 0, -1, 0, 0};
		[self addConvolutionFilter:5 :vals :@"Negative blur" :convValues];
	}
	{
		short vals[9] = {1, 2, 1, 0, 0, 0, -1, -2, -1};
		[self addConvolutionFilter:3 :vals :@"Emboss north" :convValues];
	}
	{
		short vals[9] = {1, 0, -1, 2, 0, -2, 1, 0, -1};
		[self addConvolutionFilter:3 :vals :@"Emboss west" :convValues];
	}
	{
		short vals[9] = {0, 1, 0, -1, 0, 1, 0, -1, 0};
		[self addConvolutionFilter:3 :vals :@"Emboss diagonal" :convValues];
	}
	{
		short vals[9] = {-1, -1, -1, -1, 8, -1, -1, -1, -1};
		[self addConvolutionFilter:3 :vals :@"Laplacian 8" :convValues];
	}
	{
		short vals[9] = {0, -1, 0, -1, 4, -1, 0, -1, 0};
		[self addConvolutionFilter:3 :vals :@"Laplacian 4" :convValues];
	}	
	{
		short vals[9] = {-1, 0, -1, 0, 7, 0, -1, 0, -1};
		[self addConvolutionFilter:3 :vals :@"Sharpen 3x3" :convValues];
	}
	{
		short vals[9] = {-1, 0, 0, 0, 0, 0, 0, 0, 1};
		[self addConvolutionFilter:3 :vals :@"Emboss" :convValues];
	}
	{
		short vals[9] = {-1, -1, 0, -1, 0, 1, 0, 1, 1};
		[self addConvolutionFilter:3 :vals :@"Emboss heavy" :convValues];
	}
	{
		short vals[9] = {1, 1, 1, 1, 1, 1, 1, 1, 1};
		[self addConvolutionFilter:3 :vals :@"Lowpass" :convValues];
	}
	{
		short vals[9] = {1, -2, 1, -2, 4, -2, 1, -2, 1};
		[self addConvolutionFilter:3 :vals :@"Edge 3x3" :convValues];
	}
	{
		short vals[25] = {0, -1, -1, -1, 0, -1, 2, -4, 2, -1, -1, -4, 13, -4, -1, -1, 2, -4, 2, -1, 0, -1, -1, -1, 0};
		[self addConvolutionFilter:5 :vals :@"Highpass 5x5" :convValues];
	}
	{
		short vals[25] = {1, 1, 2, 1, 1, 1, 2, 4, 2, 1, 2, 4, 8, 4, 2, 1, 2, 4, 2, 1, 1, 1, 2, 1, 1};
		[self addConvolutionFilter:5 :vals :@"Gaussian blur" :convValues];
	}
	{
		short vals[25] = {0,  0, -1,  0,  0, 0, -1, -2, -1,  0, -1, -2, 16, -2, -1, 0, -1, -2, -1,  0, 0,   0,  -1,   0,   0};
		[self addConvolutionFilter:5 :vals :@"Hat" :convValues];
	}
	{
		short vals[25] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 24, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
		[self addConvolutionFilter:5 :vals :@"Laplacian" :convValues];
	}
	{
		short vals[25] = {-1, -1, -1, -1, -1, -1, 2, 2, 2, -1, -1, 2, 8, 2, -1, -1, 2, 2, 2, -1, -1, -1, -1, -1, -1};
		[self addConvolutionFilter:5 :vals :@"Sharpen 5x5" :convValues];
	}
	{
		short vals[9] = {1, 1, 1, 1, -7, 1, 1, 1, 1};
		[self addConvolutionFilter:3 :vals :@"Excessive edges" :convValues];
	}
	
	// --
	
	[defaultValuesDic setObject:convValues
                      forKey:@"Convolution"];
	
#pragma mark OPACITY TABLES

    NSMutableDictionary *opacityValues = [NSMutableDictionary dictionary];
	
	NSMutableDictionary *aOpacityFilter = [NSMutableDictionary dictionary];
	NSMutableArray *points = [NSMutableArray array];
	
	for (int i = 0; i < 256; i++)
	{
		NSPoint pt;
		//math.h
		pt.x = 1000+i;
		pt.y = log10( 1. + (i/255.)*9.);
		
		[points addObject: NSStringFromPoint( pt)];
	}
	
	[aOpacityFilter setObject:points forKey:@"Points"];
	[opacityValues setObject:aOpacityFilter forKey:@"Logarithmic Table"];
	
	// Log Inverse
	
	aOpacityFilter = [NSMutableDictionary dictionary];
	points = [NSMutableArray array];
	
	for (int i = 0; i < 256; i++)
	{
		NSPoint pt;
		//math.h
		pt.x = 1000+i;
		pt.y = 1. - log10( 1. + ((255-i)/255.)*9.);
		
		[points addObject: NSStringFromPoint( pt)];
	}
	
	[aOpacityFilter setObject:points forKey:@"Points"];
	[opacityValues setObject:aOpacityFilter forKey:@"Logarithmic Inverse Table"];
	
	// Smooth CT
	
	aOpacityFilter = [NSMutableDictionary dictionary];
	points = [NSMutableArray array];
	
	{
		NSPoint pt;
		pt.x = 1000+180;
		pt.y = 0.05;
		
		[points addObject: NSStringFromPoint( pt)];
	}
	
	[aOpacityFilter setObject:points forKey:@"Points"];
	[opacityValues setObject:aOpacityFilter forKey:@"Smooth Table"];
	
	[defaultValuesDic setObject:opacityValues forKey:@"OPACITY"];
	
#pragma mark CLUT PRESETS

    NSMutableDictionary *clutValues = [NSMutableDictionary dictionary];
	
	// --
	{
	//    NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
	//	NSMutableArray		*rArray = [NSMutableArray array];
	//	for ( i = 0; i < 256; i++)
	//	{
	//		[rArray addObject: [NSNumber numberWithLong:i]];
	//	}
	//	[aCLUTFilter setObject:rArray forKey:@"Red"];
	//	
	//	NSMutableArray		*gArray = [NSMutableArray array];
	//	for ( i = 0; i < 256; i++)
	//	{
	//		[gArray addObject: [NSNumber numberWithLong:0L]];
	//	}
	//	[aCLUTFilter setObject:gArray forKey:@"Green"];
	//	
	//	NSMutableArray		*bArray = [NSMutableArray array];
	//	for ( i = 0; i < 256; i++)
	//	{
	//		[bArray addObject: [NSNumber numberWithLong:0L]];
	//	}
	//	[aCLUTFilter setObject:bArray forKey:@"Blue"];
	//	
	//	[clutValues setObject:aCLUTFilter forKey:@"Red CLUT"];
	}
	
	// --
	{
		NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
		NSMutableArray *rArray = [NSMutableArray array];
		for (int i = 0; i < 128; i++)
            [rArray addObject: [NSNumber numberWithLong:i*2]];

        for (int i = 128; i < 256; i++)
            [rArray addObject: [NSNumber numberWithLong:255L]];

        [aCLUTFilter setObject:rArray forKey:@"Red"];
		
		NSMutableArray *gArray = [NSMutableArray array];
		for (int i = 0; i < 128; i++)
            [gArray addObject: [NSNumber numberWithLong:0L]];

        for (int i = 128; i < 192; i++)
            [gArray addObject: [NSNumber numberWithLong: (i-128)*4]];
		
        for (int i = 192; i < 256; i++)
            [gArray addObject: [NSNumber numberWithLong: 255L]];

        [aCLUTFilter setObject:gArray forKey:@"Green"];
		
		NSMutableArray *bArray = [NSMutableArray array];
		for (int i = 0; i < 192; i++)
            [bArray addObject: [NSNumber numberWithLong:0L]];

        for (int i = 192; i < 256; i++)
            [bArray addObject: [NSNumber numberWithLong:(i-192)*4]];

        [aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		// Points & Colors
		NSMutableArray *colors = [NSMutableArray array], *points = [NSMutableArray array];
		
		[colors addObject:[NSArray arrayWithObjects: @0.0F, @0.0F, @0.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 0L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @0.0F, @0.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 128L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @0.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 192L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @1.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 256]];
		
		[aCLUTFilter setObject:colors forKey:@"Colors"];
		[aCLUTFilter setObject:points forKey:@"Points"];
		
		[clutValues setObject:aCLUTFilter forKey:@"PET"];
	}

	{
		NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
		NSMutableArray *rArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)
            [rArray addObject: [NSNumber numberWithLong:255-i]];
		[aCLUTFilter setObject:rArray forKey:@"Red"];
		
		NSMutableArray *gArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)
            [gArray addObject: [NSNumber numberWithLong:255-i]];
		[aCLUTFilter setObject:gArray forKey:@"Green"];
		
		NSMutableArray *bArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)
            [bArray addObject: [NSNumber numberWithLong:255-i]];
		[aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		// Points & Colors
		NSMutableArray *colors = [NSMutableArray array], *points = [NSMutableArray array];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @1.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 0L]];
		
		[colors addObject:[NSArray arrayWithObjects: @0.0F, @0.0F, @0.0F, nil]];
		[points addObject:[NSNumber numberWithLong: 256]];
		
		[aCLUTFilter setObject:colors forKey:@"Colors"];
		[aCLUTFilter setObject:points forKey:@"Points"];
		
		[clutValues setObject:aCLUTFilter forKey:@"B/W Inverse"];
	}
	
	{
		NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
		NSMutableArray *rArray = [NSMutableArray array];
		NSMutableArray *gArray = [NSMutableArray array];
		NSMutableArray *bArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)  {
			[bArray addObject: [NSNumber numberWithLong:(195 - (i * 0.26))]];
			[gArray addObject: [NSNumber numberWithLong:(187 - (i *0.26))]];
			[rArray addObject: [NSNumber numberWithLong:(240 + (i * 0.02))]];
		}

        [aCLUTFilter setObject:rArray forKey:@"Red"];
		[aCLUTFilter setObject:gArray forKey:@"Green"];
		[aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		// Points & Colors
		NSMutableArray *colors = [NSMutableArray array], *points = [NSMutableArray array];
		[points addObject:[NSNumber numberWithLong: 0L]];
		[points addObject:[NSNumber numberWithLong: 255L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @1.0F, nil]];
		[colors addObject:[NSArray arrayWithObjects: @0.0F, @0.0F, @0.0F, nil]];

		[aCLUTFilter setObject:colors forKey:@"Colors"];
		[aCLUTFilter setObject:points forKey:@"Points"];
		
		[clutValues setObject:aCLUTFilter forKey:@"Endoscopy"];
	}
    
    {
		NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
        
        int r[ 256] = {0,0,2,4,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,32,34,36,36,38,40,40,40,40,40,40,40,40,40,40,40,40,40,40,40,40,40,38,36,36,34,32,32,30,28,28,26,24,24,22,20,20,18,16,16,14,12,12,10,10,10,8,8,8,6,6,6,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,148,168,176,184,192,200,208,214,220,224,226,248,250,252,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,252,250,250,248,246,246,242,240,238,236,234,232,230,228,226,224,220,218,216,214,214,214,214,214,214,214,214,214,214,214,214,214,214,214,214,214,214,216,216,216,218,216,216,214,214,214,214,212,212,212,210,210,210,208,208,208,206,206,206,206,206,206,206,206,206,206,206,206,206,206,206,206,206,206,206,204,204,204,204,204,204,204,204,204,206,208,210,210,214,216,218,222,226,230,232,236,238,240,240,240,240,240,240,240,240,240};
        
        int g[ 256] = {0,2,4,6,8,10,12,14,16,18,20,22,24,28,30,32,36,38,40,44,46,48,52,54,56,60,62,64,68,70,72,76,78,80,84,86,88,92,94,96,100,102,104,108,110,112,116,118,120,124,126,128,132,134,136,140,142,144,146,148,150,152,154,156,158,160,162,162,162,162,162,162,162,162,162,162,160,158,158,156,154,154,152,150,150,148,146,146,144,142,142,140,140,140,130,128,128,126,126,126,126,126,126,128,128,130,130,134,138,142,148,152,158,164,168,174,180,184,190,196,202,206,212,218,222,228,234,238,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,250,226,218,210,202,194,186,178,170,162,154,146,138,130,122,114,106,98,90,82,74,66,58,50,42,34,26,18,10,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,4,4,4,6,6,6,8,8,8,10,10,10,12,14,14,16,18,18,62,34,42,50,58,66,74,82,90,98,106,114,122,130,138,144,152,160,168,176,184,192,200,208,216,224,232,240,248,254};
        
        int b[ 256] = {0,6,10,16,20,24,30,34,38,44,48,54,58,62,68,72,76,82,86,92,96,100,106,110,114,120,124,130,134,138,144,148,152,152,152,150,148,146,144,142,140,138,136,134,132,130,128,128,126,126,124,122,122,120,118,118,116,114,114,112,110,110,108,106,106,106,104,102,98,96,94,90,88,86,84,82,80,78,76,74,72,70,68,66,64,62,58,56,54,48,40,38,38,36,36,36,36,36,26,24,18,16,12,10,8,6,6,4,4,2,2,2,4,4,4,6,6,6,8,8,8,10,10,10,12,12,12,14,14,14,14,48,60,60,60,60,60,60,60,60,60,60,60,60,56,52,44,36,28,20,12,8,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,4,4,6,6,6,8,8,24,32,122,124,126,128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,158,158,160,160,162,162,164,164,164,164,164,164,164,164,164,164,164,164,164,246,248,248,250,250,252,252,244,248,252,254,254,254,254,254,254,254,254};
        
		NSMutableArray *rArray = [NSMutableArray array];
		NSMutableArray *gArray = [NSMutableArray array];
		NSMutableArray *bArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)
        {
			[bArray addObject: [NSNumber numberWithLong: r[ i]]];
			[gArray addObject: [NSNumber numberWithLong: g[ i]]];
			[rArray addObject: [NSNumber numberWithLong: b[ i]]];
		}
		[aCLUTFilter setObject:rArray forKey:@"Red"];
		[aCLUTFilter setObject:gArray forKey:@"Green"];
		[aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		// Points & Colors
		NSMutableArray *colors = [NSMutableArray array], *points = [NSMutableArray array];
		[points addObject:[NSNumber numberWithLong: 0L]];
		[points addObject:[NSNumber numberWithLong: 255L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @1.0F, nil]];
		[colors addObject:[NSArray arrayWithObjects: @0.0F, @0.0F, @0.0F, nil]];
        
		
		[aCLUTFilter setObject:colors forKey:@"Colors"];
		[aCLUTFilter setObject:points forKey:@"Points"];
		
		[clutValues setObject:aCLUTFilter forKey:@"French"];
	}
    
    {
		NSMutableDictionary *aCLUTFilter = [NSMutableDictionary dictionary];
        
        int r[ 256] = {0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,6,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,6,8,10,14,16,18,22,24,26,28,32,34,36,40,42,44,48,50,52,54,58,60,62,66,68,70,74,76,78,80,84,86,88,92,94,96,98,102,104,106,110,112,114,118,120,122,124,128,130,132,136,138,140,144,146,148,150,154,156,158,162,164,166,168,172,174,176,180,182,184,188,190,192,194,198,200,202,206,208,210,214,216,218,220,224,226,228,232,234,236,240,242,244,246,250,252,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254};
        
        int g[ 256] = {0,6,8,10,12,14,14,16,18,20,22,22,24,26,28,30,30,32,34,36,38,38,40,42,44,46,46,48,50,52,54,54,56,58,60,62,62,64,66,68,70,70,72,74,76,78,78,76,78,76,76,74,74,72,72,70,68,68,66,66,64,64,62,60,60,58,58,56,56,54,52,52,50,50,48,48,46,46,44,42,42,40,40,38,38,36,34,34,32,32,30,30,28,26,26,24,24,22,22,20,18,18,16,16,14,14,12,12,10,8,8,6,6,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,4,6,10,12,14,18,20,22,26,28,30,34,36,38,42,44,46,50,52,54,58,60,62,66,68,70,74,76,78,82,84,86,90,92,94,98,100,102,106,108,110,114,116,118,122,124,126,130,132,134,138,140,142,146,148,150,154,156,158,162,164,166,170,172,174,178,180,182,186,188,190,194,196,198,202,204,206,210,212,214,218,220,222,226,228,230,234,236,238,242,244,246,250,252,254};
        
        int b[ 256] = {0,6,12,16,22,26,32,36,42,46,52,56,62,68,72,78,82,88,92,98,102,108,112,118,122,128,134,138,144,148,154,158,164,168,174,178,184,188,194,200,204,210,214,220,224,230,234,240,244,250,252,250,246,244,240,238,234,232,230,226,224,220,218,214,212,210,206,204,200,198,194,192,190,186,184,180,178,174,172,170,166,164,160,158,154,152,150,146,144,140,138,134,132,130,126,124,120,118,114,112,110,106,104,100,98,94,92,90,86,84,80,78,74,72,70,66,64,60,58,54,52,50,46,44,40,38,34,32,30,26,24,20,18,14,12,10,6,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,14,28,42,56,68,82,96,110,124,136,150,164,178,190};
        
		NSMutableArray *rArray = [NSMutableArray array];
		NSMutableArray *gArray = [NSMutableArray array];
		NSMutableArray *bArray = [NSMutableArray array];
		for (int i = 0; i < 256; i++)
        {
			[bArray addObject: [NSNumber numberWithLong: r[ i]]];
			[gArray addObject: [NSNumber numberWithLong: g[ i]]];
			[rArray addObject: [NSNumber numberWithLong: b[ i]]];
		}
		[aCLUTFilter setObject:rArray forKey:@"Red"];
		[aCLUTFilter setObject:gArray forKey:@"Green"];
		[aCLUTFilter setObject:bArray forKey:@"Blue"];
		
		// Points & Colors
		NSMutableArray *colors = [NSMutableArray array], *points = [NSMutableArray array];
		[points addObject:[NSNumber numberWithLong: 0L]];
		[points addObject:[NSNumber numberWithLong: 255L]];
		
		[colors addObject:[NSArray arrayWithObjects: @1.0F, @1.0F, @1.0F, nil]];
		[colors addObject:[NSArray arrayWithObjects: @0.0F, @0.0F, @0.0F, nil]];

		[aCLUTFilter setObject:colors forKey:@"Colors"];
		[aCLUTFilter setObject:points forKey:@"Points"];
		
		[clutValues setObject:aCLUTFilter forKey:@"Perfusion"];
	}
	
#ifdef OSIRIX_VIEWER
	[DefaultsOsiriX addCLUT: @"VR Muscles-Bones" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"VR Bones" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"VR Red Vessels" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"BlackBody" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Flow" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"GEcolor" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Spectrum" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"NIH" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"HotIron" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"GrayRainbow" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"UCLA" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Stern" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Ratio" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Rainbow3" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Rainbow2" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Rainbow" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"ired" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Hue1" dictionary: clutValues];
	[DefaultsOsiriX addCLUT: @"Hue2" dictionary: clutValues];		
	[DefaultsOsiriX addCLUT: @"HotMetal" dictionary: clutValues];	
	[DefaultsOsiriX addCLUT: @"HotGreen" dictionary: clutValues];	
	[DefaultsOsiriX addCLUT: @"Jet" dictionary: clutValues];
	
	[defaultValuesDic setObject: clutValues forKey: @"CLUT"];
#endif
	
#pragma mark PREFERENCES - SERVERS
	
	NSMutableArray *serversValues = [NSMutableArray array];
	
	NSMutableDictionary *aServer = [[NSMutableDictionary alloc] init];
    [aServer setObject:@"1" forKey:@"Activated"];
	[aServer setObject:@"127.0.0.1" forKey: @"Address"];
	[aServer setObject:@OUR_AET forKey: @"AETitle"];
	[aServer setObject:@"4444" forKey: @"Port"];
	[aServer setObject:@0 forKey:@"TransferSyntax"];
	[aServer setObject:NSLocalizedString(@"This is an example", nil) forKey:@"Description"];
	
	[serversValues addObject:aServer];
	[aServer release];
	
	[defaultValuesDic setObject:serversValues forKey:@"SERVERS"];
	
	serversValues = [NSMutableArray array];
	[defaultValuesDic setObject:serversValues forKey:@"OSIRIXSERVERS"];
	
	//routing calendars
	[defaultValuesDic setObject:[NSMutableArray arrayWithObject:@"Osirix"] forKey:@"ROUTING CALENDARS"];
	
#pragma mark  AETITLE

    if ([defaultValuesDic objectForKey:@"AETITLE"] == nil)
	{
#ifdef OSIRIX_VIEWER
		char s[_POSIX_HOST_NAME_MAX+1];
		gethostname(s,_POSIX_HOST_NAME_MAX);
		NSString *c = [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
		NSRange range = [c rangeOfString: @"."];
		if (range.location != NSNotFound) c = [c substringToIndex: range.location];
	
		if ([c length] > 16)
			c = [c substringToIndex: 16];
			
		[defaultValuesDic setObject: c forKey:@"AETITLE"];
#endif
	}
    
    if ([defaultValuesDic objectForKey:@"AETITLE"] == nil)
        [defaultValuesDic setObject:OUR_IMPLEMENTATION_NAME forKey:@"AETITLE"];
    
	[defaultValuesDic setObject:@"11112" forKey:@"AEPORT"];

	[defaultValuesDic setObject:@"1" forKey:@"points3DcolorRed"];
	[defaultValuesDic setObject:@"0" forKey:@"points3DcolorGreen"];
	[defaultValuesDic setObject:@"0" forKey:@"points3DcolorBlue"];
	[defaultValuesDic setObject:@"1" forKey:@"points3DcolorAlpha"];
	[defaultValuesDic setObject:@"1" forKey:@"MagneticWindows"];
	[defaultValuesDic setObject:@(MPR_LAYOUT_2_1) forKey:MPR2DViewsPosition_KEY];
	
	[defaultValuesDic setObject:@"1" forKey:@"StoreThumbnailsInDB"];
	[defaultValuesDic setObject:@"1" forKey:@"DisplayDICOMOverlays"];
	[defaultValuesDic setObject:@"0" forKey:@"ALLOWDICOMEDITING"];
	[defaultValuesDic setObject:@"/~Documents/FolderToBurn" forKey:@"SupplementaryBurnPath"];
    
	NSMutableArray *presets = [NSMutableArray array];
	NSDictionary *shading;
	
	shading = [NSMutableDictionary dictionary];
	[shading setValue: @"Default" forKey: @"name"];
	[shading setValue: @"0.15" forKey: @"ambient"];
	[shading setValue: @"0.9" forKey: @"diffuse"];
	[shading setValue: @"0.3" forKey: @"specular"];
	[shading setValue: @"15" forKey: @"specularPower"];
	[presets addObject: shading];
	
	shading = [NSMutableDictionary dictionary];
	[shading setValue: @"Glossy Vascular" forKey: @"name"];
	[shading setValue: @"0.15" forKey: @"ambient"];
	[shading setValue: @"0.28" forKey: @"diffuse"];
	[shading setValue: @"1.42" forKey: @"specular"];
	[shading setValue: @"50" forKey: @"specularPower"];
	[presets addObject: shading];
	
	shading = [NSMutableDictionary dictionary];
	[shading setValue: @"Glossy Bone" forKey: @"name"];
	[shading setValue: @"0.15" forKey: @"ambient"];
	[shading setValue: @"0.24" forKey: @"diffuse"];
	[shading setValue: @"1.17" forKey: @"specular"];
	[shading setValue: @"6.98" forKey: @"specularPower"];
	[presets addObject: shading];
	
	shading = [NSMutableDictionary dictionary];
	[shading setValue: @"Endoscopy" forKey: @"name"];
	[shading setValue: @"0.12" forKey: @"ambient"];
	[shading setValue: @"0.64" forKey: @"diffuse"];
	[shading setValue: @"0.73" forKey: @"specular"];
	[shading setValue: @"50" forKey: @"specularPower"];
	[presets addObject: shading];
	
	[defaultValuesDic setObject:presets forKey:@"shadingsPresets"];
	[defaultValuesDic setObject:@(ROI_VOLUME_ISO_CONTOUR) forKey:UseDelaunayFor3DRoi_KEY];
	[defaultValuesDic setObject:@"1" forKey:@"EJECTCDDVD"];
	[defaultValuesDic setObject:@"1" forKey:@"automaticWorkspaceLoad"];
	[defaultValuesDic setObject:@"1" forKey:@"automaticWorkspaceSave"];
	[defaultValuesDic setObject:@"1" forKey:@"includeAllTiledViews"];
	[defaultValuesDic setObject:@"0" forKey:@"AUTOCLEANINGDATE"];
	[defaultValuesDic setObject:@"0" forKey:@"AUTOCLEANINGDATEPRODUCED"];
	[defaultValuesDic setObject:@"0" forKey:@"AUTOCLEANINGDATEOPENED"];
	[defaultValuesDic setObject:@"0" forKey:@"IndependentCRWLWW"];
	[defaultValuesDic setObject:@"90" forKey:@"AUTOCLEANINGDATEPRODUCEDDAYS"];
	[defaultValuesDic setObject:@"90" forKey:@"AUTOCLEANINGDATEOPENEDDAYS"];
	[defaultValuesDic setObject:@"1" forKey:@"SEPARATECARDIAC4D"];
	[defaultValuesDic setObject:@"0" forKey:@"DEFAULTPETFUSION"];
	[defaultValuesDic setObject:@"0" forKey:@"DEFAULTPETWLWW"];
	[defaultValuesDic setObject:@"0" forKey:@"PETWLWWFROM"];
	[defaultValuesDic setObject:@"100" forKey:@"PETWLWWTO"];
	[defaultValuesDic setObject:@"0" forKey:@"PETWLWWFROMSUV"];
	[defaultValuesDic setObject:@"6" forKey:@"PETWLWWTOSUV"];
	[defaultValuesDic setObject:@(EXPORT_SIZE_CURRENT) forKey:EXPORTMATRIXFOR3D_KEY];
	[defaultValuesDic setObject:@"0" forKey:@"ROITEXTNAMEONLY"];
	[defaultValuesDic setObject:@"0" forKey:@"DEFAULTLEFTTOOL"];	// WL TOOL
	[defaultValuesDic setObject:@"2" forKey:@"DEFAULTRIGHTTOOL"];	// ZOOM TOOL
	[defaultValuesDic setObject:@"1" forKey:@"AUTOCLEANINGSPACE"];
//	[defaultValuesDic setObject:@"1" forKey:@"AUTOCLEANINGSPACEPRODUCED"];
//	[defaultValuesDic setObject:@"1" forKey:@"AUTOCLEANINGSPACEOPENED"];
    [defaultValuesDic setObject:@"2" forKey:@"AutocleanSpaceMode"];
	[defaultValuesDic setObject:@"1024" forKey:@"AUTOCLEANINGSPACESIZE"];
	[defaultValuesDic setObject:@"0" forKey:@"PETMinimumValue"];
	[defaultValuesDic setObject:@"1" forKey:@"PETWindowingMode"];  // Fixed Minimum
	[defaultValuesDic setObject:@"1" forKey:@"PETOpacityTable"];
	[defaultValuesDic setObject:@"Logarithmic Table" forKey: @"PET Default Opacity Table"];
	[defaultValuesDic setObject:@"0" forKey: @"OpacityTableNM"];
	[defaultValuesDic setObject:@"B/W Inverse" forKey:@"PET Clut Mode"];
	[defaultValuesDic setObject:@"PET" forKey: @"PET Default CLUT"];
	[defaultValuesDic setObject:@"PET" forKey: @"PET Blending CLUT"];
	[defaultValuesDic setObject:@"0" forKey:@"NETWORKLOGS"];
	[defaultValuesDic setObject:@"+xi" forKey:@"AETransferSyntax"];
	[defaultValuesDic setObject:@"" forKey:@"STORESCPEXTRA"];
	[defaultValuesDic setObject:@"0" forKey:@"ROITEXTIFSELECTED"];
	[defaultValuesDic setObject:@YES forKey: @"STORESCP"];
	[defaultValuesDic setObject:@"1" forKey: @"DCMPRINT_Interval"];
	[defaultValuesDic setObject:@"3" forKey: @"LISTENERCHECKINTERVAL"];
	[defaultValuesDic setObject:@"1" forKey: @"AUTOTILING"];
	[defaultValuesDic setObject:@YES forKey: @"USEALWAYSTOOLBARPANEL2"];
	[defaultValuesDic setObject:@"1" forKey: @"SquareWindowForPrinting"];
	[defaultValuesDic setObject:@"Softw Tissue CT" forKey: @"LAST_3D_PRESET"];
	[defaultValuesDic setObject:@"0" forKey:@"HIDEPATIENTNAME"];
	[defaultValuesDic setObject:@"1" forKey:@"onlyDICOM"];
	[defaultValuesDic setObject:@"0" forKey:@"CheckForMultipleVolumesInSeries"];
	[defaultValuesDic setObject:@"3000" forKey:@"MAXWindowSize"];
	[defaultValuesDic setObject:@"1" forKey:@"ScreenCaptureSmartCropping"];
	[defaultValuesDic setObject:@YES forKey:@"checkForUpdatesPlugins"];
    [defaultValuesDic setObject:@"0" forKey:@"DoNotDeleteCrashingPlugins"];
	[defaultValuesDic setObject:@"1" forKey:@"magnifyingLens"];
	[defaultValuesDic setObject:@"12" forKey:@"LabelFONTSIZE"];
	[defaultValuesDic setObject:@"Geneva" forKey:@"LabelFONTNAME"];
	[defaultValuesDic setObject:@"1" forKey:@"EmptyNameForNewROIs"];
	[defaultValuesDic setObject:@"1" forKey:@"nextSeriesToAllViewers"];
	[defaultValuesDic setObject:@"1" forKey:@"dontDeleteStudiesWithComments"];
	[defaultValuesDic setObject:@"1" forKey:@"displaySamePatientWithColorBackground"];
	[defaultValuesDic setObject:@"Exported Series" forKey:@"default2DViewerSeriesName"];
	[defaultValuesDic setObject:@"10000" forKey:@"DefaultFolderSizeForDB"];
	[defaultValuesDic setObject:@"10000" forKey:@"maxNumberOfFilesForCheckIncoming"];
	[defaultValuesDic setObject:@"0" forKey:@"useSoundexForName"];
	[defaultValuesDic setObject:@"1" forKey:@"printAt100%Minimum"];
	[defaultValuesDic setObject:@"1" forKey:@"allowSmartCropping"];
	[defaultValuesDic setObject:@"1" forKey:@"useDCMTKForAnonymization"];
	[defaultValuesDic setObject:@"1" forKey:@"useDCMTKForDicomExport"];
    [defaultValuesDic setObject:@"1" forKey:@"SupportQRModalitiesinStudy"];
    [defaultValuesDic setObject:@"1" forKey:@"CapitalizedString"];
    [defaultValuesDic setObject:@"1" forKey:@"hasFULL32BITPIPELINE"];
    [defaultValuesDic setObject:@"1" forKey:@"FULL32BITPIPELINE"];
    [defaultValuesDic setObject:@"4" forKey:@"MAXNUMBEROF32BITVIEWERS"];
    [defaultValuesDic setObject:@"1" forKey:@"CFINDCommentsAndStatusSupport"];
    [defaultValuesDic setObject:@"1" forKey:@"restorePasswordWebServer"];
    [defaultValuesDic setObject:@"comment" forKey:@"commentFieldForAutoFill"];
    [defaultValuesDic setObject:@(SYNCHRO_ID_ABS_RATIO) forKey:DEFAULT_MODE_FOR_NON_VOLUMIC_SERIES_KEY];
	[defaultValuesDic setObject:@"2" forKey:@"drawerState"]; // NSDrawerOpenState
	if ([[NSProcessInfo processInfo] processorCount] >= 4)
		[defaultValuesDic setObject:@"2.0" forKey:@"superSampling"];
	else
		[defaultValuesDic setObject:@"1.4" forKey:@"superSampling"];
	
    [defaultValuesDic setObject:@"200" forKey: @"FetchLimitForWebPortal"];
    
#pragma mark DELETEFILELISTENER

    [defaultValuesDic setObject:@"1" forKey:@"DELETEFILELISTENER"];
    
    [defaultValuesDic setObject:@"1" forKey:@"UseFloatingThumbnailsList"];
    [defaultValuesDic setObject:@"0.2" forKey: @"MinimumTitledGantryTolerance"]; // in degrees
//		
	long pVRAM_MB = [self vramSizeMB];
    if (pVRAM_MB == 0)
        pVRAM_MB = [DefaultsOsiriX GPUModelVRAMInfo];
#ifndef NDEBUG
	NSLog(@"VRAM: %li MB", pVRAM_MB);
#endif
	
#pragma mark MAX3DTEXTURE, MAX3DTEXTURESHADING

    if (pVRAM_MB >= 512)
	{	
		[defaultValuesDic setObject:@"256" forKey:@"MAX3DTEXTURE"];
		[defaultValuesDic setObject:@"128" forKey:@"MAX3DTEXTURESHADING"];
	}
	else if (pVRAM_MB >= 256)
	{
		[defaultValuesDic setObject:@"128" forKey:@"MAX3DTEXTURE"];
		[defaultValuesDic setObject:@"64" forKey:@"MAX3DTEXTURESHADING"];
	}
	else if (pVRAM_MB >= 128)
	{
		[defaultValuesDic setObject:@"128" forKey:@"MAX3DTEXTURE"];
		[defaultValuesDic setObject:@"32" forKey:@"MAX3DTEXTURESHADING"];
	}
	else
	{
		[defaultValuesDic setObject:@"32" forKey:@"MAX3DTEXTURE"];
		[defaultValuesDic setObject:@"32" forKey:@"MAX3DTEXTURESHADING"];
	}
			
#pragma mark BESTRENDERING

#if __ppc__
	[defaultValuesDic setObject:@"1.6" forKey:@"BESTRENDERING"];
#else
	[defaultValuesDic setObject:@"1.2" forKey:@"BESTRENDERING"];
#endif

    [defaultValuesDic setObject: @"120" forKey:@"DatabaseRefreshInterval"];
    
    [defaultValuesDic setObject: @"1" forKey:@"ShowAlbumOnlyIfNotEmpty"];
	[defaultValuesDic setObject: @"0" forKey:@"UseFrameofReferenceUID"];
	[defaultValuesDic setObject: @"1" forKey:@"savedCommentsAndStatusInDICOMFiles"];
	[defaultValuesDic setObject: @"1" forKey:@"CommentsFromDICOMFiles"];
	[defaultValuesDic setObject: @"1" forKey:@"OPENVIEWER"];
	[defaultValuesDic setObject: @"0" forKey: @"ConvertPETtoSUVautomatically"];
	[defaultValuesDic setObject: @"0" forKey: @"SURVEYDONE3"];
	[defaultValuesDic setObject: @"20" forKey: @"stackThickness"];
	[defaultValuesDic setObject: @"20" forKey: @"stackThicknessOrthoMPR"];
	[defaultValuesDic setObject: @"0" forKey:@"AUTOROUTINGACTIVATED"];
	[defaultValuesDic setObject: @"0" forKey:@"httpXMLRPCServer"];
	[defaultValuesDic setObject: @"8080" forKey:@"httpXMLRPCServerPort"];
	[defaultValuesDic setObject: @"0" forKey:OsirixWebPortalEnabledDefaultsKey];
	[defaultValuesDic setObject: @"3333" forKey:OsirixWebPortalPortNumberDefaultsKey];
	[defaultValuesDic setObject: @"1" forKey:@"StrechWindows"];
	[defaultValuesDic setObject: @"0" forKey:@"ROUTINGACTIVATED"];
	[defaultValuesDic setObject: @"0" forKey: @"AUTOHIDEMATRIX"];
	[defaultValuesDic setObject: @"0" forKey: @"AutoPlayAnimation"];
	[defaultValuesDic setObject: @"1" forKey: @"KeepStudiesOfSamePatientTogether"];
	[defaultValuesDic setObject: @"1" forKey: @"KeepStudiesOfSamePatientTogetherAndGrouped"];
	[defaultValuesDic setObject: @"1" forKey: @"USEPAPYRUSDCMPIX4"];
	[defaultValuesDic setObject: @"2" forKey: @"TOOLKITPARSER4"];	// 0:DCM Framework 1:Papyrus 2:DCMTK
	[defaultValuesDic setObject: @"1" forKey: @"PREFERPAPYRUSFORCD"];
    [defaultValuesDic setObject: @"20" forKey: @"maximumNumberOfConcurrentDICOMAssociations"];
    [defaultValuesDic setObject: @"10000" forKey: @"maximumNumberOfCFindObjects"];
    [defaultValuesDic setObject: @"0" forKey: @"TryIMAGELevelDICOMRetrieveIfLocalImages"];
	[defaultValuesDic setObject: @"1" forKey: @"SingleProcessMultiThreadedListener"];
	[defaultValuesDic setObject: @"0" forKey: @"AUTHENTICATION"];
	[defaultValuesDic setObject: @YES forKey: @"Check4Updates"];
	[defaultValuesDic setObject: @(CD_MODE_ASK_USER) forKey:CD_MOUNT_KEY];
	[defaultValuesDic setObject: @"1" forKey:@"CDDVDEjectAfterAutoCopy"];
//	[defaultValuesDic setObject: @"1" forKey:@"UNMOUNT"];
	[defaultValuesDic setObject: @"1" forKey: @"UseDICOMDIRFileCD"];
	[defaultValuesDic setObject: @"1" forKey: @"SAVEROIS"];
	[defaultValuesDic setObject: @"1" forKey: @"NOLOCALIZER"];
	[defaultValuesDic setObject: @"0" forKey: @"TRANSITIONEFFECT"];  // unused ?
	[defaultValuesDic setObject: @NO  forKey: @"NOINTERPOLATION"];
    [defaultValuesDic setObject: @"0" forKey: @"MultipleAssociationsRetrieve"];
    [defaultValuesDic setObject: @"3" forKey: @"NoOfMultipleAssociationsRetrieve"];
	[defaultValuesDic setObject: @(WINDOW_SIZE_FULL_SCREEN) forKey: WINDOWSIZEVIEWER_KEY];
	[defaultValuesDic setObject: @YES forKey: @"UseOpenJpegForJPEG2000"];
	//[defaultValuesDic setObject: @"0" forKey: @"UseKDUForJPEG2000"];
	[defaultValuesDic setObject: @"0" forKey: @"KeepStudiesTogetherOnSameScreen"];
	[defaultValuesDic setObject: @"1" forKey: @"ShowErrorMessagesForAutorouting"];
	[defaultValuesDic setObject: @"1" forKey: @"SAMESTUDY"];
	[defaultValuesDic setObject: @"0" forKey: @"recomputePatientUID"];
	[defaultValuesDic setObject: @"1" forKey: @"ReserveScreenForDB"];
	[defaultValuesDic setObject: @"1" forKey: @"notificationsEmailsInterval"];
    [defaultValuesDic setObject: @"1" forKey: @"automaticallyRetrievePartialStudies"];
	NSDateFormatter	*dateFormat = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormat setDateStyle: NSDateFormatterShortStyle];
	[defaultValuesDic setObject: [dateFormat dateFormat] forKey:@"DBDateOfBirthFormat2"];
	[dateFormat setDateStyle: NSDateFormatterShortStyle];
	[dateFormat setTimeStyle: NSDateFormatterShortStyle];
	[defaultValuesDic setObject: [dateFormat dateFormat] forKey:@"DBDateFormat2"];
	
	NSDictionary *defaultAnnotations = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"AnnotationsDefault" ofType:@"plist"]];
	if (defaultAnnotations)
		[defaultValuesDic setObject: defaultAnnotations forKey:@"CUSTOM_IMAGE_ANNOTATIONS"];
	[defaultValuesDic setObject:@"0" forKey:@"SERIESORDER"];
	[defaultValuesDic setObject:@"40" forKey:@"DICOMTimeout"];
    [defaultValuesDic setObject:@"10" forKey:@"DICOMConnectionTimeout"];
	[defaultValuesDic setObject:@"1" forKey:@"NSWindowsSetFrameAnimate"];
	[defaultValuesDic setObject: @"0" forKey: @"TRANSITIONTYPE"];
#ifdef MIELE_LIGHT
	[defaultValuesDic setObject: @NO forKey: @"COPYDATABASE"];
#else
	[defaultValuesDic setObject: @YES forKey: @"COPYDATABASE"];
#endif
	[defaultValuesDic setObject: @"0" forKey: @"SUVCONVERSION"];
	[defaultValuesDic setObject: @"1" forKey: @"NoImageTilingInFullscreen"];
	[defaultValuesDic setObject: @"0" forKey: @"AUTOCLEANINGCOMMENTS"];
	[defaultValuesDic setObject: @"" forKey: @"AUTOCLEANINGCOMMENTSTEXT"];
	[defaultValuesDic setObject: @"0" forKey: @"AUTOCLEANINGDONTCONTAIN"];
	[defaultValuesDic setObject: @"0" forKey: @"AUTOCLEANINGDELETEORIGINAL"];
	[defaultValuesDic setObject: @"0" forKey: @"COMMENTSAUTOFILL"];
	[defaultValuesDic setObject: SYNC_DICOM_NODES_URL forKey: @"syncDICOMNodesURL"];
	[defaultValuesDic setObject: SYNC_DB_URL forKey: @"syncOsiriXDBURL"];
	[defaultValuesDic setObject: @"1" forKey: @"BurnOsirixApplication"];
	[defaultValuesDic setObject: @"1" forKey: @"BurnHtml"];
	[defaultValuesDic setObject: @"0" forKey: @"BurnSupplementaryFolder"];
	[defaultValuesDic setObject: @"1" forKey: @"splineForROI"];
	[defaultValuesDic setObject:@"0" forKey:@"ThreeDViewerOnAnotherScreen"];
	[defaultValuesDic setObject:@"512" forKey:@"SOFTWAREINTERPOLATION_MAX"];
	[defaultValuesDic setObject:@"1" forKey:@"SOFTWAREINTERPOLATION"];
	[defaultValuesDic setObject:@"0" forKey:@"DATABASEINDEX"];
	[defaultValuesDic setObject:@(ANNOTATIONS_BASE) forKey: ANNOTATIONS_KEY];
	[defaultValuesDic setObject:@(CLUT_BAR_HIDE) forKey :CLUTBARS_KEY];
	[defaultValuesDic setObject:@"60" forKey: @"temporaryUserDuration"];
	[defaultValuesDic setObject:@(COPY_DB_ASK_USER) forKey:COPYDATABASEMODE_KEY];
	[defaultValuesDic setObject:@"7" forKey:@"LOGCLEANINGDAYS"];
	[defaultValuesDic setObject:@"1" forKey:@"AUTOMATIC FUSE"];

    [defaultValuesDic setObject:@"0" forKey:@"DEFAULT_DATABASELOCATION"]; // Documents directory
	[defaultValuesDic setObject:@"" forKey:@"DEFAULT_DATABASELOCATIONURL"];
	[defaultValuesDic setObject:@"0" forKey: @"DATABASELOCATION"];
	[defaultValuesDic setObject:@"" forKey: @"DATABASELOCATIONURL"];

    [defaultValuesDic setObject: @"Geneva" forKey: @"FONTNAME"];
	[defaultValuesDic setObject: @"1" forKey: @"DICOMSENDALLOWED"];
	[defaultValuesDic setObject: @"14.0" forKey: @"FONTSIZE"];
	[defaultValuesDic setObject: @(REPORT_TYPE_PAGES) forKey: @"REPORTSMODE"];
	[defaultValuesDic setObject: URL_MIELE_WEB_PAGE@"/internet.dcm" forKey: @"LASTURL"];
	[defaultValuesDic setObject: @(ENGINE_CPU) forKey: @"MAPPERMODEVR"];
	[defaultValuesDic setObject: @"1" forKey: @"STARTCOUNT"];
	[defaultValuesDic setObject: @"1" forKey: @"editingLevel"];
	[defaultValuesDic setObject: @"1" forKey: @"publishDICOMBonjour"];
	[defaultValuesDic setObject: @"1" forKey: @"searchDICOMBonjour"];
	[defaultValuesDic setObject: @"1" forKey: @"autorotate3D"];
	[defaultValuesDic setObject: @"1" forKey: @"preferencesModificationsEnabled"];
	[defaultValuesDic setObject: @"0" forKey: @"Compression Mode for Export"];
	[defaultValuesDic setObject: @"0" forKey: @"ORIGINALSIZE"];
	[defaultValuesDic setObject: @"1" forKey: @"Scroll Wheel Reversed"];
	[defaultValuesDic setObject: @"Miele-LXIV" forKey: @"ALBUMNAME"];
	[defaultValuesDic setObject: @"1" forKey: @"DisplayCrossReferenceLines"];
	[defaultValuesDic setObject: @"0" forKey: @"AlwaysScaleToFit"];
	[defaultValuesDic setObject:@(VR_VIEW_SIZE_SQUARE_FULL_SCREEN) forKey: VRDefaultViewSize_KEY];
	[defaultValuesDic setObject:@"0" forKey: @"RunListenerOnlyIfActive"];
	[defaultValuesDic setObject:@"0" forKey: @"UseShutter"];
	[defaultValuesDic setObject:@"1" forKey: @"UseVOILUT"];
	[defaultValuesDic setObject:@"0" forKey: @"replaceAnonymize"];
	[defaultValuesDic setObject:@"0" forKey: @"anonymizedBeforeBurning"];
	[defaultValuesDic setObject:@"0" forKey: @"ZoomWithHorizonScroll"];
	[defaultValuesDic setObject:@"1" forKey: @"dcmExportFormat"];
    [defaultValuesDic setObject:@"0" forKey: @"CFINDBodyPartExaminedSupport"];
	[defaultValuesDic setObject:@"2" forKey: @"preferredSyntaxForIncoming"]; // 2 = EXS_LittleEndianExplicit See dcmqrsrv.mm
	[defaultValuesDic setObject:@"ISO_IR 100" forKey: @"STRINGENCODING"];
	[defaultValuesDic setObject:@"1" forKey:@"syncPreviewList"];
	[defaultValuesDic setObject:@"1" forKey:@"openPDFwithPreview"];
	[defaultValuesDic setObject:@"1" forKey:@"ROIArrowThickness"];
	[defaultValuesDic setObject:@"1" forKey:@"loopScrollWheel"];
	[defaultValuesDic setObject:@"1" forKey:@"UseJPEGColorSpace"];
	[defaultValuesDic setObject:@"0" forKey:@"displayCobbAngle"];
	[defaultValuesDic setObject:@"0" forKey:@"onlyDisplayImagesOfSamePatient"];
	[defaultValuesDic setObject:@"1" forKey:@"activateCGETSCP"];
    [defaultValuesDic setObject:@"1" forKey:@"activateCFINDSCP"];
    [defaultValuesDic setObject:@"1" forKey:@"activateCMOVESCP"];
    
#if 1
    NSColor *colorPeak = [NSColor colorWithCalibratedRed:0.5 green:0.5 blue:1.0 alpha:1.0];
    NSColor *colorIso  = [NSColor colorWithCalibratedRed:0.5 green:1.0 blue:0.5 alpha:1.0];
    NSData *dataPeak = [NSArchiver archivedDataWithRootObject:colorPeak];
    NSData *dataIso = [NSArchiver archivedDataWithRootObject:colorIso];
    [defaultValuesDic setObject: dataPeak forKey: @"peakValueColor"];
    [defaultValuesDic setObject: dataIso  forKey: @"isoContourColor"];
#else
    // Miele-LXIV Lite does it this way ?
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 0.5 * 65535.] forKey:@"peakValueColorR"];
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 0.5 * 65535.] forKey:@"peakValueColorG"];
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"peakValueColorB"];
    
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 0.5 * 65535.] forKey:@"isoContourColorR"];
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"isoContourColorG"];
    [defaultValuesDic setObject:[NSNumber numberWithFloat: 0.5 * 65535.] forKey:@"isoContourColorB"];
#endif

    [defaultValuesDic setObject:@"0" forKey:@"DICOMSCPOnAllDatabases"]; // TODO: make use of it
    [defaultValuesDic setObject:@"0" forKey:@"notificationsEmails"];
	[defaultValuesDic setObject:@"0" forKey:@"validateFilesBeforeImporting"];
	[defaultValuesDic setObject:@"10" forKey:@"defaultFrameRate"];
	[defaultValuesDic setObject:@"10" forKey:@"quicktimeExportRateValue"];
    [defaultValuesDic setObject:AVVideoCodecJPEG forKey:@"selectedMenuAVFoundationExport"];
	[defaultValuesDic setObject:@"0" forKey:@"32bitDICOMAreAlwaysIntegers"];
	[defaultValuesDic setObject:@"1" forKey:@"archiveReportsAndAnnotationsAsDICOMSR"];
	[defaultValuesDic setObject:@"1" forKey:@"SelectWindowScrollWheel"];
	[defaultValuesDic setObject:@"1" forKey:@"useDCMTKForJP2K"]; // deprecated
	[defaultValuesDic setObject:@"1" forKey:@"MouseClickZoomCentered"];
	[defaultValuesDic setObject:@"1" forKey:@"exportOrientationIn3DExport"];
	[defaultValuesDic setObject:@"600" forKey:@"WADOTimeout"];
	[defaultValuesDic setObject:@"10" forKey:@"WADOMaximumConcurrentDownloads"];
	[defaultValuesDic setObject:@"1" forKey:@"autoSelectSourceCDDVD"];
	[defaultValuesDic setObject:@"1" forKey:@"ScanDiskIfDICOMDIRZero"];
	[defaultValuesDic setObject:@"1" forKey:@"WebServerTagUploadedStudiesWithUsername"];
    [defaultValuesDic setObject:@"20" forKey:@"MaxNumberOfRetrieveForAutoQR"];
    [defaultValuesDic setObject:@"1800" forKey:@"WebServerTimeOut"]; // = 30*60 = 30 min 120*60 = 2 hours
    [defaultValuesDic setObject:@"400" forKey:@"MaxNumberOfFramesForWebPortalMovies"];
    [defaultValuesDic setObject:@"880" forKey:@"WebServerMaxWidthForMovie"];
    [defaultValuesDic setObject:@"880" forKey:@"WebServerMaxWidthForStillImage"];
    [defaultValuesDic setObject:@"512" forKey:@"WebServerMinWidthForMovie"];
    [defaultValuesDic setObject:@"1" forKey:@"WebServerUseMailAppForEmails"];
    [defaultValuesDic setObject:@"1" forKey:@"DICOMQueryAllowFutureQuery"];
    [defaultValuesDic setObject:@"1" forKey:@"SeriesListVisible"];
    [defaultValuesDic setObject:@"1" forKey:@"RescaleDuring3DResampling"];
    [defaultValuesDic setObject:@"1" forKey:@"listPODComparativesIn2DViewer"];
    [defaultValuesDic setObject:@"1" forKey:@"OVERFLOWLINES"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_name"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_id"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_accession_number"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_birthdate"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_description"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_referring_physician"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_comments"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_institution"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_status"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_study_date"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_modality"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_blank_query"];
    [defaultValuesDic setObject:@"1" forKey:@"allow_qr_custom_dicom_field"];
    [defaultValuesDic setObject:@"2" forKey:@"MaxConcurrentPODRetrieves"];
	[defaultValuesDic setObject:@"1" forKey:@"QRRemoveDuplicateEntries"];
    [defaultValuesDic setObject:@"1" forKey:@"tileWindowsOrderByStudyDate"];
    [defaultValuesDic setObject:@"1" forKey:@"AllowPluginAuthenticationForWebPortal"];
	[defaultValuesDic setObject:@"1" forKey:@"UsePatientBirthDateForUID"];
    [defaultValuesDic setObject:@"1" forKey:@"UsePatientIDForUID"];
	[defaultValuesDic setObject:@"1" forKey:@"UsePatientNameForUID"];
    [defaultValuesDic setObject:@"1" forKey:@"putSrcAETitleInSourceApplicationEntityTitle"];
    [defaultValuesDic setObject:@"0" forKey:@"putDstAETitleInPrivateInformationCreatorUID"];
    [defaultValuesDic setObject:@"1" forKey:@"wadoRequestRequireValidToken"];
    [defaultValuesDic setObject:@"1024" forKey: @"DicomImageScreenCaptureWidth"];
    [defaultValuesDic setObject:@"1024" forKey: @"DicomImageScreenCaptureHeight"];
    [defaultValuesDic setObject:@"30" forKey: @"WebPortalMaximumNumberOfRecentStudies"];
    [defaultValuesDic setObject:@"10" forKey: @"WebPortalMaximumNumberOfDaysForRecentStudies"];
    [defaultValuesDic setObject:@"2" forKey:@"yearOldDatabaseDisplay"];
    [defaultValuesDic setObject:@"1" forKey:@"SendControllerConcurrentThreads"];
    [defaultValuesDic setObject:@"4" forKey:@"MaximumSendControllerConcurrentThreads"];
    [defaultValuesDic setObject:@"4" forKey:@"MaximumSendGlobalControllerConcurrentThreads"];
    [defaultValuesDic setObject:@"1" forKey:@"COMMENTSAUTOFILLStudyLevel"];
    [defaultValuesDic setObject:@YES forKey:@"ROIDrawPlainEdge"];
    [defaultValuesDic setObject:@"1" forKey:@"PACSOnDemandForSearchField"];
    [defaultValuesDic setObject:@"1" forKey:@"CloseAllWindowsBeforeXMLRPCOpen"];
    
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeries"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForCR"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForMG"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForRF"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForDR"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForDX"];
    [defaultValuesDic setObject:@YES forKey:@"scrollThroughSeriesForOT"];
    
    [defaultValuesDic setObject:@"0.01" forKey:@"PARALLELPLANETOLERANCE"]; // In radians: 0.01 = about 0.5 degrees
    [defaultValuesDic setObject:@"0.1" forKey:@"PARALLELPLANETOLERANCE-Sync"];
    
    [defaultValuesDic setObject:@"1" forKey:@"bringOsiriXToFrontAfterReceivingMessage"];
    
#ifdef MACAPPSTORE
	[defaultValuesDic setObject:@"1" forKey:@"MACAPPSTORE"];
#else
	[defaultValuesDic setObject:@"0" forKey:@"MACAPPSTORE"];
#endif
	
	[defaultValuesDic setObject: [NSArray arrayWithObjects: [DCMAbstractSyntaxUID MRSpectroscopyStorage], nil] forKey:@"additionalDisplayedStorageSOPClassUIDArray"];
	
#pragma mark  ROI Default

    [defaultValuesDic setObject:@2.0F forKey:@"ROIThickness"];
	[defaultValuesDic setObject:@3.0F forKey:@"ROITextThickness"];
	[defaultValuesDic setObject:@1.0F forKey:@"ROIOpacity"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 0.3 * 65535.] forKey:@"ROIColorR"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"ROIColorG"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 0.3 * 65535.] forKey:@"ROIColorB"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"ROITextColorR"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"ROITextColorG"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 0.0 * 65535.] forKey:@"ROITextColorB"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 1.0 * 65535.] forKey:@"ROIRegionColorR"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 0.0 * 65535.] forKey:@"ROIRegionColorG"];
	[defaultValuesDic setObject:[NSNumber numberWithFloat: 0.0 * 65535.] forKey:@"ROIRegionColorB"];
	[defaultValuesDic setObject:@0.5F forKey:@"ROIRegionOpacity"];
	[defaultValuesDic setObject:@5.0F forKey:@"ROIRegionThickness"];
    //--- tBall
    [defaultValuesDic setObject:@YES forKey:@"computePeakValue"];
    [defaultValuesDic setObject:@10 forKey:@"peakDiameterInMm"]; // slider
    [defaultValuesDic setObject:@NO forKey:@"computeIsoContour"];
    [defaultValuesDic setObject:@2.5F forKey:@"minimumBallROIIsoContour"];
    [defaultValuesDic setObject:@YES forKey:@"definedMaximumForBallROIIsoContour"]; // tickbox
    [defaultValuesDic setObject:@999999.0F forKey:@"maximumBallROIIsoContour"]; // slider
    // Percentages
    [defaultValuesDic setObject:@NO forKey:@"percentageIsoContour"];
    [defaultValuesDic setObject:@0.42F forKey:@"minimumBallROIIsoContourPercentage"];
    [defaultValuesDic setObject:@NO forKey:@"definedMaximumForBallROIIsoContourPercentage"]; // tickbox
    [defaultValuesDic setObject:@1.0F forKey:@"maximumBallROIIsoContourPercentage"]; // slider
    // Top color
    [defaultValuesDic setObject:@1.0F forKey:@"peakValueColorR"];
    [defaultValuesDic setObject:@0.5F forKey:@"peakValueColorG"];
    [defaultValuesDic setObject:@0.5F forKey:@"peakValueColorB"];
    // Bottom color
    [defaultValuesDic setObject:@0.5F forKey:@"isoContourColorR"];
    [defaultValuesDic setObject:@0.5F forKey:@"isoContourColorG"];
    [defaultValuesDic setObject:@1.0F forKey:@"isoContourColorB"];

#pragma mark HANGING PROTOCOLS

    NSMutableDictionary *defaultHangingProtocols = [NSMutableDictionary dictionary];
	NSArray *modalities = [NSArray arrayWithObjects:
                           NSLocalizedString(@"CR", nil),
                           NSLocalizedString(@"CT", nil),
                           NSLocalizedString(@"DX", nil),
                           NSLocalizedString(@"ES", nil),
                           NSLocalizedString(@"MG", nil),
                           NSLocalizedString(@"MR", nil),
                           NSLocalizedString(@"NM", nil),
                           NSLocalizedString(@"OT", nil),
                           NSLocalizedString(@"PT", nil),
                           NSLocalizedString(@"RF", nil),
                           NSLocalizedString(@"SC", nil),
                           NSLocalizedString(@"US", nil),
                           NSLocalizedString(@"XA", nil),
                           nil];
    
	for (NSString *modality in modalities)
    {
		NSMutableDictionary *protocol = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects: NSLocalizedString( @"Default", nil), @0, @0, nil] forKeys:[NSArray arrayWithObjects:@"Study Description", @"WindowsTiling", @"ImageTiling", nil]];
        
        if ([modality isEqualToString: @"MG"])
        {
            [protocol setObject: @5 forKey: @"WindowsTiling"]; // 2 x 2
            [protocol setObject: @"R CC,L CC,R MLO,L MLO" forKey: @"SeriesOrder"];
            [protocol setObject: @4 forKey: @"NumberOfSeriesPerComparative"];
        }
		[defaultHangingProtocols setObject: [NSMutableArray arrayWithObject:protocol] forKey:modality];
	}
	[defaultValuesDic setObject: defaultHangingProtocols forKey: @"HANGINGPROTOCOLS"];
	
#pragma mark COLUMNSDATABASE

    NSMutableDictionary *defaultDATABASECOLUMNS = [NSMutableDictionary dictionary];
	[defaultValuesDic setObject: defaultDATABASECOLUMNS forKey: @"COLUMNSDATABASE"];

	[defaultValuesDic setObject: @"20" forKey: @"MaxNumberOfRecentStudies"];
    
    [defaultValuesDic setObject: @"1" forKey: @"noPropagateInSeriesForCR"];
    [defaultValuesDic setObject: @"1" forKey: @"noPropagateInSeriesForDR"];
    [defaultValuesDic setObject: @"1" forKey: @"noPropagateInSeriesForDX"];
    [defaultValuesDic setObject: @"1" forKey: @"noPropagateInSeriesForRF"];
    [defaultValuesDic setObject: @"1" forKey: @"noPropagateInSeriesForXA"];
    
	[defaultValuesDic setObject: @"1" forKey: @"COPYSETTINGS"];
	[defaultValuesDic setObject: @"1" forKey: @"USESTORESCP"];
	[defaultValuesDic setObject: @"1" forKey: @"splitMultiEchoMR"];
	[defaultValuesDic setObject: @"0" forKey: @"useSeriesDescription"];
	[defaultValuesDic setObject: @"1" forKey: @"combineProjectionSeries"];
	[defaultValuesDic setObject: @"1" forKey: @"combineProjectionSeriesMode"];
	[defaultValuesDic setObject: @(LISTENER_COMPRESSION_DONT_MODIFY) forKey:ListenerCompressionSettings_KEY];
	[defaultValuesDic setObject: @"localizer,scout,survey,locator,tracker" forKey: @"NOLOCALIZER_Strings"];
	
	//hot key prefs
	NSMutableDictionary *hotkeys = [NSMutableDictionary dictionary];
	
	NSString *stringValue;
	NSArray *array = [NSArray arrayWithObjects:
						@"~",	//DefaultWWWLHotKeyAction
						@"0",	//FullDynamicWWWLHotKeyAction
						@"1",	//Preset1WWWLHotKeyAction
						@"2",	//Preset2WWWLHotKeyAction
						@"3",	//Preset3WWWLHotKeyAction
						@"4",	//Preset4WWWLHotKeyAction
						@"5",	//Preset5WWWLHotKeyAction
						@"6",	//Preset6WWWLHotKeyAction
						@"7",	//Preset7WWWLHotKeyAction
						@"8",	//Preset8WWWLHotKeyAction
						@"9",	//Preset9WWWLHotKeyAction
						@"v",	//FlipVerticalHotKeyAction
						@"h",	//FlipHorizontalHotKeyAction
						@"w",	//WWWLToolHotKeyAction
						@"m",	//MoveHotKeyAction
						@"z",	//ZoomHotKeyAction
						@"i",	//RotateHotKeyAction
						@"",	//ScrollHotKeyAction
						@"l",	//LengthHotKeyAction
						@"a",	//AngleHotKeyAction
						@"",	//RectangleHotKeyAction
						@"e",	//OvalHotKeyAction
						@"t",	//TextHotKeyAction
						@"q",	//ArrowHotKeyAction
						@"o",	//OpenPolygonHotKeyAction
						@"c",	//ClosedPolygonHotKeyAction
						@"d",	//PencilHotKeyAction
						@"p",	//ThreeDPointHotKeyAction
						@"b",	//PlainToolHotKeyAction
						@"x",	//BoneRemovalHotKeyAction
						@"[",	//Rotate3DHotKeyAction
						@"]",	//Camera3DotKeyAction
						@"\\",	//scissors3DHotKeyAction
						@"r",	//RepulsorHotKeyAction
						@"s",	//SelectorHotKeyAction
						@",",	//EmptyHotKeyAction
						@".",	//UnreadHotKeyAction
						@"/",	//ReviewedHotKeyAction
						@"\\",	//DictatedHotKeyAction
                        @"",	//ValidatedHotKeyAction
						@"y",	//OrthoMPRCrossTool
                      @"",	//Preset1OpacityLHotKeyAction
                      @"",	//Preset2OpacityLHotKeyAction
                      @"",	//Preset3OpacityLHotKeyAction
                      @"",	//Preset4OpacityLHotKeyAction
                      @"",	//Preset5OpacityLHotKeyAction
                      @"",	//Preset6OpacityLHotKeyAction
                      @"",	//Preset7OpacityLHotKeyAction
                      @"",	//Preset8OpacityLHotKeyAction
                      @"",	//Preset9OpacityLHotKeyAction
                      @"dbl-click",	//FullScreenAction
                      @"dbl-click + alt",	//Sync3DAction
                      @"dbl-click + cmd",	//SetKeyImageAction
						nil];						
	
	for ( int x = 0; x < [array count]; x++)
	{
		stringValue = [array objectAtIndex:x];
		[hotkeys setObject:[NSNumber numberWithInt:x] forKey:stringValue];
//		[hotkeysModifiers setObject:@0 forKey:stringValue];
	}
	[defaultValuesDic setObject:hotkeys forKey:@"HOTKEYS"];
	
	NSArray *compressionSettings = [NSArray arrayWithObjects: 
							[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString( @"default", nil), @"modality", @"3", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"CR", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"CT", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"DX", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"ES", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"MG", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"MR", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"NM", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"OT", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"PT", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"RF", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"SC", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"US", @"modality", @"0", @"compression", @"1", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"XA", @"modality", @"0", @"compression", @"1", @"quality", nil],
							nil]; 
	
	[defaultValuesDic setObject: @"512" forKey: @"CompressionResolutionLimit"];
	
	[defaultValuesDic setObject: compressionSettings forKey:@"CompressionSettings"];
	
	NSArray *compressionSettingsLowRes = [NSArray arrayWithObjects: 
							[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString( @"default", nil), @"modality", @"3", @"compression", @"0", @"quality", nil], 
							[NSDictionary dictionaryWithObjectsAndKeys: @"CR", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"CT", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"DX", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"ES", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"MG", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"MR", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"NM", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"OT", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"PT", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"RF", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"SC", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"US", @"modality", @"0", @"compression", @"0", @"quality", nil],
							[NSDictionary dictionaryWithObjectsAndKeys: @"XA", @"modality", @"0", @"compression", @"0", @"quality", nil],
							nil]; 
	
	[defaultValuesDic setObject: compressionSettingsLowRes forKey:@"CompressionSettingsLowRes"];
	
	
	// Comparison Body Regions
//	NSArray *headRegions = [NSArray arrayWithObjects: 
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HEAD", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"BRAIN", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FACE", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ORBIT", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ORBITS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"IAC", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PITUITARY", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"SINUS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"MAXILLOFACIAL", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"TEMPORAL BONE", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"MANDIBLE", nil), @"region",
//									nil],
//								nil];
//								
//		NSArray *neckRegions = [NSArray arrayWithObjects: 
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"NECK", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CERVICAL", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CAROTID", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"THYROID", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"C SPINE", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"BRACHIAL", nil), @"region",
//									nil],
//								nil];
//								
//		NSArray *chestRegions = [NSArray arrayWithObjects: 
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CHEST", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"LUNG", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"THORAX", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"THORACIC", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PULMONARY", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"MEDIASTINUM", nil), @"region",
//									@YES, @"isLeaf",
//									@0, @"count",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HEART", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CARDIAC", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"T SPINE", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"STERNUM", nil), @"region",
//									nil],
//								nil];
//								
//		NSArray *abdomenRegions = [NSArray arrayWithObjects: 
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ABDOMEN", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ABD", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"LIVER", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PANCREAS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"KIDNEY", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"RENAL", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ADRENAL", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"IVP", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"L SPINE", nil), @"region",
//									nil],
//								nil];
//								
//			NSArray *pelvisRegions = [NSArray arrayWithObjects: 
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PELVIS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PELVIC", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"BLADDER", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"APPENDIX", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HIP", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HIPS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"UTERUS", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"OVARY", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"OVARIES", nil), @"region",
//									nil],
//								[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"PROSTATE", nil), @"region",
//									nil],
//								nil];
//			
//			NSArray *thighRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"THIGH", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FEMUR", nil), @"region",
//									nil],
//							nil];
//			NSArray *kneeRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"KNEE", nil), @"region",
//									nil],
//							nil];
//			NSArray *lowerLegRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"LOWER LEG", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"TIBIA", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FIBULA", nil), @"region",
//									nil],
//							nil];
//			NSArray *footRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FOOT", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ANKLE", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"TOE", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"TOES", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HEEL", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CALCANEUS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"OS CALCIS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"TALUS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HALLUX", nil), @"region",
//									nil],
//							nil];
//							
//			NSArray *shoulderRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"SHOULDER", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CLAVICLE", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"AC JOINT", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ACROMIAL", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"SCAPULA", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"BICEPS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ROTATOR CUFF", nil), @"region",
//									nil],
//							nil];
//			NSArray *armRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HUMERUS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"UPPER ARM", nil), @"region",
//									nil],
//							nil];
//			NSArray *elbowRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ELBOW", nil), @"region",
//									nil],
//							nil];
//			NSArray *forearmRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FOREARM", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"RADIUS", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"ULNA", nil), @"region",
//									nil],
//							nil];
//		
//			NSArray *handRegions = [NSArray arrayWithObjects:	
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"HAND", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"WRIST", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"THUMB", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"FINGER", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"CARPAL", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"NAVICULAR", nil), @"region",
//									nil],
//							[NSDictionary dictionaryWithObjectsAndKeys:
//									NSLocalizedString(@"SCAPHOID", nil), @"region",
//									nil],
//							nil];									
//												
//	
//	 NSDictionary *headRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"HEAD", nil), @"region",
//				headRegions, @"keywords",
//				nil];
//	NSDictionary *neckRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"NECK", nil), @"region",
//				neckRegions, @"keywords",
//				nil];
//	NSDictionary *chestRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"CHEST", nil), @"region",
//				chestRegions, @"keywords",
//				nil];
//	NSDictionary *abdomenRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"ABDOMEN", nil), @"region",
//				abdomenRegions, @"keywords",
//				nil];
//	NSDictionary *pelvisRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"PELVIS", nil), @"region",
//				pelvisRegions, @"keywords",
//				nil];
//	NSDictionary *thighRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"THIGH", nil), @"region",
//				thighRegions, @"keywords",
//				nil];
//	NSDictionary *kneeRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"KNEE", nil), @"region",
//				kneeRegions, @"keywords",
//				nil];
//	NSDictionary *lowerLegRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"LOWER LEG", nil), @"region",
//				lowerLegRegions, @"keywords",
//				nil];
//	NSDictionary *footRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"FOOT", nil), @"region",
//				footRegions, @"keywords",
//				nil];
//	NSDictionary *shoulderRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"SHOULDER", nil), @"region",
//				shoulderRegions, @"keywords",
//				nil];
//	NSDictionary *armRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"UPPER ARM", nil), @"region",
//				armRegions, @"keywords",
//				nil];
//	NSDictionary *elbowRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"ELBOW", nil), @"region",
//				elbowRegions, @"keywords",
//				nil];
//	NSDictionary *forearmRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"FOREARM", nil), @"region",
//				forearmRegions, @"keywords",
//				nil];
//	NSDictionary *handRegion = [NSDictionary dictionaryWithObjectsAndKeys:
//				NSLocalizedString(@"HAND", nil), @"region",
//				handRegions, @"keywords",
//				nil];
//	
//	NSArray *bodyRegions = [NSArray arrayWithObjects:
//				headRegion,
//				neckRegion,
//				chestRegion,
//				abdomenRegion,
//				pelvisRegion,
//				shoulderRegion,
//				armRegion,
//				elbowRegion,
//				forearmRegion,
//				handRegion,
//				thighRegion,
//				kneeRegion,
//				lowerLegRegion,
//				footRegion,
//				nil];
//	
//	[defaultValuesDic setObject:bodyRegions forKey:@"bodyRegions"];
	
	// ITK Segmentation Defaults
	[defaultValuesDic setObject: @0 forKey:@"growingRegionType"];
	[defaultValuesDic setObject: @0 forKey:@"growingRegionAlgorithm"];
	[defaultValuesDic setObject: @YES forKey:@"previewGrowingRegion"];
	[defaultValuesDic setObject: @100 forKey:@"growingRegionInterval"];
	[defaultValuesDic setObject: @0 forKey:@"growingRegionLowerThreshold"];
	[defaultValuesDic setObject: @100 forKey:@"growingRegionUpperThreshold"];
	[defaultValuesDic setObject: @2 forKey:@"growingRegionRadius"];
	[defaultValuesDic setObject: @2.5F forKey:@"growingRegionMultiplier"];
	[defaultValuesDic setObject: @5 forKey:@"growingRegionIterations"];
	[defaultValuesDic setObject: @0 forKey:@"growingRegionROIType"];
	[defaultValuesDic setObject: @20 forKey:@"growingRegionPointCount"];
	[defaultValuesDic setObject: NSLocalizedString(@"Growing Region", nil) forKey:@"growingRegionROIName"];
	[defaultValuesDic setObject: @0 forKey:@"displayCalciumScore"];
	[defaultValuesDic setObject: @0 forKey:@"CalciumScoreCTType"];
    [defaultValuesDic setObject: @YES forKey: @"defaultShading"];
    [defaultValuesDic setObject: @YES forKey: @"dontDeleteStudiesIfInAlbum"];
		
	[defaultValuesDic setObject: @YES forKey:OsirixWadoServiceEnabledDefaultsKey];
	[defaultValuesDic setObject: @YES forKey:OsirixWebPortalUsesWeasisDefaultsKey];
	[defaultValuesDic setObject: @YES forKey:OsirixWebPortalPrefersFlashDefaultsKey];
    
    [defaultValuesDic setObject: @NO forKey:@"verbose_dcmtkStoreScu"];
	
	return defaultValuesDic;
}
@end
