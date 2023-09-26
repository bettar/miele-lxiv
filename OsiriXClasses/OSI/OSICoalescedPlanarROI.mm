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

#import "GLRenderer.h"

#import "OSICoalescedPlanarROI.h"
#import "OSIFloatVolumeData.h"
#import "OSIROIMask.h"
#import "CPRGenerator.h"
#import "CPRGeneratorRequest.h"
#import "OSIGeometry.h"

@interface OSICoalescedPlanarROI ()

@property (nonatomic, readonly, retain) OSIFloatVolumeData *coalescedROIMaskVolumeData;

- (NSData *)_maskRunsDataForSlab:(OSISlab)slab dicomToPixTransform:(N3AffineTransform)dicomToPixTransform minCorner:(N3VectorPointer)minCornerPtr;

@end

@implementation OSICoalescedPlanarROI

@synthesize sourceROIs = _sourceROIs;
@synthesize volumeTransform = _volumeTransform;

- (id)initWithSourceROIs:(NSArray *)rois
{
    if ( (self = [super init]) ) {
        _sourceROIs = [rois copy];
    }
    
    return self;
}

- (void)dealloc
{
    [_sourceROIs release];
    _sourceROIs = nil;
    [_coalescedROIMaskVolumeData release];
    _coalescedROIMaskVolumeData = nil;
    [_cachedMaskRunsData release];
    _cachedMaskRunsData = nil;
    
    [super dealloc];
}

- (NSString *)name
{
    if ([_sourceROIs count] > 0) {
        return [[_sourceROIs objectAtIndex:0] name];
    }
    return nil;
}

- (NSArray *)convexHull
{
    NSMutableArray *hull = [NSMutableArray array];
    
    for (OSIROI *roi in _sourceROIs)
        [hull addObjectsFromArray:[roi convexHull]];
    
    return hull;
}

- (OSIROIMask *)ROIMaskForFloatVolumeData:(OSIFloatVolumeData *)floatVolume
{
    NSMutableArray *maskRuns = [NSMutableArray array];
    
    if (N3AffineTransformEqualToTransform(floatVolume.volumeTransform, self.volumeTransform))
    {
        for (OSIROI *roi in _sourceROIs)
            [maskRuns addObjectsFromArray:[[roi ROIMaskForFloatVolumeData:floatVolume] maskRuns]];
        
        return [[[OSIROIMask alloc] initWithMaskRuns:maskRuns] autorelease];
    }

    // we need to create a
    OSIFloatVolumeData *coalescedROIMaskVolume = self.coalescedROIMaskVolumeData;
    
    CPRObliqueSliceGeneratorRequest *sliceRequest = [[[CPRObliqueSliceGeneratorRequest alloc] init] autorelease];
    sliceRequest.pixelsWide = floatVolume.pixelsWide;
    sliceRequest.pixelsHigh = floatVolume.pixelsHigh;
    sliceRequest.slabSampleDistance = floatVolume.pixelSpacingZ;
    sliceRequest.slabWidth = floatVolume.pixelSpacingZ * floatVolume.pixelsDeep;
    sliceRequest.sliceToDicomTransform = N3AffineTransformInvert(N3AffineTransformConcat(floatVolume.volumeTransform, N3AffineTransformMakeTranslation(0, 0, (float)floatVolume.pixelsDeep/2.0)));
    
    CPRVolumeData *resampledVolume = [CPRGenerator synchronousRequestVolume:sliceRequest volumeData:coalescedROIMaskVolume];
    
    assert(floatVolume.pixelsWide == resampledVolume.pixelsWide);
    assert(floatVolume.pixelsHigh == resampledVolume.pixelsHigh);
    assert(floatVolume.pixelsDeep == resampledVolume.pixelsDeep);
    
    OSIROIMask *resampledMask = [OSIROIMask ROIMaskFromVolumeData:(OSIFloatVolumeData *)resampledVolume volumeTransform:NULL];
    
    return resampledMask;
}

- (NSSet *)osiriXROIs
{
    NSMutableSet *osirixROIs = [NSMutableSet setWithCapacity:[_sourceROIs count]];
    
    for (OSIROI *roi in _sourceROIs) {
        [osirixROIs unionSet:[roi osiriXROIs]];
    }
    
    return osirixROIs;
}

- (void)drawSlab:(OSISlab)slab
    inCGLContext:(CGLContextObj)cgl_ctx
     pixelFormat:(CGLPixelFormatObj)pixelFormat
dicomToPixTransform:(N3AffineTransform)dicomToPixTransform
{
    NSData *maskRunsData;
    N3Vector minCorner;
    
    if (_cachedMaskRunsData && OSISlabEqualTo(slab, _cachedSlab) && N3AffineTransformEqualToTransform(dicomToPixTransform, _cachedDicomToPixTransform)) {
        maskRunsData = _cachedMaskRunsData;
        minCorner = _cachedMinCorner;
    }
    else {
        [_cachedMaskRunsData release];
        _cachedMaskRunsData = [[self _maskRunsDataForSlab:slab dicomToPixTransform:dicomToPixTransform minCorner:&_cachedMinCorner] retain];
        _cachedSlab = slab;
        _cachedDicomToPixTransform = dicomToPixTransform;
        maskRunsData = _cachedMaskRunsData;
        minCorner = _cachedMinCorner;
    }

    NSInteger runsCount = [maskRunsData length] / sizeof(OSIROIMaskRun);
    const OSIROIMaskRun *maskRunsBytes = (const OSIROIMaskRun *)[maskRunsData bytes];
    
    const int nPoints = 4 * runsCount;
    glm::vec3 pA[nPoints];
    int idx = 0;
    for (NSInteger i = 0; i < runsCount; i++) {
        OSIROIMaskRun maskRun = maskRunsBytes[i];

        double widthIndex = (double)maskRun.widthRange.location + minCorner.x;
        double maxWidthIndex = widthIndex + (double)maskRun.widthRange.length;
        double heightIndex = (double)maskRun.heightIndex + minCorner.y;
        double depthIndex = maskRun.depthIndex;

        pA[idx++] = glm::vec3(widthIndex, heightIndex, depthIndex);
        pA[idx++] = glm::vec3(maxWidthIndex, heightIndex, depthIndex);
        pA[idx++] = glm::vec3(maxWidthIndex, heightIndex + 1.0, depthIndex);
        pA[idx++] = glm::vec3(widthIndex, heightIndex + 1.0, depthIndex);
    }
    assert(idx == nPoints);

    NSMutableArray *pArray = [NSMutableArray array];
    for (int i=0; i<nPoints; i++)
        [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec3)]];

    renderer_setLineWidth(3.0);
    renderer_set_rgba(1, 0, 0, .4);
    renderer_drawQuads_xyz([pArray copy]);
}

// Accessor method
- (OSIFloatVolumeData *)coalescedROIMaskVolumeData
{
    if (_coalescedROIMaskVolumeData == nil) {
        N3Vector minCorner = N3VectorMake( CGFLOAT_MAX,  CGFLOAT_MAX,  CGFLOAT_MAX);
        N3Vector maxCorner = N3VectorMake(-CGFLOAT_MAX, -CGFLOAT_MAX, -CGFLOAT_MAX);
        
        for (OSIROI *roi in _sourceROIs)
        {
            for (NSValue *hullPointValue in [roi convexHull])
            {
                N3Vector hullPoint = N3VectorApplyTransform([hullPointValue N3VectorValue], self.volumeTransform);
                
                minCorner.x = MIN(minCorner.x, hullPoint.x);
                minCorner.y = MIN(minCorner.y, hullPoint.y);
                minCorner.z = MIN(minCorner.z, hullPoint.z);
                maxCorner.x = MAX(maxCorner.x, hullPoint.x);
                maxCorner.y = MAX(maxCorner.y, hullPoint.y);
                maxCorner.z = MAX(maxCorner.z, hullPoint.z);
            }
        }
        
        minCorner.x = floor(minCorner.x) - 1;
        minCorner.y = floor(minCorner.y) - 1;
        minCorner.z = floor(minCorner.z) - 1;
        maxCorner.x = ceil(maxCorner.x) + 1;
        maxCorner.y = ceil(maxCorner.y) + 1;
        maxCorner.z = ceil(maxCorner.z) + 1;
        
        NSInteger width = maxCorner.x - minCorner.x;
        NSInteger height = maxCorner.y - minCorner.y;
        NSInteger depth = maxCorner.z - minCorner.z;
        
        N3AffineTransform coalescedROIMaskVolumeTransform = N3AffineTransformConcat(self.volumeTransform, N3AffineTransformMakeTranslation(-minCorner.x, -minCorner.y, -minCorner.z));
        
        float *coalescedROIMaskVolumeBytes = (float *)calloc(1, width * height * depth * sizeof(float));
        assert(coalescedROIMaskVolumeBytes);

        _coalescedROIMaskVolumeData = [[OSIFloatVolumeData alloc] initWithFloatBytesNoCopy:coalescedROIMaskVolumeBytes pixelsWide:width pixelsHigh:height pixelsDeep:depth volumeTransform:coalescedROIMaskVolumeTransform outOfBoundsValue:0 freeWhenDone:YES];
        
        for (OSIROI *roi in _sourceROIs)
        {
            OSIROIMask *coalescedMask = [roi ROIMaskForFloatVolumeData:_coalescedROIMaskVolumeData];
            assert([_coalescedROIMaskVolumeData checkDebugROIMask:coalescedMask]);
            
            for (NSValue *maskRunValue in [coalescedMask maskRuns])
            {
                OSIROIMaskRun maskRun = [maskRunValue OSIROIMaskRunValue];
                
                for (NSInteger i = maskRun.widthRange.location; i < NSMaxRange(maskRun.widthRange); i++)
                {
                    float *bytesPtr = &(coalescedROIMaskVolumeBytes[maskRun.depthIndex * width * height + maskRun.heightIndex * width + i]);

                    *bytesPtr = MAX(*bytesPtr, maskRun.intensity);
                }
            }
        }
    }
    
    return _coalescedROIMaskVolumeData;
}


- (NSData *)_maskRunsDataForSlab:(OSISlab)slab dicomToPixTransform:(N3AffineTransform)dicomToPixTransform minCorner:(N3VectorPointer)minCornerPtr;
{
    CPRVolumeData *floatVolumeData;
    N3Vector corner;
    N3Vector minCorner;
    N3Vector maxCorner;
    N3AffineTransform coalescedVolumeMaskToPixTransform;
    NSInteger width;
    NSInteger height;
    CPRObliqueSliceGeneratorRequest *sliceRequest;
    OSIROIMask *sliceMask;
    
    minCorner = N3VectorMake(CGFLOAT_MAX, CGFLOAT_MAX, 0);
    maxCorner = N3VectorMake(-CGFLOAT_MAX, -CGFLOAT_MAX, 0);
    coalescedVolumeMaskToPixTransform = N3AffineTransformConcat(N3AffineTransformInvert(self.coalescedROIMaskVolumeData.volumeTransform), dicomToPixTransform);
    
    // first off figure out where this float volume needs to be
    corner = N3VectorApplyTransform(N3VectorMake(0,                                          0,                                          0), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(self.coalescedROIMaskVolumeData.pixelsWide, 0,                                          0), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(0,                                          self.coalescedROIMaskVolumeData.pixelsHigh, 0), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(self.coalescedROIMaskVolumeData.pixelsWide, self.coalescedROIMaskVolumeData.pixelsHigh, 0), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(0,                                          0,                                          self.coalescedROIMaskVolumeData.pixelsDeep), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(self.coalescedROIMaskVolumeData.pixelsWide, 0,                                          self.coalescedROIMaskVolumeData.pixelsDeep), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(0,                                          self.coalescedROIMaskVolumeData.pixelsDeep, self.coalescedROIMaskVolumeData.pixelsDeep), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    corner = N3VectorApplyTransform(N3VectorMake(self.coalescedROIMaskVolumeData.pixelsWide, self.coalescedROIMaskVolumeData.pixelsDeep, self.coalescedROIMaskVolumeData.pixelsDeep), coalescedVolumeMaskToPixTransform);
    minCorner.x = MIN(minCorner.x, corner.x); minCorner.y = MIN(minCorner.y, corner.y);
    maxCorner.x = MAX(maxCorner.x, corner.x); maxCorner.y = MAX(maxCorner.y, corner.y);
    
    minCorner.x = floor(minCorner.x) - 1;
    minCorner.y = floor(minCorner.y) - 1;
    maxCorner.x = ceil(maxCorner.x) + 1;
    maxCorner.y = ceil(maxCorner.y) + 1;
    
    
    width = maxCorner.x - minCorner.x;
    height = maxCorner.y - minCorner.y;
    
    sliceRequest = [[[CPRObliqueSliceGeneratorRequest alloc] init] autorelease];
    sliceRequest.pixelsWide = width;
    sliceRequest.pixelsHigh = height;
    sliceRequest.slabWidth = slab.thickness;
    sliceRequest.projectionMode = MPR_PROJECTION_MODE_MIP;
    
    sliceRequest.sliceToDicomTransform = N3AffineTransformConcat(N3AffineTransformMakeTranslation(minCorner.x, minCorner.y, 0), N3AffineTransformInvert(dicomToPixTransform));
    
    floatVolumeData = [CPRGenerator synchronousRequestVolume:sliceRequest volumeData:self.coalescedROIMaskVolumeData];
    sliceMask = [OSIROIMask ROIMaskFromVolumeData:(OSIFloatVolumeData *)floatVolumeData volumeTransform:NULL];
    
    if (minCornerPtr) {
        *minCornerPtr = minCorner;
    }
    
    return [sliceMask maskRunsData];
 }

@end
























