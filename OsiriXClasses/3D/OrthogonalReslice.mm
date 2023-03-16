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

#import "OrthogonalReslice.h"
#import "WaitRendering.h"
#import "N2Debug.h"

#include <Accelerate/Accelerate.h>

@interface ResliceOperation: NSOperation
{
    NSDictionary *dict;
}

- (id) initWithDict:(NSDictionary *) d;

@end

#pragma mark -

@implementation ResliceOperation

- (id) initWithDict:(NSDictionary *) d
{
    self = [super init];
    dict = [d retain];
    
    return self;
}

- (void) main
{
    @autoreleasepool
    {
        NSLog( @"+");
        
        NSArray *originalDCMPixList = [dict objectForKey: @"DCMPixArray"];
        DCMPix *fPix = [originalDCMPixList objectAtIndex: 0];
        float *Ycache = (float *)[[dict objectForKey: @"Ycache"] pointerValue];
        
        int	z;
        const int maxY = [fPix pheight];
        const int maxX = [fPix pwidth];
        
        z = [[dict objectForKey:@"zValue"] intValue];
        
        float *basedstPtr = Ycache + z*maxY*maxX;
        float *basesrcPtr = [[originalDCMPixList objectAtIndex: z] fImage];
        int x = maxX;
        while (x-->0)
        {
            float *dstPtr = basedstPtr;
            float *srcPtr = basesrcPtr;
            
            basedstPtr += maxY;
            basesrcPtr++;
            
            int yy = maxY;
            while (yy-->0)
            {
                *dstPtr++ = *srcPtr;
                srcPtr += maxX;
            }
        }
    }
}

- (void) dealloc
{
    [dict release];
    [super dealloc];
}

@end

#pragma mark -

@implementation OrthogonalReslice

- (id) init
{
	if (self = [super init])
	{
		xReslicedDCMPixList = [[NSMutableArray alloc] initWithCapacity:0];
		yReslicedDCMPixList = [[NSMutableArray alloc] initWithCapacity:0];
		
		newPixListX = [[NSMutableArray alloc] initWithCapacity: 0];
		newPixListY = [[NSMutableArray alloc] initWithCapacity: 0];
		
		thickSlab = 1;
		Ycache = nil;
		useYcache = YES;
	}
	return self;
}

- (id) initWithOriginalDCMPixList: (NSMutableArray*) pixList
{
	self = [self init];

	[self setOriginalDCMPixList:pixList];
	
	float sliceInterval;
	
	if ([[pixList objectAtIndex:0] sliceInterval] == 0)
	{
		sliceInterval = [[pixList objectAtIndex:1] sliceLocation] -
                        [[pixList objectAtIndex:0] sliceLocation];
	}
	else
	{
		sliceInterval = [[pixList objectAtIndex:0] sliceInterval];
	}
	
	sign = (sliceInterval > 0)? 1.0 : -1.0;
	
	return self;
}

- (void) setOriginalDCMPixList: (NSMutableArray*) pixList
{
	originalDCMPixList = pixList;
}

-(void) dealloc
{
    while( yCacheQueue.operationCount > 0)
        [NSThread sleepForTimeInterval: 0.1];

    [yCacheQueue release];
	if (Ycache)
        free( Ycache);
	
	[processorsLock release];
	[xReslicedDCMPixList release];
	[yReslicedDCMPixList release];
	[newPixListX release];
	[newPixListY release];
	[super dealloc];
}


- (void) xReslice: (long) x
{
 	[self axeReslice:0: x];
}

- (void) xResliceThread: (NSNumber*) xNum
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try 
	{
		[self xReslice: [xNum intValue]];
	
	}
	@catch (NSException * e) 
	{
		N2LogExceptionWithStackTrace(e);
	}
 	
//	[resliceLock unlockWithCondition: 1];
	
	[pool release];
}

- (void) yReslice: (long) y
{
	[self axeReslice:1:y];
}

// processors
- (void) reslice : (long) x : (long) y
{
//	resliceLock = [[NSConditionLock alloc] initWithCondition: 0];
//	
//	[NSThread detachNewThreadSelector:@selector(xResliceThread:) toTarget:self withObject: [NSNumber numberWithInt: y]];
//	[self yReslice:x];
//	[resliceLock lockWhenCondition: 1];
//	[resliceLock release];
	
	[self yReslice:x];
	[self xReslice:y];
}

- (void) subReslice:(NSNumber*) posNumber
{
    //int stack;
    int pos = [posNumber intValue];
	int threads = [[NSProcessInfo processInfo] processorCount];
	int from, to;
	
	from = (pos * newY) / threads;
	to = ((pos+1) * newY) / threads;
	
	for (int i = minI, stack = 0 ; i < maxI ; i++, stack++)
	{
        if (newPixListX.count <= stack) { // Check added 20220804
            static int n=5; // number of times this warning is displayed
            if (n > 0) {
                NSLog(@"%s %d %d, FIXME: preventing newPixListX[%d] because newPixListX has %lu elements", __FUNCTION__, __LINE__, n, stack, (unsigned long)newPixListX.count);
                n--;
            }
            continue;
        }

        if (i < 0)
            i = 0;

        if (i >= newTotal)
            i = newTotal-1;
		
		if (currentAxe == 0)		// X - RESLICE
		{
			
			DCMPix *curPix6 = [newPixListX objectAtIndex: stack];
			
			if (sign > 0)
			{
				float *srcP, *dstP, *curPixfImage = [curPix6 fImage];
				
				for (int y = from; y < to; y++)
				{
					srcP = [[originalDCMPixList objectAtIndex: y] fImage] + i * newX;
					dstP = curPixfImage + (newY-y-1) * newX;
					memcpy(	dstP, srcP, newX *sizeof(float));
				}
			}
			else
			{
                float *srcP;
                float *curPixfImage = [curPix6 fImage];
				
				for (int y = from; y < to; y++)
				{
					srcP = [[originalDCMPixList objectAtIndex: y] fImage] + i * [firstPix pwidth];
					memcpy(	curPixfImage + y * newX, srcP, newX *sizeof(float));
				}
			}
		}
		else						// Y - RESLICE
		{
			float *srcPtr;
			float *dstPtr;
			long rowBytes = [firstPix pwidth];
			
			DCMPix *curPix7 = [newPixListY objectAtIndex: stack];
			
			if (Ycache && yCacheQueue.operationCount == 0)
			{
//				BlockMoveData(	Ycache + newY*newX*i,
//								[curPix fImage],
//								newX * newY *sizeof(float));


				if (sign > 0)
				{
                    float *curPixfImage = [curPix7 fImage];
					DCMPix *srcPix = [originalDCMPixList objectAtIndex: 0];
					long w = [srcPix pheight];
					
					for (int y = from; y < to; y++)
					{
						float *srcP = Ycache + y*newTotal*newX + i * w;
						float *dstP = curPixfImage + (newY-y-1) * newX;
						memcpy(	dstP, srcP, newX *sizeof(float));
					}
				}
				else
				{
                    float *curPixfImage = [curPix7 fImage];
					
					for (int y = from; y < to; y++)
					{
						float *srcP = Ycache + y*newTotal*newX + i * newTotal;
						memcpy(	curPixfImage + y * newX, srcP, newX *sizeof(float));
					}
				}
			}
			else
			{
				for (int x = from; x < to; x++)
				{
					if (sign > 0)
					{
						srcPtr = [[originalDCMPixList objectAtIndex: newY-x-1] fImage] + i;
					}
					else
					{
						srcPtr = [[originalDCMPixList objectAtIndex: x] fImage] + i;
					}
					dstPtr = [curPix7 fImage] + x * newX;
					
					long yy = newX;
					while (yy-->0)
					{
						*dstPtr++ = *srcPtr;
						srcPtr += rowBytes;
					}
				}
			}
		}
	} // for i
	
	[processorsLock lock];
	numberOfThreadsForCompute--;
	[processorsLock unlock];
}

- (void) axeReslice: (short) axe : (long) sliceNumber
{
	firstPix = [originalDCMPixList objectAtIndex: 0];
	
	DCMPix *lastPix = [originalDCMPixList lastObject];
	float orientation[ 9], newXSpace, newYSpace, origin[ 3], sliceInterval;
	BOOL isRGB = firstPix.isRGB;
	
	currentAxe = axe;

	if ([firstPix sliceInterval]==0)
	{
		sliceInterval = [[originalDCMPixList objectAtIndex: 1] sliceLocation]-[firstPix sliceLocation];
	}
	else
	{
		sliceInterval = [firstPix sliceInterval];
	}
    
	// Get Values
	if (axe == 0)		// X - RESLICE
	{
		newTotal = [firstPix pheight];
		newX = [firstPix pwidth];
		newXSpace = [firstPix pixelSpacingX];
		newYSpace = fabs(sliceInterval);
		newY = [originalDCMPixList count];
	}
	else				// Y - RESLICE
	{
		newTotal = [firstPix pwidth];
		newX = [firstPix pheight];
		newY = [originalDCMPixList count];
		newXSpace = [firstPix pixelSpacingY];
		newYSpace = fabs(sliceInterval);
	}
	
//	size = sizeof(float) * newX * newY;	// image weight in bytes
	
	// CREATE A NEW SERIES WITH *ONE* IMAGE !
	
	DCMPix *curPix8;
	long stack = 0;
	
	if (thickSlab <= 1)
	{
		thickSlab = 1;
		minI = sliceNumber;
		maxI = minI+1;
		if (maxI > newTotal-1)
		{
			maxI = newTotal-1;
			minI = maxI-1;
		}
	}
	else
	{
		thickSlab = (thickSlab==0) ? 1 : thickSlab ;
		minI = sliceNumber-floor((float)thickSlab/2.0);
		maxI = sliceNumber+ceil((float)thickSlab/2.0);
		
		if (maxI > newTotal-1)
		{
			maxI = newTotal-1;
			if (minI == maxI)
                minI = maxI-1;
		}
	}
						
	// Y - CACHE activated only if thick slab and if enough memory is available
	if (axe != 0)
	{
		if (thickSlab > 1 && Ycache == nil)
		{
			if (useYcache)
				Ycache = (float *)malloc( newTotal*newY*newX*sizeof(float));
			
			if (Ycache)
			{
				NSLog( @"start YCache");
				
                yCacheQueue = [[NSOperationQueue alloc] init];
                
                for (long x = 0; x < newY; x ++)
                {
                    ResliceOperation *op = [[[ResliceOperation alloc] initWithDict: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                     [NSValue valueWithPointer: Ycache], @"Ycache",
                                                                                     [NSNumber numberWithInt:x], @"zValue",
                                                                                     originalDCMPixList, @"DCMPixArray",
                                                                                     nil]] autorelease];
                    
                    [yCacheQueue addOperation: op];
                }
			}
		}
	}
	
	if (axe == 0)		// X - RESLICE
	{
		if (sign > 0)
            [lastPix orientation: orientation];
		else
            [firstPix orientation: orientation];
		
		if (sign > 0)
		{
			// Y Vector = Normal Vector
			orientation[ 3] = orientation[ 6] * -sign;
			orientation[ 4] = orientation[ 7] * -sign;
			orientation[ 5] = orientation[ 8] * -sign;
		}
		else
		{
			// Y Vector = Normal Vector
			orientation[ 3] = orientation[ 6] * sign;
			orientation[ 4] = orientation[ 7] * sign;
			orientation[ 5] = orientation[ 8] * sign;
		}
	}
	else
	{
		if (sign > 0)
            [lastPix orientation: orientation];
		else
            [firstPix orientation: orientation];
		
		// Y Vector = Normal Vector
		orientation[ 0] = orientation[ 3];
		orientation[ 1] = orientation[ 4];
		orientation[ 2] = orientation[ 5];
		
		if (sign > 0)
		{
			orientation[ 3] = orientation[ 6] * -sign;
			orientation[ 4] = orientation[ 7] * -sign;
			orientation[ 5] = orientation[ 8] * -sign;
		}
		else
		{
			orientation[ 3] = orientation[ 6] * sign;
			orientation[ 4] = orientation[ 7] * sign;
			orientation[ 5] = orientation[ 8] * sign;
		}
	}
	
    int bits = 32;
    if (isRGB)
        bits = 8;
    
	long ii;
    // Important: for some reason 'ii' must be declared outside of the for loop
    // (maybe some threading issue ?)
	for (ii = minI, stack = 0 ; ii < maxI ; ii++, stack++)
	{
		if (ii < 0)
            ii = 0;
		
		if (axe == 0)		// X - RESLICE
		{
			if (stack >= [newPixListX count])
			{
				curPix8 = [[DCMPix alloc] initWithData: nil :bits :newX :newY :1 :1 :0 :0 :0 :NO];
				[curPix8 copySUVfrom: firstPix];
				curPix8.frameofReferenceUID = firstPix.frameofReferenceUID;
				[newPixListX addObject: curPix8];
				[curPix8 release];
			}
			else
                curPix8 = [newPixListX objectAtIndex: stack];
		}
		else
		{
			if (stack  >= [newPixListY count])
			{
				curPix8 = [[DCMPix alloc] initWithData: nil :bits :newX :newY :1 :1 :0 :0 :0 :NO];
				[curPix8 copySUVfrom: firstPix];
				curPix8.frameofReferenceUID = firstPix.frameofReferenceUID;
				[newPixListY addObject: curPix8];
				[curPix8 release];
			}
			else
                curPix8 = [newPixListY objectAtIndex: stack];
		}
		
		[curPix8 fImage];	// <- Force CheckLoad
		
		[curPix8 setTot: 0];
		[curPix8 setFrameNo: 0];
		[curPix8 setID: 0];
		
		if (axe == 0)		// X - RESLICE
		{
			[curPix8 setOrientation: orientation];	// Normal vector is recomputed in this procedure
			
			[curPix8 setPixelSpacingX: newXSpace];
			[curPix8 setPixelSpacingY: newYSpace];
			
			[curPix8 setPixelRatio:  newYSpace / newXSpace];
			
			[curPix8 orientation: orientation];
			
			if (sign > 0)
			{
				origin[ 0] = [lastPix originX] + (ii * [firstPix pixelSpacingY]) * orientation[ 6] * sign;
				origin[ 1] = [lastPix originY] + (ii * [firstPix pixelSpacingY]) * orientation[ 7] * sign;
				origin[ 2] = [lastPix originZ] + (ii * [firstPix pixelSpacingY]) * orientation[ 8] * sign;
			}
			else
			{
				origin[ 0] = [firstPix originX] + (ii * [firstPix pixelSpacingY]) * orientation[ 6] * -sign;
				origin[ 1] = [firstPix originY] + (ii * [firstPix pixelSpacingY]) * orientation[ 7] * -sign;
				origin[ 2] = [firstPix originZ] + (ii * [firstPix pixelSpacingY]) * orientation[ 8] * -sign;
			}
			
            [curPix8 setOrigin: origin];
            [curPix8 computeSliceLocation];
            
			[curPix8 setSliceThickness: [firstPix pixelSpacingY]];
			[curPix8 setSliceInterval: [firstPix pixelSpacingY]];
		}
		else
		{
			[curPix8 setOrientation: orientation];	// Normal vector is recomputed in this procedure
			
			[curPix8 setPixelSpacingX: newXSpace];
			[curPix8 setPixelSpacingY: newYSpace];
			
			[curPix8 setPixelRatio:  newYSpace / newXSpace];
			
			[curPix8 orientation: orientation];
			if (sign > 0)
			{
				origin[ 0] = [lastPix originX] + (ii * [firstPix pixelSpacingX]) * orientation[ 6] * -sign;
				origin[ 1] = [lastPix originY] + (ii * [firstPix pixelSpacingX]) * orientation[ 7] * -sign;
				origin[ 2] = [lastPix originZ] + (ii * [firstPix pixelSpacingX]) * orientation[ 8] * -sign;
			}
			else
			{
				origin[ 0] = [firstPix originX] + (ii * [firstPix pixelSpacingX]) * orientation[ 6] * sign;
				origin[ 1] = [firstPix originY] + (ii * [firstPix pixelSpacingX]) * orientation[ 7] * sign;
				origin[ 2] = [firstPix originZ] + (ii * [firstPix pixelSpacingX]) * orientation[ 8] * sign;
			}
			[curPix8 setOrigin: origin];
			[curPix8 computeSliceLocation];
            
			[curPix8 setSliceThickness: [firstPix pixelSpacingX]];
			[curPix8 setSliceInterval: [firstPix pixelSpacingY]];
		}
	}
	
	if (axe == 0)		// X - RESLICE
	{
		if ([newPixListX count] > stack)
			[newPixListX removeObjectsInRange: NSMakeRange( stack, [newPixListX count]-stack)];
	}
	else
	{
		if ([newPixListY count] > stack)
			[newPixListY removeObjectsInRange: NSMakeRange( stack, [newPixListY count]-stack)];
	}
	
	if (processorsLock == nil)
		processorsLock = [[NSLock alloc] init];
	
	numberOfThreadsForCompute = [[NSProcessInfo processInfo] processorCount];
    // Important: for some reason 'ii' must be declared outside of the for loop
    // (maybe some threading issue ?)
	for (ii = 0; ii < (numberOfThreadsForCompute - 1); ii++)
	{
		[NSThread detachNewThreadSelector: @selector(subReslice:)
                                 toTarget: self
                               withObject: [NSNumber numberWithInt: ii]];
	}
	
	[self subReslice: [NSNumber numberWithInt: ii]];
	
	BOOL done = NO;
	while( done == NO)
	{
		[processorsLock lock];
		if (numberOfThreadsForCompute <= 0)
            done = YES;
        
		[processorsLock unlock];
	}
				
	if (axe == 0)
	{
		[xReslicedDCMPixList setArray:newPixListX];
	}
	else
	{
		[yReslicedDCMPixList setArray:newPixListY];
	}

}

// accessors
- (NSMutableArray*) originalDCMPixList
{
	return originalDCMPixList;
}

- (NSMutableArray*) xReslicedDCMPixList
{
	return xReslicedDCMPixList;
}

- (NSMutableArray*) yReslicedDCMPixList
{
	return yReslicedDCMPixList;
}

// thickSlab
- (short) thickSlab
{
	return thickSlab;
}

- (void) setThickSlab : (short) newThickSlab
{
	thickSlab = newThickSlab;
}

- (void) flipVolume
{
	sign = -sign;
} 

- (void)freeYCache;
{
	if (Ycache)
        free(Ycache);

    Ycache = nil;
}

- (BOOL)useYcache;
{
	return useYcache;
}

- (void)setUseYcache:(BOOL)boo;
{
	useYcache = boo;
	if (!boo)
		[self freeYCache];
}

@end
