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
#import "GLScene.h"

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

#import "ROI.h"
#import "MyPoint.h"

#import "AppController.h"
#import "StringTexture.h"

#import "DCMView.h"
#import "DCMPix.h"
#import "ITKSegmentation3D.h"
#import "Notifications.h"
#import "N2Debug.h"
#import "ITKBrushROIFilter.h"
#import "DCMUSRegion.h"   // mapping ultrasound
#import "Point3D.h"
#import "N2Stuff.h"
#import "ViewerController.h"

//#define dot(u,v)   ((u)[0] * (v)[0] + (u)[1] * (v)[1] + (u)[2] * (v)[2])
//#define norm(v)    sqrt(dot(v,v))  // norm = length of vector

#define CIRCLE_RESOLUTION    200
#define ROI_VERSION          15

static float fontHeight = 0;
static NSString *defaultName;
static int gUID = 0;
static const float ARROWSIZEConstant = 25.0f;

extern long BresLine(int Ax, int Ay, int Bx, int By,long **xBuffer, long **yBuffer);
extern void CLIP_Polygon(NSPointInt *inPoly, long inCount, NSPointInt *outPoly, long *outCount, NSPoint clipMin, NSPoint clipMax);
extern void ras_FillPolygon( NSPointInt *p,
                            long no,
                            float *pix,
                            long w,
                            long h,
                            long s,
                            float min,
                            float max,
                            BOOL outside,
                            float newVal,
                            BOOL addition,
                            BOOL RGB,
                            BOOL compute,
                            float *imax,
                            float *imin,
                            long *count,
                            float *itotal,
                            float *idev,
                            float imean,
                            long orientation,
                            long stackNo,
                            BOOL restore,
                            float *values,
                            float *locations);

static float ROIRegionOpacity, ROITextThickness, ROIThickness, ROIOpacity, ROIColorR, ROIColorG, ROIColorB, ROITextColorR, ROITextColorG, ROITextColorB;
static float ROIRegionThickness, ROIRegionColorR, ROIRegionColorG, ROIRegionColorB, ROIArrowThickness;
static BOOL ROITEXTIFSELECTED, ROITEXTNAMEONLY, ROITextIfMouseIsOver, ROIDrawPlainEdge, ROIDisplayStatisticsOnlyForFused;
static BOOL ROIDefaultsLoaded = NO;
static BOOL splineForROI = NO;
static BOOL displayCobbAngle = NO;

int spline( NSPoint *Pt, int tot, NSPoint **newPt, long **correspondingSegmentPt, double scale)
{
	NSPoint p1, p2;
	double xi, yi;
	long long nb;
	double *px, *py;
	int ok;

	double bet, *gam;
	double aax, bbx, ccx, ddx, aay, bby, ccy, ddy; // coef of spline

	if (scale > 5)
        scale = 5;

	// function spline S(x) = a x3 + bx2 + cx + d
	// with S continue, S1 continue, S2 continue.
	// smoothing of a closed polygon given by a list of points (x,y)
	// we compute a spline for x and a spline for y
	// where x and y are function of d where t is the distance between points

	// compute tridiag matrix
	//   | b1 c1 0 ...                   |   |  u1 |   |  r1 |
	//   | a2 b2 c2 0 ...                |   |  u2 |   |  r2 |
	//   |  0 a3 b3 c3 0 ...             | * | ... | = | ... |
	//   |                  ...          |   | ... |   | ... |
	//   |                an-1 bn-1 cn-1 |   | ... |   | ... |
	//   |                 0    an   bn  |   |  un |   |  rn |
	// bi = 4
	// resolution algorithm is taken from the book : Numerical recipes in C

	// initialization of different vectors
	// element number 0 is not used (except h[0])
	nb  = tot + 2;

    double *a, b, *c, *cx, *cy, *d, *g, *h;
    a   = (double *)malloc(nb*sizeof(double));
	c   = (double *)malloc(nb*sizeof(double));
	cx  = (double *)malloc(nb*sizeof(double));
	cy  = (double *)malloc(nb*sizeof(double));
	d   = (double *)malloc(nb*sizeof(double));
	g   = (double *)malloc(nb*sizeof(double));
	gam = (double *)malloc(nb*sizeof(double));
	h   = (double *)malloc(nb*sizeof(double));
	px  = (double *)malloc(nb*sizeof(double));
	py  = (double *)malloc(nb*sizeof(double));

	
	BOOL failed = NO;
	
	if (!a) failed = YES;
	if (!c) failed = YES;
	if (!cx) failed = YES;
	if (!cy) failed = YES;
	if (!d) failed = YES;
	if (!g) failed = YES;
	if (!gam) failed = YES;
	if (!h) failed = YES;
	if (!px) failed = YES;
	if (!py) failed = YES;
	
	if (failed)
	{
		if (a) 		free(a);
		if (c) 		free(c);
		if (cx)		free(cx);
		if (cy)		free(cy);
		if (d) 		free(d);
		if (g) 		free(g);
		if (gam)	free(gam);
		if (h) 		free(h);
		if (px)		free(px);
		if (py)		free(py);
		
		return 0;
	}
	
	//initialisation
	for (long long i=0; i<nb; i++)
		h[i] = a[i] = cx[i] = d[i] = c[i] = cy[i] = g[i] = gam[i] = 0.0;

	// as a spline starts and ends with a line one adds two points
	// in order to have continuity in starting point
	for (long long i=0; i<tot; i++)
	{
		px[i+1] = Pt[i].x;// * fZoom / 100;
		py[i+1] = Pt[i].y;// * fZoom / 100;
	}
	px[0] = px[nb-3]; px[nb-1] = px[2];
	py[0] = py[nb-3]; py[nb-1] = py[2];

	// check all points are separate, if not do not smooth
	// this happens when the zoom factor is too small
	// so in this case the smooth is not useful

	ok = TRUE;
	if (nb<3)
        ok=FALSE;

	for (long long i=1; i<nb; i++)
        if (px[i] == px[i-1] && py[i] == py[i-1])
        {
            ok = FALSE;
            break;
        }
    
	if (ok == FALSE)
		failed = YES;
		
	if (failed)
	{
		if (!a) 		free(a);
		if (!c) 		free(c);
		if (!cx)		free(cx);
		if (!cy)		free(cy);
		if (!d) 		free(d);
		if (!g) 		free(g);
		if (!gam)		free(gam);
		if (!h) 		free(h);
		if (!px)		free(px);
		if (!py)		free(py);
		
		return 0;
	}
			 
	// define hi (distance between points) h0 distance between 0 and 1.
	// di distance of point i from start point
	for (long long i = 0; i<nb-1; i++)
	{
		xi = px[i+1] - px[i];
		yi = py[i+1] - py[i];
		h[i] = (double) sqrt(xi*xi + yi*yi) * scale;
		d[i+1] = d[i] + h[i];
	}

	// define ai and ci
	for (long long i=2; i<nb-1; i++)
        a[i] = 2.0 * h[i-1] / (h[i] + h[i-1]);

	for (long long i=1; i<nb-2; i++)
        c[i] = 2.0 * h[i]   / (h[i] + h[i-1]);

	// define gi in function of x
	// gi+1 = 6 * Y[hi, hi+1, hi+2], 
	// Y[hi, hi+1, hi+2] = [(yi - yi+1)/(di - di+1) - (yi+1 - yi+2)/(di+1 - di+2)]
	//                      / (di - di+2)
	for (long long i=1; i<nb-1; i++)
		g[i] = 6.0 * ( ((px[i-1] - px[i]) / (d[i-1] - d[i])) - ((px[i] - px[i+1]) / (d[i] - d[i+1])) ) / (d[i-1]-d[i+1]);

	// compute cx vector
	b=4; bet=4;
	cx[1] = g[1]/b;
	for (long long j=2; j<nb-1; j++)
	{
		gam[j] = c[j-1] / bet;
		bet = b - a[j] * gam[j];
		cx[j] = (g[j] - a[j] * cx[j-1]) / bet;
	}
    
	for (long long j=(nb-2); j>=1; j--)
        cx[j] -= gam[j+1] * cx[j+1];

	// define gi in function of y
	// gi+1 = 6 * Y[hi, hi+1, hi+2], 
	// Y[hi, hi+1, hi+2] = [(yi - yi+1)/(hi - hi+1) - (yi+1 - yi+2)/(hi+1 - hi+2)]
	//                      / (hi - hi+2)
	for (long long i=1; i<nb-1; i++)
		g[i] = 6.0 * ( ((py[i-1] - py[i]) / (d[i-1] - d[i])) - ((py[i] - py[i+1]) / (d[i] - d[i+1])) ) / (d[i-1]-d[i+1]);

	// compute cy vector
	b = 4.0; bet = 4.0;
	cy[1] = g[1] / b;
	for (long long j=2; j<nb-1; j++)
	{
		gam[j] = c[j-1] / bet;
		bet = b - a[j] * gam[j];
		cy[j] = (g[j] - a[j] * cy[j-1]) / bet;
	}

    for (long long j=(nb-2); j>=1; j--)
        cy[j] -= gam[j+1] * cy[j+1];

	// OK we have the cx and cy vectors, from that we can compute the
	// coeff of the polynoms for x and y and for each interval
	// S(x) (xi, xi+1)  = ai + bi (x-xi) + ci (x-xi)2 + di (x-xi)3
	// di = (ci+1 - ci) / 3 hi
	// ai = yi
	// bi = ((ai+1 - ai) / hi) - (hi/3) (ci+1 + 2 ci)
	int totNewPt = 0;
	for (long long i=1; i<nb-2; i++)
	{
		totNewPt++;
		for (long long j = 1; j <= h[i]; j++)
            totNewPt++;
	}

	*newPt = (NSPoint *)calloc(totNewPt, sizeof(NSPoint));
	if (newPt == nil)
	{
		if (!a) 		free(a);
		if (!c) 		free(c);
		if (!cx)		free(cx);
		if (!cy)		free(cy);
		if (!d) 		free(d);
		if (!g) 		free(g);
		if (!gam)		free(gam);
		if (!h) 		free(h);
		if (!px)		free(px);
		if (!py)		free(py);
		
		return 0;
	}
	
	if (correspondingSegmentPt)
	{
		*correspondingSegmentPt = (long *)calloc(totNewPt, sizeof(long));
		if (*correspondingSegmentPt == nil)
		{
			free( newPt);
			
			if (!a) 		free(a);
			if (!c) 		free(c);
			if (!cx)		free(cx);
			if (!cy)		free(cy);
			if (!d) 		free(d);
			if (!g) 		free(g);
			if (!gam)		free(gam);
			if (!h) 		free(h);
			if (!px)		free(px);
			if (!py)		free(py);
			
			return 0;
		}
	}
		
    // TODO: use implementation in 'N3BezierCoreAdditions.mm'
	int tt = 0;
	// for each interval
	for (long long i=1; i<nb-2; i++)
	{
		// compute coef for x polynomial
		ccx = cx[i];
		aax = px[i];
		ddx = (cx[i+1] - cx[i]) / (3.0 * h[i]);
		bbx = ((px[i+1] - px[i]) / h[i]) - (h[i] / 3.0) * (cx[i+1] + 2.0 * cx[i]);

		// compute coef for y polynomial
		ccy = cy[i];
		aay = py[i];
		ddy = (cy[i+1] - cy[i]) / (3.0 * h[i]);
		bby = ((py[i+1] - py[i]) / h[i]) - (h[i] / 3.0) * (cy[i+1] + 2.0 * cy[i]);

		// compute points in this interval and display
		p1.x = aax;
		p1.y = aay;

		(*newPt)[tt]=p1;
		if (correspondingSegmentPt)
			(*correspondingSegmentPt)[tt]=i-1;
		tt++;
		
		for (long long j = 1; j <= h[i]; j++)
		{
			p2.x = (aax + bbx * (double)j + ccx * (double)(j * j) + ddx * (double)(j * j * j));
			p2.y = (aay + bby * (double)j + ccy * (double)(j * j) + ddy * (double)(j * j * j));
			(*newPt)[tt]=p2;
			if (correspondingSegmentPt)
				(*correspondingSegmentPt)[tt]=i-1;
			tt++;
		}//endfor points in 1 interval
	}//endfor each interval

	// delete dynamic structures
	free(a);
	free(c);
	free(cx);
	free(cy);
	free(d);
	free(g);
	free(gam);
	free(h);
	free(px);
	free(py);

	return tt;
}

#pragma mark -

@interface ROI ()
{
#pragma mark tArrow (14)
#define ARH_SIZE    3
    NSPoint arh[ARH_SIZE]; // TODO: define them as glm::vec2

#pragma mark - tPlain (20)

#pragma mark tOvalAngle (31)
}
@end

#pragma mark -

@implementation ROI

@synthesize min = rmin, max = rmax, mean = rmean;
@synthesize skewness = rskewness, kurtosis = rkurtosis, dev = rdev, total = rtotal;
@synthesize textureWidth, textureHeight;
@synthesize textureBuffer;

@synthesize locked, selectable, isAliased, is3DROI, originalIndexForAlias, imageOrigin, pixelSpacingX, pixelSpacingY;
@synthesize textureDownRightCornerX,textureDownRightCornerY, textureUpLeftCornerX, textureUpLeftCornerY;
@synthesize opacity, hidden, zLocation;
@synthesize name, comments, type, ROImode = mode, thickness;
@synthesize zPositions;
@synthesize clickInTextBox;
@synthesize rect, savedStudyInstanceUID;
@synthesize pix = _pix;
//@synthesize displayCMOrPixels;
@synthesize curView, peakValue, isoContour;
@synthesize mousePosMeasure;
@synthesize rgbcolor = color;
@synthesize parentROI;
@synthesize displayCalciumScoring = _displayCalciumScoring, calciumThreshold = _calciumThreshold;
@synthesize sliceThickness = _sliceThickness;
@synthesize layerReferenceFilePath;
@synthesize layerImage;
@synthesize layerPixelSpacingX, layerPixelSpacingY;
@synthesize textualBoxLine1, textualBoxLine2, textualBoxLine3, textualBoxLine4, textualBoxLine5, textualBoxLine6, textualBoxLine7, textualBoxLine8;
@synthesize groupID, mouseOverROI;
@synthesize isLayerOpacityConstant, canColorizeLayer, displayTextualData, clickPoint;

#pragma mark - tMeasure (5), tArrow (14), also tOpenPolygon (10)

- (void) tMeasure_tArrow_drawWithScaleValue:(float)scaleValue
                                     offset:(NSPoint)offset
                        highlightIfSelected:(BOOL)highlightIfSelected
                                  thickness:(float)thick
                         prepareTextualData:(BOOL)prepareTextualData
{
#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    if (points.count > 2)
        type = tOpenPolygon;  // Really ? Is this effective at all ?

    float backingScaleFactor = curView.window.backingScaleFactor;

    [curView setShaderProgramForLineWidth: thick * backingScaleFactor];
    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    
    if (type == tArrow)
    {
        //NSLog(@"ROI.mm %d, tArrow", __LINE__);

        // Extremities of the arrow
        NSPoint a = {([[points objectAtIndex: 0] x] - offset.x) * scaleValue,
                     ([[points objectAtIndex: 0] y] - offset.y) * scaleValue};
        
        NSPoint b = {([[points objectAtIndex: 1] x] - offset.x) * scaleValue,
                     ([[points objectAtIndex: 1] y] - offset.y) * scaleValue};
        
        float slide;

        if ((b.y - a.y) == 0)
            slide = (b.x - a.x)/-0.001;
        else
        {
            if (pixelSpacingX != 0 && pixelSpacingY != 0 )
                slide = (b.x-a.x)/((b.y-a.y) * (pixelSpacingY / pixelSpacingX));
            else
                slide = (b.x-a.x)/((b.y-a.y));
        }
        
        thick *= 0.5;
        if (thick > 5)
            thick = 5;
        
        float ARROWSIZE = ARROWSIZEConstant * (thick * backingScaleFactor / 3.0);
        
        // Arrow body (line)

        float angleDeg = 90 - glm::degrees(atan(slide));
        float adj = (ARROWSIZE + thick * backingScaleFactor * 13) * cos(glm::radians(angleDeg));
        float op  = (ARROWSIZE + thick * backingScaleFactor * 13) * sin(glm::radians(angleDeg));
        
        glm::vec2 arrowEnds[2];
        if (b.y - a.y > 0)
        {
            if (pixelSpacingX != 0 && pixelSpacingY != 0)
                arrowEnds[0] = glm::vec2(a.x + adj, a.y + (op*pixelSpacingX / pixelSpacingY));
            else
                arrowEnds[0] = glm::vec2(a.x + adj, a.y + (op));
        }
        else
        {
            if (pixelSpacingX != 0 && pixelSpacingY != 0)
                arrowEnds[0] = glm::vec2(a.x - adj, a.y - (op*pixelSpacingX / pixelSpacingY));
            else
                arrowEnds[0] = glm::vec2(a.x - adj, a.y - (op));
        }

        arrowEnds[1] = glm::vec2(b.x, b.y);

        NSMutableArray *arrowEndsArray = [NSMutableArray array];
        for (int i=0; i<2; i++)
            [arrowEndsArray addObject: [NSValue valueWithBytes:&arrowEnds[i] objCType:@encode(glm::vec2)]];

        [curView setShaderProgramForLineWidth: 2 * thick * backingScaleFactor];
        renderer_drawLine_xy([arrowEndsArray copy], GL_LINE_STRIP);

        [curView setShaderProgramOverlay_withMode_Point];
        glPointSize(thick*2 * backingScaleFactor);
        renderer_drawPoints([arrowEndsArray copy]);
        
#pragma mark arrow head (lines from 3 points)

        // Define arh[]
        [self tArrow_defineHead: a
                               : b
                               : slide
                               : angleDeg
                               : adj
                               : op
                               : backingScaleFactor
                               : thick];

        NSMutableArray *pArray = [NSMutableArray array];

        for (int i=0; i<ARH_SIZE; i++) {
            glm::vec2 a(arh[i].x, arh[i].y);
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }

        [curView setShaderProgramForLineWidth: 1.0*backingScaleFactor];
        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
        renderer_drawTriangles_xy([pArray copy]);

//        glBegin(GL_LINE_LOOP);
//        {
//            glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//            renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
//
//            glVertex2f( aa1.x, aa1.y);
//            glVertex2f( aa2.x, aa2.y);
//            glVertex2f( aa3.x, aa3.y);
//        }
//        glEnd();
    }
    else  // type == tMeasure or tOpenPolygon
    {
        NSMutableArray *pArray = [NSMutableArray array];
        for (id pt in points) {
            glm::vec2 pp(([pt x] - offset.x) * scaleValue,
                         ([pt y] - offset.y) * scaleValue);
            [pArray addObject: [NSValue valueWithBytes:&pp objCType:@encode(glm::vec2)]];
        }

        // If there is another line, compute Cobb's angle, and draw reference line thicker background
        if (curView &&
            displayCobbAngle && // enabled from main menu
            self.displayCMOrPixels == NO)  // Why 'self' ?
        {
            NSArray *roiList2 = curView.curRoiList;
            
            NSUInteger index = [roiList2 indexOfObject: self];
            if (index != NSNotFound)
            {
                int no = 0;
                for (ROI *r in roiList2)
                {
                    if ([r type] == tMeasure)
                    {
                        no++;
                        if (no >= 2)
                            break;
                    }
                }
                
                if (no >= 2)
                {
                    BOOL f = NO;
                    for (int i = 0; i < index; i++)
                    {
                        ROI *r = [roiList2 objectAtIndex: i];
                        
                        if ([r type] == tMeasure)
                        {
                            f = YES;
                            break;
                        }
                    }
                    
                    if (f == NO)
                    {
                        // Highlight the reference line by drawing it first 3 times thicker
                        // so that it will appear to have a border
                        [curView setShaderProgramForLineWidth: thick * 3. *backingScaleFactor];
                        renderer_set_rgba(1.0f, 1.0f, 0.0f, 0.5f); // yellow, 0.5
                        renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);

                        // Restore
                        [curView setShaderProgramForLineWidth: thick * backingScaleFactor];
                        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
                    }
                }
            }
        } // Cobb angle
        
        //[curView setShaderProgramOverlayLine];
        renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);

        [curView setShaderProgramOverlay_withMode_Point];
        glPointSize(thick * backingScaleFactor);
        renderer_drawPoints([pArray copy]);  // Do we need this ?
    }    // type == tMeasure
    
#pragma mark points if selected

    if (highlightIfSelected)  // both tArrow and tMeasure
    {
        NSMutableArray *arrayPoint2DColor = [NSMutableArray array];
        for (long i = 0; i < [points count]; i++) {
            if (i == selectedModifyPoint || i == PointUnderMouse)
            {
                Point_xy_rgb pc;
                pc.c = glm::vec3(1.0f, 0.2f, 0.2f);
                pc.p.x = ([[points objectAtIndex: i] x] - offset.x) * scaleValue;
                pc.p.y = ([[points objectAtIndex: i] y] - offset.y) * scaleValue;
                [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
            }
            else if (mode >= ROI_selected)
            {
                Point_xy_rgb pc;
                pc.c = glm::vec3(0.5f, 0.5f, 1.0f);
                pc.p.x = ([[points objectAtIndex: i] x] - offset.x) * scaleValue;
                pc.p.y = ([[points objectAtIndex: i] y] - offset.y) * scaleValue;
                [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
            }
        }

        [curView setShaderProgramOverlay_withMode_Point];

        if (type == tArrow)
            glPointSize( sqrt( thick)*3. * backingScaleFactor);
        else
            glPointSize( thick*2 * backingScaleFactor);

        renderer_set_rgba(0.5f, 0.5f, 1.0f, opacity); // light blue (redundant)
        renderer_drawPoints_xy_rgb([arrayPoint2DColor copy]);
    }
    
#pragma mark red point (under mouse)

    if (mousePosMeasure != -1)
    {
        NSPoint pt = NSMakePoint( [[points objectAtIndex: 0] x], [[points objectAtIndex: 0] y]);
        
        float theta = atan(([[points objectAtIndex: 1] y] - [[points objectAtIndex: 0] y]) /
                           ([[points objectAtIndex: 1] x] - [[points objectAtIndex: 0] x]));
        
        float pyth = ([[points objectAtIndex: 1] y] - [[points objectAtIndex: 0] y]) * ([[points objectAtIndex: 1] y] - [[points objectAtIndex: 0] y]) +
                     ([[points objectAtIndex: 1] x] - [[points objectAtIndex: 0] x]) * ([[points objectAtIndex: 1] x] - [[points objectAtIndex: 0] x]);

        pyth = sqrt( pyth);
        
        if (([[points objectAtIndex: 1] x] - [[points objectAtIndex: 0] x]) < 0)
        {
            pt.x -= (mousePosMeasure * pyth) * cos( theta);
            pt.y -= (mousePosMeasure * pyth) * sin( theta);
        }
        else
        {
            pt.x += (mousePosMeasure * pyth) * cos( theta);
            pt.y += (mousePosMeasure * pyth) * sin( theta);
        }

        glm::vec2 pRed((pt.x - offset.x) * scaleValue,
                       (pt.y - offset.y) * scaleValue);
        NSMutableArray *pArray = [NSMutableArray array];
        [pArray addObject: [NSValue valueWithBytes:&pRed objCType:@encode(glm::vec2)]];

#ifdef WITH_OPENGL_32
        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
        renderer_set_rgb(1.0f, 0.0f, 0.0f); // red
        renderer_drawPoints([pArray copy]); // TODO: consolidate with renderer_drawPoints_xy_rgb() above
    }
    
    // restore
    [curView setShaderProgramForLineWidth: 1.0*backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
    [curView setShaderProgramOverlay];
    
#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        BOOL displayCobbAngleIntern = YES;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
            [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
            self.textualBoxLine1 = name;
        else
            self.textualBoxLine1 = nil;
        
        if (type == tMeasure && ROITEXTNAMEONLY == NO)
        {
            if ((pixelSpacingX != 0 && pixelSpacingY != 0) || [[self pix] hasUSRegions])
            {
                float lPix;
                float lCm = [self MeasureLength: &lPix];
                
                if (self.displayCMOrPixels)   // CPR
                {
                    self.textualBoxLine2 = [ROI formattedLength: lCm];
                }
                else
                {
                    // US Regions (Length) --->
                    if (self.pix.hasUSRegions)
                    {
                        NSPoint roiPoint1 = [[points objectAtIndex:0] point], roiPoint2 = [[points objectAtIndex:1] point];
                        
                        BOOL roiInsideAnUsRegion = FALSE;
                        DCMUSRegion *usR = nil;
                        
                        for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                        {
                            if (!roiInsideAnUsRegion)
                            {
                                roiInsideAnUsRegion = (((int)roiPoint1.x <= [anUsRegion regionLocationMaxX1] && (int)roiPoint1.x >= [anUsRegion regionLocationMinX0]) &&
                                                       ((int)roiPoint1.y <= [anUsRegion regionLocationMaxY1] && (int)roiPoint1.y >= [anUsRegion regionLocationMinY0]) &&
                                                       ((int)roiPoint2.x <= [anUsRegion regionLocationMaxX1] && (int)roiPoint2.x >= [anUsRegion regionLocationMinX0]) &&
                                                       ((int)roiPoint2.y <= [anUsRegion regionLocationMaxY1] && (int)roiPoint2.y >= [anUsRegion regionLocationMinY0]));
                                
                                if (roiInsideAnUsRegion)
                                {
                                    usR = anUsRegion;
                                    if (usR.regionSpatialFormat == 0 &&
                                        usR.physicalUnitsXDirection == 0 &&
                                        usR.physicalUnitsYDirection == 0)
                                    {
                                        // RSF=none, PUXD=none, PUYD=none
                                        roiInsideAnUsRegion = FALSE;
                                        usR = nil;
                                    }
                                }
                            }
                        }
                        
                        if (roiInsideAnUsRegion && usR)
                        {
                            if (usR.regionSpatialFormat == 1 &&
                                usR.physicalUnitsXDirection == regionCode_cm &&
                                usR.physicalUnitsYDirection == regionCode_cm) // 2D
                            {
                                // RSF=2D, PUXD=cm, PUYD=cm
                                if (lCm < .01)
                                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.1f %cm", nil), lCm * 10000.0, 0xb5];
                                else if (lCm < 1)
                                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f mm", nil), lCm * 10.];
                                else
                                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f cm", nil), lCm];
                            }
                            else
                            {
                                displayCobbAngleIntern = NO;
                                
                                // Other formats
                                //double lengthX = fabs(roiPoint2.x - roiPoint1.x) * fabs( usR.physicalDeltaX);
                                //double lengthY = fabs(roiPoint2.y - roiPoint1.y) * fabs( usR.physicalDeltaY);
                                
                                double minY = MIN( roiPoint2.y, roiPoint1.y);
                                double maxY = MAX( roiPoint2.y, roiPoint1.y);
                                
                                minY = fabs( (minY - usR.regionLocationMinY0 - usR.referencePixelY0) * usR.physicalDeltaY);
                                maxY = fabs( (maxY - usR.regionLocationMinY0 - usR.referencePixelY0) * usR.physicalDeltaY);
                                
                                if (maxY < minY)
                                {
                                    float c = maxY;
                                    maxY = minY;
                                    minY = c;
                                }
                                
                                double minX = MIN( roiPoint2.x, roiPoint1.x);
                                double maxX = MAX( roiPoint2.x, roiPoint1.x);
                                
                                minX = fabs( (minX - usR.regionLocationMinX0 - usR.referencePixelX0) * usR.physicalDeltaX);
                                maxX = fabs( (maxX - usR.regionLocationMinX0 - usR.referencePixelX0) * usR.physicalDeltaX);
                                
                                if (maxX < minX)
                                {
                                    float c = maxX;
                                    maxX = minX;
                                    minX = c;
                                }
                                
                                NSString * unitsX = nil, * unitsY = nil;
                                
                                if (usR.physicalUnitsXDirection > 12)
                                    unitsX = NSLocalizedString( @"unknown", nil);
                                
                                else if (usR.physicalUnitsYDirection > 12)
                                    unitsY = NSLocalizedString( @"unknown", nil);
                                
                                else
                                {
                                    unitsX = [self.physicalUnitsXYDirection objectAtIndex: usR.physicalUnitsXDirection];
                                    unitsY = [self.physicalUnitsXYDirection objectAtIndex: usR.physicalUnitsYDirection];
                                }
                            }
                        }
                        else
                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f pix", nil), lPix];
                    }
                    else   // <--- US Regions (Length)
                    {
                        if (lCm < .01)
                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.1f %cm", nil), lCm * 10000.0, 0xb5];
                        else if (lCm < 1)
                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f mm", nil), lCm * 10.];
                        else
                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f cm", nil), lCm];
                    }
                }
            }
            else
                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f pix", nil), [self Length:[[points objectAtIndex:0] point] :[[points objectAtIndex:1] point]]];
            
            // If there is another line, compute Cobb's angle
            if (curView &&
                displayCobbAngle &&
                self.displayCMOrPixels == NO &&
                displayCobbAngleIntern)
            {
                NSArray *roiList3 = curView.curRoiList;
                
                NSUInteger index = [roiList3 indexOfObject: self];
                if (index != NSNotFound)
                {
                    //if (index > 0)
                    //{
                    for (int i = 0; i < index; i++)
                    {
                        ROI *r = [roiList3 objectAtIndex: i];
                        
                        if ([r type] == tMeasure)
                        {
                            NSArray *B = [r points];
                            NSPoint u1 = [[[self points] objectAtIndex: 0] point],
                                    u2 = [[[self points] objectAtIndex: 1] point],
                                    v1 = [[B objectAtIndex: 0] point],
                                    v2 = [[B objectAtIndex: 1] point];
                            
                            float pX = [curView.curDCM pixelSpacingX];
                            float pY = [curView.curDCM pixelSpacingY];
                            
                            if (pX == 0 || pY == 0)
                            {
                                pX = 1;
                                pY = 1;
                            }
                            
                            NSPoint a1 = NSMakePoint(u1.x * pX, u1.y * pY);
                            NSPoint a2 = NSMakePoint(u2.x * pX, u2.y * pY);
                            NSPoint b1 = NSMakePoint(v1.x * pX, v1.y * pY);
                            NSPoint b2 = NSMakePoint(v2.x * pX, v2.y * pY);
                            
                            double angle = [self angleBetween2Lines: a1 :a2 :b1 :b2];
                            
                            if (angle < -180)
                                angle = -180 - angle;
                            else if (angle < -90)
                                angle += 180;
                            else if (angle < 0)
                                angle *= -1;
                            
                            if (angle > 270)
                                angle = 360 - angle;
                            else if (angle > 180)
                                angle -= 180;
                            else if (angle > 90)
                                angle = 180 - angle;
                            
                            NSString *rName = r.name;
                            
                            if ([rName isEqualToString: @"Unnamed"] ||
                                [rName isEqualToString: NSLocalizedString( @"Unnamed", nil)])
                            {
                                rName = nil;
                            }
                            
                            if (rName)
                                self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Angle: %0.2f%@ with: %@", nil), angle, @"\u00B0", rName];
                            else
                                self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Angle: %0.2f%@", nil), angle, @"\u00B0"];
                            
                            break;
                        }
                    } // for
                    //} // if (index > 0)
                }
            } // Cobb
        }

        [self prepareTextualData:tPt];
    } // if textualdata
}

#pragma mark - tROI (6)

- (void) tROI_drawWithScaleValue:(float)scaleValue
                          offset:(NSPoint)offset
             highlightIfSelected:(BOOL)highlightIfSelected
                       thickness:(float)thick
              prepareTextualData:(BOOL)prepareTextualData
{
#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    const int nPoints = 4;
    glm::vec2 pA[nPoints];
    pA[0] = glm::vec2((NSMinX(rect) - offset.x) * scaleValue,
                      (NSMinY(rect) - offset.y) * scaleValue);

    pA[1] = glm::vec2((NSMinX(rect) - offset.x) * scaleValue,
                      (NSMaxY(rect) - offset.y) * scaleValue);

    pA[2] = glm::vec2((NSMaxX(rect) - offset.x) * scaleValue,
                      (NSMaxY(rect) - offset.y) * scaleValue);

    pA[3] = glm::vec2((NSMaxX(rect) - offset.x) * scaleValue,
                      (NSMinY(rect) - offset.y) * scaleValue);

    glm::vec2 pC((NSMidX(rect) - offset.x) * scaleValue,
                 (NSMidY(rect) - offset.y) * scaleValue);

    NSMutableArray *pArray6 = [NSMutableArray array];
    for (int i=0; i<nPoints; i++)
        [pArray6 addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

    float backingScaleFactor = curView.window.backingScaleFactor;
    
    [curView setShaderProgramForLineWidth: thick*backingScaleFactor];
    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    renderer_drawLine_xy([pArray6 copy], GL_LINE_LOOP);

    [curView setShaderProgramOverlay_withMode_Point];

    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"drawROICircleCenter"])
        [pArray6 addObject: [NSValue valueWithBytes:&pC objCType:@encode(glm::vec2)]];
    
    // Draw the points (bigger and blue) if this ROI is selected
    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue
    }
    else {
        glPointSize( thick * backingScaleFactor);
    }

    renderer_drawPoints([pArray6 copy]);

    // Restore
    [curView setShaderProgramForLineWidth: 1.0*backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
    [curView setShaderProgramOverlay];

#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
            [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        if (ROITEXTNAMEONLY == NO)
        {
            [self computeROIIfNedeed];
            
            // US Regions (Rectangle) --->
            BOOL roiInside2DUSRegion = FALSE;
            if ([[self pix] hasUSRegions])
            {
                NSPoint roiPoint1 = NSMakePoint(rect.origin.x, rect.origin.y);
                NSPoint roiPoint2 = NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height);
                
                //NSLog(@"roi [%i,%i] [%i,%i]", (int)roiPoint1.x, (int)roiPoint1.y, (int)roiPoint2.x, (int)roiPoint2.y);
                
                for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                {
                    if (!roiInside2DUSRegion && [anUsRegion regionSpatialFormat] == 1) {
                        // 2D spatial format
                        int usRegionMinX = [anUsRegion regionLocationMinX0];
                        int usRegionMinY = [anUsRegion regionLocationMinY0];
                        int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                        int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                        
                        //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                        
                        roiInside2DUSRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                               ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                               ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                               ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                    }
                }
                
            }
            //if (pixelSpacingX != 0 && pixelSpacingY != 0 ) {
            if (roiInside2DUSRegion || (pixelSpacingX != 0 && pixelSpacingY != 0 && ![[self pix] hasUSRegions])) {
            // <--- US Regions (Rectangle)
                if ( fabs( NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY) < 1.)
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2 (W: %0.1f %cm H: %0.1f %cm)", @"W = Width, H = Height"), fabs( NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY * 1000000.0), 0xB5, fabs(NSWidth(rect)*pixelSpacingX)*1000.0, 0xB5, fabs(NSHeight(rect)*pixelSpacingY)*1000.0, 0xB5];
                else if ( fabs( NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY)/100. < 1.)
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2 (W: %0.3f mm H: %0.3f mm)", @"W = Width, H = Height"), fabs( NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY), fabs(NSWidth(rect)*pixelSpacingX), fabs(NSHeight(rect)*pixelSpacingY)];
                else
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f cm\u00B2 (W: %0.3f cm H: %0.3f cm)", @"W = Width, H = Height"), fabs( NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY/100.), fabs(NSWidth(rect)*pixelSpacingX)/10., fabs(NSHeight(rect)*pixelSpacingY)/10.];
            }
            else
                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2 (W: %0.3f pix H: %0.3f pix)", @"W = Width, H = Height"), fabs( NSWidth(rect)*NSHeight(rect)), fabs(NSWidth(rect)), fabs(NSHeight(rect))];
            
            NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
            
            if ([self pix].SUVConverted)
                pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
            
            self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
            if (rskewness || rkurtosis)
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), rmin, pixelUnit, rmax, pixelUnit, rskewness, rkurtosis];
            else
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
            
            if ([curView blendingView])
            {
                DCMPix    *blendedPix = [[curView blendingView] curDCM];
                ROI *b = [[self copy] autorelease];
                b.pix = blendedPix;
                b.curView = curView.blendingView;
                [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                      : blendedPix.pixelSpacingY
                                      : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                [b computeROIIfNedeed];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                
                if (blendedPix.SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                
                if (b.skewness || b.kurtosis)
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), b.min, pixelUnit, b.max, pixelUnit, b.skewness, b.kurtosis];
                else
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
            }
        }
        
        [self prepareTextualData:tPt];
    }
}

#pragma mark - tOval (9), tOvalAngle (31)

- (void) tOval_tOvalAngle_drawWithScaleValue:(float)scaleValue
                                      offset:(NSPoint)offset
                         highlightIfSelected:(BOOL)highlightIfSelected
                                   thickness:(float)thick
                          prepareTextualData:(BOOL)prepareTextualData
{
    NSRect rrect = rect;
    
    if (rrect.size.height < 0)
        rrect.size.height = -rrect.size.height;
    
    if (rrect.size.width < 0)
        rrect.size.width = -rrect.size.width;
    
    int resol = (rrect.size.height + rrect.size.width) * 1.5 * scaleValue;
    
    {
#ifdef WITH_OPENGL_32
        #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
        // Define a local model matrix and apply it locally without affecting the shader
        glm::mat4 M = glm::mat4(1.0);
        M = glm::translate(M, glm::vec3((rrect.origin.x - offset.x)*scaleValue,
                                        (rrect.origin.y - offset.y)*scaleValue,
                                        0.0f));
        M = glm::rotate(M, glm::radians(roiRotationDeg), glm::vec3(0,0,1));
        #endif // WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
#else
        NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
        CGLContextObj cgl_ctx = [currentContext CGLContextObj];

        glPushMatrix();
        glTranslatef((rrect.origin.x - offset.x)*scaleValue,
                     (rrect.origin.y - offset.y)*scaleValue,
                     0.0f);
        glRotatef( roiRotationDeg, 0, 0, 1.0f);
#endif
        
#pragma mark oval line loop

        NSRect r = rrect;
        r.size.width *= scaleValue;
        r.size.height *= scaleValue;
    
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<resol; i++) {
            float angle = i * 2 * M_PI /resol;
            glm::vec2 pA(r.size.width*cos(angle),
                         r.size.height*sin(angle));
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
            // Apply local model transformation
            glm::vec4 pB = M*glm::vec4(pA,0,1);
            pA = glm::vec2(pB.x, pB.y);
            #endif
            [pArray addObject: [NSValue valueWithBytes:&pA objCType:@encode(glm::vec2)]];
        }

        float backingScaleFactor = curView.window.backingScaleFactor;

        [curView setShaderProgramForLineWidth: thick*backingScaleFactor];
        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
        renderer_drawLine_xy([pArray copy], GL_LINE_LOOP);

#pragma mark redraw as points (plus center point)

        if ([[NSUserDefaults standardUserDefaults] boolForKey: @"drawROICircleCenter"])
        {
            glm::vec2 a(0, 0);
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
            glm::vec4 pB = M*glm::vec4(a,0,1);
            a = glm::vec2(pB.x, pB.y);
            #endif
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }

        [curView setShaderProgramOverlay_withMode_Point];
#ifdef WITH_OPENGL_32
        // Redefine the color because we changed the shader program
        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
#endif
        glPointSize( thick * backingScaleFactor);
        renderer_drawPoints([pArray copy]);
        
#pragma mark For tOvalAngle draw the arms defining the angle

        glm::vec2 armEndPoints[2];

        if (type == tOvalAngle)
        {
            glm::vec2 pArm1(armScale*r.size.width*cos(ovalAngle[0]),
                            armScale*r.size.height*sin(ovalAngle[0]));

            glm::vec2 pArm2(armScale*r.size.width*cos(ovalAngle[1]),
                            armScale*r.size.height*sin(ovalAngle[1]));

            const int nPoints = 3;
            glm::vec2 pArmVert[nPoints]; // vertices
            pArmVert[0] = pArm1;
            pArmVert[1] = glm::vec2(0,0);
            pArmVert[2] = pArm2;

            armEndPoints[0] = pArm1;
            armEndPoints[1] = pArm2;

            NSMutableArray *pArrayArms = [NSMutableArray array];
            for (int i=0; i<nPoints; i++) {
                glm::vec2 a(pArmVert[i].x, pArmVert[i].y);
                #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
                glm::vec4 pB = M*glm::vec4(a,0,1);
                a = glm::vec2(pB.x, pB.y);
                #endif
                [pArrayArms addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
            }

            [curView setShaderProgramOverlay_withMode_Normal];
            renderer_drawLine_xy([pArrayArms copy], GL_LINE_STRIP);
        }
    
        // When editing this tOval show points at the corners of the bounding rectangle, and center
        if ((mode == ROI_selected ||
             mode == ROI_selectedModify ||
             mode == ROI_drawing) && highlightIfSelected)
        {
            const int nPoints = 5;
            glm::vec2 ovalBoundingPoints[nPoints]; // bounding rect corners and center
            ovalBoundingPoints[0] = glm::vec2(-r.size.width, -r.size.height);
            ovalBoundingPoints[1] = glm::vec2(-r.size.width,  r.size.height);
            ovalBoundingPoints[2] = glm::vec2( r.size.width,  r.size.height);
            ovalBoundingPoints[3] = glm::vec2( r.size.width, -r.size.height);
            ovalBoundingPoints[4] = glm::vec2(0,0); // Center always shown when editing this ROI

            NSMutableArray *pPointArray = [NSMutableArray array];

            for (int i=0; i<nPoints; i++) {
                glm::vec2 a(ovalBoundingPoints[i].x,
                            ovalBoundingPoints[i].y);
                #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
                glm::vec4 pB = M*glm::vec4(a,0,1);
                a = glm::vec2(pB.x, pB.y);
                #endif
                [pPointArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
            }
            
            if (type == tOvalAngle) {
                for (int i=0; i<2; i++) {
                    glm::vec2 a(armEndPoints[i].x, armEndPoints[i].y);
                    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI3
                    glm::vec4 pB = M*glm::vec4(a,0,1);
                    a = glm::vec2(pB.x, pB.y);
                    #endif
                    [pPointArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
                }
            }

#ifdef WITH_OPENGL_32
            [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
            glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
            renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue
            renderer_drawPoints([pPointArray copy]);
        }
        
        // Restore
#ifndef WITH_OPENGL_32
        [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
        renderer_set_rgb(1.0f, 1.0f, 1.0f); // white

        glTranslatef(-NSMaxX(rrect), -NSMaxY(rrect), 0.0f); // what's the point ?
        glPopMatrix();
#endif
    }
    
#pragma mark define textualdata
    
    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
           [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        if (ROITEXTNAMEONLY == NO)
        {
            [self computeROIIfNedeed];
            
            // US Regions (Oval) --->
            BOOL roiInside2DUSRegion = FALSE;
            if ([[self pix] hasUSRegions]) {
                
                NSPoint roiPoint1 = NSMakePoint(rrect.origin.x-rrect.size.width,
                                                rrect.origin.y-rrect.size.height);

                NSPoint roiPoint2 = NSMakePoint(rrect.origin.x+rrect.size.width,
                                                rrect.origin.y+rrect.size.height);
                
                //NSLog(@"roi [%i,%i] [%i,%i]", (int)roiPoint1.x, (int)roiPoint1.y, (int)roiPoint2.x, (int)roiPoint2.y);
                
                for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                {
                    if (!roiInside2DUSRegion && [anUsRegion regionSpatialFormat] == 1) {
                        // 2D spatial format
                        int usRegionMinX = [anUsRegion regionLocationMinX0];
                        int usRegionMinY = [anUsRegion regionLocationMinY0];
                        int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                        int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                        
                        //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                        
                        roiInside2DUSRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                               ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                               ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                               ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                    }
                }
            }
            
            if (roiInside2DUSRegion ||
                (pixelSpacingX != 0 && pixelSpacingY != 0 && ![[self pix] hasUSRegions]))
            // <--- US Regions (Oval)
            {
                float area = [self EllipseArea];
                if (area*pixelSpacingX*pixelSpacingY < 1.)
                {
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2 (W: %0.1f %cm H: %0.1f %cm)", @"W = Width, H = Height"), area*pixelSpacingX*pixelSpacingY* 1000000.0, 0xB5, 2.0*fabs(NSWidth(rect))*pixelSpacingX*10000.0, 0xB5, 2.0*fabs(NSHeight(rect))*pixelSpacingY*10000.0, 0xB5];
                }
                else if (area*pixelSpacingX*pixelSpacingY/100. < 1.)
                {
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2 (W: %0.3f mm H: %0.3f mm)", @"W = Width, H = Height"), area*pixelSpacingX*pixelSpacingY, 2.0*fabs(NSWidth(rect))*pixelSpacingX, 2.0*fabs(NSHeight(rect))*pixelSpacingY];
                }
                else
                {
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f cm\u00B2 (W: %0.3f cm H: %0.3f cm)", @"W = Width, H = Height"), area*pixelSpacingX*pixelSpacingY/100., 2.0*fabs(NSWidth(rect))*pixelSpacingX/10., 2.0*fabs(NSHeight(rect))*pixelSpacingY/10.];
                }
            }
            else
            {
                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2 (W: %0.3f pix H: %0.3f pix)", @"W = Width, H = Height"), [self EllipseArea], 2.0*fabs(NSWidth(rect)), 2.0*fabs(NSHeight(rect))];
            }
            
            if (type==tOvalAngle)
            {
                float angleDeg = glm::degrees(fabs(ovalAngle1-ovalAngle2));
                self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingFormat: @" %@: %0.1f%@/%0.1f%@", NSLocalizedString( @"Angle", nil), angleDeg, @"\u00B0", 360 - angleDeg, @"\u00B0"];
            }
            
            NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
            
            if ([self pix].SUVConverted)
                pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
            
            self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
            
            if (rskewness || rkurtosis)
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), rmin, pixelUnit, rmax, pixelUnit, rskewness, rkurtosis];
            else
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
            
            if ([curView blendingView])
            {
                DCMPix *blendedPix = [[curView blendingView] curDCM];
                ROI *b = [[self copy] autorelease];
                b.pix = blendedPix;
                b.curView = curView.blendingView;
                [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                      : blendedPix.pixelSpacingY
                                      : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                [b computeROIIfNedeed];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                
                if (blendedPix.SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                
                if (b.skewness || b.kurtosis)
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), b.min, pixelUnit, b.max, pixelUnit, b.skewness, b.kurtosis];
                else
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
            }
        }
        
        [self prepareTextualData:tPt];
    }
}

#pragma mark - tText (13)

- (void) tText_drawWithScaleValue:(float)scaleValue
                           offset:(NSPoint)offset
              highlightIfSelected:(BOOL)highlightIfSelected
{
    //NSLog(@"ROI.mm line %d, draw tText", __LINE__);

    CGSize scaleFactor = [curView drawingFrameRect].size;
    CGPoint translationOffset;
    translationOffset.x = [curView origin].x;
    translationOffset.y = -[curView origin].y;
    BOOL flipX = [curView xFlipped];
    BOOL flipY = [curView yFlipped];
    float signX = flipX ? -1.0 : 1.0;
    float signY = flipY ? -1.0 : 1.0;

#ifdef WITH_OPENGL_32
    //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI1
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI1
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::mat4(1.0);
    M = glm::scale(M, glm::vec3(signX * 2.0f / scaleFactor.width,
                               -signY * 2.0f / scaleFactor.height,
                                1.0f));
    M = glm::translate(M, glm::vec3(translationOffset.x,
                                    translationOffset.y,
                                    0.0f));
    #endif // WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI1
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];

    glPushMatrix();
    glLoadIdentity();
    glScalef(signX * 2.0f / scaleFactor.width,
            -signY * 2.0f / scaleFactor.height,
             1.0f);
    glTranslatef(translationOffset.x,
                 translationOffset.y,
                 0.0f);
#endif

    float ratio = 1.0f;
    if (pixelSpacingX != 0 && pixelSpacingY != 0)
    {
        ratio = pixelSpacingX / pixelSpacingY;
    }

    NSRect centeredRect = rect;
    NSRect unrotatedRect = rect;
    
    centeredRect.origin.y -= offset.y + [curView origin].y*ratio/scaleValue;
    centeredRect.origin.x -= offset.x - [curView origin].x/scaleValue;
    
    unrotatedRect.origin.x =  centeredRect.origin.x * cos( glm::radians(-curView.rotation)) +
                              centeredRect.origin.y * sin( glm::radians(-curView.rotation))/ratio;

    unrotatedRect.origin.y = -centeredRect.origin.x * sin( glm::radians(-curView.rotation)) +
                              centeredRect.origin.y * cos( glm::radians(-curView.rotation))/ratio;
    
    unrotatedRect.origin.y *= ratio;
    
    unrotatedRect.origin.y += offset.y + [curView origin].y*ratio/scaleValue;
    unrotatedRect.origin.x += offset.x - [curView origin].x/scaleValue;
    
    float backingScaleFactor = curView.window.backingScaleFactor;
    unrotatedRect.size.width *= backingScaleFactor;
    unrotatedRect.size.height *= backingScaleFactor;
    
    // Four corner of text bounding box
    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        const int nPoints = 4;
        glm::vec2 textCorners[nPoints];
        textCorners[0] = glm::vec2((unrotatedRect.origin.x - offset.x)*scaleValue - unrotatedRect.size.width/2,
                                  ((unrotatedRect.origin.y - offset.y)*scaleValue - unrotatedRect.size.height/2)/ratio);

        textCorners[1] = glm::vec2((unrotatedRect.origin.x - offset.x)*scaleValue - unrotatedRect.size.width/2,
                                  ((unrotatedRect.origin.y - offset.y)*scaleValue + unrotatedRect.size.height/2)/ratio);

        textCorners[2] = glm::vec2((unrotatedRect.origin.x - offset.x)*scaleValue + unrotatedRect.size.width/2,
                                  ((unrotatedRect.origin.y - offset.y)*scaleValue + unrotatedRect.size.height/2)/ratio);

        textCorners[3] = glm::vec2((unrotatedRect.origin.x - offset.x)*scaleValue + unrotatedRect.size.width/2,
                                  ((unrotatedRect.origin.y - offset.y)*scaleValue - unrotatedRect.size.height/2)/ratio);

        NSMutableArray *pPointArray = [NSMutableArray array];

        for (int i=0; i<nPoints; i++) {
            glm::vec2 a(textCorners[i].x, textCorners[i].y);
            #if 0 //def WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI1
            // FIXME: This code should be commented in, but it works when it's commented out.
            // Maybe the points textCorners[i] are already "transformed".

            // Apply local model transformation
            glm::vec4 pB = M*glm::vec4(a,0,1);
            a = glm::vec2(pB.x, pB.y);
            #endif
            [pPointArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }
        
#ifdef WITH_OPENGL_32
        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
        glPointSize(2.0 * 3 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f);         // light blue
        renderer_drawPoints([pPointArray copy]);
    }
    
#ifndef WITH_OPENGL_32
    // Unnecessary ?
    [curView setShaderProgramForLineWidth: 1.0 * backingScaleFactor];
#endif

    NSPoint tPt = unrotatedRect.origin;
    tPt.x =  (tPt.x - offset.x)*scaleValue - unrotatedRect.size.width/2;
    tPt.y = ((tPt.y - offset.y)*scaleValue - unrotatedRect.size.height/2)/ratio;
    
#ifndef WITH_OPENGL_32
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
#endif
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    if (stringTex == nil )
        self.name = name;  // Assigning to itself ?
    
    [stringTex setFlippedX: [curView xFlipped] Y:[curView yFlipped]];
    
#ifdef WITH_OPENGL_32
    GLScene *s = [GLScene currentScene];
    [s.overlayProgram Bind];
    [s.overlayProgram setMode: SHADER_MODE_TEXTURE_RGBA];
    //[curView setShaderProgramOverlay_withMode:SHADER_MODE_TEXTURE_RGBA];
#endif

    // First draw text shadow (black)
    renderer_setTextColor(0.0f, 0.0f, 0.0f, opacity);
    [stringTex drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+ 1.0) ratio: 1];
                    
    // Then draw text (ROI color, default yellow)
    renderer_setTextColor(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    [stringTex drawAtPoint:tPt ratio: 1];
        
    // Restore
    renderer_setTextColor(1.0f, 1.0f, 1.0f, 1.0); // white
#ifdef WITH_OPENGL_32
    [s.overlayProgram setMode: SHADER_MODE_NORMAL];
#else
    glDisable(GL_TEXTURE_RECTANGLE_EXT);
    glPopMatrix();
#endif
}

#pragma mark - tArrow (14)

// Define an array of 3 NSPoint 'arh', the triangle representing the arrow head
- (void) tArrow_defineHead: (NSPoint) a
                          : (NSPoint) b
                          : (float) slide
                          : (float) angleDeg
                          : (float) adj
                          : (float) op
                          : (float) backingScaleFactor
                          : (float) thick
{
    float ARROWSIZE = ARROWSIZEConstant * (thick * backingScaleFactor / 3.0);

    if (b.y-a.y > 0)
    {
        angleDeg = glm::degrees(atan(slide));
        
        angleDeg = 80 - angleDeg - thick * backingScaleFactor;
        adj = (ARROWSIZE + thick * backingScaleFactor * 15) * cos( glm::radians(angleDeg));
        op  = (ARROWSIZE + thick * backingScaleFactor * 15) * sin( glm::radians(angleDeg));
        
        if (pixelSpacingX != 0 && pixelSpacingY != 0 )
            arh[0] = NSMakePoint( a.x + adj, a.y + (op*pixelSpacingX / pixelSpacingY));
        else
            arh[0] = NSMakePoint( a.x + adj, a.y + (op));
            
        angleDeg = glm::degrees(atan( slide));
        angleDeg = 100 - angleDeg + thick * backingScaleFactor;
        adj = (ARROWSIZE + thick * backingScaleFactor * 15) * cos( glm::radians(angleDeg));
        op  = (ARROWSIZE + thick * backingScaleFactor * 15) * sin( glm::radians(angleDeg));
        
        if (pixelSpacingX != 0 && pixelSpacingY != 0 )
            arh[1] = NSMakePoint( a.x + adj, a.y + (op*pixelSpacingX / pixelSpacingY));
        else
            arh[1] = NSMakePoint( a.x + adj, a.y + (op));
    }
    else
    {
        angleDeg = glm::degrees(atan( slide));
        angleDeg = 180 + 80 - angleDeg - thick * backingScaleFactor;
        adj = (ARROWSIZE + thick * backingScaleFactor * 15) * cos( glm::radians(angleDeg));
        op  = (ARROWSIZE + thick * backingScaleFactor * 15) * sin( glm::radians(angleDeg));
        
        if (pixelSpacingX != 0 && pixelSpacingY != 0 )
            arh[0] = NSMakePoint( a.x + adj, a.y + (op*pixelSpacingX / pixelSpacingY));
        else
            arh[0] = NSMakePoint( a.x + adj, a.y + (op));
            
        angleDeg = glm::degrees(atan( slide));
        angleDeg = 180 + 100 - angleDeg + thick * backingScaleFactor;
        adj = (ARROWSIZE + thick * backingScaleFactor * 15) * cos( glm::radians(angleDeg));
        op  = (ARROWSIZE + thick * backingScaleFactor * 15) * sin( glm::radians(angleDeg));
        
        if (pixelSpacingX != 0 && pixelSpacingY != 0 )
            arh[1] = NSMakePoint( a.x + adj, a.y + (op*pixelSpacingX / pixelSpacingY));
        else
            arh[1] = NSMakePoint( a.x + adj, a.y + (op));
    }

    arh[2] = NSMakePoint( a.x , a.y );
}

#pragma mark - t2DPoint (19)

- (void) t2DPoint_drawWithScaleValue:(float)scaleValue
                              offset:(NSPoint)offset
                 highlightIfSelected:(BOOL)highlightIfSelected
                           thickness:(float)thick
                  prepareTextualData:(BOOL)prepareTextualData
{
    //float angle;

    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);

    glm::vec2 pThinCircle[CIRCLE_RESOLUTION];
    for (int i = 0; i < CIRCLE_RESOLUTION; i++) {
        float angle = i * 2 * M_PI /CIRCLE_RESOLUTION;
      
        if (pixelSpacingX != 0 && pixelSpacingY != 0 ) {
            pThinCircle[i] = glm::vec2((rect.origin.x - offset.x)*scaleValue + 8*cos(angle),
            (rect.origin.y - offset.y)*scaleValue + 8*sin(angle)*pixelSpacingX/pixelSpacingY);
        }
        else {
            pThinCircle[i] = glm::vec2((rect.origin.x - offset.x)*scaleValue + 8*cos(angle),
            (rect.origin.y - offset.y)*scaleValue + 8*sin(angle));
        }
    }

#pragma mark external thin circle
    {
        NSMutableArray *pArray19 = [NSMutableArray array];
        for (int i=0; i<CIRCLE_RESOLUTION; i++) {
            [pArray19 addObject: [NSValue valueWithBytes:&pThinCircle[i] objCType:@encode(glm::vec2)]];
        }

        renderer_drawLine_xy([pArray19 copy], GL_LINE_LOOP);
    }
    
#pragma mark Draw the actual center point

#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif

    // the color depends on the selection
    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        renderer_set_rgba(0.5f, 0.5f, 1.0f, opacity); // light blue
    }
    else {
        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    }
    //else renderer_set_rgba(1.0f, 0.0f, 0.0f, opacity);
    
    glm::vec2 pActualPoint((rect.origin.x - offset.x) * scaleValue,
                           (rect.origin.y - offset.y) * scaleValue);
    
    float backingScaleFactor = curView.window.backingScaleFactor;
#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif
    glPointSize( (1 + sqrt( thick))*3.5 * backingScaleFactor);
    
    {
        NSMutableArray *pArray = [NSMutableArray array];
        [pArray addObject: [NSValue valueWithBytes:&pActualPoint objCType:@encode(glm::vec2)]];

        renderer_drawPoints([pArray copy]);
    }
    
    // Restore
    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
    
#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO && [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO) self.textualBoxLine1 = name;
        else
            self.textualBoxLine1 = nil;
        
        if (ROITEXTNAMEONLY == NO )
        {
            [self computeROIIfNedeed];
            
            // US Regions (Point) --->
            double roiPosXValue, roiPosYValue;
            int physicalUnitsXDirection, physicalUnitsYDirection;
            BOOL roiInsideMModeOrSpectralUSRegion = NO;
            BOOL isReferencePixelX0Present = NO, isReferencePixelY0Present = NO;
            if ([[self pix] hasUSRegions])
            {
                for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                {
                    if (!roiInsideMModeOrSpectralUSRegion && ([anUsRegion regionSpatialFormat] == 2 || [anUsRegion regionSpatialFormat] == 3)) {
                        // M-Mode or Spectral spatial format
                        int usRegionMinX = [anUsRegion regionLocationMinX0];
                        int usRegionMinY = [anUsRegion regionLocationMinY0];
                        int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                        int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                        
                        //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                        
                        roiInsideMModeOrSpectralUSRegion = (((int)rect.origin.x >= usRegionMinX) && ((int)rect.origin.x <= usRegionMaxX) &&
                                                            ((int)rect.origin.y >= usRegionMinY) && ((int)rect.origin.y <= usRegionMaxY));
                        
                        if (roiInsideMModeOrSpectralUSRegion)
                        {
                            // X axis
                            physicalUnitsXDirection = [anUsRegion physicalUnitsXDirection];
                            isReferencePixelX0Present = [anUsRegion isReferencePixelX0Present];
                            if (isReferencePixelX0Present)
                                roiPosXValue = (rect.origin.x - (usRegionMinX + [anUsRegion referencePixelX0]) + [anUsRegion refPixelPhysicalValueX]) * [anUsRegion physicalDeltaX];
                            
                            // Y axis
                            physicalUnitsYDirection = [anUsRegion physicalUnitsYDirection];
                            isReferencePixelY0Present = [anUsRegion isReferencePixelY0Present];
                            if (isReferencePixelY0Present)
                            {
                                if ([anUsRegion regionSpatialFormat] == 2)
                                    // M-Mode
                                    roiPosYValue = -((usRegionMinY + [anUsRegion referencePixelY0]) - rect.origin.y) * fabs([anUsRegion physicalDeltaY]);
                                else
                                    // Spectral
                                    roiPosYValue = ((usRegionMinY + [anUsRegion referencePixelY0]) - rect.origin.y) * fabs([anUsRegion physicalDeltaY]);
                            }
                        }
                    }
                }
            }
            // <--- US Regions (Point)
            
            NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
            
            if ([self pix].SUVConverted)
                pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
            
            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Value: %0.3f%@", nil), rmean, pixelUnit];
            
            
            if ([curView blendingView])
            {
                DCMPix *blendedPix = [[curView blendingView] curDCM];
                
                ROI *b = [[[ROI alloc] initWithType: type
                                                   : [blendedPix pixelSpacingX]
                                                   : [blendedPix pixelSpacingY]
                                                   : [DCMPix originCorrectedAccordingToOrientation: blendedPix]] autorelease];
                b.curView = curView.blendingView;
                
                NSRect blendedRect = [self rect];
                blendedRect.origin = [curView ConvertFromGL2GL: blendedRect.origin toView:[curView blendingView]];
                [b computeROIIfNedeed];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                
                if (blendedPix.SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Value: %0.3f%@", nil), b.mean, pixelUnit];
            }
            
            // US Regions (Point) --->
            if (roiInsideMModeOrSpectralUSRegion)
            {
                NSString * unitsX;
                NSString * unitsY;
                if ((physicalUnitsXDirection < 0) ||
                    (physicalUnitsXDirection > 12))
                {
                    unitsX = NSLocalizedString( @"unknown", nil);
                }
                else if ((physicalUnitsYDirection < 0) ||
                         (physicalUnitsYDirection > 12))
                {
                    unitsY = NSLocalizedString( @"unknown", nil);
                }
                else
                {
                    unitsX = [self.physicalUnitsXYDirection objectAtIndex:physicalUnitsXDirection];
                    unitsY = [self.physicalUnitsXYDirection objectAtIndex:physicalUnitsYDirection];
                }
                
                if (!isReferencePixelX0Present &&
                    isReferencePixelY0Present)
                {
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"2D Pos: X:n/a %@ Y:%0.3f %@", nil), unitsX, roiPosYValue, unitsY];
                }
                else if (isReferencePixelX0Present &&
                         !isReferencePixelY0Present)
                {
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"2D Pos: X:%0.3f %@ Y:n/a %@", nil), roiPosXValue, unitsX, unitsY];
                }
                else if (!isReferencePixelX0Present &&
                         !isReferencePixelY0Present)
                {
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"2D Pos: X:n/a %@ Y:n/a %@", nil), unitsX, unitsY];
                }
                else
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"2D Pos: X:%0.3f %@ Y:%0.3f %@", nil), roiPosXValue, unitsX, roiPosYValue, unitsY];
                
            }
            else {
            // <--- US Regions (Point)
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"2D Pos: X:%0.3f px Y:%0.3f px", nil), rect.origin.x, rect.origin.y];
            } // US Regions (Point)
            
            float location[ 3 ];
            [[curView curDCM] convertPixX: rect.origin.x
                                     pixY: rect.origin.y
                            toDICOMCoords: location
                              pixelCenter: YES];
            
            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"3D Pos: X:%0.3f mm Y:%0.3f mm Z:%0.3f mm", nil), location[0], location[1], location[2]];
        }
        [self prepareTextualData:tPt];
    }
}

#pragma mark - tPlain (20)

#ifndef NDEBUG
-(void)displayTexture: (unsigned char *)texture
                width: (int) w
               height: (int) h
{
    printf("texture buffer, WH: %d,%d\n", w, h);
    for (int i = 0; i < w*h; i++) {
        if (i%w == 0)
            printf("\n");

        printf("%3d ", texture[i]);
    }
    printf("\n");
}
#endif

#define MARGIN_SELECTED      1

// Brush
- (void) tPlain_drawWithScaleValue:(float)scaleValue
                            offset:(NSPoint)offset
               highlightIfSelected:(BOOL)highlightIfSelected
                prepareTextualData:(BOOL)prepareTextualData
{
    float screenXUpL;
    float screenYUpL;
    float screenXDr;
    float screenYDr;

#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    glDisable(GL_POLYGON_SMOOTH);       checkOpenGLErrors(__LINE__);
    
    if (textureWidth % 4 != 0 ||
        textureHeight % 4 != 0)
    {
        [self reduceTextureIfPossible];
    }
    
#pragma mark highlight (edge)

    if (highlightIfSelected && ROIDrawPlainEdge)
    {
        switch (mode)
        {
            case ROI_drawing:
            case ROI_selected:
            case ROI_selectedModify:
            {
                int margin = MARGIN_SELECTED;
                
                int newWidth = textureWidth + 4*margin;
                int newHeight = textureHeight + 4*margin;
                int newTextureUpLeftCornerX = textureUpLeftCornerX-2*margin;
                int newTextureUpLeftCornerY = textureUpLeftCornerY-2*margin;
                
                if (textureBufferSelected == nil)
                {
                    textureBufferSelected = [ROI addMargin: 2*margin
                                                    buffer: textureBuffer
                                                     width: textureWidth
                                                    height: textureHeight];
                    
                    if (textureBufferSelected)
                    {
                        unsigned char *newBufferCopy = (unsigned char *)malloc( newWidth*newHeight);
                        if (newBufferCopy)
                        {
                            memcpy( newBufferCopy, textureBufferSelected, newWidth*newHeight);
                            
                            {
                                // input buffer
                                unsigned char *buff = textureBufferSelected;
                                int bufferWidth = newWidth;
                                int bufferHeight = newHeight;
                                
                                margin *= 2;
                                margin++;
                                
                                {
                                    unsigned char *kernelDilate = (unsigned char*) calloc( margin*margin, sizeof(unsigned char));
                                    assert (kernelDilate);
                                    vImage_Buffer srcbuf, dstBuf;
                                    vImage_Error err;
                                    srcbuf.data = buff;
                                    dstBuf.data = malloc( bufferHeight * bufferWidth);
                                    if (dstBuf.data)
                                    {
                                        dstBuf.height = srcbuf.height = bufferHeight;
                                        dstBuf.width = srcbuf.width = bufferWidth;
                                        dstBuf.rowBytes = srcbuf.rowBytes = bufferWidth;
                                        err = vImageDilate_Planar8( &srcbuf, &dstBuf, 0, 0, kernelDilate, margin, margin, kvImageDoNotTile);
                                    
                                        memcpy(buff,dstBuf.data,bufferWidth*bufferHeight);
                                        free( dstBuf.data);
                                    }

                                    free( kernelDilate);
                                }
                            }
                            
                            // Subtraction (make it hollow)
                            for (long i = 0; i < newWidth*newHeight; i++)
                                if (newBufferCopy[ i])
                                    textureBufferSelected[ i] = 0;
                            
                            free( newBufferCopy);
                        }
                    }
                }
                
                // draw the selection edge

                if (textureBufferSelected)
                {
#ifdef WITH_OPENGL_32
                    GLenum target = GL_TEXTURE_RECTANGLE;
                    GLint internalFormat = GL_R8;
                    GLenum format = GL_RED;
#else
                    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
                    GLint internalFormat = GL_INTENSITY8;
                    GLenum format = GL_LUMINANCE;

                    glEnable(target); checkOpenGLErrors(__LINE__);
#endif
          
#ifndef WITH_OPENGL_32
                    // Make a single memory mapping for all of the textures used by the application:
                    glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, newWidth * newHeight, textureBufferSelected);
#endif
                    GLuint textureID = 0;
                    glGenTextures(1, &textureID);
                    glBindTexture(target, textureID);

                    glPixelStorei (GL_UNPACK_ROW_LENGTH, newWidth);
                    glPixelStorei (GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
                    
#ifndef WITH_OPENGL_32
                    // The cached hint specifies to cache texture data in video memory. This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering
                    glTexParameteri(target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif
                    
                    glBlendEquation(GL_FUNC_ADD);
                    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                    
                    GLint param;
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NOINTERPOLATION"])
                        param = GL_NEAREST; //GL_LINEAR_MIPMAP_LINEAR
                    else
                        param = GL_LINEAR; //GL_LINEAR_MIPMAP_LINEAR
                    
                    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, param);
                    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, param);

//#ifndef NDEBUG
//                    [self displayTexture: textureBufferSelected
//                                   width: newWidth
//                                  height: newHeight];
//#endif
                    glTexImage2D(target, 0,
                                 internalFormat,
                                 newWidth, newHeight, 0,
                                  
                                 format, GL_UNSIGNED_BYTE,
                                 textureBufferSelected);

                    screenXUpL = (newTextureUpLeftCornerX-offset.x)*scaleValue;
                    screenYUpL = (newTextureUpLeftCornerY-offset.y)*scaleValue;
                    screenXDr = screenXUpL + newWidth*scaleValue;
                    screenYDr = screenYUpL + newHeight*scaleValue;
                    
                    NSMutableArray *pArray = [NSMutableArray array];
                    glm::vec2 t = glm::vec2(0,0);   // upper left in world coordinates
                    glm::vec2 p = glm::vec2(screenXUpL, screenYUpL);
                    glm::vec4 v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v
                                                      objCType:@encode(glm::vec4)]];

                    t = glm::vec2(newWidth, 0); // upper right in world coordinates
                    p = glm::vec2(screenXDr, screenYUpL);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

                    t = glm::vec2(0, newHeight);    // lower left in world coordinates
                    p = glm::vec2(screenXUpL, screenYDr);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

                    t = glm::vec2(newWidth, newHeight); // lower right in world coordinates
                    p = glm::vec2(screenXDr, screenYDr);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

                    [curView setShaderProgramOverlay_withMode_TextureLuminosity];
                    renderer_setTextColor(0.0f, 0.0f, 0.0f, 1.0f); // black
                    renderer_drawQuadStrip_xyuv([pArray copy]);
                    
                    glDeleteTextures(1, &textureID);
                    
#ifndef WITH_OPENGL_32
                    glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
                } // if (textureBufferSelected)
            }
                break;
                
            default:
                break;
        } // switch( mode)
    } // if (highlightIfSelected && ROIDrawPlainEdge)
    
#pragma mark draw brush

#ifdef WITH_OPENGL_32
    GLenum target = GL_TEXTURE_RECTANGLE;
#else
    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
    glEnable(target);

    // Make a single memory mapping for all of the textures used by the application:
    glTextureRangeAPPLE(target, textureWidth * textureHeight, textureBuffer);
#endif

    GLuint texID = 0;
    glGenTextures(1, &texID);
    glBindTexture(target, texID);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, textureWidth);
    glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

    // The cached hint specifies to cache texture data in video memory. This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering
#ifndef WITH_OPENGL_32
    glTexParameteri(target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif
    
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
#ifdef WITH_OPENGL_32
    GLint internalFormat = GL_R8;
    GLenum format = GL_RED;
#else
    GLint internalFormat = GL_INTENSITY8;
    GLenum format = GL_LUMINANCE;
#endif
    GLint param;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NOINTERPOLATION"])
        param = GL_NEAREST;
    else
        param = GL_LINEAR;

    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, param); //GL_LINEAR_MIPMAP_LINEAR
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, param); //GL_LINEAR_MIPMAP_LINEAR

//#ifndef NDEBUG
//    [self displayTexture: textureBuffer
//                   width: textureWidth
//                  height: textureHeight];
//#endif

    // textureBuffer bytes are either 0 or 255
    glTexImage2D(target, 0,
                 internalFormat,
                 textureWidth, textureHeight, 0,

                 format, GL_UNSIGNED_BYTE,
                 textureBuffer);

    screenXUpL = (textureUpLeftCornerX-offset.x)*scaleValue;
    screenYUpL = (textureUpLeftCornerY-offset.y)*scaleValue;
    screenXDr = screenXUpL + textureWidth*scaleValue;
    screenYDr = screenYUpL + textureHeight*scaleValue;
    
    NSMutableArray *pArray = [NSMutableArray array];

    // upper left
    glm::vec2 t = glm::vec2(0, 0);
    glm::vec2 p = glm::vec2(screenXUpL, screenYUpL);
    glm::vec4 v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    // upper right
    t = glm::vec2(textureWidth, 0);
    p = glm::vec2(screenXDr, screenYUpL);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    // lower left
    t = glm::vec2(0, textureHeight);
    p = glm::vec2(screenXUpL, screenYDr);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    // lower right
    t = glm::vec2(textureWidth, textureHeight);
    p = glm::vec2(screenXDr, screenYDr);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    
    [curView setShaderProgramOverlay_withMode_TextureLuminosity];
    renderer_setTextColor(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    renderer_drawQuadStrip_xyuv([pArray copy]); // GL_QUAD_STRIP/GL_TRIANGLE_FAN
     
    // Cleanup
    [curView setShaderProgramOverlay_withMode_Normal]; // Maybe not required (TBC)
    glDeleteTextures(1, &texID);
    
#ifndef WITH_OPENGL_32
    glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
    
#pragma mark highlight (4 points at corner of bounding box)
    
    if (highlightIfSelected && ROIDrawPlainEdge == NO)
    {
        glEnable(GL_POLYGON_SMOOTH);
        
        switch (mode)
        {
            case ROI_drawing:
            case ROI_selected:
            case ROI_selectedModify:
                //if (highlightIfSelected && ROIDrawPlainEdge == NO)
                {
                    const int nPoints = 4;
                    glm::vec2 pA[nPoints];
                    pA[0] = glm::vec2(screenXUpL, screenYUpL);
                    pA[1] = glm::vec2(screenXDr,  screenYUpL);
                    pA[2] = glm::vec2(screenXUpL, screenYDr);
                    pA[3] = glm::vec2(screenXDr,  screenYDr);
                    NSMutableArray *pArray = [NSMutableArray array];

                    for (int i=0; i<nPoints; i++)
                        [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

#ifdef WITH_OPENGL_32
                    [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif

                    // Smaller points for calcium scoring
                    float backingScaleFactor = curView.window.backingScaleFactor;
                    if (_displayCalciumScoring)
                        glPointSize(3.0 * backingScaleFactor);
                    else
                        glPointSize(8.0 * backingScaleFactor);

                    renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue
                    renderer_drawPoints([pArray copy]);
                }
                break;
                
            default:
                break;
        }
    }
    
    // Restore
    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
    
#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = [self lowerRightPoint];
        
        if ([name isEqualToString: @"Unnamed"] == NO &&
            [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        if (ROITEXTNAMEONLY == NO)
        {
            [self computeROIIfNedeed];
            
            float area = [self plainArea];

            if (!_displayCalciumScoring)
            {
                // US Regions (Brush) --->
                BOOL roiInside2DUSRegion = FALSE;
                if ([[self pix] hasUSRegions]) {
                    
                    NSPoint roiPoint1 = NSMakePoint(textureUpLeftCornerX, textureUpLeftCornerY);
                    NSPoint roiPoint2 = NSMakePoint(textureDownRightCornerX, textureDownRightCornerY);
                    
                    //NSLog(@"roi [%i,%i] [%i,%i]", (int)roiPoint1.x, (int)roiPoint1.y, (int)roiPoint2.x, (int)roiPoint2.y);
                    
                    for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                    {
                        if (!roiInside2DUSRegion && [anUsRegion regionSpatialFormat] == 1)
                        {
                            // 2D spatial format
                            int usRegionMinX = [anUsRegion regionLocationMinX0];
                            int usRegionMinY = [anUsRegion regionLocationMinY0];
                            int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                            int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                            
                            //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                            
                            roiInside2DUSRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                                   ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                                   ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                                   ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                        }
                    }
                }

                //if (pixelSpacingX != 0 && pixelSpacingY != 0 )
                if (roiInside2DUSRegion ||
                    ((pixelSpacingX != 0 && pixelSpacingY != 0) && (![[self pix] hasUSRegions])))
                // <--- US Regions (Brush)
                {
                    if (area*pixelSpacingX*pixelSpacingY < 1.)
                        self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2", nil), area*pixelSpacingX*pixelSpacingY* 1000000.0, 0xB5];
                    else if (area*pixelSpacingX*pixelSpacingY/100. < 1.)
                        self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2", nil), area*pixelSpacingX*pixelSpacingY];
                    else
                        self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f cm\u00B2", nil), area*pixelSpacingX*pixelSpacingY/100.];
                }
                else
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2", nil), area];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
                
                if ([self pix].SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
                if (rskewness || rkurtosis)
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), rmin, pixelUnit, rmax, pixelUnit, rskewness, rkurtosis];
                else
                    self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
            }
            else
            {
                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Calcium Score: %0.1f", nil), [self calciumScore]];
                self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Calcium Volume: %0.1f", nil), [self calciumVolume]];
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Calcium Mass: %0.1f", nil), [self calciumMass]];
            }
            
            if ([curView blendingView])
            {
                DCMPix *blendedPix = [[curView blendingView] curDCM];
                ROI *b = [[self copy] autorelease];
                b.pix = blendedPix;
                [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                      : blendedPix.pixelSpacingY
                                      : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                [b computeROIIfNedeed];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                
                if (blendedPix.SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                if (b.skewness || b.kurtosis)
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), b.min, pixelUnit, b.max, pixelUnit, b.skewness, b.kurtosis];
                else
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
            }
        }

        //if (!_displayCalciumScoring)
        [self prepareTextualData:tPt];
    }
}

#pragma mark - tLayerROI (24)

- (void) tLayerROI_drawWithScaleValue:(float)scaleValue
                               offset:(NSPoint)offset
                  highlightIfSelected:(BOOL)highlightIfSelected
                   prepareTextualData:(BOOL)prepareTextualData
{
    NSLog(@"ROI.mm %d, tLayerROI", __LINE__);
    
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    if (layerImage == nil)
        return;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSBitmapImageRep *layerImageRep = (NSBitmapImageRep *)[[layerImage representations] objectAtIndex:0];
    
    NSSize imageSize = NSMakeSize(layerImageRep.pixelsWide, layerImageRep.pixelsHigh); // [layerImage size];
    float imageWidth = imageSize.width;
    float imageHeight = imageSize.height;
                                                    
    glDisable(GL_POLYGON_SMOOTH);
#ifdef WITH_OPENGL_32
    GLenum target = GL_TEXTURE_RECTANGLE;
#else
    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
    glEnable(target);
#endif

//    if (needsLoadTexture)
//    {
//        [self loadLayerImageTexture];
//        if (layerImageWhenSelected)
//            [self loadLayerImageWhenSelectedTexture];
//        needsLoadTexture = NO;
//    }
//
//    if (layerImageWhenSelected && mode==ROI_selected)
//    {
//        if (needsLoadTexture2) [self loadLayerImageWhenSelectedTexture];
//        needsLoadTexture2 = NO;
//        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureName2);
//    }
//    else
    {
        GLuint texName = 0;
        NSUInteger index = [ctxArray indexOfObjectIdenticalTo: currentContext];
        if (index != NSNotFound)
            texName = [[textArray objectAtIndex: index] intValue];
        
        if (!texName)
            texName = [self loadLayerImageTexture];

        glBindTexture(target, texName);
    }
    
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    NSPoint p1 = [[points objectAtIndex:0] point];
    NSPoint p2 = [[points objectAtIndex:1] point];
    NSPoint p3 = [[points objectAtIndex:2] point];
    NSPoint p4 = [[points objectAtIndex:3] point];
    
    p1.x = (p1.x-offset.x)*scaleValue;
    p1.y = (p1.y-offset.y)*scaleValue;
    p2.x = (p2.x-offset.x)*scaleValue;
    p2.y = (p2.y-offset.y)*scaleValue;
    p3.x = (p3.x-offset.x)*scaleValue;
    p3.y = (p3.y-offset.y)*scaleValue;
    p4.x = (p4.x-offset.x)*scaleValue;
    p4.y = (p4.y-offset.y)*scaleValue;
                
    NSMutableArray *pArray = [NSMutableArray array];
    
    glm::vec2 t = glm::vec2(0, 0); // upper left corner
    glm::vec2 p = glm::vec2(p1.x, p1.y);
    glm::vec4 v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    
    t = glm::vec2(imageWidth, 0); // upper right corner
    p = glm::vec2(p2.x, p2.y);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
    
    t = glm::vec2(0, imageHeight); // lower left corner
    p = glm::vec2(p4.x, p4.y);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];
                                                                
    t = glm::vec2(imageWidth, imageHeight); // lower right corner
    p = glm::vec2(p3.x, p3.y);
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v
                                      objCType:@encode(glm::vec4)]];

    [curView setShaderProgramOverlay_withMode_TextureRgba];
    renderer_drawQuadStrip_xyuv([pArray copy]);

    glDisable( GL_BLEND);
#ifndef WITH_OPENGL_32
    glDisable(target);
#endif

#pragma mark 4 points at corner of bounding box

    glEnable(GL_POLYGON_SMOOTH);

    if (mode == ROI_selected && highlightIfSelected)
    {
        const int nPoints = 4;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(p1.x, p1.y);
        pA[1] = glm::vec2(p2.x, p2.y);
        pA[2] = glm::vec2(p3.x, p3.y);
        pA[3] = glm::vec2(p4.x, p4.y);

        NSMutableArray *pPointArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pPointArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];
        
#ifdef WITH_OPENGL_32
        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif

        float backingScaleFactor = curView.window.backingScaleFactor;
        glPointSize(8.0 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue
        renderer_drawPoints([pPointArray copy]);

        // Restore
        renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
    }
    
#pragma mark define textualdata

    if (self.isTextualDataDisplayed &&
        prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
            [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;

        [self prepareTextualData:tPt];
    }

    [pool release];
}

#pragma mark - tAxis (26)

- (void) drawAxisAndArea_withScaleValue: (float)scaleValue
                                 offset: (NSPoint)offset
{
    const int nAreaPoints = 4;

    if ([points count] < nAreaPoints)
        return;

    NSPoint p[nAreaPoints];  // TODO: use glm::vec2
    p[0] = NSMakePoint(([[points objectAtIndex: 0] x] - offset.x) * scaleValue,
                       ([[points objectAtIndex: 0] y] - offset.y) * scaleValue);

    p[1] = NSMakePoint(([[points objectAtIndex: 1] x] - offset.x) * scaleValue,
                       ([[points objectAtIndex: 1] y] - offset.y) * scaleValue);

    p[2] = NSMakePoint(([[points objectAtIndex: 2] x] - offset.x) * scaleValue,
                       ([[points objectAtIndex: 2] y] - offset.y) * scaleValue);

    p[3] = NSMakePoint(([[points objectAtIndex: 3] x] - offset.x) * scaleValue,
                       ([[points objectAtIndex: 3] y] - offset.y) * scaleValue);

    /* Line equation through two points p1-p2
     *
     *  // y = ax+b
     *  float a = (p2.y-p1.y) / (p2.x-p1.x);  // slope
     *  float b = p1.y - a * p1.x;            // y intercept
     *
     *  float y1 = a * point.x + b;
     *  point.x = (y1-b)/a;
     */
    // https://math.stackexchange.com/questions/175896/finding-a-point-along-a-line-a-certain-distance-away-from-another-point

    // Line 1
    // Middle point between 0 and 1
    NSPoint p01 = NSMakePoint((p[1].x + p[0].x)/2,
                              (p[1].y + p[0].y)/2);
    // Middle point between 2 and 3
    NSPoint p23 = NSMakePoint((p[3].x + p[2].x)/2,
                              (p[3].y + p[2].y)/2);
#if 0
    const float lineExtensionAbs = 125.0f; // absolute, pixels
    float a1 = (p23.y-p01.y)/(p23.x-p01.x);
    float b1 = p01.y - a1*p01.x;
    float blueY1 = p01.y-lineExtensionAbs; // FIXME: It is accurate only if 0-1 and 2-3 are horizontal
    float blueY2 = p23.y+lineExtensionAbs;
    float blueX1 = (blueY1-b1)/a1;
    float blueX2 = (blueY2-b1)/a1;
#else
    const float lineExtensionRel = 0.3f; // relative, percent: 0 is the 1st point, 1 is the 2nd point
    float t = 1 + lineExtensionRel;
    float blueX1 = (1-t)*p01.x + t*p23.x;
    float blueY1 = (1-t)*p01.y + t*p23.y;

    t = 0 - lineExtensionRel;
    float blueX2 = (1-t)*p01.x + t*p23.x;
    float blueY2 = (1-t)*p01.y + t*p23.y;
#endif

    // Line 2
    // Middle point between 0 and 3
    NSPoint p03 = NSMakePoint((p[3].x + p[0].x)/2,
                              (p[3].y + p[0].y)/2);
    // Middle point between 2 and 1
    NSPoint p21 = NSMakePoint((p[1].x + p[2].x)/2,
                              (p[1].y + p[2].y)/2);
#if 0
    float a2 = (p21.y-p03.y)/(p21.x-p03.x);
    float b2 = p03.y - a2*p03.x;
    float redX1 = p03.x-lineExtensionAbs;// FIXME: It is accurate only if 0-3 and 2-1 are vertical
    float redX2 = p21.x+lineExtensionAbs;
    float redY1 = a2*redX1 + b2;
    float redY2 = a2*redX2 + b2;
#else
    t = 1 + lineExtensionRel;
    float redX1 = (1-t)*p03.x + t*p21.x;
    float redY1 = (1-t)*p03.y + t*p21.y;

    t = 0 - lineExtensionRel;
    float redX2 = (1-t)*p03.x + t*p21.x;
    float redY2 = (1-t)*p03.y + t*p21.y;
#endif

#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

#pragma mark plot 2 axis

    //if (plotTwoAxis)
    {
        const int nPointsBlue = 2;
        NSPoint axisBlue[nPointsBlue];
#ifndef DEBUG_SHOW_WITHOUT_OVERSHOOT
        axisBlue[0] = NSMakePoint(blueX1, blueY1);
        axisBlue[1] = NSMakePoint(blueX2, blueY2);
#else
        axisBlue[0] = p01;
        axisBlue[1] = p23;
#endif

        {
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPointsBlue; i++) {
                glm::vec2 a(axisBlue[i].x, axisBlue[i].y);
                [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
            }

            renderer_set_rgb(0.0f, 0.0f, 1.0f); // blue
            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
        }
        
        const int nPointsRed = 2;
        NSPoint axisRed[nPointsRed];
#ifndef DEBUG_SHOW_WITHOUT_OVERSHOOT
        axisRed[0] = NSMakePoint(redX1, redY1);
        axisRed[1] = NSMakePoint(redX2, redY2);
#else
        axisRed[0] = p03;
        axisRed[1] = p21;
#endif

        {
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPointsRed; i++) {
                glm::vec2 a(axisRed[i].x, axisRed[i].y);
                [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
            }

            renderer_set_rgb(1.0f, 0.0f, 0.0f); // red
            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
        }
    }

#pragma mark fill area

    //if (fillArea)
    {
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nAreaPoints; i++) {
            glm::vec2 a(p[i].x, p[i].y);
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }

        glEnable(GL_BLEND);
        glDisable(GL_POLYGON_SMOOTH);
#ifndef WITH_OPENGL_32
        glDisable(GL_POINT_SMOOTH);
#endif
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., 0.25f);
        renderer_drawPolygon([pArray copy]);
        
        // no border
        
        /*
         renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., 0.2f);

        glBegin(GL_LINE_LOOP);
        {
            for (int i=0; i<4; i++)
                glVertex2f(p[i].x, p[i].y);
        }
        glEnd();
        */
        glDisable(GL_BLEND);
    } // fill area
}

- (void) tAxis_drawWithScaleValue: (float)scaleValue
                           offset: (NSPoint)offset
              highlightIfSelected: (BOOL)highlightIfSelected
                        thickness: (float)thick
               prepareTextualData: (BOOL)prepareTextualData
{
    float backingScaleFactor = curView.window.backingScaleFactor;
    
    if (mode == ROI_drawing)
        [curView setShaderProgramForLineWidth: 2 * thick * backingScaleFactor];
    else
        [curView setShaderProgramForLineWidth: thick * backingScaleFactor];

    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);

    NSMutableArray *pArray26 = [NSMutableArray array];

    for (long i = 0; i < MIN([points count],4); i++) {
        glm::vec2 pt(([[points objectAtIndex: i] x] - offset.x) * scaleValue,
                     ([[points objectAtIndex: i] y] - offset.y) * scaleValue);
        [pArray26 addObject: [NSValue valueWithBytes:&pt objCType:@encode(glm::vec2)]];
    }

    renderer_drawLine_xy([pArray26 copy], GL_LINE_LOOP);
    
    [self drawAxisAndArea_withScaleValue:scaleValue
                                  offset:offset];
    
    if ([points count] > 3) // Why are we doing this ?
        for (long i=4; i<[points count]; i++)
            [points removeObjectAtIndex: i];

#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
           [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        [self prepareTextualData:tPt];
    }

#pragma mark draw points if selected

    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        NSPoint tempPt = [curView convertPoint: [[curView window] mouseLocationOutsideOfEventStream] fromView: nil];
        tempPt = [curView ConvertFromNSView2GL:tempPt];

        NSMutableArray *arrayPoint2DColor = [NSMutableArray array];
        for (long i = 0; i < [points count]; i++)
        {
            Point_xy_rgb pc;
            if (mode >= ROI_selected && (i == selectedModifyPoint || i == PointUnderMouse))
            {
                pc.c = {1.0f, 0.2f, 0.2f}; // light red
            }
            else if (mode == ROI_drawing &&
                     [[points objectAtIndex: i] isNearToPoint: tempPt
                                                             : scaleValue/(thick*backingScaleFactor)
                                                             : [[curView curDCM] pixelRatio]])
            {
                pc.c = {1.0f, 0.0f, 1.0f}; // magenta
            }
            else
            {
                pc.c = {0.5f, 0.5f, 1.0f}; // light blue
            }
            
            pc.p = {([[points objectAtIndex: i] x] - offset.x) * scaleValue,
                    ([[points objectAtIndex: i] y] - offset.y) * scaleValue};

            [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
        }

        [curView setShaderProgramOverlay_withMode_Point];
#ifndef WITH_OPENGL_32
        NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
        CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif
        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue (not needed here ?)
        renderer_drawPoints_xy_rgb([arrayPoint2DColor copy]);
    } // if tAxis selected

    // Restore
#ifndef WITH_OPENGL_32
    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
#endif
}

#pragma mark - tDynAngle (27)

- (void) tDynAngle_drawWithScaleValue: (float)scaleValue
                               offset: (NSPoint)offset
                  highlightIfSelected: (BOOL)highlightIfSelected
                            thickness: (float)thick
                   prepareTextualData: (BOOL)prepareTextualData
{
#pragma mark draw line strip

    NSMutableArray *arrayPoint2DColor = [NSMutableArray array];
    for (long i = 0; i < MIN([points count],4); i++) {
        Point_xy_rgba pc;
        pc.c.r = color.red / 65535.;
        pc.c.g = color.green / 65535.;
        pc.c.b = color.blue / 65535.;

        // The second and third point are almost transparent so that the line connecting them is barely visible
        if (i==1 || i==2)
            pc.c.a = 0.1f;
        else
            pc.c.a = opacity;
        
        pc.p.x = ([[points objectAtIndex: i] x] - offset.x) * scaleValue;
        pc.p.y = ([[points objectAtIndex: i] y] - offset.y) * scaleValue;
        
        [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc
                                                     objCType:@encode(Point_xy_rgba)]];
    }

    float backingScaleFactor = curView.window.backingScaleFactor;
    if (mode == ROI_drawing)
        [curView setShaderProgramForLineWidth: 2 * thick * backingScaleFactor];
    else
        [curView setShaderProgramForLineWidth: thick * backingScaleFactor];
    
#ifndef WITH_OPENGL_32
    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);  // redundant ?
#endif
    renderer_drawLineStrip_xy_rgba([arrayPoint2DColor copy]);
    
#pragma mark calculate angle values to be printed

//    [curView setShaderProgramOverlay];

    if ([points count] > 3)
        for (long i=4; i<[points count]; i++ )
            [points removeObjectAtIndex: i];
    
    float angle=0;

    if ([points count] > 3)
    {
        NSPoint a1 = [[points objectAtIndex: 0] point];
        NSPoint a2 = [[points objectAtIndex: 1] point];
        NSPoint b1 = [[points objectAtIndex: 2] point];
        NSPoint b2 = [[points objectAtIndex: 3] point];
        
        if (pixelSpacingX != 0 && pixelSpacingY != 0)
        {
            a1 = NSMakePoint(a1.x * pixelSpacingX, a1.y * pixelSpacingY);
            a2 = NSMakePoint(a2.x * pixelSpacingX, a2.y * pixelSpacingY);
            b1 = NSMakePoint(b1.x * pixelSpacingX, b1.y * pixelSpacingY);
            b2 = NSMakePoint(b2.x * pixelSpacingX, b2.y * pixelSpacingY);
        }
        
        angle = [self angleBetween2Lines: a1 :a2 :b1 :b2];
        
        if (angle < -180)
            angle = -180 - angle;
        else if (angle < -90)
            angle += 180;
        else if (angle < 0)
            angle *= -1;
        
        if (angle > 270)
            angle = 360 - angle;
        else if (angle > 180)
            angle -= 180;
        else if (angle > 90)
            angle = 180 - angle;
    }
    
#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if (![name isEqualToString:@"Unnamed"] &&
            ![name isEqualToString: NSLocalizedString( @"Unnamed", nil)])
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Angle: %0.2f%@", nil), angle, @"\u00B0"];
        self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Angle 2: %0.2f%@", nil), 360 - angle, @"\u00B0"];
        self.textualBoxLine4 = nil;
        self.textualBoxLine5 = nil;
        
        [self prepareTextualData:tPt];
    }

#pragma mark selection (points)
    
    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        NSPoint tempPt = [curView convertPoint: [[curView window] mouseLocationOutsideOfEventStream] fromView: nil];
        tempPt = [curView ConvertFromNSView2GL:tempPt];

        [curView setShaderProgramOverlay_withMode_Point];
#ifndef WITH_OPENGL_32
        NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
        CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif
        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue (redundant ?)

        NSMutableArray *pArray = [NSMutableArray array];
        
        for (long i = 0; i < [points count]; i++) {
            Point_xy_rgb pc;
            if (mode >= ROI_selected && (i == selectedModifyPoint || i == PointUnderMouse))
            {
                pc.c = glm::vec3(1.0f, 0.2f, 0.2f);
            }
            else if (mode == ROI_drawing &&
                     [[points objectAtIndex: i] isNearToPoint:tempPt
                                                             :scaleValue/(thick*backingScaleFactor)
                                                             :[[curView curDCM] pixelRatio]])
            {
                pc.c = glm::vec3(1.0f, 0.0f, 1.0f);
            }
            else
            {
                pc.c = glm::vec3(0.5f, 0.5f, 1.0f);
            }

            pc.p.x = ([[points objectAtIndex: i] x] - offset.x) * scaleValue;
            pc.p.y = ([[points objectAtIndex: i] y] - offset.y) * scaleValue;
            [pArray addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
        }
        
        renderer_drawPoints_xy_rgb([pArray copy]);
    }

    // Restore
#ifndef WITH_OPENGL_32
    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
#endif
}

#pragma mark - tTAGT (29)

- (void) tTAGT_draw_withScaleValue:(float)scaleValue
                            offset:(NSPoint)offset
               highlightIfSelected:(BOOL)highlightIfSelected
                         thickness:(float)thick
                prepareTextualData:(BOOL)prepareTextualData
{
    if ([points count] != 2 &&
        [points count] != 6)
        return;

    //NSLog(@"ROI.mm %d, tTAGT", __LINE__);

    // Proceed only if we have either 2 or 6 points

    [self valid];

    float backingScaleFactor = curView.window.backingScaleFactor;

    // Main line (A)
    
    NSMutableArray *pArray = [NSMutableArray array];

    glm::vec2 pA[2];
    pA[0] = glm::vec2(([[points objectAtIndex: 0] x] - offset.x) * scaleValue,
                      ([[points objectAtIndex: 0] y] - offset.y) * scaleValue);

    pA[1] = glm::vec2(([[points objectAtIndex: 1] x] - offset.x) * scaleValue,
                      ([[points objectAtIndex: 1] y] - offset.y) * scaleValue);

    for (int i=0; i<2; i++)
        [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];
    
    if ([points count] == 6)
    {
        // Secondary line (C)
        glm::vec2 pC[2];
        pC[0] = glm::vec2(([[points objectAtIndex: 2] x] - offset.x) * scaleValue,
                          ([[points objectAtIndex: 2] y] - offset.y) * scaleValue);

        pC[1] = glm::vec2(([[points objectAtIndex: 3] x] - offset.x) * scaleValue,
                          ([[points objectAtIndex: 3] y] - offset.y) * scaleValue);
        
        for (int i=0; i<2; i++)
            [pArray addObject: [NSValue valueWithBytes:&pC[i] objCType:@encode(glm::vec2)]];

        // Another Secondary line (B)
        glm::vec2 pB[2];
        pB[0] = glm::vec2(([[points objectAtIndex: 4] x] - offset.x) * scaleValue,
                          ([[points objectAtIndex: 4] y] - offset.y) * scaleValue);

        pB[1] = glm::vec2(([[points objectAtIndex: 5] x] - offset.x) * scaleValue,
                          ([[points objectAtIndex: 5] y] - offset.y) * scaleValue);
        
        for (int i=0; i<2; i++)
            [pArray addObject: [NSValue valueWithBytes:&pB[i] objCType:@encode(glm::vec2)]];
    }

    [curView setShaderProgramForLineWidth: thick * backingScaleFactor];
    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);
    renderer_drawLine_xy([pArray copy], GL_LINES); // A,B,C lines
    
    [curView setShaderProgramOverlay];

#pragma mark define textualdata

    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
           [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        float lCm = 0;
        if ([points count] == 6)
        {
            lCm = [self MeasureLength: nil
                              pointA: [[points objectAtIndex: 4] point]
                              pointB: [[points objectAtIndex: 5] point]];
            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"B: %@", nil), [ROI formattedLength: lCm]];
        }
        
        lCm = [self MeasureLength: nil
                          pointA: [[points objectAtIndex: 0] point]
                          pointB: [[points objectAtIndex: 1] point]];
        self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"A: %@", nil), [ROI formattedLength: lCm]];
        
        if ([points count] == 6)
        {
            lCm = [self MeasureLength: nil
                              pointA: [[points objectAtIndex: 2] point]
                              pointB: [[points objectAtIndex: 3] point]];
            self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"C: %@", nil), [ROI formattedLength: lCm]];
            
            lCm = [self MeasureLength: nil
                              pointA: [[points objectAtIndex: 4] point]
                              pointB: [[points objectAtIndex: 2] point]];
            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"B-C: %@", nil), [ROI formattedLength: lCm]];
        }
        
        [self prepareTextualData:tPt];
    }

#pragma mark draw points: highlight, selected
    
#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        NSPoint tempPt = [curView convertPoint: [[curView window] mouseLocationOutsideOfEventStream] fromView: nil];
        tempPt = [curView ConvertFromNSView2GL:tempPt];
        
        NSMutableArray *pArray = [NSMutableArray array];
        
        for (long i = 0; i < [points count]; i++) {
            if (i == 0 || i == 2)
                continue;
            
            Point_xy_rgb pc;
            if (mode >= ROI_selected &&
                (i == selectedModifyPoint || i == PointUnderMouse))
            {
                pc.c = {1.0f, 0.2f, 0.2f}; // light red
            }
            else if (mode == ROI_drawing &&
                    [[points objectAtIndex: i] isNearToPoint: tempPt
                                                            : scaleValue/(thick*backingScaleFactor)
                                                            : [[curView curDCM] pixelRatio]])
            {
                pc.c = {1.0f, 0.0f, 1.0f}; // magenta
            }
            else
            {
                pc.c = {0.5f, 0.5f, 1.0f}; // light blue
            }
            
            pc.p = {([[points objectAtIndex: i] x] - offset.x) * scaleValue,
                    ([[points objectAtIndex: i] y] - offset.y) * scaleValue};

            [pArray addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
        }

        [curView setShaderProgramOverlay_withMode_Point];
        glPointSize(thick*2 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue (redundant ?)
        renderer_drawPoints_xy_rgb([pArray copy]);
    }

    // Clean up (unnecessary ?)
    [curView setShaderProgramForLineWidth: 1.0 * backingScaleFactor];
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white (redundant ?)
    [curView setShaderProgramOverlay];
    
#pragma mark labels

    if (stanStringAttrib == nil)
    {
        stanStringAttrib = [[NSMutableDictionary dictionary] retain];
        [stanStringAttrib setObject:[NSFont fontWithName:@"Helvetica" size: 14.0] forKey:NSFontAttributeName];
        [stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    }
    
    if (stringTexA == nil) // generate the texture only once
    {
        stringTexA = [[StringTexture alloc] initWithString: @"A"
                                            withAttributes:stanStringAttrib
                                             withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                              withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                           withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
        [stringTexA setAntiAliasing: YES];
        [stringTexA genTextureWithBackingScaleFactor: curView.window.backingScaleFactor];
    }

    if (stringTexB == nil)
    {
        stringTexB = [[StringTexture alloc] initWithString: @"B"
                                            withAttributes:stanStringAttrib
                                             withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                              withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                           withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
        [stringTexB setAntiAliasing: YES];
        [stringTexB genTextureWithBackingScaleFactor: curView.window.backingScaleFactor];
    }

    if (stringTexC == nil)
    {
        stringTexC = [[StringTexture alloc] initWithString: @"C"
                                            withAttributes:stanStringAttrib
                                             withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                              withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                           withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
        [stringTexC setAntiAliasing: YES];
        [stringTexC genTextureWithBackingScaleFactor: curView.window.backingScaleFactor];
    }
    
#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_TextureRgba];
#else
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
#endif

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    // Show a label every second point
    for (int i = 0; i < [points count]; i += 2)
    {
        [stringTexA setFlippedX: [curView xFlipped] Y:[curView yFlipped]];
        [stringTexB setFlippedX: [curView xFlipped] Y:[curView yFlipped]];
        [stringTexC setFlippedX: [curView xFlipped] Y:[curView yFlipped]];
        
        StringTexture *tex = nil;
        if (i == 0) tex = stringTexA;
        if (i == 2) tex = stringTexC;
        if (i == 4) tex = stringTexB;
        
        NSPoint tPt = [[points objectAtIndex: i+1] point];
        
        // Label shadow offset by 1 pixel
        //renderer_set_rgba(0.0f, 0.0f, 0.0f, 1.0f); // black
        renderer_setTextColor(0.0f, 0.0f, 0.0f, 1.0f); // black
        [tex drawAtPoint:NSMakePoint((tPt.x + 1./scaleValue - offset.x) * scaleValue,
                                     (tPt.y + 1./scaleValue - offset.y) * scaleValue)
                   ratio: 1];
        
        // Label foreground
        //renderer_set_rgba(1.0f, 1.0f, 0.0f, 1.0f); // yellow
        renderer_setTextColor(1.0f, 1.0f, 0.0f, 1.0f); // yellow
        [tex drawAtPoint:NSMakePoint((tPt.x - offset.x) * scaleValue,
                                     (tPt.y - offset.y) * scaleValue)
                   ratio: 1];
    }

    // Cleanup
#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_Normal];
#else
    glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
}

#pragma mark - tBall (30)

- (void) tBall_draw_withScaleValue:(float)scaleValue
                            offset:(NSPoint)offset
               highlightIfSelected:(BOOL)highlightIfSelected
                         thickness:(float)thick
                prepareTextualData:(BOOL)prepareTextualData
{
    float angle;
    
    float backingScaleFactor = curView.window.backingScaleFactor;

    NSRect rrect = rect;
    
    if (rrect.size.height < 0)
        rrect.size.height = -rrect.size.height;
    
    if (rrect.size.width < 0)
        rrect.size.width = -rrect.size.width;
    
    int resol = (rrect.size.height + rrect.size.width) * 1.5 * scaleValue;
    
#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::mat4(1.0);
    M = glm::translate(M, glm::vec3((rrect.origin.x - offset.x) * scaleValue,
                                    (rrect.origin.y - offset.y) * scaleValue,
                                    0.0f));
    M = glm::rotate(M, glm::radians(roiRotationDeg), glm::vec3(0,0,1));
    #endif // WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];

    glPushMatrix();
    glTranslatef((rrect.origin.x - offset.x) * scaleValue,
                 (rrect.origin.y - offset.y) * scaleValue,
                 0.0f);
    glRotatef(roiRotationDeg, 0, 0, 1.0f);
#endif
    
    NSRect r = rrect;
    r.size.width *= scaleValue;
    r.size.height *= scaleValue;
    
    double dZ = (curView.curDCM.originZ-_pix.originZ) * scaleValue * _pix.sliceInterval;
    float radius = r.size.width/2.0;
    
    if (curView.curDCM == _pix) // The ROI was placed on this image: normal size
    {
        //NSLog(@"ROI.m:%i %@, on this pix", __LINE__, name);
    }
    else if (fabs(dZ) > radius)    // Too far: not visible
    {
        //NSLog(@"ROI.m:%i %@, too far, dz:%.2f, radius:%.2f", __LINE__, name, dZ, radius);
        //break;
        return;
    }
    else                        // Scale the radius by the distance of the two images
    {
        double a = asin(dZ/radius);
        r.size.width *= cos(a);
        r.size.height *= cos(a);
        //NSLog(@"ROI.m:%i %@, dz:%.2f, a:%f", __LINE__, name, dZ, glm::degrees(a));
    }

    NSMutableArray *pArray = [NSMutableArray array];
    for (int i = 0; i < resol ; i++ ) {
        angle = i * 2 * M_PI /resol;
        glm::vec2 pA = glm::vec2(r.size.width*cos(angle), r.size.height*sin(angle));
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
        // Apply local model transformation
        glm::vec4 pB = M*glm::vec4(pA,0,1);
        pA = glm::vec2(pB.x, pB.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&pA objCType:@encode(glm::vec2)]];
    }

#ifdef WITH_OPENGL_32
    [curView setShaderProgramForLineWidth: 1.0]; // It's filled anyway
#else
    [curView setShaderProgramForLineWidth: thick*backingScaleFactor];
#endif
    renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity/2.);
    renderer_drawPolygon([pArray copy]); // was GL_TRIANGLE_FAN

    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"drawROICircleCenter"]) {
        glm::vec2 a(0, 0);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
        glm::vec4 pB = M*glm::vec4(a,0,1);
        a = glm::vec2(pB.x, pB.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
    }

#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
    glPointSize(thick * backingScaleFactor);
    renderer_set_rgba(color.red / 65535.,
                      color.green / 65535.,
                      color.blue / 65535.,
                      opacity);
    renderer_drawPoints([pArray copy]);

    // TODO: draw the pink circle
#if 0
    NSColor *colorPeak = nil;
    //NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"peakValueColor"];
    NSData *colorData = [[NSUserDefaults standardUserDefaults] dataForKey:@"peakValueColor"];
    if (colorData != nil)
        colorPeak = (NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData];

    NSLog(@"%f %f %f", [colorPeak redComponent], [colorPeak greenComponent], [colorPeak blueComponent]);
#endif

#pragma mark draw points: highlight, selected

    if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
    {
        glm::vec2 boundingPoint[5]; // bounding rect corners and center

        boundingPoint[0] = glm::vec2( -r.size.width, -r.size.height);
        boundingPoint[1] = glm::vec2( -r.size.width,  r.size.height);
        boundingPoint[2] = glm::vec2(  r.size.width,  r.size.height);
        boundingPoint[3] = glm::vec2(  r.size.width, -r.size.height);
        
        //Center
        boundingPoint[4] = glm::vec2( 0, 0);
        NSMutableArray *pPointArray = [NSMutableArray array];
        
        for (int i=0; i<5; i++) {
            glm::vec2 a(boundingPoint[i].x, boundingPoint[i].y);
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ROI2
            glm::vec4 pB = M*glm::vec4(a,0,1);
            a = glm::vec2(pB.x, pB.y);
            #endif
            [pPointArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }
        
#ifdef WITH_OPENGL_32
        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue
        renderer_drawPoints([pPointArray copy]);
    }
    
    // Restore (unnecessary ?)
#ifndef WITH_OPENGL_32
    [curView setShaderProgramForLineWidth: 1.0*backingScaleFactor];
#endif
    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white

#ifndef WITH_OPENGL_32
    glTranslatef(-NSMaxX(rrect), -NSMaxY(rrect), 0.0f); // what's the point ?
    glPopMatrix();
#endif
    
#pragma mark define textualdata
    
    if (self.isTextualDataDisplayed && prepareTextualData)
    {
        NSPoint tPt = self.lowerRightPoint;
        
        if ([name isEqualToString:@"Unnamed"] == NO &&
           [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
        {
            self.textualBoxLine1 = name;
        }
        else
            self.textualBoxLine1 = nil;
        
        if (ROITEXTNAMEONLY == NO )
        {
            [self computeROIIfNedeed];
            
            // US Regions (Oval) --->
            BOOL roiInside2DUSRegion = FALSE;
            if ([[self pix] hasUSRegions])
            {
                NSPoint roiPoint1 = NSMakePoint(rrect.origin.x-rrect.size.width, rrect.origin.y-rrect.size.height);
                NSPoint roiPoint2 = NSMakePoint(rrect.origin.x+rrect.size.width, rrect.origin.y+rrect.size.height);
                
                //NSLog(@"roi [%i,%i] [%i,%i]", (int)roiPoint1.x, (int)roiPoint1.y, (int)roiPoint2.x, (int)roiPoint2.y);
                
                for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                {
                    if (!roiInside2DUSRegion && [anUsRegion regionSpatialFormat] == 1) {
                        // 2D spatial format
                        int usRegionMinX = [anUsRegion regionLocationMinX0];
                        int usRegionMinY = [anUsRegion regionLocationMinY0];
                        int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                        int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                        
                        //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                        
                        roiInside2DUSRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                               ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                               ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                               ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                    }
                }
            }
            
            if (roiInside2DUSRegion || (pixelSpacingX != 0 && pixelSpacingY != 0 && ![[self pix] hasUSRegions]))
                // <--- US Regions (Oval)
            {
                float area = [self EllipseArea];
                if (area*pixelSpacingX*pixelSpacingY < 1.)
                {
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2 (W: %0.1f %cm H: %0.1f %cm)", @"W = Width, H = Height"), area*pixelSpacingX*pixelSpacingY* 1000000.0, 0xB5, 2.0*fabs(NSWidth(rect))*pixelSpacingX*10000.0, 0xB5, 2.0*fabs(NSHeight(rect))*pixelSpacingY*10000.0, 0xB5];
                }
                else if (area*pixelSpacingX*pixelSpacingY/100. < 1.)
                {
                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2 (W: %0.3f mm H: %0.3f mm)", @"W = Width, H = Height"), area*pixelSpacingX*pixelSpacingY, 2.0*fabs(NSWidth(rect))*pixelSpacingX, 2.0*fabs(NSHeight(rect))*pixelSpacingY];
                }
                else
                {
                    float r = rect.size.width*pixelSpacingX/10.;
#if 1
                    float v = M_PI * powf(r,3) * 4. / 3.;
#else
                    float v = [self ballVolume] * pixelSpacingX * pixelSpacingY * self.pix.sliceInterval / 1000.; // @@@ TBC
#endif
                    self.textualBoxLine2 = [NSString stringWithFormat:@"Volume: %0.3f cm\u00B3 (\u2300: %0.3f cm)", v, 2.0*r];
                }
            }
            else
            {
                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2 (W: %0.3f pix H: %0.3f pix)", @"W = Width, H = Height"), [self EllipseArea], 2.0*fabs(NSWidth(rect)), 2.0*fabs(NSHeight(rect))];
            }
            
            NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
            
            if ([self pix].SUVConverted)
                pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
            
            self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
            
            if (rskewness || rkurtosis)
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), rmin, pixelUnit, rmax, pixelUnit, rskewness, rkurtosis];
            else
            {
                self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
            }
            
            self.textualBoxLine5 = [NSString stringWithFormat:@"Peak: (\u2300: cm)"];   // TODO: calculate
            
            if ([curView blendingView])
            {
                DCMPix *blendedPix = [[curView blendingView] curDCM];
                ROI *b = [[self copy] autorelease];
                b.pix = blendedPix;
                b.curView = curView.blendingView;
                [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                      : blendedPix.pixelSpacingY
                                      : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                [b computeROIIfNedeed];
                
                NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                
                if (blendedPix.SUVConverted)
                    pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                
                self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                
                if (b.skewness || b.kurtosis)
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), b.min, pixelUnit, b.max, pixelUnit, b.skewness, b.kurtosis];
                else
                    self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
            }
        }
        
        [self prepareTextualData:tPt];
    }
}

#pragma mark - tOvalAngle (31)
static const CGFloat armScale = 1.2f; // tOvalAngle looks like a clock :-)

#pragma mark -

- (void) setOriginalIndexForAlias:(int)i
{
    originalIndexForAlias = i;
    [self recompute];
}

- (void) setROIRect:(NSRect)r
{
    [self recompute];
    rect = r;
}

- (NSMutableArray *) roiList
{
    if ([self.curView.curRoiList containsObject: self])
        return self.curView.curRoiList;
    
    for (NSMutableArray *a in self.curView.dcmRoiList)
    {
        if ([a containsObject: self])
            return a;
    }
    
    NSLog( @"----- roiListForROI didn't find the container array");
    
    return nil;
}

+ (void) deleteROIs: (NSArray*) array
{
    if (array.count == 0)
        return;
    
    NSMutableArray *roisToAdd = [NSMutableArray array];
    // Add parent ROIs
    for (ROI* r in array)
    {
        if (r.parentROI)
        {
            if ([array containsObject: r.parentROI] == NO)
                [roisToAdd addObject: r.parentROI];
        }
    }
    
    // Add ROIs of same group ID
    for (ROI* r in array)
    {
        if (r.groupID != 0)
        {
            if (r.curView == nil)
                NSLog( @"----- deleteROIs : r.curView == nil");
            
            for (ROI *b in r.roiList)
            {
                if (b.groupID == r.groupID)
                {
                    if ([array containsObject: b] == NO)
                        [roisToAdd addObject: b];
                }
            }
        }
    }
    
    array = [array arrayByAddingObjectsFromArray: roisToAdd];
    
    // Delete ROIs
    for (ROI* r in array)
    {
        [r retain];
        
        if (r.locked)
            NSLog( @"---- ROI is locked : cannot delete");
        else
        {
            if ([NSThread isMainThread])
                [[NSNotificationCenter defaultCenter] postNotificationName: OsirixRemoveROINotification object: r userInfo: nil];
            
            @try
            {
                if (r.curView == nil)
                    NSLog( @"----- deleteROIs : r.curView == nil");
                
                else if (r.curView.dcmRoiList == nil) // For subclasses
                    [r.curView.curRoiList removeObject: r];
                
                else
                {
                    // 4D Data?
                    if (r.curView.is2DViewer)
                    {
                        ViewerController *v = r.curView.windowController;
                
                        for (int i = 0; i < v.maxMovieIndex; i++)
                        {
                            // Aliases & 3D ROI : the same ROI object can be contained in several images !
                            for (NSMutableArray *roiList4 in [v roiList: i])
                                [roiList4 removeObject: r];
                        }
                    }
                    else
                    {
                        // Aliases & 3D ROI : the same ROI object can be contained in several images !
                        for (NSMutableArray *roiList5 in r.curView.dcmRoiList)
                            [roiList5 removeObject: r];
                    }
                }
            }
            @catch (NSException * e)
            {
                N2LogException( e);
            }
        }
        [r autorelease];
    }
    
    if ([NSThread isMainThread])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIRemovedFromArrayNotification
                                                            object: NULL
                                                          userInfo: NULL];

        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdateViewNotification
                                                            object: nil
                                                          userInfo: nil];
    }
}

+ (void) deleteROI: (ROI*) r
{
    [ROI deleteROIs: [NSArray arrayWithObject: r]];
}

- (BOOL) isInside: (int*) pixelCoordinates
{
    return [self isInside: pixelCoordinates :0];
}

- (BOOL) isInside: (int*) pixelCoordinates :(float) sliceInterval
{
    switch( type)
    {
        case tClosedPolygon:
        case tOpenPolygon:
        case tPencil:
        {
            if (cachedNSPoint == nil)
            {
                NSArray *ptsArray = [self splinePoints];
                
                cachedNSPointSize = ptsArray.count;
                cachedNSPoint = (NSPoint *)malloc( cachedNSPointSize * sizeof(NSPoint));
                
                NSPoint *ptr = cachedNSPoint;
                for (MyPoint *p in ptsArray)
                {
                    *ptr = p.point;
                    ptr++;
                }
            }
            
            return [DCMPix IsPoint: NSMakePoint( pixelCoordinates[ 0], pixelCoordinates[ 1])
                         inPolygon: cachedNSPoint
                              size: cachedNSPointSize];
        }
            break;
            
//        case tPlain:
//            break;
            
        default:
            break;
    }
    return NO;
}

- (unsigned char*) getMapSize:(NSSize*) size origin:(NSPoint*) ROIorigin
{
    return [self getMapSize: size origin: ROIorigin minimum:-FLT_MAX maximum:FLT_MAX dcmPix: nil];
}

- (unsigned char*) getMapSize:(NSSize*) size origin:(NSPoint*) ROIorigin minimum: (float) minimum maximum : (float) maximum dcmPix: (DCMPix*) inPix
{
    unsigned char *map = nil;
    float *tempImage = nil;
    
    if (self.type == tOval ||
        self.type == tOvalAngle ||
        self.type == tROI)
    {
        ROI *roi = [[self copy] autorelease];
        NSMutableArray *pts = roi.points;
        
        if (roi.type == tROI)
            roi.isSpline = NO;
        
        roi.type = tClosedPolygon;
        roi.points = pts;
        
        return [roi getMapSize: size origin: ROIorigin minimum: minimum maximum: maximum dcmPix: inPix];
    }
    
    if (self.type == tClosedPolygon ||
        self.type == tOpenPolygon ||
        self.type == tPencil)
    {
        NSArray *ptsTemp = [self points];
        
        int no = ptsTemp.count;
        NSPointInt *ptsInt = (struct NSPointInt*) malloc( no * sizeof(struct NSPointInt));
        
        if (ptsInt)
        {
            if (no == 0)
                N2LogStackTrace( @"no == 0");
            
            int minX = 0, maxX = 0, minY = 0, maxY = 0;
            
            for (int i = 0; i < no; i++)
            {
                ptsInt[ i].x = round( [[ptsTemp objectAtIndex: i] point].x-0.9);
                ptsInt[ i].y = round( [[ptsTemp objectAtIndex: i] point].y-0.9);
            }
            
            // Need to clip?
            BOOL clip = NO;
            
            for (int i = 0; i < no && clip == NO; i++)
            {
                if (ptsInt[ i].x < 0) clip = YES;
                if (ptsInt[ i].y < 0) clip = YES;
                if (ptsInt[ i].x >= inPix.pwidth) clip = YES;
                if (ptsInt[ i].y >= inPix.pheight) clip = YES;
            }
            
            if (clip)
            {
                long newNo = 0;
                
                NSPointInt *pTemp = (NSPointInt*) malloc( sizeof(NSPointInt) * 4 * no);
                if (pTemp)
                {
                    CLIP_Polygon( ptsInt, no, pTemp, &newNo, NSZeroPoint, NSMakePoint( inPix.pwidth, inPix.pheight));
                    
                    free( ptsInt);
                    ptsInt = pTemp;
                    no = newNo;
                }
                else
                    no = 0;
            }
            
            for (int i = 0; i < no; i++)
            {
                if (i == 0)
                {
                    minX = ptsInt[ 0].x;
                    maxX = ptsInt[ 0].x;
                    minY = ptsInt[ 0].y;
                    maxY = ptsInt[ 0].y;
                }
                else
                {
                    if (ptsInt[ i].x < minX) minX = ptsInt[ i].x;
                    if (ptsInt[ i].x > maxX) maxX = ptsInt[ i].x;
                    if (ptsInt[ i].y < minY) minY = ptsInt[ i].y;
                    if (ptsInt[ i].y > maxY) maxY = ptsInt[ i].y;
                }
            }
            
            for (int i = 0; i < no; i++)
            {
                ptsInt[ i].x -= minX;
                ptsInt[ i].y -= minY;
            }
            
            if (no >= 3)
            {
                size->width = maxX-minX+2;
                size->height = maxY-minY+2;
                
                ROIorigin->x = minX;
                ROIorigin->y = minY;
                
                tempImage = (float *)calloc( 1, (5 + size->height) * (5+size->width) * sizeof(float));
                
                // Copy the original data
                if (inPix && (minimum != -FLT_MAX || maximum != FLT_MAX))
                {
                    int cminX = minX, cminY = minY, cmaxX = maxX+2, cmaxY = maxY+2;
                    
                    if (cminX < 0)
                        cminX = 0;
                    if (cminX >= inPix.pwidth)
                        cminX = inPix.pwidth-1;
                    if (cmaxX < 0)
                        cmaxX = 0;
                    if (cmaxX >= inPix.pwidth)
                        cmaxX = inPix.pwidth-1;
                    if (cminY < 0)
                        cminY = 0;
                    if (cminY >= inPix.pheight)
                        cminY = inPix.pheight-1;
                    if (cmaxY < 0)
                        cmaxY = 0;
                    if (cmaxY >= inPix.pheight)
                        cmaxY = inPix.pheight-1;
                    
                    long linewidth = cmaxX-cminX, lineheight = cmaxY-cminY, fullline = size->width;
                    float *src = inPix.fImage;
                    for (int y = 0; y < lineheight; y++)
                        memcpy( tempImage + y * fullline, src + minX + (minY+y)*inPix.pwidth, linewidth * sizeof( float));
                }
                
                map = (unsigned char *)calloc( 1, (5 + size->height) * (5+size->width));
                
                if (map && tempImage)
                {
                    // Need to clip?
                    int yIm = size->height;
                    int xIm = size->width;
                    
                    if (no > 1)
                    {
                        BOOL restore = NO, addition = NO, outside = NO;
                        
                        ras_FillPolygon( ptsInt, no, tempImage, size->width, size->height, 1, minimum, maximum, outside, FLT_MAX, addition, NO, NO, nil, nil, nil, nil, nil, 0, 2, 0, restore, nil, nil);
                    }
                    
                    // Convert float to char
                    int i = yIm * xIm;
                    while ( i-- > 0)
                    {
                        if (tempImage[ i] == FLT_MAX)
                            map[ i] = 255;
                    }

                    // Keep a free box around the image
                    for (int i = 0; i < xIm; i++) {
                        map[ i] = 0;
                        map[ (yIm-1)*xIm +i] = 0;
                    }
                    
                    for (int i = 0; i < yIm; i++) {
                        map[ i*xIm] = 0;
                        map[ i*xIm + xIm-1] = 0;
                    }
                    
                    free( tempImage);
                }
            }
            free( ptsInt);
        }
    }
    
    return map;
}

- (ROI*) getBrushROI
{
    return [self getBrushROIwithMinimum: -FLT_MAX maximum: FLT_MAX dcmPix: nil];
}

- (ROI*) getBrushROIwithMinimum: (float) minimum maximum : (float) maximum dcmPix: (DCMPix*) inPix
{
    NSSize s = NSZeroSize;
    NSPoint o = NSZeroPoint;
    
    unsigned char* texture = [self getMapSize: &s origin: &o minimum: minimum maximum: maximum dcmPix: inPix];
    
    if (texture)
    {
        ROI *theNewROI = [[[ROI alloc] initWithTexture: texture
                                             textWidth: s.width
                                            textHeight: s.height
                                              textName: @""
                                             positionX: o.x
                                             positionY: o.y
                                              spacingX: [self.curView.curDCM pixelSpacingX]
                                              spacingY: [self.curView.curDCM pixelSpacingY]
                                           imageOrigin: NSMakePoint([self.curView.curDCM originX], [self.curView.curDCM originY])] autorelease];
        
        free( texture);
        
        theNewROI.pix = curView.curDCM;
        theNewROI.curView = curView;
        
        RGBColor c;
        c.red = [[NSUserDefaults standardUserDefaults] floatForKey: @"isoContourColorR"] * 65535.0;
        c.green = [[NSUserDefaults standardUserDefaults] floatForKey: @"isoContourColorG"] * 65535.0;
        c.blue = [[NSUserDefaults standardUserDefaults] floatForKey: @"isoContourColorB"] * 65535.0;
        
        [theNewROI setColor: c globally: NO];
        [theNewROI setOpacity: [[NSUserDefaults standardUserDefaults] floatForKey: @"isoContourColorA"]];
        
        if ([theNewROI reduceTextureIfPossible] == NO)	// NO means that the ROI is NOT empty
            return theNewROI;
    }
    
    return nil;
}

+ (BOOL) isPolygonRectangle: (NSArray*) pts
                      width: (double*) w
                     height: (double*) h
                     center: (NSPoint*) c
{
    if (pts.count != 4)
        return NO;
    
    NSPoint p1 = [[pts objectAtIndex: 0] point];
    NSPoint p2 = [[pts objectAtIndex: 1] point];
    NSPoint p3 = [[pts objectAtIndex: 2] point];
    NSPoint p4 = [[pts objectAtIndex: 3] point];
    
    double side1 = sqrt( pow( p1.x-p2.x, 2) + pow( p1.y-p2.y, 2));
    double side2 = sqrt( pow( p3.x-p2.x, 2) + pow( p3.y-p2.y, 2));
    double side3 = sqrt( pow( p3.x-p4.x, 2) + pow( p3.y-p4.y, 2));
    double side4 = sqrt( pow( p4.x-p1.x, 2) + pow( p4.y-p1.y, 2));
    
    if (fabs( side1 - side3) > 0.01)
        return NO;
    
    if (fabs( side2 - side4) > 0.01)
        return NO;
    
    double diag1 = sqrt( pow( p1.x-p3.x, 2) + pow( p1.y-p3.y, 2));
    double diag2 = sqrt( pow( p2.x-p4.x, 2) + pow( p2.y-p4.y, 2));
    
    if (fabs( diag1 - diag2) > 0.01)
        return NO;
    
    if (w && h && c)
    {
        if (fabs( p1.y - p2.y) - fabs( p1.x - p2.x) > fabs( p2.y - p3.y) - fabs( p2.x - p3.x))
        {
            *w = side2;  *h = side1;
        }
        else
        {
            *w = side1; *h = side2;
        }
        
        c->x = (p1.x+p2.x+p3.x+p4.x) / 4.;
        c->y = (p1.y+p2.y+p3.y+p4.y) / 4.;
    }
    
    return YES;
}

+(void) setFontHeight: (float) f
{
	fontHeight = f;
}

+(void) saveDefaultSettings
{
	if (ROIDefaultsLoaded)
	{
		[[NSUserDefaults standardUserDefaults] setFloat: ROIRegionOpacity forKey: @"ROIRegionOpacity"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROITextThickness forKey: @"ROITextThickness"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIThickness forKey: @"ROIThickness"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIOpacity forKey: @"ROIOpacity"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIColorR forKey: @"ROIColorR"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIColorG forKey: @"ROIColorG"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIColorB forKey: @"ROIColorB"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROITextColorR forKey: @"ROITextColorR"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROITextColorG forKey: @"ROITextColorG"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROITextColorB forKey: @"ROITextColorB"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIRegionColorR forKey: @"ROIRegionColorR"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIRegionColorG forKey: @"ROIRegionColorG"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIRegionColorB forKey: @"ROIRegionColorB"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIRegionThickness forKey: @"ROIRegionThickness"];
		[[NSUserDefaults standardUserDefaults] setFloat: ROIArrowThickness forKey: @"ROIArrowThickness"];
	}
}

+(void) loadDefaultSettings
{
	ROIRegionOpacity = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionOpacity"];
	if (ROIRegionOpacity < 0.3) ROIRegionOpacity = 0.3;
	
	ROITextThickness = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextThickness"];
	ROIThickness = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIThickness"];
    if (ROIThickness < 0.3) ROIThickness = 0.3;
    
	ROIOpacity = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIOpacity"];
	if (ROIOpacity < 0.3) ROIOpacity = 0.3;
	
	ROIColorR = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorR"];
	ROIColorG = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorG"];
	ROIColorB = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorB"];
	ROITextColorR = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorR"];
	ROITextColorG = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorG"];
	ROITextColorB = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorB"];
	ROIRegionColorR = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorR"];
	ROIRegionColorG = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorG"];
	ROIRegionColorB = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorB"];
	ROIRegionThickness = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionThickness"];
	ROIArrowThickness = [[NSUserDefaults standardUserDefaults] floatForKey: @"ROIArrowThickness"];
	
	ROITEXTIFSELECTED = [[NSUserDefaults standardUserDefaults] boolForKey: @"ROITEXTIFSELECTED"];
    ROITextIfMouseIsOver = [NSUserDefaults.standardUserDefaults boolForKey: @"ROITextIfMouseIsOver"];
	ROITEXTNAMEONLY = [[NSUserDefaults standardUserDefaults] boolForKey: @"ROITEXTNAMEONLY"];
	splineForROI = [[NSUserDefaults standardUserDefaults] boolForKey: @"splineForROI"];
	displayCobbAngle = [[NSUserDefaults standardUserDefaults] boolForKey: @"displayCobbAngle"];
    ROIDrawPlainEdge = [[NSUserDefaults standardUserDefaults] boolForKey: @"ROIDrawPlainEdge"];
    ROIDisplayStatisticsOnlyForFused = [[NSUserDefaults standardUserDefaults] boolForKey: @"ROIDisplayStatisticsOnlyForFused"];
	
	ROIDefaultsLoaded = YES;
}

+ (BOOL) splineForROI
{
	return splineForROI;
}

-(void)setIsSpline:(BOOL)isSpline {
	_isSpline = isSpline;
	_hasIsSpline = YES;
}

-(BOOL)isSpline {
	return _hasIsSpline? _isSpline : [ROI splineForROI];
}

+(void) setDefaultName:(NSString*) n
{
	[defaultName release];
	if ( n == nil ) {
		defaultName = nil;
		return;
	}
	defaultName = [[[NSString alloc] initWithString: n] retain];
}

+(NSString*) defaultName {
	return defaultName;
}

+ (NSPoint) pointBetweenPoint:(NSPoint) a
                     andPoint:(NSPoint) b
                        ratio:(float) r
{
    return NSMakePoint(a.x*(1.0-r)+b.x*r, a.y*(1.0-r)+b.y*r);
}

+ (float) lengthBetween:(NSPoint) measureA
               andPoint:(NSPoint) measureB
{
    return sqrt(((double)measureA.x - (double)measureB.x) * ((double)measureA.x - (double)measureB.x) +
                ((double)measureA.y - (double)measureB.y) * ((double)measureA.y - (double)measureB.y));
}

+ (NSPoint) segmentDistToPoint:(NSPoint) segA
                              :(NSPoint) segB
                              :(NSPoint) p
{
    NSPoint p2 = NSMakePoint(segB.x - segA.x, segB.y - segA.y);
    double f = p2.x*p2.x + p2.y*p2.y;
    double u = ((p.x - segA.x) * p2.x + (p.y - segA.y) * p2.y) / f;
    
//    if (u > 1)
//        u = 1;
//    else if (u < 0)
//        u = 0;
    
    double x = segA.x + u * p2.x;
    double y = segA.y + u * p2.y;
    
//    float dx = x - p.x;
//    float dy = y - p.y;
//
//    float length = sqrtf(dx*dx + dy*dy);
    
    return NSMakePoint( x, y);
}

+ (NSPoint) positionAtDistance: (float) distance inPolygon:(NSArray*) points
{
	int i = 0;
	double position = 0, ratio;
	NSPoint p;
	
	if ([points count] == 0)
		return NSZeroPoint;
	
	if (distance == 0)
        return [[points objectAtIndex:0] point];
	
	while (position < distance && i < (long)[points count] -1)
	{
		position += [ROI lengthBetween:[[points objectAtIndex:i] point]
                              andPoint:[[points objectAtIndex:(i+1)] point]];
		i++;
	}
	
	if (position < distance)
	{
		position += [ROI lengthBetween:[[points objectAtIndex:i] point]
                              andPoint:[[points objectAtIndex:0] point]];
		i++;
	}
	
	if (i == [points count])
	{
		ratio = (position - distance) / [ROI lengthBetween:[[points objectAtIndex:i-1] point]
                                                  andPoint:[[points objectAtIndex: 0] point]];

        p = [ROI pointBetweenPoint:[[points objectAtIndex:i-1] point]
                          andPoint:[[points objectAtIndex:0] point]
                             ratio: 1.0 - ratio];
	}
	else
	{
		ratio = (position - distance) / [ROI lengthBetween:[[points objectAtIndex:i-1] point]
                                                  andPoint:[[points objectAtIndex:i] point]];
		p = [ROI pointBetweenPoint:[[points objectAtIndex:i-1] point]
                          andPoint:[[points objectAtIndex:i] point]
                             ratio: 1.0 - ratio];
	}
	
	return p;
}

+ (NSMutableArray*) resamplePoints: (NSArray*) points number:(int) no
{
	double length = 0.0;
    int ii;
	for (ii = 0; ii < (long)[points count]-1; ii++ )
	{
		length += [ROI lengthBetween:[[points objectAtIndex:ii] point]
                            andPoint:[[points objectAtIndex:ii+1] point]];
	}

    length += [ROI lengthBetween:[[points objectAtIndex:ii] point]
                        andPoint:[[points objectAtIndex:0] point]];
	
	NSMutableArray* newPts = [NSMutableArray array];
	for (int i = 0; i < no; i++)
    {
		double s = (i * length) / no;
		NSPoint p = [ROI positionAtDistance: s inPolygon: points];
		[newPts addObject: [MyPoint point: p]];
	}
	
	double minx = [[newPts objectAtIndex: 0] x];
	double miny = [[newPts objectAtIndex: 0] y];
	int minyIndex = 0, minxIndex = 0;
	
	//find min x - reorder the points
	for (int i = 0 ; i < [newPts count] ; i++) {
		
		if (minx > [[newPts objectAtIndex: i] x])
		{
			minx = [[newPts objectAtIndex: i] x];
			minxIndex = i;
		}
		
		if (miny > [[newPts objectAtIndex: i] y])
		{
			miny = [[newPts objectAtIndex: i] y];
			minyIndex = i;
		}
	}
	BOOL reverse = NO;
	
	int distance = 0;
	
	distance = minxIndex - minyIndex;
	
	if ( abs( distance) > [newPts count]/2)
	{
		if (distance >= 0)
            reverse = YES;
		else
            reverse = NO;
	}
	else
	{
		if (distance >= 0)
            reverse = NO;
		else
            reverse = YES;
	}
	
	NSMutableArray* orderedPts = [NSMutableArray array];
	if (reverse == NO )
	{
		for (int i = 0 ; i < [newPts count] ; i++) {
			
			[orderedPts addObject: [newPts objectAtIndex: minxIndex]];
			minxIndex++;
			if (minxIndex == [newPts count]) minxIndex = 0;
		}
	}
	else
	{
		for (int i = 0 ; i < [newPts count] ; i++) {
			
			[orderedPts addObject: [newPts objectAtIndex: minxIndex]];
			minxIndex--;
			if (minxIndex < 0) minxIndex = (long)[newPts count] -1;
		}
	}
	
	return orderedPts;
}

- (BOOL) isValidForVolume
{
    if (type == tClosedPolygon ||
        type == tOpenPolygon ||
        type == tPlain ||
        type == tPencil ||
        type == tOval)
    {
        return YES;
    }

    return NO;
}

-(void) setDefaultName:(NSString*) n { [ROI setDefaultName: n]; }
-(NSString*) defaultName { return defaultName; }

- (void) computeROIIfNedeed
{
    if (rtotal == -1)
    {
        [[curView curDCM] computeROI:self :&rmean :&rtotal :&rdev :&rmin :&rmax :&rskewness :&rkurtosis];
    }
}

- (void) setOpacity:(float) a
{
	[self setOpacity: a globally: YES];
}

- (void) setOpacity:(float)newOpacity globally: (BOOL) g
{
	opacity = newOpacity;
	
	if (type == tPlain)
	{
		if (g)
			ROIRegionOpacity = opacity;
	}
	else if (type == tLayerROI)
	{
		while ([ctxArray count])
            [self deleteTexture: [ctxArray lastObject]];
	}
	else if (g)
		ROIOpacity = opacity;
}

- (DCMPix*) pix
{
	if (_pix)
		return _pix;

    if (curView)
        NSLog( @"----- warning pix == [curView curDCM]");
    else
        NSLog( @"***** warning pix == nil !!");
    
    _pix = [curView.curDCM retain];
    
    return _pix;
}

- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)obj change:(NSDictionary*)change context:(void*)context
{
    if ([keyPath isEqualToString: @"values.computePeakValue"] ||
       [keyPath isEqualToString: @"values.computeIsoContour"] ||
       [keyPath isEqualToString: @"values.peakDiameterInMm"] ||
       [keyPath isEqualToString: @"values.minimumBallROIIsoContour"] ||
       [keyPath isEqualToString: @"values.maximumBallROIIsoContour"] ||
       [keyPath isEqualToString: @"values.percentageIsoContour"] ||
       [keyPath isEqualToString: @"values.minimumBallROIIsoContourPercentage"] ||
       [keyPath isEqualToString: @"values.maximumBallROIIsoContourPercentage"] ||
       [keyPath isEqualToString: @"values.definedMaximumForBallROIIsoContourPercentage"] ||
       [keyPath isEqualToString: @"values.definedMaximumForBallROIIsoContour"] )
    {
        float peakDiameter = [[NSUserDefaults standardUserDefaults] floatForKey: @"peakDiameterInMm"];
        
        if (peakDiameter != roundf( peakDiameter))
            [[NSUserDefaults standardUserDefaults] setFloat: roundf( peakDiameter) forKey: @"peakDiameterInMm"];
        
        [self recompute];
        [self.curView setNeedsDisplay: YES];
        
        [self.parentROI recompute];
        [self.parentROI.curView setNeedsDisplay: YES];
        
    }
}

- (void) setObservers
{
}

#pragma mark -

- (id) initWithCoder:(NSCoder*) coder
{
	long fileVersion;
	
    if (self = [super init])
    {
		uniqueID = [[NSNumber numberWithInt: gUID++] retain];
		groupID = 0.0;
		PointUnderMouse = -1;
		selectedModifyPoint = -1;
        zLocation = FLT_MIN;
		
    @try {
		fileVersion = [coder versionForClassName: @"ROI"];
		parentROI = nil;
		points = [coder decodeObject];
		rect = NSRectFromString( [coder decodeObject]);
		type = (ToolMode)[[coder decodeObject] floatValue];
		needQuartz = [[coder decodeObject] floatValue];
		thickness = [[coder decodeObject] floatValue];
		fill = [[coder decodeObject] floatValue];
		opacity = [[coder decodeObject] floatValue];
		color.red = [[coder decodeObject] floatValue];
		color.green = [[coder decodeObject] floatValue];
		color.blue = [[coder decodeObject] floatValue];
		name = [coder decodeObject];
		comments = [coder decodeObject];
		pixelSpacingX = [[coder decodeObject] floatValue];
		imageOrigin = NSPointFromString( [coder decodeObject]);
		
		if (fileVersion >= 2)
			pixelSpacingY = [[coder decodeObject] floatValue];
		else
            pixelSpacingY = pixelSpacingX;
		
		if (type == tPlain)
		{
			textureWidth = [[coder decodeObject] intValue];
			[[coder decodeObject] intValue];	// Keep it for backward compatibility & compatibility with encoder
			textureHeight = [[coder decodeObject] intValue];
			[[coder decodeObject] intValue];	// Keep it for backward compatibility & compatibility with encoder
			
			textureUpLeftCornerX = [[coder decodeObject] intValue];
			textureUpLeftCornerY = [[coder decodeObject] intValue];
			textureDownRightCornerX = [[coder decodeObject] intValue];
			textureDownRightCornerY = [[coder decodeObject] intValue];
			
			textureBuffer = (unsigned char*)malloc(textureWidth*textureHeight*sizeof(unsigned char));
			
			@try
			{
				unsigned char *pointerBuff = (unsigned char*)[[coder decodeObject] bytes];
				
				for (int j=0; j<textureHeight; j++ )
					for (int i=0; i<textureWidth; i++ )
						textureBuffer[i+j*textureWidth] = pointerBuff[i+j*textureWidth];
			}
			@catch (NSException * e)
			{
			}
		}
		
		if (fileVersion >= 3)
			zPositions = [coder decodeObject];
		else
            zPositions = [[NSMutableArray array] retain];
		
		if (fileVersion >= 4)
		{
			offsetTextBox_x = [[coder decodeObject] floatValue];
			offsetTextBox_y = [[coder decodeObject] floatValue];
		}
		else
		{
			offsetTextBox_x = 0;
			offsetTextBox_y = 0;
		}
		
		if (fileVersion >= 5) {
			_calciumThreshold = [[coder decodeObject] intValue];
			_displayCalciumScoring = [[coder decodeObject] boolValue];
		}

		if (fileVersion >= 6)
		{
			groupID = [[coder decodeObject] doubleValue];
			if (type==tLayerROI)
			{
				layerImageJPEG = [coder decodeObject];
				[layerImageJPEG retain];
//				layerImageWhenSelectedJPEG = [coder decodeObject];
//				[layerImageWhenSelectedJPEG retain];
				
				layerImage = [[NSImage alloc] initWithData: layerImageJPEG];
//				layerImageWhenSelected = [[NSImage alloc] initWithData: layerImageWhenSelectedJPEG];
				
				while ([ctxArray count])
                    [self deleteTexture: [ctxArray lastObject]];
				//needsLoadTexture2 = YES;
			}
			textualBoxLine1 = [coder decodeObject];
			textualBoxLine2 = [coder decodeObject];
			textualBoxLine3 = [coder decodeObject];
			textualBoxLine4 = [coder decodeObject];
			textualBoxLine5 = [coder decodeObject];
			[textualBoxLine1 retain];
			[textualBoxLine2 retain];
			[textualBoxLine3 retain];
			[textualBoxLine4 retain];
			[textualBoxLine5 retain];
		}

		if (fileVersion >= 7)
		{
			isLayerOpacityConstant = [[coder decodeObject] boolValue];
			canColorizeLayer = [[coder decodeObject] boolValue];
			layerColor = [coder decodeObject];
			if (layerColor) [layerColor retain];
			displayTextualData = [[coder decodeObject] boolValue];
		}
		else
            displayTextualData = YES;
		
		if (fileVersion >= 8)
		{
			canResizeLayer = [[coder decodeObject] boolValue];
		}
		
		if (fileVersion >= 9)
		{
			selectable = [[coder decodeObject] boolValue];
			locked = [[coder decodeObject] boolValue];
		}
		else
		{
			selectable = YES;
			locked = NO;
		}
		
		if (fileVersion >= 10)
		{
			isAliased = [[coder decodeObject] boolValue];
		}
		else
		{
			isAliased = NO;
		}
		
		if (fileVersion >= 11)
		{
			_isSpline = [[coder decodeObject] boolValue];
			_hasIsSpline = [[coder decodeObject] boolValue];
		}
		else
		{
			_isSpline = NO;
			_hasIsSpline = NO;
		}
        
        if (fileVersion >= 12)
        {
            savedStudyInstanceUID = [[coder decodeObject] copy];
        }
		
        if (fileVersion >= 13 && type == tOvalAngle)
        {
            ovalAngle1 = [[coder decodeObject] doubleValue];
            ovalAngle2 = [[coder decodeObject] doubleValue];
        }
        
        if (fileVersion >= 14)
            roiRotationDeg = [[coder decodeObject] doubleValue];
        
        if (fileVersion >= 15)
            zLocation = [[coder decodeObject] doubleValue];
        
		[points retain];
		[name retain];
		[comments retain];
		[zPositions retain]; 
		mode = ROI_sleep;
		
		previousPoint.x = previousPoint.y = -1000;
		
		stringTex = nil;
		[self recompute];
		mousePosMeasure = -1;
		
		ctxArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		textArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		
        // init fonts for use with strings
        NSFont * font =[NSFont fontWithName:@"Helvetica" size: 12.0 + thickness*2];
        stanStringAttrib = [[NSMutableDictionary dictionary] retain];
        [stanStringAttrib setObject:font forKey:NSFontAttributeName];
        [stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		
		[self reduceTextureIfPossible];
        
        [self setObservers];
    }
    @catch (NSException * e)
    {
        NSLog( @"ROI.mm:%d, exception %@", __LINE__,  e);
    }
    } // if (self)

    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification
                                                            object: self
                                                          userInfo: nil];

    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
	ROI *c = [[[self class] allocWithZone: zone] init];
	if (c == nil)
        return nil;
	
    c->zLocation = FLT_MIN;
	c->uniqueID = [[NSNumber numberWithInt: gUID++] retain];
	c->groupID = 0.0;
	c->PointUnderMouse = -1;
	c->selectedModifyPoint = -1;
	
	c->parentROI = nil;
	
	NSMutableArray *a = [[NSMutableArray array] retain];
	
	for (MyPoint *p in points)
		[a addObject: [[p copy] autorelease]];
		
	c->points = a;
	
	c->rect = rect;
	c->type = type;
	c->needQuartz = needQuartz;
	c->thickness = thickness;
	c->fill = fill;
	c->opacity = opacity;
	c->color = color;
	c->name = [name copy];
	c->comments = [comments copy];
    c->savedStudyInstanceUID = [savedStudyInstanceUID copy];
	c->pixelSpacingX = pixelSpacingX;
	c->imageOrigin = imageOrigin;
	c->pixelSpacingY = pixelSpacingY;
	
	if (c->type == tPlain)
	{
		c->textureWidth = textureWidth;
		c->textureHeight = textureHeight;
		
		c->textureUpLeftCornerX = textureUpLeftCornerX;
		c->textureUpLeftCornerY = textureUpLeftCornerY;
		c->textureDownRightCornerX = textureDownRightCornerX;
		c->textureDownRightCornerY = textureDownRightCornerY;
		
		c->textureBuffer = (unsigned char*) malloc( textureWidth*textureHeight*sizeof(unsigned char));
        if (c->textureBuffer == nil)
        {
            [c autorelease];
            return nil;
        }

        if (c->textureBuffer && textureBuffer)
			memcpy(c->textureBuffer,
                   textureBuffer,
                   textureWidth*textureHeight*sizeof(unsigned char));
	}
	
	NSMutableArray *z = [[NSMutableArray array] retain];
	for (NSNumber *p in zPositions)
		[z addObject: [[p copy] autorelease]];
	c->zPositions = z;
	
	c->offsetTextBox_x = offsetTextBox_x;
	c->offsetTextBox_y = offsetTextBox_y;
	
	c->_calciumThreshold = _calciumThreshold;
	c->_displayCalciumScoring = _displayCalciumScoring;

	c->groupID = groupID;
	if (c->type == tLayerROI)
	{
		c->layerImageJPEG = [layerImageJPEG copy];
		c->layerImage = [[NSImage alloc] initWithData: c->layerImageJPEG];
		
        if (c->layerImage == nil) {
            [c autorelease];
            return nil;
        }
        
		while ([ctxArray count])
            [self deleteTexture: [ctxArray lastObject]];
	}
	c->textualBoxLine1 = [textualBoxLine1 copy];
	c->textualBoxLine2 = [textualBoxLine2 copy];
	c->textualBoxLine3 = [textualBoxLine3 copy];
	c->textualBoxLine4 = [textualBoxLine4 copy];
	c->textualBoxLine5 = [textualBoxLine5 copy];

	c->isLayerOpacityConstant = isLayerOpacityConstant;
	c->canColorizeLayer = canColorizeLayer;
	c->layerColor = [layerColor copy];
	c->displayTextualData = displayTextualData;

	c->canResizeLayer = canResizeLayer;

	c->selectable = selectable;
	c->locked = locked;

	c->isAliased = isAliased;
	
	c->mode = ROI_sleep;
	
	c->previousPoint.x = c->previousPoint.y = -1000;
	
	c->stringTex = nil;
    c->stringTexA = nil;
    c->stringTexB = nil;
    c->stringTexC = nil;
    
    [c recompute];
	c->mousePosMeasure = -1;
	
	c->ctxArray = [[NSMutableArray arrayWithCapacity: 10] retain];
	c->textArray = [[NSMutableArray arrayWithCapacity: 10] retain];
	
	// init fonts for use with strings
	NSFont * font =[NSFont fontWithName:@"Helvetica" size: 12.0 + c->thickness*2];
	c->stanStringAttrib = [[NSMutableDictionary dictionary] retain];
	[c->stanStringAttrib setObject:font forKey:NSFontAttributeName];
	[c->stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	
	[c reduceTextureIfPossible];
	
	c->_hasIsSpline = _hasIsSpline;
	c->_isSpline = _isSpline;
    c->ovalAngle1 = ovalAngle1;
    c->ovalAngle2 = ovalAngle2;
    c->roiRotationDeg = roiRotationDeg;
    
    [c setObservers];
	
	return c;
}

- (void) encodeWithCoder:(NSCoder*) coder
{
	[ROI setVersion:ROI_VERSION];
	
    [coder encodeObject:points];
    [coder encodeObject:NSStringFromRect(rect)];
    [coder encodeObject:[NSNumber numberWithFloat:type]]; 
    [coder encodeObject:[NSNumber numberWithFloat:needQuartz]];
	[coder encodeObject:[NSNumber numberWithFloat:thickness]];
	[coder encodeObject:[NSNumber numberWithFloat:fill]];
	[coder encodeObject:[NSNumber numberWithFloat:opacity]];
	[coder encodeObject:[NSNumber numberWithFloat:color.red]];
	[coder encodeObject:[NSNumber numberWithFloat:color.green]];
	[coder encodeObject:[NSNumber numberWithFloat:color.blue]];
	[coder encodeObject:name];
	[coder encodeObject:comments];
	[coder encodeObject:[NSNumber numberWithFloat:pixelSpacingX]];
	[coder encodeObject:NSStringFromPoint(imageOrigin)];
	[coder encodeObject:[NSNumber numberWithFloat:pixelSpacingY]];
	if (type==tPlain)
	{
		[coder encodeObject:[NSNumber numberWithInt:textureWidth]];
		[coder encodeObject:@0];
		
		[coder encodeObject:[NSNumber numberWithInt:textureHeight]];
		[coder encodeObject:@0];
		
		[coder encodeObject:[NSNumber numberWithInt:textureUpLeftCornerX]];
		[coder encodeObject:[NSNumber numberWithInt:textureUpLeftCornerY]];
		
		[coder encodeObject:[NSNumber numberWithInt:textureDownRightCornerX]];
		[coder encodeObject:[NSNumber numberWithInt:textureDownRightCornerY]];
		
		[coder encodeObject:[NSData dataWithBytes:textureBuffer length:(textureWidth*textureHeight)]];
	}
	[coder encodeObject:zPositions];
	[coder encodeObject:[NSNumber numberWithFloat:offsetTextBox_x]];
	[coder encodeObject:[NSNumber numberWithFloat:offsetTextBox_y]];
	[coder encodeObject:[NSNumber numberWithInt:_calciumThreshold]];
	[coder encodeObject:[NSNumber numberWithBool:_displayCalciumScoring]];
	
	// ROI_VERSION = 6
	[coder encodeObject:[NSNumber numberWithDouble:groupID]];
	if (type==tLayerROI)
	{
		if (layerImageJPEG == nil)
		{
//			NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData: [layerImage TIFFRepresentation]];
//			NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.3] forKey:NSImageCompressionFactor];
//	
//			layerImageJPEG = [[imageRep representationUsingType:NSJPEG2000FileType properties:imageProps] retain];	//NSJPEGFileType
			[self generateEncodedLayerImage];
		}
//		if (layerImageWhenSelectedJPEG == nil)
//		{
//			NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData: [layerImage TIFFRepresentation]];
//			NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.3] forKey:NSImageCompressionFactor];
//	
//			layerImageWhenSelectedJPEG = [[imageRep representationUsingType:NSJPEG2000FileType properties:imageProps] retain];	//NSJPEGFileType
//		}
		[coder encodeObject: layerImageJPEG];
//		[coder encodeObject: layerImageWhenSelectedJPEG];
	}
	[coder encodeObject:textualBoxLine1];
	[coder encodeObject:textualBoxLine2];
	[coder encodeObject:textualBoxLine3];
	[coder encodeObject:textualBoxLine4];
	[coder encodeObject:textualBoxLine5];
	
	// ROI_VERSION = 7
	[coder encodeObject:[NSNumber numberWithBool:isLayerOpacityConstant]];
	[coder encodeObject:[NSNumber numberWithBool:canColorizeLayer]];
	[coder encodeObject:layerColor];
	[coder encodeObject:[NSNumber numberWithBool:displayTextualData]];
	
	// ROI_VERSION = 8
	[coder encodeObject:[NSNumber numberWithBool:canResizeLayer]];
	
	// ROI_VERSION = 9
	[coder encodeObject:[NSNumber numberWithBool: selectable]];
	[coder encodeObject:[NSNumber numberWithBool: locked]];
	
	// ROI_VERSION = 10
	[coder encodeObject:[NSNumber numberWithBool: isAliased]];
	
	// ROI_VERSION = 11
	[coder encodeObject:[NSNumber numberWithBool: _isSpline]];
	[coder encodeObject:[NSNumber numberWithBool: _hasIsSpline]];
    
    // ROI_VERSION = 12
    if (savedStudyInstanceUID.length > 0)
        [coder encodeObject: savedStudyInstanceUID];
    else
        [coder encodeObject: @"0000"];
    
    // ROI_VERSION = 13
    if (type == tOvalAngle)
    {
        [coder encodeObject: @(ovalAngle1)];
        [coder encodeObject: @(ovalAngle2)];
    }
    
    // ROI_VERSION = 14
    [coder encodeObject: @(roiRotationDeg)];
    
    // ROI_VERSION = 15
    [self computeZLocation];
    [coder encodeObject: @(zLocation)];    
}

- (NSData*) data
{
	return [NSArchiver archivedDataWithRootObject: self];
}

- (void) deleteTexture:(NSOpenGLContext*) c
{
    NSUInteger index;
    do
    {
        index = [ctxArray indexOfObjectIdenticalTo: c];
        
        if (c && index != NSNotFound)
        {
            CGLContextObj cgl_ctx = [c CGLContextObj];
            if (cgl_ctx == nil)
                return;
       
            GLuint t = [[textArray objectAtIndex: index] intValue];
            if (t)
                (*cgl_ctx->disp.delete_textures)(cgl_ctx->rend, 1, &t);

            [ctxArray removeObjectAtIndex: index];
            [textArray removeObjectAtIndex: index];
        }
    } while (index != NSNotFound);
}

- (void) prepareForRelease // We need to unlink the links related to OpenGLContext
{
    [stringTextureCache release];
    stringTextureCache = nil;
    
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];
    
    [ctxArray release];
    ctxArray = nil;
	
	if ([textArray count])
        NSLog( @"** not all texture were deleted...");
    
	[textArray release];
    textArray = nil;
}

- (void) dealloc
{
	self.parentROI = nil;
	
	// This autorelease pool is required : postNotificationName seems to keep the self object with an autorelease, creating a conflict with the 'hard' [super dealloc] at the end of this function.
	// We have to drain the pool before !
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixRemoveROINotification object:self userInfo: nil];
		[pool release];
	}
	
    [self prepareForRelease];
	
	if (textureBuffer)
        free(textureBuffer);

    [self textureBufferHasChanged];
    
    [peakValue release];
    [isoContour release];
    
    [savedStudyInstanceUID release];
	[uniqueID release];
	[points release];
	[zPositions release];
	[name release];
	[comments release];
	[stringTex release];
	[stanStringAttrib release];
    [stringTexA release];
    [stringTexB release];
    [stringTexC release];
    [cachedSplinePoints release];
    [cachedSplinePointsWithoutScale release];
    if (cachedNSPoint)
        free( cachedNSPoint);
	[roiLock release];
	roiLock = 0;
	
	[layerImageJPEG release];

	[layerReferenceFilePath release];
	[layerImage release];
	[layerColor release];
	
	[textualBoxLine1 release];
	[textualBoxLine2 release];
	[textualBoxLine3 release];
	[textualBoxLine4 release];
	[textualBoxLine5 release];
	[textualBoxLine6 release];
    [textualBoxLine7 release];
    [textualBoxLine8 release];
    
	[parentROI release];
	[_pix release];
    
	[super dealloc];
}

- (void) setOriginAndSpacing :(float) ipixelSpacing :(NSPoint) iimageOrigin
{
	[self setOriginAndSpacing :ipixelSpacing :ipixelSpacing :iimageOrigin];
}

- (void) setOriginAndSpacing :(float) ipixelSpacingx :(float) ipixelSpacingy :(NSPoint) iimageOrigin
{
	[self setOriginAndSpacing :ipixelSpacingx :ipixelSpacingy :iimageOrigin :YES];
}

- (void) setOriginAndSpacing :(float) ipixelSpacingx :(float) ipixelSpacingy :(NSPoint) iimageOrigin :(BOOL) sendNotification
{
	[self setOriginAndSpacing :ipixelSpacingx :ipixelSpacingy :iimageOrigin :sendNotification :YES];
}

- (void) setOriginAndSpacing :(float) ipixelSpacingx :(float) ipixelSpacingy :(NSPoint) iimageOrigin :(BOOL) sendNotification :(BOOL) inImageCheck
{
	BOOL change = NO;
	
	if (ipixelSpacingx == 0) return;
	if (ipixelSpacingy == 0) return;
	
	if (pixelSpacingY == 0 || pixelSpacingX == 0)
	{
	
	}
	else
	{
		if (pixelSpacingX != ipixelSpacingx)
			change = YES;
		
		if (pixelSpacingY != ipixelSpacingy)
			change = YES;
		
        if (savedStudyInstanceUID == nil)
        {
            if (imageOrigin.x != iimageOrigin.x || imageOrigin.y != iimageOrigin.y)
                change = YES;
		}
        else
            iimageOrigin = imageOrigin;
        
		if (change == NO)
            return;
		
		NSPoint offset;
		
		ROI_mode modeSaved = mode;
		mode = ROI_selected;
		
		if (type == tPlain)
		{
            vImage_Buffer srcVimage;
			srcVimage.data = textureBuffer;
			srcVimage.height = textureHeight;
			srcVimage.width = textureWidth;
			srcVimage.rowBytes = textureWidth;
			
			textureWidth *= pixelSpacingX / ipixelSpacingx;
			textureHeight *= pixelSpacingX / ipixelSpacingx;
			
			unsigned char *newBuffer = (unsigned char *)malloc( textureWidth * textureHeight * sizeof(unsigned char));
			
            vImage_Buffer dstVimage;
			dstVimage.height = textureHeight;
			dstVimage.width = textureWidth;
			dstVimage.rowBytes = textureWidth;
			dstVimage.data = newBuffer;
			
			vImageScale_Planar8( &srcVimage, &dstVimage, nil, kvImageHighQualityResampling);
			
			textureUpLeftCornerX *= pixelSpacingX / ipixelSpacingx;
			textureUpLeftCornerY *= pixelSpacingY / ipixelSpacingy;
			textureDownRightCornerX = textureUpLeftCornerX + textureWidth;
			textureDownRightCornerY = textureUpLeftCornerY + textureHeight;
			
			for (int x = 0 ; x < textureWidth; x++)
			{
				for (int y = 0 ; y < textureHeight; y++)
				{
					if (newBuffer[ y*textureWidth + x] < 127)
						newBuffer[ y*textureWidth + x] = 0;
					else
						newBuffer[ y*textureWidth + x] = 0xFF;
				}
			}
			
			offset.x = (imageOrigin.x - iimageOrigin.x)/pixelSpacingX;
			offset.y = (imageOrigin.y - iimageOrigin.y)/pixelSpacingY;
			
			offset.x *= (pixelSpacingX/ipixelSpacingx);
			offset.y *= (pixelSpacingY/ipixelSpacingy);
			
			[self roiMove:offset :sendNotification];
			
			free( textureBuffer);
			textureBuffer = newBuffer;
            
            [self textureBufferHasChanged];
		}
		else
		{
			offset.x = (imageOrigin.x - iimageOrigin.x)/pixelSpacingX;
			offset.y = (imageOrigin.y - iimageOrigin.y)/pixelSpacingY;
			
			[self roiMove:offset :sendNotification];
			
			if (self.pix && inImageCheck)
			{
				BOOL inImage = NO;
				NSRect imRect = NSMakeRect( 0, 0, self.pix.pwidth, self.pix.pheight);
				NSArray *pts = [self points];
				for (MyPoint* pt in pts)
				{
					if (NSPointInRect( NSMakePoint( pt.x * (pixelSpacingX/ipixelSpacingx), pt.y * (pixelSpacingX/ipixelSpacingx)), imRect))
					{
						inImage = YES;
						break;
					}
				}
				
				if (inImage == NO)
					[self roiMove: NSMakePoint( -offset.x, -offset.y) :sendNotification];
			}

			rect.origin.x *= (pixelSpacingX/ipixelSpacingx);
			rect.origin.y *= (pixelSpacingY/ipixelSpacingy);
			rect.size.width *= (pixelSpacingX/ipixelSpacingx);
			rect.size.height *= (pixelSpacingY/ipixelSpacingy);
			
			for (int i = 0; i < [points count]; i++)
			{
				NSPoint aPoint = [[points objectAtIndex:i] point];
				
				aPoint.x *= (pixelSpacingX/ipixelSpacingx);
				aPoint.y *= (pixelSpacingY/ipixelSpacingy);
				
				[[points objectAtIndex:i] setPoint: aPoint];
			}
		}
		
		mode = modeSaved;
	}
	
	pixelSpacingX = ipixelSpacingx;
	pixelSpacingY = ipixelSpacingy;
	imageOrigin = iimageOrigin;
	
	if (sendNotification)
	{
		[self recompute];
		
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	}
}

- (id) initWithType: (long) itype :(float) ipixelSpacing :(NSPoint) iimageOrigin
{
	return [self initWithType: itype :ipixelSpacing :ipixelSpacing :iimageOrigin];
}

// tPlain
- (instancetype) initWithTexture: (unsigned char*)tBuff
             textWidth:(int)tWidth
            textHeight:(int)tHeight
              textName:(NSString*)tName
			 positionX:(int)posX
             positionY:(int)posY
			  spacingX:(float)ipixelSpacingx
              spacingY:(float)ipixelSpacingy
           imageOrigin:(NSPoint)iimageOrigin
{
	self = [super init];
    if (self)
	{
        if (tWidth < 0 || tHeight < 0)
        {
            N2LogStackTrace( @"tWidth < 0 || tHeight < 0");
            [self autorelease];
            return nil;
        }
        
		textureBuffer = (unsigned char*)malloc(tWidth*tHeight*sizeof(unsigned char));
        if (textureBuffer == nil) {
            [self autorelease];
            return nil;
        }
		
		// Basic init from other ROIs
		uniqueID = [[NSNumber numberWithInt: gUID++] retain];
		groupID = 0.0;
		PointUnderMouse = -1;
		selectedModifyPoint = -1;
        zLocation = FLT_MIN;
		
		ctxArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		textArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		
		selectable = YES;
		locked = NO;
        type = tPlain;
		mode = ROI_sleep;
		parentROI = nil;
		thickness = 2.0;
		opacity = 0.5;
		mousePosMeasure = -1;
		pixelSpacingX = ipixelSpacingx;
		pixelSpacingY = ipixelSpacingy;
		imageOrigin = iimageOrigin;
		points = [[NSMutableArray array] retain];
		zPositions = [[NSMutableArray array] retain];
		comments = [[NSString alloc] initWithString:@""];
		stringTex = nil;
		[self recompute];
		previousPoint.x = previousPoint.y = -1000;
		
		// specific init for tPlain ...
		textureFirstPoint=1; // a simple indic use to know when it is the first time we create a texture ...
		textureUpLeftCornerX=posX;
		textureUpLeftCornerY=posY;
		textureDownRightCornerX=posX+tWidth-1;
		textureDownRightCornerY=posY+tHeight-1;
		textureWidth=tWidth;
		textureHeight=tHeight;
		
		memcpy( textureBuffer, tBuff, tHeight*tWidth);
		[self reduceTextureIfPossible];
		
		self.name = tName;
		displayTextualData = YES;
		
		thickness = ROIRegionThickness;
		color.red = ROIRegionColorR;
		color.green = ROIRegionColorG;
		color.blue = ROIRegionColorB;
		opacity = ROIRegionOpacity;
        
        [self setObservers];
	}
	
	if ([[NSUserDefaults standardUserDefaults] integerForKey: ANNOTATIONS_KEY] == ANNOTATIONS_NONE)
	{
		[[NSUserDefaults standardUserDefaults] setInteger: ANNOTATIONS_GRAPHICS forKey: ANNOTATIONS_KEY];
		[DCMView setDefaults];
	}
    
    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	return self;
}

- (BOOL) is3DROI
{
    return NO;
}

- (NSDictionary*) representationIn3D
{
    NSMutableDictionary *d = nil;
    
    if (self.type == t2DPoint)
    {
        d = [NSMutableDictionary dictionary];
        
        double c[ 3] = {0,0,0};
        
        [self.pix convertPixDoubleX: self.rect.origin.x pixY: self.rect.origin.y toDICOMCoords:c pixelCenter: NO];
        
        [d setObject: [Point3D pointWithX: c[ 0] y:c[ 1] z:c[ 2]] forKey: @"origin"];
        [d setObject: @(type) forKey: @"type"];
    }
    
    return d;
}

- (id) initWith3DRepresentation:(NSDictionary*) d inView: (DCMView*) v
{
//    if (v.volumicData != 1)
//    {
//        NSLog( @"------ volumic data required for 3D ROIs");
//        return nil;
//    }
    
    if ([d objectForKey: @"type"] == nil)
        return nil;
    
    BOOL valid = NO;
    DCMPix *destPix = nil;
    
    if ([[d objectForKey: @"type"] intValue] == t2DPoint)
    {
        Point3D *pt = [d objectForKey: @"origin"];
        
        float destPoint3D[ 3] = {pt.x, pt.y, pt.z};
        float resultPoint[ 3] = {0,0,0};
        float distance = 0;
        
        NSUInteger dcmPixIndex = [v findPlaneForPoint: destPoint3D
                                     preferParallelTo: nil
                                           localPoint: resultPoint
                                    distanceWithPlane: &distance
                              limitWithSliceThickness: NO];
        
        if (dcmPixIndex != NSNotFound)
        {
            float slicePoint3D[ 3];
            
            destPix = [v.dcmPixList objectAtIndex: dcmPixIndex];
            
            [destPix convertDICOMCoords: resultPoint toSliceCoords: slicePoint3D pixelCenter: NO];
            
            if (destPix.pixelSpacingX) // Back to pixels
            {
                slicePoint3D[ 0] /= destPix.pixelSpacingX;
                slicePoint3D[ 1] /= destPix.pixelSpacingY;
            }
            
            rect.origin = NSMakePoint( slicePoint3D[ 0], slicePoint3D[ 1]);
            
            valid = YES;
        }
    }
    
    if (valid)
    {
        self = [self initWithType:[[d objectForKey: @"type"] intValue]
                                 :destPix.pixelSpacingX
                                 :destPix.pixelSpacingY
                                 :[DCMPix originCorrectedAccordingToOrientation: destPix]];
        
        self.pix = destPix;
        self.curView = v;
        
        return self;
    }
    
    return nil;
}

+ (id) roiWithType: (long) itype
            inView: (DCMView*) v
{
    ROI *r = [[ROI alloc] initWithType:itype
                                      :v.curDCM.pixelSpacingX
                                      :v.curDCM.pixelSpacingY
                                      :[DCMPix originCorrectedAccordingToOrientation: v.curDCM]];
    
    r.pix = v.curDCM;
    r.curView = v;
    
    return [r autorelease];
}

- (id) initWithType: (long) itype
             inView: (DCMView*) v
{
    ROI *r = [self initWithType: itype :v.curDCM.pixelSpacingX :v.curDCM.pixelSpacingY :[DCMPix originCorrectedAccordingToOrientation: v.curDCM]];
    
    r.pix = v.curDCM;
    r.curView = v;
    
    return r;
}

- (instancetype) initWithType:(long) itype
                   :(float) ipixelSpacingx
                   :(float) ipixelSpacingy
                   :(NSPoint) iimageOrigin
{
	self = [super init];
    if (self)
	{
        zLocation = FLT_MIN;
		uniqueID = [[NSNumber numberWithInt: gUID++] retain];
		groupID = 0.0;
		PointUnderMouse = -1;
		selectedModifyPoint = -1;
		
		ctxArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		textArray = [[NSMutableArray arrayWithCapacity: 10] retain];
		
        opacity = 1.0;
		selectable = YES;
		locked = NO;
        type = (ToolMode)itype;
		mode = ROI_sleep;
		parentROI = nil;
        ovalAngle1 = [[NSUserDefaults standardUserDefaults] floatForKey: @"ovalAngle1"];
		ovalAngle2 = [[NSUserDefaults standardUserDefaults] floatForKey: @"ovalAngle2"];
        
		previousPoint.x = previousPoint.y = -1000;
		
		if (type == tText) thickness = ROITextThickness;
		else if (type == tArrow) thickness = ROIArrowThickness;
		else if (type == tPlain) thickness = ROIRegionThickness;
		else thickness = ROIThickness;
		
		opacity = ROIOpacity;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIOpacity"];
		color.red = ROIColorR;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorR"];
		color.green = ROIColorG;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorG"];
		color.blue = ROIColorB;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIColorB"];
		
		mousePosMeasure = -1;
		
		pixelSpacingX = ipixelSpacingx;
		pixelSpacingY = ipixelSpacingy;
		imageOrigin = iimageOrigin;
		
		points = [[NSMutableArray array] retain];
		zPositions = [[NSMutableArray array] retain];
		
		comments = [[NSString alloc] initWithString:@""];
		
		stringTex = nil;
		[self recompute];
		
		if (type == tText)
		{
			// init fonts for use with strings
			NSFont *font = [NSFont fontWithName:@"Helvetica" size:12.0 + thickness*2];
			stanStringAttrib = [[NSMutableDictionary dictionary] retain];
			[stanStringAttrib setObject:font forKey:NSFontAttributeName];
			[stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
			
			self.name = NSLocalizedString( @"Double-Click to edit", nil);	// Recompute the texture
			
			color.red = ROITextColorR;   //[[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorR"];
			color.green = ROITextColorG; //[[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorG"];
			color.blue = ROITextColorB;  //[[NSUserDefaults standardUserDefaults] floatForKey: @"ROITextColorB"];
		}
		else if (type == tPlain)
		{
			textureUpLeftCornerX	= 0.0;
			textureUpLeftCornerY	= 0.0;
			textureDownRightCornerX	= 0.0;
			textureDownRightCornerY	= 0.0;
			textureWidth			= 128;
			textureHeight			= 128;
			textureBuffer			= NULL;
			textureFirstPoint		= 0;
			
			thickness = ROIRegionThickness;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionThickness"];
			color.red = ROIRegionColorR;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorR"];
			color.green = ROIRegionColorG;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorG"];
			color.blue = ROIRegionColorB;	//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionColorB"];
			opacity = ROIRegionOpacity;		//[[NSUserDefaults standardUserDefaults] floatForKey: @"ROIRegionOpacity"];
			
			self.name = NSLocalizedString( @"Region", nil);
		}
		else if (type == tLayerROI)
		{
			layerReferenceFilePath = @"";
			[layerReferenceFilePath retain];
			layerImage = nil;
//			layerImageWhenSelected = nil;
			layerPixelSpacingX = 1.0 / 72.0 * 25.4; // 1/72 inches in millimeters
			layerPixelSpacingY = layerPixelSpacingX;
			self.name = NSLocalizedString( @"Layer", nil);
			textualBoxLine1 = @"";
			textualBoxLine2 = @"";
			textualBoxLine3 = @"";
			textualBoxLine4 = @"";
			textualBoxLine5 = @"";
			textualBoxLine6 = @"";
            textualBoxLine7 = @"";
            textualBoxLine8 = @"";
			
			[textualBoxLine1 retain];
			[textualBoxLine2 retain];
			[textualBoxLine3 retain];
			[textualBoxLine4 retain];
			[textualBoxLine5 retain];
			[textualBoxLine6 retain];
            [textualBoxLine7 retain];
            [textualBoxLine8 retain];
			
			while ([ctxArray count])
                [self deleteTexture: [ctxArray lastObject]];
			//needsLoadTexture2 = NO;
		}
		else
		{
			self.name = NSLocalizedString( @"Unnamed", nil);
		}
		
		displayTextualData = YES;
		
		if ([[NSUserDefaults standardUserDefaults] integerForKey: ANNOTATIONS_KEY] == ANNOTATIONS_NONE)
		{
			[[NSUserDefaults standardUserDefaults] setInteger: ANNOTATIONS_GRAPHICS forKey: ANNOTATIONS_KEY];
			[DCMView setDefaults];
		}
        
        [self setObservers];
    }

    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification
                                                            object: self
                                                          userInfo: nil];

    return self;
}

-(void)updateLabelFont
{
    [stringTextureCache removeAllObjects];
    [curView setNeedsDisplay: YES];
}

- (StringTexture*) stringTextureForString: (NSString*) str
{
    if (stringTextureCache == nil)
    {
        stringTextureCache = [[NSCache alloc] init];
        stringTextureCache.countLimit = 50;
    }
    
    StringTexture *sT = [stringTextureCache objectForKey: str];
    if (sT == nil)
    {
        NSMutableDictionary *attrib = [NSMutableDictionary dictionary];
        
        NSFont *tempLabelFont =
            [NSFont fontWithName: [[NSUserDefaults standardUserDefaults] stringForKey: @"LabelFONTNAME"]
                            size: [[NSUserDefaults standardUserDefaults] floatForKey: @"LabelFONTSIZE"]];
        
        [attrib setObject: tempLabelFont forKey:NSFontAttributeName];
        [attrib setObject: [NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        
        sT = [[[StringTexture alloc] initWithString: str withAttributes: attrib] autorelease];
        [sT setAntiAliasing: YES];
        [sT genTextureWithBackingScaleFactor: curView.window.backingScaleFactor];
        
        [stringTextureCache setObject: sT forKey: str];
    }
    
    return sT;
}

- (long) maxStringWidth: (NSString*) str
                    max: (long) max
{
	if (str.length == 0)
        return max;
    
	long temp = [[self stringTextureForString: str] texSize].width;
    
	if (temp > max)
        max = temp;
	
	return max;
}

#define MAXLENGTH 300

- (void) glStr: (NSString*) str
              : (float) x
              : (float) y
              : (float) line
{
	if (str.length == 0)
        return;
    
    if (str.length > MAXLENGTH)
        str = [str substringToIndex: MAXLENGTH];

    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
	
	line *= fontHeight * curView.window.backingScaleFactor;
	
	float xx = x;
	float yy = y + line;
	
    StringTexture *sT= [self stringTextureForString: str];
    
#ifdef WITH_OPENGL_32
    //GLenum cap = GL_TEXTURE_RECTANGLE;
#else
    GLenum cap = GL_TEXTURE_RECTANGLE_EXT;
    checkOpenGLErrors(__LINE__);
    glEnable(cap);
#endif
    checkOpenGLErrors(__LINE__);

//    glEnable(GL_BLEND);
//    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
    
    long xc = xx - 2*curView.window.backingScaleFactor;
    long yc = yy - [sT texSize].height;
    
#if 0 // def WITH_OPENGL_32
    // TODO: maybe draw only once
#else
    renderer_setTextColor(0.0f, 0.0f, 0.0f, 1.0f); // black
    [sT drawAtPoint: NSMakePoint(xc+1, yc+1)];
#endif

    renderer_setTextColor(1.0f, 1.0f, 1.0f, 1.0f); // white
    [sT drawAtPoint: NSMakePoint(xc, yc)];
    
//    glDisable(GL_BLEND);
#ifndef WITH_OPENGL_32
    glDisable (cap);
#endif
}

-(float) EllipseArea
{
	return fabs (M_PI * rect.size.width*2. * rect.size.height*2.) / 4.;
}

-(float) ballVolume
{
    if (self.pix.sliceInterval == 0)
        return 0.0;
    
    return fabs(M_PI * rect.size.width * rect.size.width * rect.size.width) * 4. / 3.;
}

-(float) plainArea
{
    if (textureBuffer == nil)
        return 0;
    
	long x = 0;
	for (long i = 0; i < textureWidth*textureHeight ; i++ )
	{
		if (textureBuffer[i] != 0)
            x++;
	}
	
	return x;
}

-(float) Area: (NSMutableArray*) pts
{
    double area = 0;
    long count = pts.count;
    
    for (long i = 0 ; i < count ; i++ )
    {
        long j = (i + 1) % count;
        
        MyPoint *a = [pts objectAtIndex:i], *b = [pts objectAtIndex:j];
        
        area += a.x * b.y;
        area -= a.y * b.x;
    }
    
    area *= 0.5f;
   
   return fabs( area );
}

-(float) Area
{
	if (type == tPlain)
		return [self plainArea];
	
	return [self Area: [self splinePoints]];
}

- (double) angleBetween2Lines: (NSPoint) line1pt1
                             : (NSPoint) line1pt2
                             : (NSPoint) line2pt1
                             : (NSPoint) line2pt2
{
    double angle1 = atan2(line1pt1.y - line1pt2.y, line1pt1.x - line1pt2.x);
    double angle2 = atan2(line2pt1.y - line2pt2.y, line2pt1.x - line2pt2.x);
    
    return (angle1 - angle2) * (180. / M_PI);
}

// Returns angle in degrees
-(float) Angle: (NSPoint) p2
              : (NSPoint) p1
              : (NSPoint) p3
{
    double px = 1;
    double py = 1;
    
    if (pixelSpacingX != 0 && pixelSpacingY != 0) {
        px = pixelSpacingX;
        py = pixelSpacingY;
    }
    
    double ax = p2.x*px - p1.x*px;
    double ay = p2.y*py - p1.y*py;
    double bx = p3.x*px - p1.x*px;
    double by = p3.y*py - p1.y*py;
    
    if (ax == 0 && ay == 0)
        return 0;
    
    double val = ((ax * bx) + (ay * by)) / (sqrt(ax*ax + ay*ay) * sqrt(bx*bx + by*by));
    
    return glm::degrees( acosf(val) );
}

- (float) Magnitude: (NSPoint) Point1
                   : (NSPoint) Point2
{
    NSPoint Vector;

    Vector.x = Point2.x - Point1.x;
    Vector.y = Point2.y - Point1.y;

    return sqrt( Vector.x * Vector.x + Vector.y * Vector.y);
}

// in cm or in pixels if no pixelspacing values
-(float) Length: (NSPoint) measureA
               : (NSPoint) measureB
{
	return [self LengthFrom: measureA to : measureB inPixel: NO];
}

// in cm or in pixels if no pixelspacing values
-(float) LengthFrom: (NSPoint) measureA
                 to: (NSPoint) measureB
            inPixel: (BOOL) inPixel
{
    double coteA = fabs(measureA.x - measureB.x);
    double coteB = fabs(measureA.y - measureB.y);
    
    if (pixelSpacingX != 0 && pixelSpacingY != 0)
    {
        if (inPixel == NO)
        {
            coteA *= pixelSpacingX;
            coteB *= pixelSpacingY;
        }
    }

    double measureLength;
    if (coteA == 0)
        measureLength = coteB;
    else if (coteB == 0)
        measureLength = coteA;
    else
        measureLength = coteB / (sin (atan( coteB / coteA)));
    
    if (pixelSpacingX != 0 && pixelSpacingY != 0)
    {
        if (inPixel == NO)
            measureLength /= 10.0;
    }
	
	return measureLength;
}

-(NSPoint) ProjectionPointLine:(NSPoint) Point
                              :(NSPoint) startPoint
                              :(NSPoint) endPoint
{
    double LineMag, U;
    NSPoint Intersection;
 
    LineMag = [self Magnitude: endPoint
                             : startPoint];
 
    U = ( ( ( Point.x - startPoint.x ) * ( endPoint.x - startPoint.x ) ) +
        ( ( Point.y - startPoint.y ) * ( endPoint.y - startPoint.y ) ) );
		
	U /= ( LineMag * LineMag );
    
    Intersection.x = startPoint.x + U * ( endPoint.x - startPoint.x );
    Intersection.y = startPoint.y + U * ( endPoint.y - startPoint.y );
	
    return Intersection;
}

- (int) DistancePointLine:(NSPoint) pt
                         :(NSPoint) startPoint
                         :(NSPoint) endPoint
                         :(float*) Distance
{
    double LineMag, U;
    NSPoint Intersect;
 
    LineMag = [self Magnitude: endPoint
                             : startPoint];
 
    U = ( ( ( pt.x - startPoint.x ) * ( endPoint.x - startPoint.x ) ) +
        (   ( pt.y - startPoint.y ) * ( endPoint.y - startPoint.y ) ) );
		
	U /= ( LineMag * LineMag);
	
    if (U < -0.01f || U > 1.01f)
	{
		*Distance = 100;
		return 0;
	}
	
    Intersect.x = startPoint.x + U * ( endPoint.x - startPoint.x );
    Intersect.y = startPoint.y + U * ( endPoint.y - startPoint.y );

    *Distance = [self Magnitude: pt
                               : Intersect];
 
    return 1;
}

- (NSPoint) lowerRightPoint
{
	double xmin, xmax, ymin, ymax;
	NSPoint result = NSZeroPoint;
	
	switch (type)
	{
		case tMeasure:
			if ([[points objectAtIndex:0] x] < [[points objectAtIndex:1] x])
                result = [[points objectAtIndex:1] point];
			else
                result = [[points objectAtIndex:0] point];
            
            break;
			
		case tPlain:
			result.x = textureDownRightCornerX;
			result.y = textureDownRightCornerY;
			break;
			
		case tArrow:
			result = [[points objectAtIndex:1] point];
            break;
		
		case tAngle:
			result = [[points objectAtIndex:1] point];
            break;
            
		case tDynAngle:
		case tAxis:
		case tClosedPolygon:
		case tOpenPolygon:
		case tPencil:
        case tTAGT:
		
			xmin = xmax = [[points objectAtIndex:0] x];
			ymin = ymax = [[points objectAtIndex:0] y];
			
			for (MyPoint *p in points)
			{
				if ([p x] < xmin) xmin = [p x];
				if ([p x] > xmax) xmax = [p x];
				if ([p y] < ymin) ymin = [p y];
				if ([p y] > ymax) ymax = [p y];
			}
			
			result.x = xmax;
			result.y = ymax;
            break;
		
		case t2DPoint:
		case tText:
			result = rect.origin;
            break;
		
        case tOval:
        case tOvalAngle:
        case tBall:
			result.x = NSMidX(rect) - rect.size.width/4;
			result.y = NSMaxY(rect);
            break;
		
		case tROI:
			result.x = NSMaxX(rect);
			result.y = NSMaxY(rect);
            break;

		case tLayerROI:
			result = [[points objectAtIndex:2] point];
            break;
            
        default:
            N2LogStackTrace( @"***** no lowerRightPoint for this type of ROI");
            break;
	}
	
	return result;
}

- (NSMutableArray*) points
{
    return [self pointsWithRotation: YES];
}

- (NSMutableArray*) pointsWithRotation: (BOOL) withRotation
{
	if (type == t2DPoint)
	{
		NSMutableArray *tempArray = [NSMutableArray array];
		MyPoint	*tempPoint = [[MyPoint alloc] initWithPoint: NSMakePoint( NSMinX(rect), NSMinY(rect))];
		[tempArray addObject:tempPoint];
		[tempPoint release];
		
		return tempArray;
	}
	
	if (type == tROI)
	{
		NSMutableArray *tempArray = [NSMutableArray array];
		MyPoint *tempPoint;
		
		tempPoint = [[MyPoint alloc] initWithPoint: NSMakePoint( NSMinX(rect), NSMinY(rect))];
		[tempArray addObject:tempPoint];
		[tempPoint release];
		
		tempPoint = [[MyPoint alloc] initWithPoint: NSMakePoint( NSMinX(rect), NSMaxY(rect))];
		[tempArray addObject:tempPoint];
		[tempPoint release];
		
		tempPoint = [[MyPoint alloc] initWithPoint: NSMakePoint( NSMaxX(rect), NSMaxY(rect))];
		[tempArray addObject:tempPoint];
		[tempPoint release];
		
		tempPoint = [[MyPoint alloc] initWithPoint: NSMakePoint( NSMaxX(rect), NSMinY(rect))];
		[tempArray addObject:tempPoint];
		[tempPoint release];
		
		return tempArray;
	}
	
    if ((type == tOval) ||
        (type == tOvalAngle) ||
        (type == tBall))
	{
		NSMutableArray *tempArray = [NSMutableArray array];
		MyPoint *tempPoint = nil;
		float angle, ratio = [[self pix] pixelRatio];
		
        if (ratio == 0)
            ratio = 1.0;
        
		for (int i = 0; i < CIRCLE_RESOLUTION ; i++ )
		{
			angle = i * 2 * M_PI / CIRCLE_RESOLUTION;
		  
            NSPoint pt = NSMakePoint(rect.origin.x + rect.size.width*cos(angle),
                                     rect.origin.y + rect.size.height*sin(angle));
            if (withRotation)
            {
                float rotRad = glm::radians(roiRotationDeg);
                
                float newx = cos( rotRad) * (pt.x - rect.origin.x) - sin( rotRad) * (pt.y - rect.origin.y) * ratio;
                float newy = sin( rotRad) * (pt.x - rect.origin.x) + cos( rotRad) * (pt.y - rect.origin.y) * ratio;
                
                pt = NSMakePoint( newx, newy);
                
                pt.x += rect.origin.x;
                pt.y /= ratio;
                pt.y += rect.origin.y;
            }
            
			tempPoint = [[MyPoint alloc] initWithPoint:pt];
			[tempArray addObject:tempPoint];
			[tempPoint release];
		}
		
		return tempArray;
	}
	
#ifndef MIELE_LIGHT
	if (type == tPlain)
	{
		NSMutableArray *tempArray = [ITKSegmentation3D extractContour:textureBuffer
                                                                width:textureWidth
                                                               height:textureHeight];
		
		for (MyPoint *pt in tempArray)
			[pt move: textureUpLeftCornerX :textureUpLeftCornerY];
		
		return tempArray;
	}
#endif
	
	return points;
}

- (void) setPoints: (NSMutableArray*) pts
{
	if (type == tROI ||
        type == tBall ||
        type == tOval ||
        type == t2DPoint ||
        type == tOvalAngle)  // Doesn't make sense to set points for these types.
    {
         return;
    }
	
	if (locked)
        return;
	
	[points removeAllObjects];
	for ( long i = 0; i < [pts count]; i++ )
		[points addObject: [pts objectAtIndex: i]];
	
	return;
}

- (void) setTextBoxOffset:(NSPoint) o
{
	offsetTextBox_x += o.x;
	offsetTextBox_y += o.y;
}

- (void) addPointUnderMouse: (NSPoint) pt scale:(float) scale
{
    float backingScaleFactor = curView.window.backingScaleFactor;
    
    @try {
	switch( type)
	{
		case tOpenPolygon:
		case tClosedPolygon:
		case tPencil:
		{
			BOOL nearPoint = NO;
			
			// Is it near any existing points?
			for (MyPoint *p in points)
			{
				if ([p isNearToPoint: pt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
					nearPoint = YES;
			}
			
			if (nearPoint == NO)
			{
				NSMutableArray *correspondingSegments = nil;
				NSMutableArray *splinePoints2 = [self splinePoints: scale correspondingSegmentArray: &correspondingSegments];
				
				if ([splinePoints2 count] > 0)
				{
					for (int i = 0; i < ([splinePoints2 count] - 1); i++ )
					{					
						float distance = 0.;

						[self DistancePointLine:pt
                                               :[[splinePoints2 objectAtIndex:i] point]
                                               :[[splinePoints2 objectAtIndex:(i+1)] point]
                                               :&distance];
						
						if (distance*scale < 5.0)
						{
							// Add a point here, if distant from existing points.

                            if (correspondingSegments)
								[points insertObject: [MyPoint point: pt]
                                             atIndex: [[correspondingSegments objectAtIndex: i] intValue] +1];
                            else
								[points insertObject: [MyPoint point: pt]
                                             atIndex: i +1];
							break;
						}
					}
                        
                    if (type == tClosedPolygon || type == tPencil)
                    {
                        float distance = 0;
                        [self DistancePointLine:pt
                                               :[[splinePoints2 lastObject] point]
                                               :[[splinePoints2 objectAtIndex: 0] point]
                                               :&distance];
                        
                        if (distance*scale < 5.0)
                        {
                            // Add a point here, if distant from existing points.
                            
                            if (correspondingSegments)
                                [points addObject: [MyPoint point: pt]];
                            else
                                [points addObject: [MyPoint point: pt]];
                            break;
                        }
                    }

                    [self recompute];
                    [curView setNeedsDisplay: YES];
				}
			}
		}
            break;

        default:
            break;
	}
    }
    @catch (NSException *exception) {
        N2LogException( exception);
    }
}

static float Sign(NSPoint p1, NSPoint p2, NSPoint p3)
{
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

+ (BOOL) point: (NSPoint) pt
    inTriangle: (NSPoint) v1
              : (NSPoint) v2
              : (NSPoint) v3
{
    BOOL b1, b2, b3;
    
    b1 = Sign(pt, v1, v2) < 0.0f;
    b2 = Sign(pt, v2, v3) < 0.0f;
    b3 = Sign(pt, v3, v1) < 0.0f;
    
    return ((b1 == b2) && (b2 == b3));
}

- (ROI_mode) clickInROI:(NSPoint) pt
                       :(float) offsetx
                       :(float) offsety
                       :(float) scale
                       :(BOOL) testDrawRect
{
	NSRect arect;
	ROI_mode imode = ROI_sleep;
	
    if (hidden)
        return ROI_sleep;
    
	if (selectable == NO)
		return ROI_sleep;
	
	if (mode == ROI_drawing)
		return ROI_sleep;
	
	clickInTextBox = NO;
	previousMode = mode;
    
    @try
    {
#define NEIGHBORHOODRADIUS 10.0
    float neighborhoodRad = NEIGHBORHOODRADIUS * curView.window.backingScaleFactor;
    float backingScaleFactor = curView.window.backingScaleFactor;
	
	if (testDrawRect)
	{
		NSPoint cPt = [curView ConvertFromGL2View: pt];
		
		if (NSPointInRect( cPt, drawRect))
		{
			imode = ROI_selected;
			clickInTextBox = YES;
		}
	}
	//else
	{
		switch (type)
		{
			case tLayerROI:
			{
				NSPoint p1, p2, p3, p4;
				p1 = [[points objectAtIndex:0] point];
				p2 = [[points objectAtIndex:1] point];
				p3 = [[points objectAtIndex:2] point];
				p4 = [[points objectAtIndex:3] point];
								
				if ([self isPoint:pt inRectDefinedByPointA:p1 pointB:p2 pointC:p3 pointD:p4])
				{
					float width;
					float height;
					NSBitmapImageRep *bitmap;
//					if (mode==ROI_selected)
//					{
//						bitmap = [[NSBitmapImageRep alloc] initWithData:[layerImageWhenSelected TIFFRepresentation]];
//						width = [layerImageWhenSelected size].width;
//						height = [layerImageWhenSelected size].height;
//					}
//					else
					{
						bitmap = [[NSBitmapImageRep alloc] initWithData:[layerImage TIFFRepresentation]];
                        width = bitmap.pixelsWide;
                        height = bitmap.pixelsHigh;
					}
					
					// base vectors of the layer image coordinate system
					NSPoint v, w;
					v.x = (p2.x - p1.x);
					v.y = (p2.y - p1.y);
					float l = sqrt(v.x*v.x + v.y*v.y);
					v.x /= l;
					v.y /= l;
					
					float scaleRatio = width / l; // scale factor between the ROI (actual display size) and the texture image (stored)
					
					w.x = (p4.x - p1.x);
					w.y = (p4.y - p1.y);
					l = sqrt(w.x*w.x + w.y*w.y);
					w.x /= l;
					w.y /= l;
					
					// clicked point
					NSPoint c;
					c.x = pt.x - p1.x;
					c.y = pt.y - p1.y;

					// point in the layer image coordinate system
					float y = (c.y-c.x*(v.y/v.x))/(w.y-w.x*(v.y/v.x));
					float x = (c.x-y*w.x)/v.x;
					
					x *= scaleRatio;
					y *= scaleRatio;
					
					// Test if the clicked pixel is not transparent (otherwise the ROI won't be selected)
					// define a neighborhood around the point					
					float xi, yj;
					BOOL found = NO;

					for (int i=-neighborhoodRad; i<=neighborhoodRad && !found; i++ )
					{
						for (int j=-neighborhoodRad; j<=neighborhoodRad && !found; j++ )
						{
							xi = x+i;
							yj = y+j;
							if (xi >= 0.0 &&
                                yj >= 0.0 &&
                                xi < width &&
                                yj < height)
							{
								NSColor *pixelColor = [bitmap colorAtX:xi y:yj];
								if ([pixelColor alphaComponent]>0.0)
									found = YES;
							}
						}
					}
					if (found)
						imode = ROI_selected;

                    [bitmap release];
				}
			}
                break;

            case tPlain:
				if (pt.x > textureUpLeftCornerX &&
                    pt.x < textureDownRightCornerX &&
                    pt.y > textureUpLeftCornerY &&
                    pt.y < textureDownRightCornerY)
				{
                    if (textureBuffer[ (int) pt.x - textureUpLeftCornerX + textureWidth * ( (int) pt.y - textureUpLeftCornerY)] > 1)
                    {
                        if (mode == ROI_selected ||
                            mode == ROI_selectedModify ||
                            mode == ROI_drawing)
                        {
                            imode = mode;
                            if ([curView currentTool] == tPlain)
                                imode = ROI_selectedModify; // tPlain ROIs can only be modified by the tPlain tool
                        }
                        else
                        {
                            imode = ROI_selected;
                        }
                    }
				}
				break;
//			case tOval:
//				arect = NSMakeRect( rect.origin.x -rect.size.width -(neighborhoodRad/2)/scale, rect.origin.y -rect.size.height -(neighborhoodRad/2)/scale, 2*rect.size.width + neighborhoodRad/scale, 2*rect.size.height + neighborhoodRad/scale);
//				
//				if (NSPointInRect( pt, arect))
//                    imode = ROI_selected;
//			break;
			
			
//			case tROI:
//				arect = NSMakeRect( rect.origin.x -(neighborhoodRad/2), rect.origin.y-(neighborhoodRad/2), rect.size.width+neighborhoodRad, rect.size.height+neighborhoodRad);
//				
//				if (NSPointInRect( pt, arect))
//                    imode = ROI_selected;
//			break;
			
            case tROI:
            {
				float distance;
				NSArray *pts = [self points];
				
				if (pts.count > 0)
				{
					for (int i = 0; i < [pts count]; i++ )
					{
                        if (i == pts.count-1) // last point
                            [self DistancePointLine:pt
                                                   :[[pts objectAtIndex:i] point]
                                                   :[[pts objectAtIndex: 0] point]
                                                   :&distance];
						else
                            [self DistancePointLine:pt
                                                   :[[pts objectAtIndex:i] point]
                                                   :[[pts objectAtIndex:(i+1)] point]
                                                   :&distance];
						
						if (distance*scale < neighborhoodRad/2)
						{
							imode = ROI_selected;
							break;
						}
					}
				}
			}
                break;
                
			case t2DPoint:
				arect = NSMakeRect(rect.origin.x - neighborhoodRad/scale,
                                   rect.origin.y - neighborhoodRad/scale,
                                   neighborhoodRad*2/scale,
                                   neighborhoodRad*2/scale);
				
				if (NSPointInRect( pt, arect))
                    imode = ROI_selected;

                break;
			
			case tText:
				arect = NSMakeRect(rect.origin.x - backingScaleFactor*rect.size.width/(2*scale),
                                   rect.origin.y - backingScaleFactor*rect.size.height/(2*scale),
                                   backingScaleFactor*rect.size.width/scale,
                                   backingScaleFactor*rect.size.height/scale);
				
				if (NSPointInRect( pt, arect))
                    imode = ROI_selected;

                break;
			
			case tArrow:
			case tMeasure:
			{
				float distance;

				if (points.count >= 2)
				{
                    [self DistancePointLine:pt
                                           :[[points objectAtIndex:0] point]
                                           :[[points objectAtIndex:1] point]
                                           :&distance];
				
                    if (distance*scale < neighborhoodRad/2)
                        imode = ROI_selected;
				}

                if (type == tArrow) // test arrow head
                {
                    NSPoint ppt = pt;
                    ppt.x -= offsetx;
                    ppt.y -= offsety;
                    
                    ppt.x *= scale;
                    ppt.y *= scale;
                    
                    if ([ROI point:ppt inTriangle:arh[0] :arh[1] :arh[2]])
                        imode = ROI_selected;
                }
			}
                break;
			
            case tOvalAngle:
            case tOval:
			case tOpenPolygon:
			case tAngle:
            case tBall:
			{
				NSMutableArray *splinePoints = [self splinePoints: scale];
				
				if ([splinePoints count] > 0)
				{
					for (int i = 0; i < ([splinePoints count] - 1); i++ )
					{
                        float distance;
						[self DistancePointLine:pt
                                               :[[splinePoints objectAtIndex:i] point]
                                               :[[splinePoints objectAtIndex:(i+1)] point]
                                               :&distance];
						
						if (distance*scale < neighborhoodRad/2)
						{
							imode = ROI_selected;
							break;
						}
                    }
                    
                    if (type == tBall)
                    {
                        // The inside of the oval also selects the ROI
                        float distance = [self Magnitude: pt
                                                        : rect.origin];
#ifndef NDEBUG
                        NSLog(@"ROI.m:%i %@ %p distance:%.1f, %.1f", __LINE__,
                              NSStringFromSelector(_cmd),
                              self,
                              distance,
                              scale/backingScaleFactor);
#endif
                        
//                        if ( [[MyPoint point:pt] isNearToPoint:rect.origin
//                                                              :scale/backingScaleFactor
//                                                              :[[curView curDCM] pixelRatio]])
//                        {
//                            NSLog(@"ROI.m:%i %p A", __LINE__, self);
////                            imode = ROI_selected;
////                            break;
//                        }
                        
                        if (distance*scale < rect.size.width)
                        {
#ifndef NDEBUG
                            NSLog(@"ROI.m:%i %p B", __LINE__, self);
#endif
                            imode = ROI_selected;
                            break;
                        }
                    }
                    
                    if (type == tOvalAngle)
                    {
                        NSPoint aPt;
                        float distance;
                        
                        aPt.x = rect.origin.x + armScale*rect.size.width*cos(ovalAngle[0]);
                        aPt.y = rect.origin.y + armScale*rect.size.height*sin(ovalAngle[0]);
                        
                        [self DistancePointLine:pt
                                               :aPt
                                               :rect.origin
                                               :&distance];
                        
                        if (distance*scale < neighborhoodRad/2)
                            imode = ROI_selected;
                        
                        aPt.x = rect.origin.x + armScale*rect.size.width*cos(ovalAngle[1]);
                        aPt.y = rect.origin.y + armScale*rect.size.height*sin(ovalAngle[1]);
                        
                        [self DistancePointLine:pt
                                               :aPt
                                               :rect.origin
                                               :&distance];

                        if (distance*scale < neighborhoodRad/2) {
                            imode = ROI_selected;
                            //break; // TBC
                        }
                    }
                    
                    // Test ROI center
                    if (imode != ROI_selected)
                    {
                        float distance = [self Magnitude: pt
                                                        : rect.origin];
                        if (distance*scale < neighborhoodRad/2)
						{
							imode = ROI_selected;
							break;
						}
                    }
				} // if
			}
                break;
			
			case tDynAngle:
			case tAxis:
			case tClosedPolygon:
			case tPencil:
            case tTAGT:
			{
				float distance;
				NSMutableArray *splinePoints = [self splinePoints: scale];
				
				if ([splinePoints count] > 0)
				{
					int ii;
					for (ii = 0; ii < ([splinePoints count] - 1); ii++ )
					{					
						[self DistancePointLine:pt
                                               :[[splinePoints objectAtIndex:ii] point]
                                               :[[splinePoints objectAtIndex:(ii+1)] point]
                                               :&distance];

                        if (distance*scale < neighborhoodRad/2)
						{
							imode = ROI_selected;
							break;
						}
					}
					
					[self DistancePointLine:pt
                                           :[[splinePoints objectAtIndex:ii] point]
                                           :[[splinePoints objectAtIndex:0] point]
                                           :&distance];
                    
					if (distance*scale < neighborhoodRad/2)
                        imode = ROI_selected;
				}
			}
                break;

//			case tClosedPolygon:
//			case tPencil:
//			{
//				int count = 0;
//				
//				for (j = 0; j < 5; j++)
//				{
//					NSPoint selectPt = pt;
//					
//					switch(j)
//					{
//						case 0: break;
//						case 1: selectPt.x += 5.0/scale; break;
//						case 2: selectPt.x -= 5.0/scale; break;
//						case 3: selectPt.y += 5.0/scale; break;
//						case 4: selectPt.y -= 5.0/scale; break;
//					}
//					for (i = 0; i < [points count]; i++)
//					{
//						NSPoint p1 = [[points objectAtIndex:i] point];
//						NSPoint p2 = [[points objectAtIndex:(i+1)%[points count]] point];
//						double intercept;
//						
//						if (selectPt.y > MIN(p1.y, p2.y) && selectPt.y <= MAX(p1.y, p2.y) && selectPt.x <= MAX(p1.x, p2.x) && p1.y != p2.y)
//						{
//							intercept = (selectPt.y-p1.y)*(p2.x-p1.x)/(p2.y-p1.y)+p1.x;
//							if (p1.x == p2.x || selectPt.x <= intercept)
//								count = !count;
//						}
//					}
//					
//					if (count)
//					{
//						imode = ROI_selected;
//						break;
//					}
//				}
//				break;
//			}
            default:
                break;
		}
	}
	
//	if (imode == ROI_selected)
	{
		MyPoint *tempPoint = [[[MyPoint alloc] initWithPoint: pt] autorelease];
		NSPoint aPt;
		
		switch (type)
		{
//			case tPlain:
//				imode = ROI_selectedModify;
//			break;

            case tOvalAngle:
			case tOval:
				selectedModifyPoint = 0;
				
				aPt.x = rect.origin.x - rect.size.width;
                aPt.y = rect.origin.y - rect.size.height;
                aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 1;
				
				aPt.x = rect.origin.x - rect.size.width;
                aPt.y = NSMaxY(rect);
                aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 2;
				
				aPt.x = NSMaxX(rect);
                aPt.y = NSMaxY(rect);
                aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 3;
				
				aPt.x = NSMaxX(rect);
                aPt.y = rect.origin.y - rect.size.height;
                aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 4;
                
                if (type == tOvalAngle)
                {
                    aPt.x = rect.origin.x + armScale*rect.size.width*cos(ovalAngle[0]);
                    aPt.y = rect.origin.y + armScale*rect.size.height*sin(ovalAngle[0]);
                    aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
                    if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                        selectedModifyPoint = 5;
                    
                    aPt.x = rect.origin.x + armScale*rect.size.width*cos(ovalAngle[1]);
                    aPt.y = rect.origin.y + armScale*rect.size.height*sin(ovalAngle[1]);
                    aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
                    if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                        selectedModifyPoint = 6;
                }
				
				if (selectedModifyPoint)
                    imode = ROI_selectedModify;

                break;
			
			case tROI:
				selectedModifyPoint = 0;
				
				aPt.x = NSMinX(rect);
                aPt.y = NSMinY(rect);
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 1;
				
				aPt.x = NSMinX(rect);
                aPt.y = NSMaxY(rect);
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 2;
				
				aPt.x = NSMaxX(rect);
                aPt.y = NSMaxY(rect);
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 3;
				
				aPt.x = NSMaxX(rect);
                aPt.y = NSMinY(rect);
				if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                    selectedModifyPoint = 4;
				
				if (selectedModifyPoint)
                    imode = ROI_selectedModify;
                
                break;
			
			case tAngle:
			case tArrow:
			case tMeasure:
			case tDynAngle:
			case tAxis:
			case tClosedPolygon:
			case tOpenPolygon:
			case tPencil:
            case tTAGT:
                {
                    if (mode != ROI_selectedModify)
                        selectedModifyPoint = -1;

                    //NSUInteger modifierFlags = [[[NSApplication sharedApplication] currentEvent] modifierFlags];
                    
                    for (int i = 0; i < [points count]; i++)
                    {
                        if ([[points objectAtIndex: i] isNearToPoint: pt
                                                                    : scale/backingScaleFactor
                                                                    : [[curView curDCM] pixelRatio]])
                        {
                            imode = ROI_selectedModify;
                            selectedModifyPoint = i;
                        }
                    }
                }
                break;
                
            default:
                break;
		} // switch
		
		clickPoint = pt;
	}
	
    }
    @catch (NSException *exception) {
        N2LogException( exception);
    }

	return imode;
}

- (void) displayPointUnderMouse:(NSPoint) pt
                               :(float) offsetx
                               :(float) offsety
                               :(float) scale
{
    if (hidden)
        return;
    
	MyPoint	*tempPoint = [[[MyPoint alloc] initWithPoint: pt] autorelease];
	
	int previousPointUnderMouse = PointUnderMouse;
	
	PointUnderMouse = -1;
	NSPoint aPt;
	float backingScaleFactor = curView.window.backingScaleFactor;
    
	switch (type)
	{
        case tBall:
		case tOval:
        case tOvalAngle:
			aPt.x = rect.origin.x - rect.size.width;
            aPt.y = rect.origin.y - rect.size.height;
            aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
            if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 1;
			
			aPt.x = rect.origin.x - rect.size.width;
            aPt.y = NSMaxY(rect);
            aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 2;
			
			aPt.x = NSMaxX(rect);
            aPt.y = NSMaxY(rect);
            aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 3;
			
			aPt.x = NSMaxX(rect);
            aPt.y = rect.origin.y - rect.size.height;
            aPt = [self rotatePoint: aPt withAngle: roiRotationDeg aroundCenter: rect.origin];
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 4;

            break;
		
		case tROI:
			aPt.x = NSMinX(rect);
            aPt.y = NSMinY(rect);
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 1;
			
			aPt.x = NSMinX(rect);
            aPt.y = NSMaxY(rect);
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 2;
			
			aPt.x = NSMaxX(rect);
            aPt.y = NSMaxY(rect);
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 3;
			
			aPt.x = NSMaxX(rect);
            aPt.y = NSMinY(rect);
			if ([tempPoint isNearToPoint: aPt :scale/backingScaleFactor :[[curView curDCM] pixelRatio]])
                PointUnderMouse = 4;
            
            break;
		
		case tAngle:
		case tArrow:
		case tMeasure:
		case tDynAngle:
		case tAxis:
		case tClosedPolygon:
		case tOpenPolygon:
		case tPencil:
        case tTAGT:
            {
//                NSLog(@"%s %d, %lu points, pt:%@", __FUNCTION__, __LINE__,
//                      (unsigned long)[points count],
//                      NSStringFromPoint(pt));

                float scale3 = scale/backingScaleFactor;
                float ratio3 = [[curView curDCM] pixelRatio];

                for (int i = 0; i < [points count]; i++)
                {
                    if ([[points objectAtIndex: i] isNearToPoint:pt :scale3 :ratio3])
                    {
                        PointUnderMouse = i;
                        break;
                    }
                }
            }
            break;
            
        default:
            break;
	}
	
	if (PointUnderMouse != previousPointUnderMouse)
	{
		[curView setNeedsDisplay: YES];
	}
}

- (BOOL)mouseRoiDown:(NSPoint)pt :(float)scale
{
	return [self mouseRoiDown:pt :[curView curImage] :scale];
}

- (BOOL)mouseRoiDownIn:(NSPoint)pt :(int)slice :(float)scale
{
    float backingScaleFactor = curView.window.backingScaleFactor;
	MyPoint	*mypt;
	
	if (selectable == NO)
	{
		self.ROImode = ROI_sleep;
		return NO;
	}
	
	if (mode == ROI_sleep)
		self.ROImode = ROI_drawing;
	
	if (locked)
		return NO;
	
	if ([self.comments isEqualToString: @"morphing generated"] )
        self.comments = @"";
	
    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	
	if (type == tPlain)
	{
		if (textureFirstPoint==0)
		{
			textureUpLeftCornerX = pt.x;
			textureUpLeftCornerY = pt.y;
			textureDownRightCornerX = pt.x+1;
			textureDownRightCornerY = pt.y+1;
			textureFirstPoint = 1;
			textureWidth = 2;
			textureHeight = 2;
			textureBuffer = (unsigned char *)calloc(1, textureWidth*textureHeight*sizeof(unsigned char));
			
            [self textureBufferHasChanged];
            
			self.ROImode = ROI_drawing;
		}
		else
		{
			self.ROImode = ROI_selected;
		}
		
		previousPoint = pt;
		
		return NO;
	}
	
	if (type == t2DPoint)
	{
		rect.origin.x = pt.x;
		rect.origin.y = pt.y;
		rect.size.height = 0;
		rect.size.width = 0;
		
		self.ROImode = ROI_selected;
		
		return NO;
	}
	else if (type == tText)
	{
		rect.size = [stringTex frameSize];
		rect.origin.x = pt.x;   // - rect.size.width/2;
		rect.origin.y = pt.y;   // - rect.size.height/2;
		
		if (pixelSpacingX != 0 && pixelSpacingY != 0 )
			rect.size.height *= pixelSpacingX/pixelSpacingY;
		
		self.ROImode = ROI_selected;
		
		return NO;
	}
	else if (type == tOval ||
             type == tOvalAngle ||
             type == tROI ||
             type == tBall)
	{
		rect.origin = pt;
		rect.size.width = 0;
		rect.size.height = 0;
		
		self.ROImode = ROI_drawing;
		
		return NO;
	}
	else if (type == tArrow ||
             type == tMeasure)
	{
		mypt = [[MyPoint alloc] initWithPoint: pt];
		[points addObject: mypt];
		[mypt release];
		
		mypt = [[MyPoint alloc] initWithPoint: pt];
		[points addObject: mypt];
		[mypt release];
		
		self.ROImode = ROI_drawing;
		
		return NO;
	}
    else if (type == tTAGT)
	{
        mypt = [MyPoint point: pt];
		[points addObject: mypt];
        
        mypt = [MyPoint point: pt];
		[points addObject: mypt];
        
		self.ROImode = ROI_drawing;
		
		return NO;
	}
//	else if (type == tPencil)
//	{
//		self.ROImode = ROI_selected;
//	}
	else
	{
        //NSLog(@"%s %d, type:%d", __FUNCTION__, __LINE__, type);
		if ([[points lastObject] isNearToPoint: pt : scale/(thickness*backingScaleFactor) :[[curView curDCM] pixelRatio]] == NO)
		{
			mypt = [[MyPoint alloc] initWithPoint: pt];
			
			[points addObject: mypt];
			[mypt release];
			
//			NSLog(@" [ROI, mouseRoiDown] adding point for polygon...");
//			NSLog(@" [ROI, mouseRoiDown] slice : %d", slice);
			[zPositions addObject:[NSNumber numberWithInt:slice]];
			
			clickPoint = pt;
		}
		else	// Click on same point as last object -> STOP drawing
		{
#ifndef NDEBUG
            NSLog(@"%s %d, STOP drawing", __FUNCTION__, __LINE__);
#endif
			self.ROImode = ROI_selected;
		}
		
		if (type == tAngle)
		{
			if ([points count] > 2)
                self.ROImode = ROI_selected;
		}
#if 0  // the point remains red
        if (type == tAxis)
        {
            if ([points count] >= 4)
                self.ROImode = ROI_selected;
        }
#endif
	}
	
	if (type == tPencil)
        return NO;
	
	if (mode == ROI_drawing)
        return YES;

    return NO;
}

- (BOOL)mouseRoiDown:(NSPoint)pt :(int)slice :(float)scale
{
	[roiLock lock];
	
	BOOL result = NO;
	
	@try
	{
		result = [self mouseRoiDownIn:pt :slice :scale];
	}
	@catch (NSException * e)
	{
		NSLog( @"**** mouseRoiDown exception %@", e);
	}
	
	[roiLock unlock];
	
	return result;
}

- (void) flipVertically: (BOOL) vertically
{
	if (locked)
        return;
    
    float new_x, new_y;
	NSMutableArray	*pts = self.points;
	
	if (type == tROI)
	{
		self.isSpline = NO;
	}
	
	if (pts.count > 0)
	{
		if (type == tROI ||
            type == tBall ||
            type == tOval ||
            type == tOvalAngle)
		{
			type = tClosedPolygon;
			[points release];
			points = [pts copy];
		}
		
//		float ratio = [[self pix] pixelRatio];
//		
//		if (ratio == 0)
//			ratio = 1.0;
		
        NSPoint centroid = self.centroid;
        
		for (MyPoint *pt in pts)
		{
            if (vertically)
            {
                new_x = pt.x;
                new_y = -(pt.y - centroid.y) + centroid.y;
			}
            else
            {
                new_x = -(pt.x - centroid.x) + centroid.x;
                new_y = pt.y;
            }
            
			[pt setPoint: NSMakePoint( new_x, new_y)];
		}
		
		[self recompute];
        
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	}
}

- (void) rotate: (float) angleDeg
               : (NSPoint) center
{
	if (locked)
        return;

    float new_x;
    float new_y;
	float intYCenter, intXCenter;
	NSMutableArray *pts = self.points;
	
	if (type == tROI)
		self.isSpline = NO;

    float thetaRad = glm::radians(angleDeg);

    if (type == tOval ||
        type == tOvalAngle)
    {
        roiRotationDeg += angleDeg;
        [self recompute];
        return;
    }
    
	if (pts.count > 0)
	{
        // TODO: remove tOval and tOvalAngle as they were checked before
		if (type == tROI ||
            type == tBall ||
            type == tOval ||
            type == tOvalAngle)
		{
			type = tClosedPolygon;
			[points release];
			points = [pts copy];
		}
		
		intXCenter = center.x;
		intYCenter = center.y;
		
		float ratio = [[self pix] pixelRatio];
		
		if (ratio == 0)
			ratio = 1.0;
		
		for (MyPoint *pt in pts)
		{ 
			new_x = cos(thetaRad) * ([pt x] - intXCenter) - sin(thetaRad) * ([pt y] - intYCenter)  * ratio;
			new_y = sin(thetaRad) * ([pt x] - intXCenter) + cos(thetaRad) * ([pt y] - intYCenter)  * ratio;
			
			[pt setPoint: NSMakePoint( new_x + intXCenter, new_y / ratio + intYCenter)];
		}
		
		[self recompute];
        
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	}
}

- (BOOL)canResize;
{
	if (type == tLayerROI)
		return canResizeLayer;
	else
		return YES;
}

- (void) resize: (float) factor :(NSPoint) center
{
	if (![self canResize])
        return;
	
	if (locked)
        return;
	
    float new_x;
    float new_y;
	float intYCenter, intXCenter;
	NSMutableArray	*pts = self.points;
	
	if (pts.count > 0)
	{
		if (type == tROI ||
            type == tBall ||
            type == tOval ||
            type == tOvalAngle)
		{
			intXCenter = center.x;
			intYCenter = center.y;
			
			rect.origin.y = intYCenter + (rect.origin.y - intYCenter) * factor;
			rect.origin.x = intXCenter + (rect.origin.x - intXCenter) * factor;
			
			rect.size.width *= factor;
			rect.size.height *= factor;
		}
		else
		{
			intXCenter = center.x;
			intYCenter = center.y;
			
			for (MyPoint *pt in pts)
			{ 
				new_x = ([pt x] - intXCenter) * factor;
				new_y = ([pt y] - intYCenter) * factor;
				
				[pt setPoint: NSMakePoint( new_x + intXCenter, new_y + intYCenter)];
			}
		}
		
		[self recompute];
        
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	}
}

- (BOOL) valid
{
	if (mode == ROI_drawing)
        return YES;
	
	switch (type)
	{
        case tPlain:
            if ([self plainArea] == 0)
                return NO;
            
            break;
            
        case tOval:
        case tOvalAngle:
        case tBall:
			if (rect.size.width < 0)
				rect.size.width = -rect.size.width;
			
			if (rect.size.height < 0)
				rect.size.height = -rect.size.height;
			
			if (rect.size.width < 0.2) return NO;
			if (rect.size.height < 0.2) return NO;

            break;
		
		case t2DPoint:
			if (rect.size.width < 0)
			{
				//rect.origin.x = NSMaxX(rect);
				rect.origin.x = rect.origin.x + rect.size.width;
				rect.size.width = 0;
			}
			
			if (rect.size.height < 0)
			{
				//rect.origin.y = NSMaxY(rect);
				rect.origin.y = rect.origin.y + rect.size.height;
				rect.size.height = 0;
			}

            break;
		
		case tText:
		case tROI:
		
			if (rect.size.width < 0)
			{
				rect.origin.x = NSMaxX(rect);
				rect.size.width = -rect.size.width;
			}
			
			if (rect.size.height < 0)
			{
				rect.origin.y = NSMaxY(rect);
				rect.size.height = -rect.size.height;
			}
			
			if (rect.size.width < 0.2) return NO;
			if (rect.size.height < 0.2) return NO;
            
            break;
		
		case tClosedPolygon:
		case tOpenPolygon:
		case tPencil:
			if ([points count] < 3)
                return NO;
            break;
		
		case tAngle:
			if ([points count] < 3)
                return NO;
            break;
		
		case tMeasure:
		case tArrow:
			if ([points count] < 2)
                return NO;
			
			if (ABS([[points objectAtIndex:0] x] - [[points objectAtIndex:1] x]) < 0.2 &&
                ABS([[points objectAtIndex:0] y] - [[points objectAtIndex:1] y]) < 0.2)
            {
                return NO;
            }
            break;
		
		case tDynAngle:
			if ([points count] < 4)
                return NO;
            break;
            
		case tAxis:
			if ([points count] < 4)
                return NO;
            break;
            
        case tTAGT:
            if ([points count] < 6)
                return NO;
            
            // 0-1, 2-3
            
            //Points 2 and must be on the A line
            [points replaceObjectAtIndex: 4 withObject: [MyPoint point: [ROI segmentDistToPoint:[[points objectAtIndex: 0] point]
                                                                                               :[[points objectAtIndex: 1] point]
                                                                                               :[[points objectAtIndex: 5] point]]]];
            
            [points replaceObjectAtIndex: 2 withObject: [MyPoint point: [ROI segmentDistToPoint:[[points objectAtIndex: 0] point]
                                                                                               :[[points objectAtIndex: 1] point]
                                                                                               :[[points objectAtIndex: 3] point]]]];
            break;
            
        default:
            break;
	}
	
	return YES;
}

- (void) resetCache
{
    if (cachedNSPoint) {
        free(cachedNSPoint);
        cachedNSPoint = nil;
    }
    
    [cachedSplinePoints autorelease];
    [cachedSplinePointsWithoutScale autorelease];
    
    cachedSplinePoints = nil;
    cachedSplinePointsWithoutScale = nil;
}

- (void) recompute
{
    [self resetCache];
    
    rmean = rmax = rmin = rdev = rtotal = rLength = -1;
}

- (void) computeZLocation
{
    zLocation = FLT_MIN;
}

- (void) roiMove:(NSPoint) offset :(BOOL) sendNotification
{
	if (locked)
        return;

	if (mode == ROI_selected)
	{
		switch( type)
		{
			case tBall: // TBC
			case tOvalAngle:
			case tOval:
			case tText:
			case t2DPoint:
			case tROI:
				rect = NSOffsetRect( rect, offset.x, offset.y);
                break;
                
			case tDynAngle:
			case tAxis:
			case tClosedPolygon:
			case tOpenPolygon:
			case tMeasure:
			case tArrow:
			case tAngle:
			case tPencil:
			case tLayerROI:
            case tTAGT:
				for (MyPoint *p in points)
                    [p move: offset.x : offset.y];
                break;
			
			case tPlain:
				textureUpLeftCornerX += (int) offset.x;
				textureUpLeftCornerY += (int) offset.y;
				textureDownRightCornerX += (int) offset.x;
				textureDownRightCornerY += (int) offset.y;
                break;
                
            default:
                break;
		}
		
		if (sendNotification)
		{
			[self recompute];
            
            if ([NSThread isMainThread])
                [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
		}
	}
}

- (void) roiMove:(NSPoint) offset
{
	[self roiMove:offset :YES];
}

- (BOOL) mouseRoiUp:(NSPoint) pt
{
	return [self mouseRoiUp: pt scaleValue: 1];
}

- (BOOL) mouseRoiUp:(NSPoint) pt scaleValue: (float) scaleValue
{
    zLocation = FLT_MIN;

    previousPoint.x = previousPoint.y = -1000;
	
	if (type == tTAGT || type == tOval || type == tOvalAngle || type == tROI ||
        type == tBall || type == tText || type == tArrow || type == tMeasure ||
        type == tPencil || type == t2DPoint || type == tPlain)
	{
        if (type == tTAGT && points.count == 2)
        {
            NSPoint p1 = [[points objectAtIndex: 0] point];
            NSPoint p2 = [[points objectAtIndex: 1] point];
            //MyPoint *mypt = nil;
            
            float blend = 0.3;
            NSPoint pt;
            pt.x = p1.x + blend * (p2.x - p1.x);
            pt.y = p1.y + blend * (p2.y - p1.y);
            [points addObject: [MyPoint point: pt]];
            
            float angle = atan2((p2.y - p1.y), (p2.x - p1.x));
            
            angle += M_PI/2;
            
            pt.x += 40 * cos(angle);
            pt.y += 40 * sin(angle);
            [points addObject: [MyPoint point: pt]];
            
            blend = 0.6;
            pt.x = p1.x + blend * (p2.x - p1.x);
            pt.y = p1.y + blend * (p2.y - p1.y);
            [points addObject: [MyPoint point: pt]];
            
            pt.x += 40 * cos(angle);
            pt.y += 40 * sin(angle);
            [points addObject: [MyPoint point: pt]];
            
            [self valid];
        }
        
		[self reduceTextureIfPossible];
		
		if (mode == ROI_drawing)
		{
			[self recompute];
            if ([NSThread isMainThread])
                [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification
                                                                    object: self
                                                                  userInfo: [NSDictionary dictionaryWithObjectsAndKeys:@"mouseUp", @"action", nil]];
			
			self.ROImode = ROI_selected;
			return NO;
		}
	}
	else
	{
		if (mode == ROI_selectedModify) 
			self.ROImode = ROI_selected;
	}
	
	if (clickPoint.x == pt.x && clickPoint.y == pt.y && previousMode == mode && (mode == ROI_selected || mode == ROI_selectedModify))
	{
		[self addPointUnderMouse: pt scale: scaleValue];
	}
	
    [[self retain] autorelease]; // Important !
    
    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification
                                                            object: self
                                                          userInfo: [NSDictionary dictionaryWithObjectsAndKeys:@"mouseUp", @"action", nil]];
    
	return YES;
}

- (void) mergeWithTexture: (ROI*) r
{
	if (type != tPlain) return;
	if (r.type != tPlain) return;
	if (self == r) return;
	
#define min(x,y) ((x<y)? x:y)
#define max(x,y) ((x>y)? x:y)
	
	int	newTextureUpLeftCornerX = min( textureUpLeftCornerX, r.textureUpLeftCornerX);
	int	newTextureDownRightCornerX = max( textureDownRightCornerX, r.textureDownRightCornerX);
	
	int	newTextureUpLeftCornerY = min( textureUpLeftCornerY, r.textureUpLeftCornerY);
	int	newTextureDownRightCornerY = max( textureDownRightCornerY, r.textureDownRightCornerY);
	
	int newTextureWidth = newTextureDownRightCornerX - newTextureUpLeftCornerX;
	int newTextureHeight = newTextureDownRightCornerY - newTextureUpLeftCornerY;
	
	NSRect aRect = NSMakeRect( textureUpLeftCornerX, textureUpLeftCornerY, textureWidth, textureHeight);
	NSRect bRect = NSMakeRect( r.textureUpLeftCornerX, r.textureUpLeftCornerY, r.textureWidth, r.textureHeight);
	
	unsigned char *tempBuf = (unsigned char *)calloc( newTextureWidth * newTextureHeight, sizeof(unsigned char));
	
	for (int y = 0; y < newTextureHeight ; y++)
	{
		for (int x = 0; x < newTextureWidth; x++)
		{
			NSPoint p = NSMakePoint( x + newTextureUpLeftCornerX, y + newTextureUpLeftCornerY);
			
			if (NSPointInRect( p, aRect))
			{
				unsigned char v = *(textureBuffer +  x + newTextureUpLeftCornerX - textureUpLeftCornerX + textureWidth * ( y + newTextureUpLeftCornerY - textureUpLeftCornerY));
				
				if (v)
				{
					*(tempBuf + x + ( y * newTextureWidth)) = v;
				}
			}
			
			if (NSPointInRect( p, bRect))
			{
				unsigned char v = *(r.textureBuffer +  x + newTextureUpLeftCornerX - r.textureUpLeftCornerX + r.textureWidth * ( y + newTextureUpLeftCornerY - r.textureUpLeftCornerY));
				
				if (v)
				{
					*(tempBuf + x + ( y * newTextureWidth)) = v;
				}
			}
		}
	}
	
	textureUpLeftCornerX = newTextureUpLeftCornerX;
	textureDownRightCornerX = newTextureDownRightCornerX;
	textureUpLeftCornerY = newTextureUpLeftCornerY;
	textureDownRightCornerY = newTextureDownRightCornerY;
	
	textureWidth = newTextureWidth;
	textureHeight = newTextureHeight;
	
	free( textureBuffer);
	textureBuffer = tempBuf;
	
	[self reduceTextureIfPossible];
    
    [self textureBufferHasChanged];
}

- (void) textureBufferHasChanged
{
    if (textureBufferSelected)
    {
        free( textureBufferSelected);
        textureBufferSelected = nil;
    }
}

- (BOOL) reduceTextureIfPossible
{
	if (type != tPlain)
        return YES;
	
	unsigned char *tempBuf = textureBuffer;
	
    if (tempBuf == nil)
        return NO;
    
	int minX = textureWidth;
	int maxX = 0;
	int minY = textureHeight;
	int maxY = 0;
	
	for (int y = 0; y < textureHeight ; y++)
	{
		for (int x = 0; x < textureWidth; x++)
		{                      
			if (*tempBuf++ != 0)
			{
				if (x < minX) minX = x;
				if (x > maxX) maxX = x;
				if (y < minY) minY = y;
				if (y > maxY) maxY = y;
			}
		}
	}
	
	if (minX > maxX) return YES;	// means the ROI is empty;
	if (minY > maxY) return YES;	// means the ROI is empty;
	
#define CUTOFF 8
	
//	NSLog( @"%d %d %d %d", minX, maxX, minY, maxY);
//	NSLog( @"%d %d %d %d", 0, textureWidth, 0, textureHeight);
	
	if (minX > CUTOFF ||
        maxX < textureWidth-CUTOFF ||
        minY > CUTOFF ||
        maxY < textureHeight-CUTOFF ||
        textureWidth % 4 != 0 ||
        textureHeight % 4 != 0)
	{
		minX -= 2;
		minY -= 2;
		maxX += 2;
		maxY += 2;
		
		if (minX < 0) minX = 0;
		if (minY < 0) minY = 0;
		if (maxX-minX > textureWidth) maxX = textureWidth+1+minX;
		if (maxY-minY > textureHeight) maxY = textureHeight+1+minY;
		
		int offsetTextureY = minY;
		int offsetTextureX = minX;
		
		int oldTextureWidth = textureWidth;
		int oldTextureHeight = textureHeight;
		
		textureWidth = maxX - minX+1;
		textureHeight = maxY - minY+1;
				
		if (textureWidth > oldTextureWidth) {
			textureWidth = oldTextureWidth;
			offsetTextureX = 0;
		}

        if (oldTextureWidth < textureWidth + offsetTextureX) {
			textureWidth = oldTextureWidth;
			offsetTextureX = 0;
		}

        if (textureHeight > oldTextureHeight) {
			textureHeight = oldTextureHeight;
			offsetTextureY = 0;
		}
		
        if (textureWidth % 4) {
            textureWidth /= 4;
            textureWidth *= 4;
            textureWidth += 4;
        }

        if (textureHeight % 4) {
            textureHeight /= 4;
            textureHeight *= 4;
            textureHeight += 4;
        }

        if (textureWidth != oldTextureWidth ||
            textureHeight != oldTextureHeight ||
            offsetTextureY != 0 ||
            offsetTextureX != 0)
        {
            unsigned char *newTextureBuffer = (unsigned char *)calloc( (1+textureWidth)*(1+textureHeight), sizeof(unsigned char));
            if (newTextureBuffer == nil)
            {
                textureWidth = oldTextureWidth;
                textureHeight = oldTextureHeight;
                return NO;
            }
            
            int minTextureWidth = textureWidth > oldTextureWidth ? oldTextureWidth : textureWidth;
            int minTextureHeight = textureHeight > oldTextureHeight ? oldTextureHeight : textureHeight;

            for (int y = 0 ; y < minTextureHeight ; y++)
            {
                if (y + offsetTextureY < oldTextureHeight)
                    memcpy(newTextureBuffer + (y * textureWidth),
                           textureBuffer + offsetTextureX+ (y+ offsetTextureY)*oldTextureWidth,
                           textureWidth);
            }
            
            if (newTextureBuffer != textureBuffer)
            {
                free( textureBuffer);
                textureBuffer = newTextureBuffer;
            }
            
            textureUpLeftCornerX += offsetTextureX;
            textureUpLeftCornerY += offsetTextureY;
            textureDownRightCornerX = textureUpLeftCornerX + textureWidth-1;
            textureDownRightCornerY = textureUpLeftCornerY + textureHeight-1;
            
            [self textureBufferHasChanged];
        }
	}
	
	return NO;	// means the ROI is NOT empty;
}

+ (void) fillCircle:(unsigned char *) buf :(int) width :(unsigned char) val
{
	int xsqr;
	int radsqr = (width*width)/4;
	int rad = width/2;
	
	for (int x = 0; x < rad; x++ )
	{
		xsqr = x*x;
		for (int y = 0 ; y < rad; y++)
		{
			if ((xsqr + y*y) < radsqr)
			{
				buf[ rad+x + (rad+y)*width] = val;
				buf[ rad-x + (rad+y)*width] = val;
				buf[ rad+x + (rad-y)*width] = val;
				buf[ rad-x + (rad-y)*width] = val;
			}
			else
                break;
		}
	}
}

- (BOOL) mouseRoiDragged:(NSPoint) pt :(unsigned int) modifier :(float) scale
{
	if (locked)
		return NO;
		
	if (selectable == NO)
		return NO;

	[roiLock lock];
	
	BOOL action = NO;
	float backingScaleFactor = curView.window.backingScaleFactor;
    
	@try
	{
        BOOL textureGrowDownX = YES;
        BOOL textureGrowDownY = YES;
		float oldTextureUpLeftCornerX, oldTextureUpLeftCornerY, offsetTextureX, offsetTextureY;
			
		if (type == tText || type == t2DPoint)
		{
			action = NO;
		}
		else if (type == tPlain)
		{
			switch (mode)
			{
				case ROI_selectedModify:
				case ROI_drawing:
                {
					thickness = ROIRegionThickness;
					
					if (textureUpLeftCornerX > (pt.x - thickness))
					{
						oldTextureUpLeftCornerX = textureUpLeftCornerX;
						textureUpLeftCornerX = pt.x - thickness - 4;
						textureGrowDownX = NO;
					}
                    
					if (textureUpLeftCornerY > (pt.y - thickness))
					{
						oldTextureUpLeftCornerY=textureUpLeftCornerY;
						textureUpLeftCornerY = pt.y - thickness - 4;
						textureGrowDownY = NO;
					}
                    
					if (textureDownRightCornerX < (pt.x + thickness))
					{
						textureDownRightCornerX = pt.x + thickness + 4;
						textureGrowDownX = YES;
					}
                    
					if (textureDownRightCornerY < (pt.y + thickness))
					{
						textureDownRightCornerY = pt.y + thickness + 4;
						textureGrowDownY = YES;
					}
					
					int oldTextureHeight = textureHeight;
					int oldTextureWidth = textureWidth;
					unsigned char *tempTextureBuffer = nil;
					
					// copy current Buffer to temp Buffer	
					if (textureBuffer!=NULL)
					{
						tempTextureBuffer = (unsigned char *)malloc( oldTextureHeight*oldTextureWidth*sizeof(unsigned char));
						memcpy( tempTextureBuffer, textureBuffer, oldTextureWidth*oldTextureHeight);
						free(textureBuffer);
						textureBuffer = nil;
                        
                        [self textureBufferHasChanged];
					}
					
					// new width and height
					textureWidth = (textureDownRightCornerX-textureUpLeftCornerX) + 1;
					textureHeight = (textureDownRightCornerY-textureUpLeftCornerY) + 1;
					
					if (textureWidth % 4)
                    {
                        textureWidth /= 4;
                        textureWidth *= 4;
                        textureWidth += 4;
                    }
                    
					if (textureHeight % 4)
                    {
                        textureHeight /= 4;
                        textureHeight *= 4;
                        textureHeight += 4;
                    }
					
					textureDownRightCornerX = textureWidth+textureUpLeftCornerX-1;
					textureDownRightCornerY = textureHeight+textureUpLeftCornerY-1;
					
					// ROI cannot be smaller !
					if (textureWidth<oldTextureWidth)
						textureWidth=oldTextureWidth;
						
					if (textureHeight<oldTextureHeight)
						textureHeight=oldTextureHeight;
					
					// new texture buffer		
					textureBuffer = (unsigned char *)calloc( textureWidth * textureHeight, sizeof(unsigned char));
					if (textureBuffer)
					{
						// copy temp buffer to the new buffer
                        
						if (textureGrowDownX && textureGrowDownY)
						{
							for (long j=0; j<oldTextureHeight; j++ )
								for (long i=0; i<oldTextureWidth; i++ )
									textureBuffer[i+j*textureWidth] = tempTextureBuffer[i+j*oldTextureWidth];
						}
						
						if (!textureGrowDownX && textureGrowDownY)
						{
							offsetTextureX = (oldTextureUpLeftCornerX-textureUpLeftCornerX);
							for (long j=0; j<oldTextureHeight; j++ )
								for (long i=0; i<oldTextureWidth; i++)
									textureBuffer[(long)(i+offsetTextureX+j*textureWidth)] = tempTextureBuffer[i+j*oldTextureWidth];
						}
						
						if (textureGrowDownX && !textureGrowDownY)
						{
							offsetTextureY = (oldTextureUpLeftCornerY-textureUpLeftCornerY);
							for (long j=0; j<oldTextureHeight; j++ )
								for (long i=0; i<oldTextureWidth; i++ )
									textureBuffer[(long)(i+(j+offsetTextureY)*textureWidth)] = tempTextureBuffer[i+j*oldTextureWidth];
						}
						
						if (!textureGrowDownX && !textureGrowDownY)
						{
							offsetTextureY = (oldTextureUpLeftCornerY-textureUpLeftCornerY);
							offsetTextureX = (oldTextureUpLeftCornerX-textureUpLeftCornerX);
							for (long j=0; j<oldTextureHeight; j++ )
								for (long i=0; i<oldTextureWidth; i++)
									textureBuffer[(long)(i+offsetTextureX+(j+offsetTextureY)*textureWidth)] = tempTextureBuffer[i+j*oldTextureWidth];
						}
					}
						
					free(tempTextureBuffer);
					tempTextureBuffer = nil;
						
					oldTextureWidth = textureWidth;
					oldTextureHeight = textureHeight;	
					
					unsigned char val;
					
					if (![curView eraserFlag])
                        val = 0xFF;
					else
                        val = 0x00;
					
					if ((modifier & NSEventModifierFlagCommand) &&
                        !(modifier & NSEventModifierFlagShift))
					{
						if (val == 0xFF)
                            val = 0;
						else
                            val = 0xFF;
					}
					
					long size, *xPoints, *yPoints;
					
					if (previousPoint.x == -1000 && previousPoint.y == -1000)
                        previousPoint = pt;
					
					int intThickness = thickness;
					
					unsigned char *brush = (unsigned char *)calloc( intThickness*2*intThickness*2, sizeof( unsigned char));
					
					[ROI fillCircle: brush :intThickness*2 :0xFF];

					size = BresLine(	previousPoint.x,
										previousPoint.y,
										pt.x,
										pt.y,
										&xPoints,
										&yPoints);
					
					for (long x = 0 ; x < size; x++)
                    {
						long xx = xPoints[ x];
						long yy = yPoints[ x];
								
						for (long j =- intThickness; j < intThickness; j++ ) {
							for (long i =- intThickness; i < intThickness; i++ ) {
								
								if (xx+j > textureUpLeftCornerX && xx+j < textureDownRightCornerX)
								{
									if (yy+i > textureUpLeftCornerY && yy+i < textureDownRightCornerY)
									{
										if (brush[ (j + intThickness) + (i + intThickness)*intThickness*2] != 0)
											textureBuffer[(i+( xx - textureUpLeftCornerX) + textureWidth*(j+( yy - textureUpLeftCornerY)))] = val;
									}
								}
							}
						}
					}
					
					free( brush);
					free( xPoints);
					free( yPoints);
					
					previousPoint = pt;
					
					action = YES;
					
					[self recompute];
                    [self textureBufferHasChanged];
                }
                    break;
				
				case ROI_selected:
					action = NO;
					break;
                    
                default:
                    break;
			}
		}
        else if (type == tOval || type == tOvalAngle || type == tROI || type == tBall) // TBC
		{
			switch( mode)
			{
				case ROI_drawing:
					rect.size.width = pt.x - rect.origin.x;
					rect.size.height = pt.y - rect.origin.y;
					
					if (modifier & NSEventModifierFlagShift)
						rect.size.width = rect.size.height;
						
					[self recompute];
					action = YES;
					break;
					
				case ROI_selected:
					action = NO;
					break;
					
				case ROI_selectedModify:
					[self recompute];
                    
					if (type == tROI)
					{
                        NSPoint leftUp    = NSMakePoint(NSMinX(rect), NSMinY(rect));
                        NSPoint rightUp   = NSMakePoint(NSMaxX(rect), NSMinY(rect));
                        NSPoint leftDown  = NSMakePoint(NSMinX(rect), NSMaxY(rect));
                        NSPoint rightDown = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
						
						switch (selectedModifyPoint)
						{
							case 1:
                                leftUp = pt;
                                rightUp.y = pt.y;
                                leftDown.x = pt.x;
                                break;
							case 4:
                                rightUp = pt;
                                leftUp.y = pt.y;
                                rightDown.x = pt.x;
                                break;
							case 3:
                                rightDown = pt;
                                rightUp.x = pt.x;
                                leftDown.y = pt.y;
                                break;
							case 2: leftDown = pt;
                                leftUp.x = pt.x;
                                rightDown.y = pt.y;
                                break;
						}
						
						rect = NSMakeRect( leftUp.x, leftUp.y, (rightDown.x - leftUp.x), (rightDown.y - leftUp.y));
						
						action = YES;
					}
                    else if (type == tOval || type == tOvalAngle)
                    {
                        pt = [self rotatePoint: pt withAngle: -roiRotationDeg aroundCenter: rect.origin];
                        
                        // tOvalAngle
                        if (selectedModifyPoint == 5)
                        {
                            ovalAngle[0] = atan2((pt.y - rect.origin.y) / (2*NSHeight(rect)),
                                                 (pt.x - rect.origin.x) / (2*NSWidth(rect)));
                            
                            if (modifier & NSEventModifierFlagShift)
                            {
                                float tempDeg = glm::degrees(ovalAngle[0]);
                                tempDeg = 45.0f * roundf(tempDeg/45.0f);
                                ovalAngle[0] = glm::radians(tempDeg);
                            }
                        }
                        
                        else if (selectedModifyPoint == 6)
                        {
                            ovalAngle[1] = atan2((pt.y - rect.origin.y) / (2*NSHeight(rect)),
                                                 (pt.x - rect.origin.x) / (2*NSWidth(rect)));
                            
                            if (modifier & NSEventModifierFlagShift)
                            {
                                float tempDeg = glm::degrees(ovalAngle[1]);
                                tempDeg = 45.0f * roundf(tempDeg/45.0f);
                                ovalAngle[1] = glm::radians(tempDeg);
                            }
                        }
                        
                        else
                        {
                            rect.size.height = pt.y - rect.origin.y;
                            rect.size.width = (modifier & NSEventModifierFlagShift) ? rect.size.height : pt.x - rect.origin.x;
                        }
                        
                        [[NSUserDefaults standardUserDefaults] setFloat: ovalAngle1 forKey: @"ovalAngle1"];
                        [[NSUserDefaults standardUserDefaults] setFloat: ovalAngle2 forKey: @"ovalAngle2"];
                        
                        action = YES;
                    }
                    break;
                    
                default:
                    break;
			}
		}
		else if (type == tPencil )
		{
			switch (mode)
			{
				case ROI_drawing:
                    if ([[points lastObject] isNearToPoint: pt
                                                          : scale/(thickness*backingScaleFactor)
                                                          : [[curView curDCM] pixelRatio]] == NO)
                    {
                        MyPoint *mypt = [[MyPoint alloc] initWithPoint: pt];
                        [points addObject: mypt];
                        [mypt release];
                        clickPoint = pt;
                        [self recompute];
                        action = YES;
                    }
                    break;
				
				case ROI_selected:
					action = NO;
                    break;
				
				case ROI_selectedModify:
                    if (selectedModifyPoint >= 0)
                        [[points objectAtIndex: selectedModifyPoint] setPoint: pt];

                    [self recompute];
                    action = YES;
                    break;

                default:
                    break;
			}
		}
		else
		{
			if (type == tLayerROI)
                clickPoint = pt;
			
			switch (mode)
			{
				case ROI_drawing:
                    [[points lastObject] setPoint: pt];

                    if (type == tMeasure)
                    {
                        if ((modifier & NSEventModifierFlagShift) &&
                            points.count == 2)
                        {
                            NSPoint first = [[points objectAtIndex: 0] point];
                            NSPoint last = [[points lastObject] point];
                            
                            if (fabs( first.y - last.y) / fabs( first.x - last.x) < 0.5)
                                last.y = first.y;
                            else if (fabs( first.y - last.y) / fabs( first.x - last.x) < 1.5)
                                last.y = first.y + (last.x - first.x) *
                                         copysignf( 1.0, first.y - last.y) *
                                         copysignf( 1.0, first.x - last.x);
                            else
                                last.x = first.x;
                            
                            [[points lastObject] setPoint: last];
                        }
                    }
                    
					[self recompute];
					action = YES;
                    break;
				
				case ROI_selected:
					action = NO;
                    break;
				
				case ROI_selectedModify:
                    
					if (selectedModifyPoint >= 0)
                    {
                        if (type == tClosedPolygon &&
                            _isSpline == NO &&
                            [ROI isPolygonRectangle: self.points width: nil height: nil center: nil])
                        {
                            int nextPoint = selectedModifyPoint+1;
                            int prevPoint = selectedModifyPoint-1;
                            
                            if (prevPoint < 0)
                                prevPoint = points.count-1;
                            
                            if (nextPoint >= points.count)
                                nextPoint = 0;
                            
                            int nextPoint2 = nextPoint+1;
                            int prevPoint2 = prevPoint-1;
                            
                            if (prevPoint2 < 0)
                                prevPoint2 = points.count-1;
                            
                            if (nextPoint2 >= points.count)
                                nextPoint2 = 0;
                            
                            NSPoint a = [self ProjectionPointLine: pt
                                                                 : [[points objectAtIndex: prevPoint2] point]
                                                                 : [[points objectAtIndex: prevPoint] point]];

                            NSPoint b = [self ProjectionPointLine: pt
                                                                 : [[points objectAtIndex: nextPoint2] point]
                                                                 : [[points objectAtIndex: nextPoint] point]];
                            
                            double side1 = sqrt( pow( a.x-pt.x, 2) + pow( a.y-pt.y, 2));
                            double side2 = sqrt( pow( b.x-pt.x, 2) + pow( b.y-pt.y, 2));
                            
                            if (side1 > 2.0 &&
                                side2 > 2.0)
                            {
                                [[points objectAtIndex: selectedModifyPoint] setPoint: pt];
                                [[points objectAtIndex: prevPoint] setPoint: a];
                                [[points objectAtIndex: nextPoint] setPoint: b];
                            }
                        }
                        else
                            [[points objectAtIndex: selectedModifyPoint] setPoint: pt];
                        
                        if (type == tMeasure)
                        {
                            if ((modifier & NSEventModifierFlagShift) &&
                                points.count == 2)
                            {
                                NSPoint first = selectedModifyPoint ? [[points objectAtIndex: 0] point] : [[points objectAtIndex: 1] point];
                                NSPoint last = [[points objectAtIndex: selectedModifyPoint] point];
                                
                                if (fabs( first.y - last.y) / fabs( first.x - last.x) < 0.5)
                                    last.y = first.y;
                                else if (fabs( first.y - last.y) / fabs( first.x - last.x) < 1.5)
                                    last.y = first.y + (last.x - first.x) *
                                            copysignf( 1.0, first.y - last.y) *
                                            copysignf( 1.0, first.x - last.x);
                                else
                                    last.x = first.x;
                                
                                [[points objectAtIndex: selectedModifyPoint] setPoint: last];
                            }
                        }
                    }
                        
                    [self recompute];
					action = YES;
                    break;
                    
                default:
                    break;
			}
		}
		
		[self valid];
		
		if (action)
		{
			if ( [self.comments isEqualToString: @"morphing generated"] )
                self.comments = @"";
			
            if ([NSThread isMainThread])
                [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"%s exception: %@", __FUNCTION__, e);
	}

    [roiLock unlock];
	return action;
}

- (BOOL) selectable
{
    if (hidden)
        return NO;
    
    return selectable;
}

- (BOOL) locked
{
    if (hidden)
        return YES;
    
    return locked;
}

- (void) setHidden:(BOOL) h
{
    hidden = h;
    curView.needsDisplay = YES;
}

- (void) setROIMode: (ROI_mode) m
{
    if (hidden)
        m = ROI_sleep;
    
	if (mode == m)
        return;

#ifndef NDEBUG
    if ([NSEvent pressedMouseButtons] != 0 &&
        (mode == ROI_drawing || mode == ROI_selectedModify))
    {
        NSLog( @"---- change ROI mode during modification? from %d to %d", m, mode);
    }
#endif
    
    mode = m;
    
    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification
                                                            object: self
                                                          userInfo: nil];
    parentROI.ROImode = m;
}

- (void) setName:(NSString*) a
{
	if (a == nil)
		a = @"";
	
	if (name != a && ![name isEqualToString:a]) // checking twice the same condition ?
	{
		[name release];
		
		if (type != tText && [a length] > 256)
			a = [a substringToIndex: 256];
		
        name = [a copy];
		
        if ([NSThread isMainThread])
            [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	}
	
	if (type == tText)
	{
		NSString *finalString;
		
		if ([comments length] > 0)
            finalString = [name stringByAppendingFormat:@"\r%@", comments];
		else
            finalString = name;
		
		if ([finalString length] > 4096)
			finalString = [finalString substringToIndex: 4096];
		
		if (stringTex)
            [stringTex setString: finalString withAttributes:stanStringAttrib];
		else
		{
			stringTex = [[StringTexture alloc]
                         initWithString: finalString
                         withAttributes: stanStringAttrib
                         withTextColor: [NSColor colorWithDeviceRed:color.red / 65535. green:color.green / 65535. blue:color.blue / 65535. alpha:1.0f]
                         withBoxColor: [NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                         withBorderColor: [NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
			[stringTex setAntiAliasing: YES];
		}
		
		rect.size = [stringTex frameSize];
		if (pixelSpacingX != 0 && pixelSpacingY != 0 )
			rect.size.height *= pixelSpacingX/pixelSpacingY;
	}
}

- (void) setColor:(RGBColor) a
{
	[self setColor: a globally: YES];
}

- (void) setColor:(RGBColor) a globally: (BOOL) g
{
	color = a;
	
	if (type == tText)
	{
		if (g)
		{
			ROITextColorR = color.red;	//[[NSUserDefaults standardUserDefaults] setFloat:color.red forKey:@"ROITextColorR"];
			ROITextColorG = color.green;//[[NSUserDefaults standardUserDefaults] setFloat:color.green forKey:@"ROITextColorG"];
			ROITextColorB = color.blue;	//[[NSUserDefaults standardUserDefaults] setFloat:color.blue forKey:@"ROITextColorB"];
		}
	}
	else if (type == tPlain)
	{
		if (g)
		{
			ROIRegionColorR = color.red;	//[[NSUserDefaults standardUserDefaults] setFloat:color.red forKey:@"ROIRegionColorR"];
			ROIRegionColorG = color.green;	//[[NSUserDefaults standardUserDefaults] setFloat:color.green forKey:@"ROIRegionColorG"];
			ROIRegionColorB = color.blue;	//[[NSUserDefaults standardUserDefaults] setFloat:color.blue forKey:@"ROIRegionColorB"];
		}
	}
	else if (type == tLayerROI)
	{
		if (!canColorizeLayer)
            return;
        
		if (layerColor)
            [layerColor release];
        
		layerColor = [NSColor colorWithCalibratedRed:color.red/65535.0
                                               green:color.green/65535.0
                                                blue:color.blue/65535.0
                                               alpha:1.0];
		[layerColor retain];
		while ([ctxArray count])
            [self deleteTexture: [ctxArray lastObject]];
	}
	else
	{
		if (g)
		{
			ROIColorR = color.red;		//[[NSUserDefaults standardUserDefaults] setFloat:color.red forKey:@"ROIColorR"];
			ROIColorG = color.green;		//[[NSUserDefaults standardUserDefaults] setFloat:color.green forKey:@"ROIColorG"];
			ROIColorB = color.blue;		//[[NSUserDefaults standardUserDefaults] setFloat:color.blue forKey:@"ROIColorB"];
		}
	}
}

- (void) setThickness:(float) a
{
	[self setThickness: a globally: YES];
}

- (void) setThickness: (float) a
             globally: (BOOL) g
{
	float v = roundf( a);	// To reduce the OpenGL memory leak - PointSize LineWidth
	
	if (v < 1) v = 1;
	if (v > 20) v = 20;
	
	thickness = v;
    
    //NSLog(@"%s %d, thickness: %f", __FUNCTION__, __LINE__, thickness);
	
	if (type == tPlain)
	{
		if (g)
			ROIRegionThickness = thickness;	//[[NSUserDefaults standardUserDefaults] setFloat:thickness forKey:@"ROIRegionThickness"];
	}
	else if (type == tArrow)
	{
		if (g)
			ROIArrowThickness = thickness;
	}
	else if (type == tText || type == tTAGT)
	{
		if (g)
			ROITextThickness = thickness;	//[[NSUserDefaults standardUserDefaults] setFloat:thickness forKey:@"ROITextThickness"];
		
		[stanStringAttrib release];
		
		// init fonts for use with strings
		NSFont * font =[NSFont fontWithName:@"Helvetica" size: 12.0 + thickness*2];
		stanStringAttrib = [[NSMutableDictionary dictionary] retain];
		[stanStringAttrib setObject:font forKey:NSFontAttributeName];
		[stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		
        [stringTexA release];   stringTexA = nil;
        [stringTexB release];   stringTexB = nil;
        [stringTexC release];   stringTexC = nil;
        
		self.name = name;
	}
	else
	{
		if (g)
			ROIThickness = thickness;
	}
}

- (BOOL) deleteSelectedPoint
{
    if (hidden)
        return NO;
    
	if (locked)
		return NO;

	switch( type)
	{
		case tPlain:
			return NO;
			break;
            
		case tText:
		case t2DPoint:
		case tOval:
        case tOvalAngle:
		case tROI:
        case tBall:
			rect.size = NSZeroSize;
            break;
		
		case tMeasure:
		case tArrow:
		case tClosedPolygon:
		case tOpenPolygon:
		case tPencil:
			if (mode == ROI_selectedModify)
			{
				if (selectedModifyPoint >= 0)
					[points removeObjectAtIndex: selectedModifyPoint];
			}
			else
                [points removeLastObject];
			
			if (selectedModifyPoint >= [points count])
                selectedModifyPoint = (long)[points count]-1;
            
            break;
            
		case tDynAngle:
		case tAxis:
        case tTAGT:
			if (selectedModifyPoint>3 && selectedModifyPoint >= 0) // ?!
			{
				if (mode == ROI_selectedModify)
					[points removeObjectAtIndex: selectedModifyPoint];
				else
                    [points removeLastObject];
                
				if (selectedModifyPoint >= [points count])
                    selectedModifyPoint = (long)[points count]-1;
			}
            break;
            
        default:
            break;
	}
    
    if ([NSThread isMainThread])
        [[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:self userInfo: nil];
	
    [self recompute];
    
	return [self valid];
}

// in cm or in pixels if no pixelspacing values
-(float) MeasureLength:(float*) pixels pointA: (NSPoint) a pointB: (NSPoint) b
{
	float val = [self Length:a :b];
	
	if (pixels)
	{
		if (pixelSpacingX != 0)
		{
			float measureLength = val;
			
			measureLength *= 10.0;
			measureLength /= pixelSpacingX;
			
			*pixels = measureLength;
		}
		else
            *pixels = val;
	}
	
	return val;
}

- (float) MeasureLength:(float*) pixels
{
	return [self MeasureLength: pixels
                        pointA: [[points objectAtIndex:0] point]
                        pointB: [[points objectAtIndex:1] point]];
}

+ (NSString*) formattedLength: (float) lCm
{
    if (lCm < .01)
        return [NSString stringWithFormat: NSLocalizedString( @"%0.1f %cm", nil), lCm * 10000.0, 0xb5];

    if (lCm < 1)
        return [NSString stringWithFormat: NSLocalizedString( @"%0.2f mm", nil), lCm * 10.];

    return [NSString stringWithFormat: NSLocalizedString( @"%0.2f cm", nil), lCm];
}

#ifdef BOX_WITH_ROUNDED_CORNERS
void gl_round_box(int mode,
                  float minx, float miny,
                  float maxx, float maxy,
                  float rad,
                  float factor)
{
	CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
    
//	renderer_setLineWidth( 0.1 * factor);
//	glBegin(GL_POLYGON);
//		glVertex2f(  minx, miny);
//		glVertex2f(  minx, maxy);
//		glVertex2f(  maxx, maxy);
//		glVertex2f(  maxx, miny);
//	glEnd();
    
    float vec[7][2]= {
        {0.195, 0.02},
        {0.383, 0.067},
        {0.55, 0.169},
        {0.707, 0.293},
        {0.831, 0.45},
        {0.924, 0.617},
        {0.98, 0.805}};
    
    rad *= factor;
    
    if (fabs( miny-maxy) < rad * 5.)
        rad = fabs( miny-maxy) / 5.;
    
    for (int a=0; a<7; a++) {
        vec[a][0] *= rad;
        vec[a][1] *= rad;
    }
    
#ifdef WITH_OPENGL_32
    // TODO:
    NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
#else
    glBegin(mode);
    {
        glVertex2f( maxx-rad, miny);
        for (int a=0; a<7; a++)
            glVertex2f( maxx-rad+vec[a][0], miny+vec[a][1]);
        glVertex2f( maxx, miny+rad);
        
        glVertex2f( maxx, maxy-rad);
        for (int a=0; a<7; a++)
            glVertex2f( maxx-vec[a][1], maxy-rad+vec[a][0]);
        glVertex2f( maxx-rad, maxy);
        
        glVertex2f( minx+rad, maxy);
        for (int a=0; a<7; a++)
            glVertex2f( minx+rad-vec[a][0], maxy-vec[a][1]);
        glVertex2f( minx, maxy-rad);
        
        glVertex2f( minx, miny+rad);
        for (int a=0; a<7; a++)
            glVertex2f( minx+vec[a][1], miny+rad-vec[a][0]);
        glVertex2f( minx+rad, miny);
    }
    glEnd();
#endif
}
#endif // BOX_WITH_ROUNDED_CORNERS

#pragma mark - TextualData

- (NSRect) findAnEmptySpaceForMyRect:(NSRect) dRect
                                    :(BOOL*) movedOut // output parameter
{
	NSMutableArray *rectArray = [curView rectArray];
	if (rectArray == nil)
	{
		*movedOut = NO;
		return dRect;
	}

    // 0 = still undefined
    // -1 = up, +1 = down (or viceversa, TBC)
    int vertDirection = 0;

    int maxRedo = [rectArray count] + 2;
	
	*movedOut = NO;
	
	dRect.origin.x += 8;
	dRect.origin.y += 8;
	
	// Does it intersect with the frame view?
	NSRect displayingRect = [curView drawingFrameRect];
	displayingRect.origin.x = -displayingRect.size.width/2;
	displayingRect.origin.y = -displayingRect.size.height/2;
	if (NSIntersectsRect( dRect, displayingRect))
	{
		if (NSEqualRects( NSUnionRect( dRect, displayingRect), displayingRect) == NO)
		{
			if (NSMinX(dRect) < NSMinX(displayingRect))
				dRect.origin.x = displayingRect.origin.x;
			
			if (NSMinY(dRect) < NSMinY(displayingRect))
				dRect.origin.y = displayingRect.origin.y;
			
			if (NSMaxY(dRect) > NSMaxY(displayingRect))
				dRect.origin.y = NSMaxY(displayingRect) - dRect.size.height;
			
			if (NSMaxX(dRect) > NSMaxX(displayingRect))
				dRect.origin.x = NSMaxX(displayingRect) - dRect.size.width;
		}
	}
	
	for (int i = 0; i < [rectArray count]; i++)
	{
		NSRect curRect = [[rectArray objectAtIndex: i] rectValue];
		if (NSIntersectsRect( curRect, dRect))
		{
			NSRect interRect = NSIntersectionRect( curRect, dRect);
			interRect.size.height++;
			interRect.size.width++;
			
			NSPoint cInterRect = NSMakePoint( NSMidX(interRect), NSMidY(interRect));
			NSPoint cCurRect   = NSMakePoint( NSMidX(curRect), NSMidY(curRect));
			
			if (vertDirection != 0)
			{
				if (vertDirection == -1)
                    dRect.origin.y -= interRect.size.height;
				else
                    dRect.origin.y += interRect.size.height;
			}
			else // direction == 0
			{
				if (cInterRect.y < cCurRect.y)
				{
					dRect.origin.y -= interRect.size.height;
					vertDirection = -1;
				}
				else
				{
					dRect.origin.y += interRect.size.height;
					vertDirection = 1;
				}
			}
			
			if (maxRedo-- >= 0)
                i = -1;
			
			*movedOut = YES;
		} // if intersect
	} // for
	
	if (*movedOut)
		dRect.origin.x += 5;
	
	[rectArray addObject: [NSValue valueWithRect: dRect]];
	
	return dRect;
}

- (BOOL) isTextualDataDisplayed
{
	if (!displayTextualData)
        return NO;
	
    if (hidden)
        return NO;
    
	// No text for Calcium Score
	if (_displayCalciumScoring)
		return NO;
		
	BOOL drawTextBox = NO;
	
	if (ROITEXTIFSELECTED == NO ||
        mode == ROI_selected ||
        mode == ROI_selectedModify ||
        mode == ROI_drawing)
	{
		drawTextBox = YES;
	}
    
    if (ROITEXTIFSELECTED)
    {
        if (mouseOverROI)
            drawTextBox = YES;
	}
    
	if (mode == ROI_selectedModify || mode == ROI_drawing)
	{
		if (type == tOpenPolygon ||
			type == tClosedPolygon ||
			type == tPencil ||
			type == tPlain)
        {
            drawTextBox = NO;
        }
	}
	
	return drawTextBox;
}

// Draw connecting path
- (void) drawUmbilicalCord
{
    NSPoint anchor = originAnchor;
    
    if (type == tPlain)
        anchor = [curView ConvertFromGL2View: NSMakePoint(textureDownRightCornerX - textureWidth/2,
                                                          textureDownRightCornerY - textureHeight/2)];

    // Eliminate rotation
    // Maybe important only if the view is currently rotated
#ifdef WITH_OPENGL_32
    CGSize scaleFactor = [curView drawingFrameRect].size;
    //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_UMBILICAL
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_UMBILICAL
    // TODO: this would be the preferred way but it needs more debugging
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::scale(glm::mat4(1.0),
                             glm::vec3(2.0f / scaleFactor.width,
                                      -2.0f / scaleFactor.height,
                                       1.0f));
    #else
    // It's not "polite" to modify the MV matrix in the shader
    // but we are doing this at the end of the draw call so it doesn't seem to matter
    renderer_reset_scale_MV(scaleFactor);
    #endif // WITH_LOCAL_MV_MATRIX_TRANSFORMATION_UMBILICAL
#else
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    glPushMatrix();
    glLoadIdentity();
    //CGSize scaleFactor = [curView frame].size; // Problem for iChat : if ICHAT [curView frame] should be 640 *480....
    CGSize scaleFactor = [curView drawingFrameRect].size;
    glScalef(2.0f / scaleFactor.width,
            -2.0f / scaleFactor.height,
             1.0f);
#endif

    const int dimVert = 3; // XYZ
    const int nControlPoints = 3;
    const int nInterpolatedPoints = 30;
    const int OFFSET_X = 30;

    GLfloat cp[nControlPoints][dimVert];
            
    cp[0][0] = NSMinX(drawRect);
    cp[0][1] = NSMidY(drawRect);
    cp[0][2] = 0;
    
    cp[1][0] = anchor.x - OFFSET_X;
    cp[1][1] = anchor.y;
    cp[1][2] = 0;
    
    cp[2][0] = anchor.x;
    cp[2][1] = anchor.y;
    cp[2][2] = 0;
    
#ifdef WITH_OPENGL_32
    // 3 Bezier control points
    glm::vec2 p[3];
    p[0] = glm::vec2(NSMinX(drawRect), NSMidY(drawRect));
    p[1] = glm::vec2(anchor.x - OFFSET_X, anchor.y);
    p[2] = glm::vec2(anchor.x, anchor.y);

    // 30 Bezier interpolated points
    // TODO: use glm::gtx::spline::cubic
    glm::vec2 ip[nInterpolatedPoints+1];
    for (int i=0; i<=nInterpolatedPoints; i++) {
        float t = (float)i / (float)nInterpolatedPoints;
        float t2 = t*t;
        ip[i] = glm::vec2((1.0 - t)*(1.0 - t))*p[0] +
                glm::vec2(2.0 - 2.0*t)*glm::vec2(t)*p[1] +
                glm::vec2(t2)*p[2];
    }
    
    // Prepare the array that will be used twice
    NSMutableArray *pArray = [NSMutableArray array];
    for (int i=0; i<=nInterpolatedPoints; i++) {
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_UMBILICAL
        // Apply local model transformation
        glm::vec4 pB = M*glm::vec4(ip[i],0,1);
        ip[i] = glm::vec2(pB.x, pB.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&ip[i] objCType:@encode(glm::vec2)]];
    }
#endif

    [curView setShaderProgramOverlay];

//#ifdef DEBUG_SHOW_BEZIER_CONTROL_POINTS
//    // Show control points
//    {
//        NSMutableArray *pArray = [NSMutableArray array];
//
//        for (int i=0; i<nControlPoints; i++) {
//            NSPoint p = NSMakePoint(cp[i][0], cp[i][1]);
//            NSLog(@"%s %d, cp[%i] %@", __FUNCTION__, __LINE__, i, NSStringFromPoint(p));
//            MyPoint *tempPoint = [[MyPoint alloc] initWithPoint:p];
//            [pArray addObject:tempPoint];
//            [tempPoint release];
//        }
//
//        glPointSize( 12 );
//        renderer_set_rgb(1.0f, 0.0f, 1.0f); // magenta
//        renderer_drawPoints([pArray copy], false); // square points
//    }
//#endif

    // Draw line strip with 30 points, first time thick and dark
    [curView setShaderProgramForLineWidth: 3.0 * curView.window.backingScaleFactor];

    if (mode == ROI_sleep)
        renderer_set_rgba(0.0f, 0.0f, 0.0f, 0.4f); // black
    else
        renderer_set_rgba(0.3f, 0.0f, 0.0f, 0.8f); // dark red

#ifdef WITH_OPENGL_32
    #ifndef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_UMBILICAL
    renderer_reset_scale_MV(scaleFactor); // reapply in case we changed the shader program
    #endif
    renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
#else
    // GL_MAP1_VERTEX_3:
    //  - One-dimensional map
    //  - Each control point is three floating-point values representing x,y,z.
    //  - Internal glVertex3 commands are generated when the map is evaluated.
    GLenum targetValuesType = GL_MAP1_VERTEX_3;

    GLint stride = 3;
    GLint order = nControlPoints;

    glMap1f(targetValuesType, 0.0, 1.0, stride, order, &cp[0][0]); // gl2 gl3
    glEnable(targetValuesType);
    
    glBegin(GL_LINE_STRIP);
    {
        for (int i = 0; i <= nInterpolatedPoints; i++ )
            glEvalCoord1f((GLfloat) i/(float)nInterpolatedPoints);  // gl2 gl3
    }
    glEnd();
    glDisable(targetValuesType);
#endif
    
    // Re-draw the same line strip with 30 points, this time thin and white

    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
    renderer_set_rgba(1.0f, 1.0f, 1.0f, 1.0f); // white

#ifdef WITH_OPENGL_32
    renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
#else
    glMap1f(targetValuesType, 0.0, 1.0, stride, order, &cp[0][0]);
    glEnable(targetValuesType);
    
    glBegin(GL_LINE_STRIP);
    {
        for ( int i = 0; i <= nInterpolatedPoints; i++ )
            glEvalCoord1f((GLfloat) i/(float)nInterpolatedPoints);
    }
    glEnd();
    glDisable(targetValuesType);
    
    glPopMatrix();   // Maybe important only if the view is currently rotated
#endif
}

- (void) drawROITextualData
{
    if (hidden) {
        drawRect = NSZeroRect;
        return;
    }
    
	if (textualBoxLine1.length == 0 &&
        textualBoxLine2.length == 0 &&
        textualBoxLine3.length == 0 &&
        textualBoxLine4.length == 0 &&
        textualBoxLine5.length == 0 &&
        textualBoxLine6.length == 0 &&
        textualBoxLine7.length == 0 &&
        textualBoxLine8.length == 0)
	{
		drawRect = NSZeroRect;
		return;
	}
	
	if (!displayTextualData)
	{
		drawRect = NSZeroRect;
		return;
	}

    BOOL moved;
	drawRect = [self findAnEmptySpaceForMyRect: drawRect
                                              : &moved];
	
	if (type == tDynAngle || type == tTAGT || type == tAxis || type == tClosedPolygon || type == tOpenPolygon || type == tPencil)
    {
        moved = YES;
    }

//	if (type == tClosedPolygon || type == tOpenPolygon || type == tPencil) moved = YES;
//	if (fabs( offsetTextBox_x) > 0 || fabs( offsetTextBox_y) > 0) moved = NO;

    if (!self.isTextualDataDisplayed) {
        drawRect = NSZeroRect;
        return;
    }

	if (moved &&
        ![curView suppressLabels])
	{
        [self drawUmbilicalCord];    // Draw Bezier line
	}

#pragma mark Text

    if (type == tText)
        return;

    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
    
    // TODO: deal with positioning of the ROI text
    
#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_Normal];
#else
    glPushMatrix();
#endif
    renderer_reset_scale_MV([curView drawingFrameRect].size);
    
//  glEnable(GL_BLEND);
//  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    float sf = curView.window.backingScaleFactor;
    
    const int nPoints = 4; // box corners
    glm::vec2 pA[nPoints];
    pA[0] = glm::vec2(NSMinX(drawRect), NSMinY(drawRect) - 1);
    pA[1] = glm::vec2(NSMinX(drawRect), NSMaxY(drawRect));
    pA[2] = glm::vec2(NSMaxX(drawRect), NSMaxY(drawRect));
    pA[3] = glm::vec2(NSMaxX(drawRect), NSMinY(drawRect) - 1);

    if (mode == ROI_sleep)
        renderer_set_rgba(0.0f, 0.0f, 0.0f, 0.4f); // black
    else
        renderer_set_rgba(0.3f, 0.0f, 0.0f, 0.8f); // dark red

#ifndef BOX_WITH_ROUNDED_CORNERS
    {
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        renderer_drawPolygon([pArray copy]);    // GL_POLYGON / GL_TRIANGLE_FAN
    }
#else
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
    glEnable(GL_POLYGON_SMOOTH);
    gl_round_box(GL_POLYGON,
                 NSMinX(drawRect),
                 NSMinY(drawRect) - 1,
                 NSMaxX(drawRect),
                 NSMaxY(drawRect),
                 fontHeight*sf/5.,
                 sf);
    glDisable(GL_POLYGON_SMOOTH);
#endif
    
    NSPoint tPt = NSMakePoint(drawRect.origin.x + 4*sf,
                              drawRect.origin.y + (fontHeight*sf + 2*sf));
        
#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_TextureRgba];
#endif

    long line = 0;
    [self glStr: textualBoxLine1 : tPt.x : tPt.y : line];	if (textualBoxLine1.length) line++;
    [self glStr: textualBoxLine2 : tPt.x : tPt.y : line];	if (textualBoxLine2.length) line++;
    [self glStr: textualBoxLine3 : tPt.x : tPt.y : line];	if (textualBoxLine3.length) line++;
    [self glStr: textualBoxLine4 : tPt.x : tPt.y : line];	if (textualBoxLine4.length) line++;
    [self glStr: textualBoxLine5 : tPt.x : tPt.y : line];	if (textualBoxLine5.length) line++;
    [self glStr: textualBoxLine6 : tPt.x : tPt.y : line];	if (textualBoxLine6.length) line++;
    [self glStr: textualBoxLine7 : tPt.x : tPt.y : line];	if (textualBoxLine7.length) line++;
    [self glStr: textualBoxLine8 : tPt.x : tPt.y : line];	if (textualBoxLine8.length) line++;

    // Restore
    glDisable(GL_BLEND);
    
#ifdef WITH_OPENGL_32
    [curView setShaderProgramOverlay_withMode_Normal];
#else
    glPopMatrix();
#endif
}

- (void) prepareTextualData:(NSPoint) tPt
{
	NSPoint ctPt = tPt;
	
	tPt = [curView ConvertFromGL2View: ctPt];
	originAnchor = tPt;
	
	ctPt.x += offsetTextBox_x;
	ctPt.y += offsetTextBox_y;
	
	tPt = [curView ConvertFromGL2View: ctPt];
	drawRect.origin = tPt;
	
	long line = 0;
    long maxWidth = 0;
	maxWidth = [self maxStringWidth:textualBoxLine1 max: maxWidth];	if (textualBoxLine1.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine2 max: maxWidth];	if (textualBoxLine2.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine3 max: maxWidth];	if (textualBoxLine3.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine4 max: maxWidth];	if (textualBoxLine4.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine5 max: maxWidth];	if (textualBoxLine5.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine6 max: maxWidth];	if (textualBoxLine6.length > 0) line++;
	maxWidth = [self maxStringWidth:textualBoxLine7 max: maxWidth];	if (textualBoxLine7.length > 0) line++;
    maxWidth = [self maxStringWidth:textualBoxLine8 max: maxWidth];	if (textualBoxLine8.length > 0) line++;
    
	drawRect.size.height = line * fontHeight*curView.window.backingScaleFactor + 2;
	drawRect.size.width = maxWidth + 8;
	
	if (type == tDynAngle || type == tAxis || type == tTAGT || type == tClosedPolygon || type == tOpenPolygon || type == tPencil)
	{
		if ([points count] > 0)
		{
			float ymin = [[points objectAtIndex:0] y];
			
			tPt.y = [[points objectAtIndex: 0] y];
			tPt.x = [[points objectAtIndex: 0] x];
			
			for (long i = 0; i < [points count]; i++ )
			{
				if ([[points objectAtIndex:i] y] > ymin)
				{
					ymin = [[points objectAtIndex:i] y];
					tPt.y = [[points objectAtIndex:i] y];
					tPt.x = [[points objectAtIndex:i] x];
				}
			}
			
			ctPt = tPt;
			
			tPt = [curView ConvertFromGL2View: ctPt];
			originAnchor = tPt;
			
			tPt = ctPt;
			tPt.x += offsetTextBox_x;
			tPt.y += offsetTextBox_y;
			
			tPt = [curView ConvertFromGL2View: tPt];
			drawRect.origin = tPt;
		}
	}
}

#pragma mark -

- (void) drawROI;
{
    [self drawROIWithScaleValue: curView.scaleValue
                        offset: NSMakePoint(curView.curDCM.pwidth/2., curView.curDCM.pheight/2.)
                  pixelSpacing: NSMakeSize(curView.curDCM.pixelSpacingX, curView.curDCM.pixelSpacingY)
            highlightIfSelected: YES
                      thickness: thickness
             prepareTextualData: YES];
}

- (void) drawOneROI :(float) scaleValue :(NSPoint) offset :(NSSize) spacing
{
    [self drawROIWithScaleValue: scaleValue
                         offset: offset
                   pixelSpacing: spacing
            highlightIfSelected: YES
                      thickness: thickness
             prepareTextualData: YES];
}

- (void) setTexture: (unsigned char*) t width: (int) w height:(int) h
{
    if (textureBuffer)
        free( textureBuffer);
    
    textureBuffer = t;
    textureWidth = w;
    textureHeight = h;
    
    [self textureBufferHasChanged];
}

- (NSArray*) physicalUnitsXYDirection
{
    static NSArray *physicalUnitsXYDirection = nil;
    
    if (physicalUnitsXYDirection == nil)
        physicalUnitsXYDirection = [[NSArray arrayWithObjects:
                                     NSLocalizedString( @"none", nil),
                                     @"%",
                                     NSLocalizedString( @"dB", @"decibel"),
                                     NSLocalizedString( @"cm", nil),
                                     NSLocalizedString( @"sec", @"second"),
                                     NSLocalizedString( @"hertz", nil),
                                     NSLocalizedString( @"dB/sec", @"decibel per second"),
                                     NSLocalizedString( @"cm/sec", nil),
                                     NSLocalizedString( @"cm\u00B2", @"cm2"),
                                     NSLocalizedString( @"cm\u00B2/sec", @"cm2/sec"),
                                     NSLocalizedString( @"cm\u00B3", @"cm3"),
                                     NSLocalizedString( @"cm\u00B3/sec", @"cm3/sec"),
                                     @"\u00B0",
                                     nil] retain];
    
    return physicalUnitsXYDirection;
}

- (void) displayPolygonUsRegion: (DCMUSRegion*) usR spline: (NSArray*) splinePoints area: (float) area
{
    NSString *unitsX = [self.physicalUnitsXYDirection objectAtIndex: usR.physicalUnitsXDirection];
    NSString *unitsY = [self.physicalUnitsXYDirection objectAtIndex: usR.physicalUnitsYDirection];
    
    if (usR.regionSpatialFormat == 1 &&
        usR.physicalUnitsXDirection == regionCode_cm &&
        usR.physicalUnitsYDirection == regionCode_cm) // 2D
    {
        self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f %@\u00B2", nil), area*usR.physicalDeltaX*usR.physicalDeltaY, unitsX];
        
        NSPoint rectCenter = NSZeroPoint;
        double sideW = 0;
        double sideH = 0;
        
        if (type == tClosedPolygon &&
            _isSpline == NO &&
            [ROI isPolygonRectangle: splinePoints width: &sideW height: &sideH center: &rectCenter])
        {
            self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingString: @" "];
            self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingFormat: NSLocalizedString( @"(W: %0.3f %@ H: %0.3f %@)", @"W = width, H = height"), sideW*usR.physicalDeltaY, unitsX, sideH *usR.physicalDeltaX, unitsY];
        }
    }
}

+ (NSString*) totalLocalized: (double) total
{
    NSString *suffix = nil;
    
    double abstotal = fabs( total);
    
    if (abstotal > pow( 10, 13))
    {
        total /= pow( 10, 9);
        suffix = @"x10\u2079"; // superscript 9
    }
    else if (abstotal > pow( 10, 10))
    {
        total /= pow( 10, 6);  // superscript 6
        suffix = @"x10\u2076";
    }
    else if (abstotal > pow( 10, 7))
    {
        total /= pow( 10, 3);  // superscript 3
        suffix = @"x10\u00B3";
    }
    
    NSString *str = N2LocalizedDecimal( total);
    
    if (suffix)
        str = [str stringByAppendingString: suffix];
    
    return str;
}

#pragma mark -

- (void) drawROIWithScaleValue:(float)scaleValue
                        offset:(NSPoint)offset
                  pixelSpacing:(NSSize)spacing
           highlightIfSelected:(BOOL)highlightIfSelected
                     thickness:(float)thick
            prepareTextualData:(BOOL)prepareTextualData
{
    if (hidden)
        return;
    
	if (roiLock == nil)
        roiLock = [[NSRecursiveLock alloc] init];
	
	if (curView == nil && prepareTextualData)
    {
        NSLog(@"curView == nil! We will not draw this ROI...");
        return;
    }
    
    float backingScaleFactor = curView.window.backingScaleFactor;
    
	[roiLock lock];
	
    if (_previousDrawingPix != self.pix)
    {
        [self recompute];
        _previousDrawingPix = self.pix;
    }
    
    self.textualBoxLine1 = self.textualBoxLine2 = self.textualBoxLine3 = self.textualBoxLine4 = self.textualBoxLine5 = self.textualBoxLine6 = self.textualBoxLine7 = self.textualBoxLine8 = nil;
    
	@try
	{
		if (selectable == NO)
			self.ROImode = ROI_sleep;
		
		pixelSpacingX = spacing.width;
		pixelSpacingY = spacing.height;

#ifdef WITH_OPENGL_32
        [curView setShaderProgramOverlay_withMode_Normal];
#else
        NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
        CGLContextObj cgl_ctx = [currentContext CGLContextObj];
        if (cgl_ctx == nil)
            return;
#endif
        renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
		
		glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
		glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);

        renderer_enable_blend_smooth();
		
		switch (type)
		{
#pragma mark tLayerROI

            case tLayerROI:
                [self tLayerROI_drawWithScaleValue: scaleValue
                                            offset: offset
                               highlightIfSelected: highlightIfSelected
                                prepareTextualData: prepareTextualData];
                break;

#pragma mark tPlain

            case tPlain:  // brush
                //if (mode == ROI_selected | mode == ROI_selectedModify | mode == ROI_drawing)
                [self tPlain_drawWithScaleValue: scaleValue
                                         offset: offset
                            highlightIfSelected: highlightIfSelected
                             prepareTextualData: prepareTextualData];
                break;

#pragma mark t2DPoint
                
			case t2DPoint:
                [self t2DPoint_drawWithScaleValue: scaleValue
                                           offset: offset
                              highlightIfSelected: highlightIfSelected
                                        thickness: thick
                               prepareTextualData: prepareTextualData];
                break;

#pragma mark tText

            case tText:
                [self tText_drawWithScaleValue: scaleValue
                                        offset: offset
                           highlightIfSelected: highlightIfSelected];
                break;

#pragma mark tMeasure, tArrow

            case tMeasure:
			case tArrow:
                [self tMeasure_tArrow_drawWithScaleValue: scaleValue
                                                  offset: offset
                                     highlightIfSelected: highlightIfSelected
                                               thickness: thick
                                      prepareTextualData: prepareTextualData];
                break;

#pragma mark tROI

			case tROI: // rectangle
                [self tROI_drawWithScaleValue: scaleValue
                                       offset: offset
                          highlightIfSelected: highlightIfSelected
                                    thickness: thick
                           prepareTextualData: prepareTextualData];
                break;
                
#pragma mark tOval, tOvalAngle

            case tOval:
            case tOvalAngle:
                [self tOval_tOvalAngle_drawWithScaleValue: scaleValue
                                                   offset: offset
                                      highlightIfSelected: highlightIfSelected
                                                thickness: thick
                                       prepareTextualData: prepareTextualData];
                break;

#pragma mark tBall

            case tBall:
                [self tBall_draw_withScaleValue: scaleValue
                                         offset: offset
                            highlightIfSelected: highlightIfSelected
                                      thickness: thick
                             prepareTextualData: prepareTextualData];
                break;
                
#pragma mark tAxis

            case tAxis:
                [self tAxis_drawWithScaleValue: scaleValue
                                        offset: offset
                           highlightIfSelected: highlightIfSelected
                                     thickness: thick
                            prepareTextualData: prepareTextualData];
                break;
                
#pragma mark tTAGT (Perpendicular lines)

            case tTAGT:
                [self tTAGT_draw_withScaleValue: scaleValue
                                         offset: offset
                            highlightIfSelected: highlightIfSelected
                                      thickness: thick
                             prepareTextualData: prepareTextualData];
                break;
                
#pragma mark tDynAngle

            case tDynAngle:
                [self tDynAngle_drawWithScaleValue: scaleValue
                                            offset: offset
                               highlightIfSelected: highlightIfSelected
                                         thickness: thick
                                prepareTextualData: prepareTextualData];
                break;

#pragma mark tClosedPolygon, tOpenPolygon, tAngle, tPencil

            case tOpenPolygon:
            case tClosedPolygon:
			case tAngle:
			case tPencil:
			{
#define RATIO_FOROPOLYGONAREA 3.
			
				if (mode == ROI_drawing)
                    [curView setShaderProgramForLineWidth: 2 * thick * backingScaleFactor];
				else
                    [curView setShaderProgramForLineWidth: thick * backingScaleFactor];

                renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);

                if (rLength == -1.0)
                {
                    NSArray *splineForLength = [self splinePoints];
                    
                    if (splineForLength.count)
                    {
                        int ii;
                        rLength = 0;
                        for (ii = 0; ii < splineForLength.count-1; ii++)
                            rLength += [self Length:[[splineForLength objectAtIndex:ii] point]
                                                   :[[splineForLength objectAtIndex:ii+1] point]];
                        
                        if (type == tClosedPolygon)
                            rLength += [self Length:[[splineForLength objectAtIndex:ii] point]
                                                   :[[splineForLength objectAtIndex:0] point]];
                    }
                }
                
				NSMutableArray *splinePoints3 = [self splinePoints: scaleValue];
				
				if ([splinePoints3 count] >= 1) // Cannot draw a line with only 1 point
				{
                    GLenum lineMode;
					if ((type == tClosedPolygon || type == tPencil) && mode != ROI_drawing )
                        lineMode = GL_LINE_LOOP;
					else
                        lineMode = GL_LINE_STRIP;

                    // The first segment of tOpenPolygon is drawn as a line, the rest are redundantly drawn as lines and as splinePoints
                    // Also used for tAngle in which case there is no redundant drawing
                    {
                        NSMutableArray *pArray = [NSMutableArray array];
                            
                        for (MyPoint *p in splinePoints3) {
                            glm::vec2 pp(((double) [p x]-(double) offset.x)*(double) scaleValue,
                                         ((double) [p y]-(double) offset.y)*(double) scaleValue);

                            [pArray addObject: [NSValue valueWithBytes:&pp objCType:@encode(glm::vec2)]];
                        }

                        renderer_drawLine_xy([pArray copy], lineMode);
                    }

                    if (type == tOpenPolygon)
					{
						// If the first and the last point are too far away it's probably not a good idea to display the Area
						if ([self Length:[[splinePoints3 objectAtIndex: 0] point]
                                        :[[splinePoints3 lastObject] point]] < rLength / RATIO_FOROPOLYGONAREA)
						{
                            double x1 = ((double) [[splinePoints3 objectAtIndex: 0] x]-(double) offset.x) * (double) scaleValue;
                            double y1 = ((double) [[splinePoints3 objectAtIndex: 0] y]-(double) offset.y) * (double) scaleValue;

                            double x2 = ((double) [[splinePoints3 lastObject] x]-(double) offset.x)*(double) scaleValue;
                            double y2 = ((double) [[splinePoints3 lastObject] y]-(double) offset.y)*(double) scaleValue;
                            
                            renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity/4.);

                            {
                                NSMutableArray *pArray = [NSMutableArray array];

                                glm::vec2 pp1(x1,y1);
                                [pArray addObject: [NSValue valueWithBytes:&pp1 objCType:@encode(glm::vec2)]];

                                glm::vec2 pp2(x2,y2);
                                [pArray addObject: [NSValue valueWithBytes:&pp2 objCType:@encode(glm::vec2)]];

                                renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
                            }
                            renderer_set_rgba(color.red / 65535., color.green / 65535., color.blue / 65535., opacity);

						} // if
					} // tOpenPolygon
					
                    // If we are currently editing this ROI, show its points bigger
					if (mode == ROI_drawing)
                        glPointSize( 2 * thick * backingScaleFactor);
					else
                        glPointSize( thick * backingScaleFactor);
					
                    NSPoint rectCenter = NSZeroPoint;
                    double sideW = 0;
                    double sideH = 0;
                    BOOL rectPoly = NO;
                    
                    if (type == tClosedPolygon &&
                        _isSpline == NO &&
                        [ROI isPolygonRectangle: splinePoints3 width: &sideW height: &sideH center: &rectCenter])
                    {
                        rectPoly = YES;
                    }
                  
                    //NSLog(@"ROI drawROIWithScaleValue %d, POINTS, type: %d, %ld splinePoints (+center)", __LINE__, type, [splinePoints3 count]);   // easily in the hundreds

                    NSMutableArray *pArray = [NSMutableArray array];

                    for (MyPoint *p in splinePoints3) {  // same as defined above. TODO: reuse
                        glm::vec2 pp(((double) [p x]-(double) offset.x)*(double) scaleValue,
                                     ((double) [p y]-(double) offset.y)*(double) scaleValue);

                        [pArray addObject: [NSValue valueWithBytes:&pp objCType:@encode(glm::vec2)]];
                    }
                        
                    if (rectPoly &&  // only for rectangles optionally show the center
                        [[NSUserDefaults standardUserDefaults] boolForKey: @"drawROICircleCenter"])
                    {
                        glm::vec2 pp((rectCenter.x - offset.x) * scaleValue,
                                     (rectCenter.y - offset.y) * scaleValue);

                        [pArray addObject: [NSValue valueWithBytes:&pp objCType:@encode(glm::vec2)]];

                    }

                    [curView setShaderProgramOverlay_withMode_Point];
                    renderer_drawPoints([pArray copy]);
					
					if (type == tClosedPolygon || type == tPencil)
					{
#pragma mark define textualdata (tClosedPolygon, tPencil)
						if (self.isTextualDataDisplayed && prepareTextualData)
						{
							NSPoint tPt = self.lowerRightPoint;
							
							if ([name isEqualToString:@"Unnamed"] == NO &&
                               [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
                            {
                                self.textualBoxLine1 = name;
                            }
                            else
                                self.textualBoxLine1 = nil;
                            
							if (ROITEXTNAMEONLY == NO )
							{
                                [self computeROIIfNedeed];
                                
                                BOOL roiInsideAnUsRegion = FALSE;
                                DCMUSRegion *usR = nil;
                                
                                if ([[self pix] hasUSRegions])
                                {
                                    MyPoint *firstPoint = [splinePoints3 objectAtIndex:0];
                                
                                    float xMin = [firstPoint x];
                                    float xMax = [firstPoint x];
                                    float yMin = [firstPoint y];
                                    float yMax = [firstPoint y];
                                    
                                    float x, y;
                                    
                                    for (MyPoint *aPoint in splinePoints3)
                                    {
                                        x = [aPoint x];
                                        y = [aPoint y];
                                        
                                        if (x < xMin) xMin = x;
                                        if (x > xMax) xMax = x;
                                        if (y < yMin) yMin = y;
                                        if (y > yMax) yMax = y;
                                    }
                                    
                                    NSPoint roiPoint1 = NSMakePoint(xMin, yMin);
                                    NSPoint roiPoint2 = NSMakePoint(xMax, yMax);
                                    
                                    for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                                    {
                                        if (!roiInsideAnUsRegion)
                                        {
                                            // 2D spatial format
                                            int usRegionMinX = [anUsRegion regionLocationMinX0];
                                            int usRegionMinY = [anUsRegion regionLocationMinY0];
                                            int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                                            int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                                            
                                            roiInsideAnUsRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                                                   ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                                                   ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                                                   ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                                            
                                            if (roiInsideAnUsRegion)
                                            {
                                                usR = anUsRegion;
                                                if (usR.regionSpatialFormat == 0 && usR.physicalUnitsXDirection == 0 && usR.physicalUnitsYDirection == 0)
                                                {
                                                    // RSF=none, PUXD=none, PUYD=none
                                                    roiInsideAnUsRegion = FALSE;
                                                    usR = nil;
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                float area = [self Area: splinePoints3];
                                
                                if (roiInsideAnUsRegion && usR)
                                {
                                    [self displayPolygonUsRegion: usR spline: splinePoints3 area: area];
                                }
                                else
                                {
                                    self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2", nil), area];
                                    
                                    if ((pixelSpacingX != 0 && pixelSpacingY != 0 && ![[self pix] hasUSRegions]))
                                    {
                                        if (area *pixelSpacingX*pixelSpacingY < 1.)
                                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2", nil), area *pixelSpacingX*pixelSpacingY * 1000000.0, 0xB5];
                                        else if (area *pixelSpacingX*pixelSpacingY/100. < 1.)
                                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2", nil), area *pixelSpacingX*pixelSpacingY];
                                        else
                                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f cm\u00B2", nil), area *pixelSpacingX*pixelSpacingY / 100.];
                                        
                                        NSPoint rectCenter = NSZeroPoint;
                                        double sideW = 0;
                                        double sideH = 0;
                                        
                                        if (type == tClosedPolygon &&
                                           _isSpline == NO &&
                                            [ROI isPolygonRectangle: splinePoints3 width: &sideW height: &sideH center: &rectCenter])
                                        {
                                            self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingString: @" "];
                                            
                                            if (area *pixelSpacingX*pixelSpacingY < 1.)
                                                self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingFormat: NSLocalizedString( @"(W:a %0.1f %cm H: %0.1f %cm)", nil), sideW *pixelSpacingX * 1000.0, 0xB5, sideH *pixelSpacingX * 1000.0, 0xB5]; // TBC: why "W:a" ?
                                            else if (area *pixelSpacingX*pixelSpacingY/100. < 1.)
                                                self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingFormat: NSLocalizedString( @"(W: %0.3f mm H: %0.3f mm)", nil), sideW *pixelSpacingY, sideH *pixelSpacingX];
                                            else
                                                self.textualBoxLine2 = [self.textualBoxLine2 stringByAppendingFormat: NSLocalizedString( @"(W: %0.3f cm H: %0.3f cm)", nil), sideW *pixelSpacingY / 10., sideH *pixelSpacingX / 10.];
                                        }
                                    }
                                
                                    NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
                                
                                    if ([self pix].SUVConverted)
                                        pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                                
                                    self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
                                    
                                    if (rskewness || rkurtosis)
                                        self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), rmin, pixelUnit, rmax, pixelUnit, rskewness, rkurtosis];
                                    else
                                        self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
                                    
                                    if ([splinePoints3 count] < 2)
                                        self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f cm", nil), 0.0];
                                    else
                                    {
                                        if ([curView blendingView])
                                        {
                                            DCMPix	*blendedPix = [[curView blendingView] curDCM];
                                            ROI *b = [[self copy] autorelease];
                                            b.pix = blendedPix;
                                            b.curView = curView.blendingView;
                                            [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                                                  : blendedPix.pixelSpacingY
                                                                  : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                                            [b computeROIIfNedeed];
                                            
                                            NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                                            
                                            if (blendedPix.SUVConverted)
                                                pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                                            
                                            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                                            
                                            if (b.skewness || b.kurtosis)
                                                self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@ Skewness: %0.3f Kurtosis: %0.3f", nil), b.min, pixelUnit, b.max, pixelUnit, b.skewness, b.kurtosis];
                                            else
                                                self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
                                        }
                                        else
                                        {
                                            if (rLength >= 0)
                                            {
                                                if (rLength < .01)
                                                    self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.1f %cm", nil), rLength * 10000.0, 0xB5];
                                                else if ( rLength < 1)
                                                    self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f mm", nil), rLength * 10.0];
                                                else
                                                    self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f cm", nil), rLength];
                                            }
                                        }
                                    }
                                }
							}
							
							[self prepareTextualData:tPt];
						}
					} // tClosedPolygon, tPencil
					else if (type == tOpenPolygon)
					{
#pragma mark define textualdata (tOpenPolygon)
						if (self.isTextualDataDisplayed && prepareTextualData)
						{
							NSPoint tPt = self.lowerRightPoint;
							
							if ([name isEqualToString:@"Unnamed"] == NO && [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
                                self.textualBoxLine1 = name;
                            else
                                self.textualBoxLine1 = nil;
                            
							if (ROITEXTNAMEONLY == NO )
							{
                                [self computeROIIfNedeed];
                                
                                BOOL roiInsideAnUsRegion = FALSE;
                                DCMUSRegion *usR = nil;
                                
                                if ([[self pix] hasUSRegions])
                                {
                                    MyPoint *firstPoint = [splinePoints3 objectAtIndex:0];
                                    
                                    float xMin = [firstPoint x];
                                    float xMax = [firstPoint x];
                                    float yMin = [firstPoint y];
                                    float yMax = [firstPoint y];
                                    
                                    float x, y;
                                    
                                    for (MyPoint *aPoint in splinePoints3)
                                    {
                                        x = [aPoint x];
                                        y = [aPoint y];
                                        
                                        if (x < xMin) xMin = x;
                                        if (x > xMax) xMax = x;
                                        if (y < yMin) yMin = y;
                                        if (y > yMax) yMax = y;
                                    }
                                    
                                    NSPoint roiPoint1 = NSMakePoint(xMin, yMin);
                                    NSPoint roiPoint2 = NSMakePoint(xMax, yMax);
                                    
                                    for (DCMUSRegion *anUsRegion in self.pix.usRegions)
                                    {
                                        if (!roiInsideAnUsRegion)
                                        {
                                            // 2D spatial format
                                            int usRegionMinX = [anUsRegion regionLocationMinX0];
                                            int usRegionMinY = [anUsRegion regionLocationMinY0];
                                            int usRegionMaxX = [anUsRegion regionLocationMaxX1];
                                            int usRegionMaxY = [anUsRegion regionLocationMaxY1];
                                            
                                            //NSLog(@"usRegion [%i,%i] [%i,%i]", usRegionMinX, usRegionMinY, usRegionMaxX, usRegionMaxY);
                                            
                                            roiInsideAnUsRegion = (((int)roiPoint1.x >= usRegionMinX) && ((int)roiPoint1.x <= usRegionMaxX) &&
                                                                   ((int)roiPoint1.y >= usRegionMinY) && ((int)roiPoint1.y <= usRegionMaxY) &&
                                                                   ((int)roiPoint2.x >= usRegionMinX) && ((int)roiPoint2.x <= usRegionMaxX) &&
                                                                   ((int)roiPoint2.y >= usRegionMinY) && ((int)roiPoint2.y <= usRegionMaxY));
                                            
                                            if (roiInsideAnUsRegion)
                                            {
                                                usR = anUsRegion;
                                                if (usR.regionSpatialFormat == 0 &&
                                                    usR.physicalUnitsXDirection == 0 &&
                                                    usR.physicalUnitsYDirection == 0)
                                                {
                                                    // RSF=none, PUXD=none, PUYD=none
                                                    roiInsideAnUsRegion = FALSE;
                                                    usR = nil;
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                float area = [self Area: splinePoints3];
                                
                                if (roiInsideAnUsRegion && usR)
                                {
                                    [self displayPolygonUsRegion: usR
                                                          spline: splinePoints3
                                                            area: area];
                                }
                                else
                                {
                                    BOOL areaAvailable = YES;
                                    
                                    // The first and the last point are too far away : probably not a good idea to display the Area
                                    if ([self Length: [[splinePoints3 objectAtIndex: 0] point] :[[splinePoints3 lastObject] point]] > rLength / RATIO_FOROPOLYGONAREA)
                                    {
                                        areaAvailable = NO;
                                    }
                                    else
                                    {
                                        if (pixelSpacingX != 0 && pixelSpacingY != 0)
                                        {
                                            if (area *pixelSpacingX*pixelSpacingY < 1.)
                                                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.1f %cm\u00B2", nil), area *pixelSpacingX*pixelSpacingY * 1000000.0, 0xB5];
                                            else if (area *pixelSpacingX*pixelSpacingY/100. < 1.)
                                                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f mm\u00B2", nil), area *pixelSpacingX*pixelSpacingY];
                                            else
                                                self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f cm\u00B2", nil), area *pixelSpacingX*pixelSpacingY / 100.];
                                        }
                                        else
                                            self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Area: %0.3f pix\u00B2", nil), area];
                                        
                                        NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", self.pix.rescaleType];
                                        
                                        if ([self pix].SUVConverted)
                                            pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                                        
                                        self.textualBoxLine3 = [NSString stringWithFormat: NSLocalizedString( @"Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), rmean, pixelUnit, rdev, pixelUnit, [ROI totalLocalized: rtotal], pixelUnit];
                                        self.textualBoxLine4 = [NSString stringWithFormat: NSLocalizedString( @"Min: %0.3f%@ Max: %0.3f%@", nil), rmin, pixelUnit, rmax, pixelUnit];
                                    }
                                    
                                    if ([curView blendingView])
                                    {
                                        DCMPix	*blendedPix = [[curView blendingView] curDCM];
                                        ROI *b = [[self copy] autorelease];
                                        b.pix = blendedPix;
                                        b.curView = curView.blendingView;
                                        [b setOriginAndSpacing:blendedPix.pixelSpacingX
                                                              :blendedPix.pixelSpacingY
                                                              :[DCMPix originCorrectedAccordingToOrientation: blendedPix]];
                                        [b computeROIIfNedeed];
                                        
                                        NSString *pixelUnit = [NSString stringWithFormat:@" %@ ", blendedPix.rescaleType];
                                        
                                        if (blendedPix.SUVConverted)
                                            pixelUnit = [NSString stringWithFormat:@" %@ ", NSLocalizedString( @"SUV", @"SUV = Standard Uptake Value")];
                                        
                                        self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Mean: %0.3f%@ SDev: %0.3f%@ Sum: %@%@", nil), b.mean, pixelUnit, b.dev, pixelUnit, [ROI totalLocalized: b.total], pixelUnit];
                                        self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"Fused Image Min: %0.3f%@ Max: %0.3f%@", nil), b.min, pixelUnit, b.max, pixelUnit];
                                    }
                                    
                                    if (rLength >= 0)
                                    {
                                        if (rLength < .01)
                                            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.1f %cm", nil), rLength * 10000.0, 0xB5];
                                        else if (rLength < 1)
                                            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f mm", nil), rLength * 10.0];
                                        else
                                            self.textualBoxLine5 = [NSString stringWithFormat: NSLocalizedString( @"Length: %0.3f cm", nil), rLength];
                                    }
                                    
                                    // 3D Length
                                    if (curView &&
                                        pixelSpacingX != 0 &&
                                        pixelSpacingY != 0 &&
                                        [[NSUserDefaults standardUserDefaults] boolForKey: @"splineForROI"] == NO)
                                    {
                                        NSArray *zPosArray = [self zPositions];
                            
                                        if ([zPosArray count])
                                        {
                                            int zPos = [[zPosArray objectAtIndex:0] intValue];
                                            for (int i = 1; i < [zPosArray count]; i++)
                                            {
                                                if (zPos != [[zPosArray objectAtIndex:i] intValue])
                                                {
                                                    if ([zPosArray count] != [points count])
                                                        NSLog( @"***** [zPosArray count] != [points count]");
                                                    
                                                    double sliceInterval = [[self pix] sliceInterval];
                                                    
                                                    // Compute 3D distance between each points
                                                    double distance3d = 0;
                                                    for (i = 1; i < (long)[points count]; i++)
                                                    {
                                                        double x[ 3];
                                                        double y[ 3];
                                                        
                                                        x[ 0] = [[points objectAtIndex:i] point].x * pixelSpacingX;
                                                        x[ 1] = [[points objectAtIndex:i] point].y * pixelSpacingY;
                                                        x[ 2] = [[zPosArray objectAtIndex:i] intValue] * sliceInterval;
                                                        
                                                        y[ 0] = [[points objectAtIndex:i-1] point].x * pixelSpacingX;
                                                        y[ 1] = [[points objectAtIndex:i-1] point].y * pixelSpacingY;
                                                        y[ 2] = [[zPosArray objectAtIndex:i-1] intValue] * sliceInterval;
                                                        
                                                        distance3d += sqrt((x[0]-y[0])*(x[0]-y[0]) +
                                                                           (x[1]-y[1])*(x[1]-y[1]) +
                                                                           (x[2]-y[2])*(x[2]-y[2]));
                                                    }
                                                    
                                                    if (distance3d < .01)
                                                        self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"3D Length: %0.1f %cm", nil), distance3d * 10000.0, 0xB5];
                                                    else if (distance3d < 1)
                                                        self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"3D Length: %0.3f mm", nil), distance3d * 10.0];
                                                    else
                                                        self.textualBoxLine6 = [NSString stringWithFormat: NSLocalizedString( @"3D Length: %0.3f cm", nil), distance3d / 10.];
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
							}
							
							[self prepareTextualData:tPt];
						}
					} // tOpenPolygon
					else if (type == tAngle)
					{
						if ([points count] == 3)
						{
							displayTextualData = YES;
                            
#pragma mark define textualdata (tAngle)

                            if (self.isTextualDataDisplayed && prepareTextualData)
							{
								NSPoint tPt = self.lowerRightPoint;
								
								if ([name isEqualToString:@"Unnamed"] == NO &&
                                    [name isEqualToString: NSLocalizedString( @"Unnamed", nil)] == NO)
                                {
                                    self.textualBoxLine1 = name;
                                }
                                else
                                    self.textualBoxLine1 = nil;
                                
								float angleDeg = [self Angle:[[points objectAtIndex: 0] point]
                                                   :[[points objectAtIndex: 1] point]
                                                   :[[points objectAtIndex: 2] point]];
								
								self.textualBoxLine2 = [NSString stringWithFormat: NSLocalizedString( @"Angle: %0.2f%@ / %0.2f%@", nil), angleDeg, @"\u00B0", 360 - angleDeg, @"\u00B0"];
								
								[self prepareTextualData:tPt];
							}
						}
						else
                            displayTextualData = NO;
					} // tAngle
					
#pragma mark highlight selected
					if ((mode == ROI_selected || mode == ROI_selectedModify || mode == ROI_drawing) && highlightIfSelected)
					{
						[curView window];  // What is this doing ?
						
						NSPoint tempPt = [curView convertPoint: [[curView window] mouseLocationOutsideOfEventStream] fromView: nil];
						tempPt = [curView ConvertFromNSView2GL:tempPt];

                        NSMutableArray *arrayPoint2DColor = [NSMutableArray array];

                        for (long i = 0; i < [points count]; i++)
                        {
                            Point_xy_rgb pc;

                            if (mode >= ROI_selected && (i == selectedModifyPoint || i == PointUnderMouse))
                            {
                                pc.c = {1.0f, 0.2f, 0.2f};  // light red
                            }
                            else if (mode == ROI_drawing &&
                                     [[points objectAtIndex: i] isNearToPoint: tempPt
                                                                             : scaleValue/(thick*backingScaleFactor)
                                                                             : [[curView curDCM] pixelRatio]])
                            {
                                pc.c = {1.0f, 0.0f, 1.0f}; // magenta
                            }
                            else
                            {
                                pc.c = {0.5f, 0.5f, 1.0f}; // light blue
                            }
                            
                            pc.p = {([[points objectAtIndex: i] x] - offset.x) * scaleValue,
                                    ([[points objectAtIndex: i] y] - offset.y) * scaleValue};
                            
                            [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
                        }
                        
                        // Only for rectangles. Is this ever used ?
                        if (rectPoly && [[NSUserDefaults standardUserDefaults] boolForKey: @"drawROICircleCenter"])
                        {
                            Point_xy_rgb pc;
                            pc.c = {0.5f, 0.5f, 1.0f}; // TBC

                            pc.p.x = (rectCenter.x - offset.x) * scaleValue;
                            pc.p.y = (rectCenter.y - offset.y) * scaleValue;
                            [arrayPoint2DColor addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
                        }

#ifdef WITH_OPENGL_32
                        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
                        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);
                        renderer_set_rgb(0.5f, 0.5f, 1.0f); // light blue, redundant here
                        renderer_drawPoints_xy_rgb([arrayPoint2DColor copy]);
					}
					                    
#pragma mark point under mouse

                    if ((PointUnderMouse != -1) &&
                        (PointUnderMouse < [points count]))
					{
#ifdef WITH_OPENGL_32
                        [curView setShaderProgramOverlay_withMode_Point]; // Added
#endif
                        glPointSize( (1 * backingScaleFactor + sqrt( thick))*3.5 * backingScaleFactor);

                        NSMutableArray *pArray = [NSMutableArray array];
                        Point_xy_rgb pc;
                        pc.c = glm::vec3(1.0f, 0.0f, 1.0f);  // magenta
                        pc.p = glm::vec2(([[points objectAtIndex: PointUnderMouse] x] - offset.x) * scaleValue,
                                         ([[points objectAtIndex: PointUnderMouse] y] - offset.y) * scaleValue);
    #if 1 // Either way is okay, but maybe the first one is better as it can be merged with previous code
                        [pArray addObject: [NSValue valueWithBytes:&pc objCType:@encode(Point_xy_rgb)]];
                        renderer_drawPoints_xy_rgb([pArray copy]);
    #else
                        renderer_set_rgb(1.0f, 0.0f, 1.0f);  // magenta
                        [pArray addObject: [NSValue valueWithBytes:&pc.p objCType:@encode(glm::vec2)]];
                        renderer_drawPoints([pArray copy]);
    #endif
					}
					
                    // Restore
#ifndef WITH_OPENGL_32
                    [curView setShaderProgramForLineWidth: 1.0 * curView.window.backingScaleFactor];
                    renderer_set_rgb(1.0f, 1.0f, 1.0f); // white
#endif
				}
			}
                break;

            default:
                break;
		}  // switch
		
		glPointSize( 1.0 * backingScaleFactor);
		
        renderer_disable_blend_smooth();
	}
	@catch (NSException *e)
	{
		NSLog(@"%s %d, exception: %@", __FUNCTION__, __LINE__, e);
	}

    [roiLock unlock];
}

#pragma mark -

- (float*) dataValuesAsFloatPointer :(long*) no
{
	float *data = nil;
	
	switch(type)
	{
		case tMeasure:
			data = [[self pix] getLineROIValue:no :self];
            break;
		
		default:
			data = [[self pix] getROIValue:no :self :nil];
            break;
	}
	
	return data;
}

- (NSMutableArray*) dataValues
{
	NSMutableArray* array = [NSMutableArray array];

	long no;
	float *data = [self dataValuesAsFloatPointer: &no];
	
	if (data)
	{
		for (long i = 0 ; i < no; i++) {
			[array addObject:[NSNumber numberWithFloat: data[ i]]];
		}
		
		free( data);
	}
	
	return array;
}


-(NSPoint)pointAtIndex:(NSUInteger)index {
	return [[[self points] objectAtIndex:index] point];
}

-(void)setPoint:(NSPoint)point atIndex:(NSUInteger)index{
    [self recompute];
	[[[self points] objectAtIndex:index] setPoint:point];
}

-(void)addPoint:(NSPoint)point {
    [self recompute];
	[[self points] addObject:[MyPoint point:point]];
}

- (NSMutableDictionary*) dataString
{
	NSMutableDictionary* array = [NSMutableDictionary dictionary];
		
	switch( type)
	{
        case tBall:
//            break;	// TBC
            
        case tOvalAngle:
		case tOval:
		case tROI:
		case tDynAngle:
        case tTAGT:
		case tAxis:
		case tClosedPolygon:
		case tOpenPolygon:
		case tPencil:
		case tPlain:
            {
                array = [NSMutableDictionary dictionaryWithCapacity:0];
                
                [self computeROIIfNedeed];

                if (type == tBall)
                {
                    // TODO: set some volume parameter...
                }

                if (type == tOval || type == tOvalAngle)
                {
                    if (pixelSpacingX != 0 && pixelSpacingY != 0)
                        [array setObject: [NSNumber numberWithFloat:[self EllipseArea] *pixelSpacingX*pixelSpacingY / 100.] forKey:@"AreaCM2"];
                    else
                        [array setObject: [NSNumber numberWithFloat:[self EllipseArea]] forKey:@"AreaPIX2"];
                }
                else if (type == tROI)
                {
                    if (pixelSpacingX != 0 && pixelSpacingY != 0)
                        [array setObject: [NSNumber numberWithFloat:NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY / 100.] forKey:@"AreaCM2"];
                    else
                        [array setObject: [NSNumber numberWithFloat:NSWidth(rect)*NSHeight(rect)] forKey:@"AreaPIX2"];
                }
                else
                {
                    if (pixelSpacingX != 0 && pixelSpacingY != 0)
                        [array setObject: [NSNumber numberWithFloat:[self Area] *pixelSpacingX*pixelSpacingY / 100.] forKey:@"AreaCM2"];
                    else
                        [array setObject: [NSNumber numberWithFloat:[self Area]] forKey:@"AreaPIX2"];
                }
                    
                [array setObject: [NSNumber numberWithFloat:rmean] forKey:@"Mean"];
                [array setObject: [NSNumber numberWithFloat:rdev] forKey:@"Dev"];
                [array setObject: [NSNumber numberWithFloat:rtotal] forKey:@"Total"];
                [array setObject: [NSNumber numberWithFloat:rmin] forKey:@"Min"];
                [array setObject: [NSNumber numberWithFloat:rmax] forKey:@"Max"];
                
                float length = 0;
                long ii = 0;
                NSMutableArray* ptsTemp = self.points;
                if ([self.points count] > 0)
                {
                    for (ii = 0; ii < (long)[ptsTemp count]-1; ii++ )
                        length += [self Length:[[ptsTemp objectAtIndex:ii] point]
                                              :[[ptsTemp objectAtIndex:ii+1] point]];
                }
                
                if (type != tOpenPolygon && [ptsTemp count] > 0)
                    length += [self Length:[[ptsTemp objectAtIndex:ii] point]
                                          :[[ptsTemp objectAtIndex:0] point]];
                
                [array setObject: [NSNumber numberWithFloat:length] forKey:@"Length"];
            }
            break;
		
		case tAngle:
            {
                array = [NSMutableDictionary dictionaryWithCapacity:0];
                
                float angleDeg = [self Angle:[[points objectAtIndex: 0] point]
                                            :[[points objectAtIndex: 1] point]
                                            :[[points objectAtIndex: 2] point]];
                [array setObject: [NSNumber numberWithFloat:angleDeg] forKey:@"Angle"];
            }
            break;
		
		case tMeasure:
            {
                array = [NSMutableDictionary dictionaryWithCapacity:0];
                
                float length = [self Length:[[points objectAtIndex:0] point]
                                           :[[points objectAtIndex:1] point]];
                [array setObject: [NSNumber numberWithFloat:length] forKey:@"Length"];
            }
            break;

        default:
            break;
	}
	
	return array;
}

- (BOOL) needQuartz
{
	switch (type)
	{
		default:
            return NO;
            break;
	}
	
	return NO;
}

- (void) setRoiView:(DCMView*) v __deprecated
{
    self.curView = v;
}

- (void) setPix:(DCMPix *)p
{
    if (_pix != p)
    {
        [_pix release];
        _pix = [p retain];
        
        [self recompute];
    }
}

- (void) setCurView:(DCMView *) v
{
    if (curView != v)
    {
        [self recompute];
        
        curView = v;
    }
}

- (float) roiArea
{
	if (pixelSpacingX == 0 && pixelSpacingY == 0 )
        return 0;

	switch( type)
	{
		case tDynAngle:
		case tAxis:
		case tOpenPolygon:
		case tClosedPolygon:
		case tPencil:
			return ([self Area] *pixelSpacingX*pixelSpacingY) / 100.;
            break;
		
		case tROI:
			return NSWidth(rect)*pixelSpacingX*NSHeight(rect)*pixelSpacingY/100.;
            break;
		
        case tBall: // TODO: can the ball be squashed like an ellipse ?
        case tOvalAngle:
		case tOval:
			return ([self EllipseArea]*pixelSpacingX*pixelSpacingY)/100.;
            break;

		case tPlain:
            {
                float area=0.0;
                if (textureBuffer)
                {
                    for (long i = 0; i < textureWidth*textureHeight;i++)
                        if (textureBuffer[i]!=0)
                            area++;
                }
                return (area*pixelSpacingX*pixelSpacingY)/100.;
            }
            break;
            
        default:
            break;
	}
	
	return 0.0f;
}

- (NSPoint) centroid
{
	if (type == tOval || type == tBall || type == tOvalAngle)
		return rect.origin;
	
    if (type == tROI)
        return NSMakePoint(NSMidX(rect), NSMidY(rect));
    
    if (self.points.count == 0)
        return NSZeroPoint;
    
	NSPoint centroid = NSZeroPoint;
		
	for ( MyPoint *p in self.points)
	{
		centroid.x += [p x];
		centroid.y += [p y];
	}
	
    centroid.x /= self.points.count;
    centroid.y /= self.points.count;
    
	return centroid;
}

+ (unsigned char*) addMargin: (int) margin
                      buffer: (unsigned char *) textureBuffer
                       width: (int) width
                      height: (int) height
{
	int newWidth = width + 2*margin;
	int newHeight = height + 2*margin;
    
	unsigned char* newBuffer, *originalBuffer;
    
    newBuffer = originalBuffer = (unsigned char*)calloc(newWidth*newHeight, sizeof(unsigned char));
	
	if (newBuffer)
	{
		for (int i=0; i<margin; i++)
		{
			// skip the 'margin' first lines
			newBuffer += newWidth;
		}
		
		unsigned char *temptextureBuffer = textureBuffer;
		
		for (int i=0; i<height; i++)
		{
			newBuffer += margin; // skip the left margin pixels
			memcpy( newBuffer,temptextureBuffer,width*sizeof(unsigned char));
			newBuffer += width+margin; // move to the next line, skipping the right margin pixels
			temptextureBuffer += width; // move to the next line
		}
	}
    
    return originalBuffer;
}

- (void) addMarginToBuffer: (int) margin
{
    unsigned char* newBuffer = [ROI addMargin: margin buffer: textureBuffer width: textureWidth height: textureHeight];
    
	textureWidth += 2*margin;
	textureHeight += 2*margin;
	
    if (textureBuffer)
        free( textureBuffer);

    textureBuffer = newBuffer;
    
    textureDownRightCornerX += margin;
    textureDownRightCornerY += margin;
    textureUpLeftCornerX -= margin;
    textureUpLeftCornerY -= margin;
    
    [self textureBufferHasChanged];
}

// Calcium Scoring
// Should we check to see if we using a brush ROI and other appropriate checks before return a calcium measurement?

- (int)calciumScoreCofactor
{
	/* 
	Cofactor values used by Agaston.  
	Using a threshold of 90 rather than 130. Assuming
	multislice CT rather than electron beam.
	We could have a flag for Electron beam rather than multichannel CT
	and use 130 as a cutoff
	*/
    [self computeROIIfNedeed];
    
	if (_calciumCofactor == 0)
		_calciumCofactor = [[self pix] calciumCofactorForROI:self threshold:_calciumThreshold];
	//NSLog(@"cofactor: %d", _calciumCofactor);
	return _calciumCofactor;
}

- (float)calciumScore
{
	// roi Area * cofactor;  area is is mm2.
	//plainArea is number of pixels 
	// still to compensate for overlapping slices interval/sliceThickness
	
    [self computeROIIfNedeed];
    
	//area needs to be > 1 mm
	
	float intervalRatio = 1;
	
	if (curView)
		intervalRatio = fabs([[self pix] sliceInterval] / [[self pix] sliceThickness]);
	else
		NSLog( @"curView == nil");
	
	if (intervalRatio > 1)
		intervalRatio = 1;
	
	float area = [self plainArea] * pixelSpacingX * pixelSpacingY;
	//if (area < 1)
	//	return 0;
	return area * [self calciumScoreCofactor] * intervalRatio ;   
}

- (float)calciumVolume
{
	// area * thickness
	
    [self computeROIIfNedeed];
    
	float area = [self plainArea] * pixelSpacingX * pixelSpacingY;
	//if (area < 1)
	//	return 0;
	
	return area * [[self pix] sliceThickness];
	//return [self roiArea] * [self thickness] * 100;
}

- (float) calciumMass
{
	//Volume * mean CT Density / 250
    [self computeROIIfNedeed];
	
	return fabs( [self calciumVolume] * rmean)/ 250;
}

- (void) setLayerImage:(NSImage*)image;
{
	if (layerImage) [layerImage release];
	layerImage = [image retain];
	
	isLayerOpacityConstant = YES;
	canColorizeLayer = NO;
	
//    NSBitmapImageRep* rep = [[image representations] objectAtIndex:0];
//	NSSize imageSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh); // [layerImage size];
	NSSize imageSize = [layerImage size];
	float imageWidth = imageSize.width;
	float imageHeight = imageSize.height;
	
	float scaleFactorX;
	float scaleFactorY;

	if (pixelSpacingX != 0 && pixelSpacingY != 0 )
	{
		scaleFactorX = layerPixelSpacingX / pixelSpacingX;
		scaleFactorY = layerPixelSpacingY / pixelSpacingY;
	}
	else
	{
		scaleFactorX = 1.0;
		scaleFactorY = 1.0;
	}
	
	NSPoint p1 = NSZeroPoint;
	NSPoint p2 = NSMakePoint(imageWidth*scaleFactorX, 0.0);
	NSPoint p3 = NSMakePoint(imageWidth*scaleFactorX, imageHeight*scaleFactorY);
	NSPoint p4 = NSMakePoint(0.0, imageHeight*scaleFactorY);

	NSArray *pts = [NSArray arrayWithObjects:[MyPoint point:p1],
                                             [MyPoint point:p2],
                                             [MyPoint point:p3],
                                             [MyPoint point:p4],
                                             nil];
	[points setArray:pts];
	[self generateEncodedLayerImage];
	[self loadLayerImageTexture];
}

- (GLuint) loadLayerImageTexture;
{
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithData: [layerImage TIFFRepresentation]];
    size_t height = [bitmap pixelsHigh], width = [bitmap pixelsWide];
//    NSSize osize = [layerImage size];

	int bytesPerRow = [bitmap bytesPerRow];
	int spp = [bitmap samplesPerPixel];
	
    if (textureBuffer) {
        free(textureBuffer);
        textureBuffer = nil;
    }
	
    [self textureBufferHasChanged];
    
	if (spp == 1)
	{
		bytesPerRow = [bitmap bytesPerRow]/spp;
		bytesPerRow *= 4;

		unsigned char *tmpImage = (unsigned char *)malloc (bytesPerRow * height);
        if (tmpImage)
        {
            int	loop = (int) height * bytesPerRow/4;
            unsigned char *ptr = tmpImage;
            unsigned char *bufPtr = [bitmap bitmapData];
            while (loop-- > 0)
            {
                *ptr++	= *bufPtr;
                *ptr++	= *bufPtr;
                *ptr++	= *bufPtr++;
                *ptr++	= 255;
            }
            
            textureBuffer = tmpImage;
        }
	}
	else if (spp == 3)
	{
		bytesPerRow = [bitmap bytesPerRow]/spp;
		bytesPerRow *= 4;

		unsigned char *tmpImage = (unsigned char *)malloc (bytesPerRow * height);
		int	loop = (int) height * bytesPerRow/4;
		unsigned char *ptr = tmpImage;
        if (tmpImage)
        {
            unsigned char   *bufPtr;
            bufPtr = [bitmap bitmapData];
            while (loop-- > 0)
            {
                *ptr++	= *bufPtr++;
                *ptr++	= *bufPtr++;
                *ptr++	= *bufPtr++;
                *ptr++	= 255;
            }
            
            textureBuffer = tmpImage;
        }
	}
	else
	{
		textureBuffer = (unsigned char *)malloc(bytesPerRow * height);
        if (textureBuffer)
            memcpy( textureBuffer, [bitmap bitmapData], [bitmap bytesPerRow] * height);
	}
	
    if (textureBuffer == nil) {
        [bitmap release];
        return 0;
    }
    
	if (!isLayerOpacityConstant)// && opacity<1.0)
	{
		unsigned char *rgbaPtr = (unsigned char*) textureBuffer;
		long ss = bytesPerRow/4 * height;
		
		while (ss-- > 0)
		{
			unsigned char r = *(rgbaPtr+0);
			unsigned char g = *(rgbaPtr+1);
			unsigned char b = *(rgbaPtr+2);
			
			*(rgbaPtr+0) = (r+g+b) / 3 * opacity;
			*(rgbaPtr+1) = r;
			*(rgbaPtr+2) = g;
			*(rgbaPtr+3) = b;
			
			rgbaPtr+= 4;
		}
	}
	else
	{
		unsigned char *rgbaPtr = (unsigned char*) textureBuffer;
		long ss = bytesPerRow/4 * height;
		
		while (ss-- > 0)
		{
			unsigned char r = *(rgbaPtr+0);
			unsigned char g = *(rgbaPtr+1);
			unsigned char b = *(rgbaPtr+2);
			unsigned char a = *(rgbaPtr+3);
			
			*(rgbaPtr+0) = a;
			*(rgbaPtr+1) = r;
			*(rgbaPtr+2) = g;
			*(rgbaPtr+3) = b;
			
			rgbaPtr+= 4;
		}
	}

	if (canColorizeLayer && layerColor)
	{
		vImage_Buffer dest;
		dest.height = height;
		dest.width = width;
		dest.rowBytes = bytesPerRow;
		dest.data = textureBuffer;
		
		vImage_Buffer src = dest;
		
		unsigned char redTable[ 256];
        unsigned char greenTable[ 256];
        unsigned char blueTable[ 256];
        unsigned char alphaTable[ 256];
			
		for (int i = 0; i < 256; i++ ) {
			redTable[i] = (float) i * [layerColor redComponent];
			greenTable[i] = (float) i * [layerColor greenComponent];
			blueTable[i] = (float) i * [layerColor blueComponent];
			alphaTable[i] = (float) i * opacity;
		}
		
		//vImageOverwriteChannels_ARGB8888(const vImage_Buffer *newSrc, &src, &dest, 0x4, 0);
		
//		#if __BIG_ENDIAN__
//		vImageTableLookUp_ARGB8888( &src, &dest, (Pixel_8*) &alphaTable, (Pixel_8*) redTable, (Pixel_8*) greenTable, (Pixel_8*) blueTable, 0);
//		#else
//		vImageTableLookUp_ARGB8888( &dest, &dest, (Pixel_8*) blueTable, (Pixel_8*) greenTable, (Pixel_8*) redTable, (Pixel_8*) &alphaTable, 0);
//		#endif

		vImageTableLookUp_ARGB8888( &src, &dest, (Pixel_8*) &alphaTable, (Pixel_8*) redTable, (Pixel_8*) greenTable, (Pixel_8*) blueTable, 0);
	}
	
	NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
#ifndef WITH_OPENGL_32
	CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif
	
	[self deleteTexture: currentContext];
	
#ifdef WITH_OPENGL_32
    GLenum target = GL_TEXTURE_RECTANGLE;
#else
    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
#endif

    GLuint tex_ID = 0;
	glGenTextures(1, &tex_ID);
	glBindTexture(target, tex_ID);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, bytesPerRow/4);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

#ifdef WITH_OPENGL_32
    // TODO:
    //NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
#else
    // The cached hint specifies to cache texture data in video memory. This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering
	glTexParameteri(target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif // WITH_OPENGL_32

    GLint param;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NOINTERPOLATION"])
        param = GL_NEAREST;
    else
        param = GL_LINEAR;

    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, param);	//GL_LINEAR_MIPMAP_LINEAR
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, param);	//GL_LINEAR_MIPMAP_LINEAR
//#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
    
#if __BIG_ENDIAN__
    GLenum _type = GL_UNSIGNED_INT_8_8_8_8_REV;
#else
    GLenum _type = GL_UNSIGNED_INT_8_8_8_8;
#endif

    glTexImage2D(target, 0,
                 GL_RGBA,
                 width, height, 0,
                 GL_BGRA, _type,
                 textureBuffer);

	[ctxArray addObject: currentContext];
	[textArray addObject: [NSNumber numberWithInt: tex_ID]];
			
	[bitmap release];
	
	return tex_ID;
}

- (void)generateEncodedLayerImage;
{
	if (layerImageJPEG)
        [layerImageJPEG release];
	
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData: [layerImage TIFFRepresentation]];
	
	NSSize size = [layerImage size];
	NSDictionary *imageProps;
	if (size.height>512 && size.width>512)
		imageProps = [NSDictionary dictionaryWithObject:@0.3F forKey:NSImageCompressionFactor];
	else
		imageProps = [NSDictionary dictionaryWithObject:@1.0F forKey:NSImageCompressionFactor];

    layerImageJPEG = [[imageRep representationUsingType:NSPNGFileType properties:imageProps] retain];	//NSJPEGFileType //NSJPEG2000FileType
}

NSInteger sortPointArrayAlongX(id point1, id point2, void *context)
{
    float x1 = (float)[point1 pointValue].x;
    float x2 = (float)[point2 pointValue].x;
    
	if (x1 < x2)
        return NSOrderedAscending;
    else if (x1 > x2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (BOOL)isPoint:(NSPoint)point inRectDefinedByPointA:(NSPoint)pointA pointB:(NSPoint)pointB pointC:(NSPoint)pointC pointD:(NSPoint)pointD;
{
    NSBezierPath* path = [NSBezierPath bezierPath];
    [path moveToPoint:pointA];
    [path lineToPoint:pointB];
    [path lineToPoint:pointC];
    [path lineToPoint:pointD];
    [path closePath];
    return [path containsPoint:point];
}

- (NSPoint)rotatePoint:(NSPoint)point
             withAngle:(float)alphaDeg
          aroundCenter:(NSPoint)center
{
    if (alphaDeg == 0)
        return point;
    
	float alphaRad = glm::radians(alphaDeg);
	float x = cos(alphaRad) * (point.x - center.x) - sin(alphaRad) * (point.y - center.y);
	float y = sin(alphaRad) * (point.x - center.x) + cos(alphaRad) * (point.y - center.y);
	return NSMakePoint(x+center.x, y+center.y);
}

- (void)setIsLayerOpacityConstant:(BOOL)boo
{
	isLayerOpacityConstant = boo;
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];
}

- (void)setCanColorizeLayer:(BOOL)boo
{
	canColorizeLayer = boo;
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];
}

- (void)setCanResizeLayer:(BOOL)boo
{
	canResizeLayer = boo;
}

#define DEFAULTSPLINESCALE 5.0

-(NSMutableArray*) splinePoints:(float) scale
{
    if (scale <= previousScaleForSplinePoints && cachedSplinePoints)
        return cachedSplinePoints;
    
    [cachedSplinePoints autorelease];
    cachedSplinePoints = [[self splinePoints: scale correspondingSegmentArray: nil] retain];
    previousScaleForSplinePoints = scale;
    
	return cachedSplinePoints;
}

-(NSMutableArray*) splinePoints;
{
    if (cachedSplinePointsWithoutScale)
        return cachedSplinePointsWithoutScale;
    
    [cachedSplinePointsWithoutScale autorelease];
    cachedSplinePointsWithoutScale = [[self splinePoints: DEFAULTSPLINESCALE correspondingSegmentArray: nil] retain];
    
	return cachedSplinePointsWithoutScale;
}

-(NSMutableArray*) splinePoints: (float) scale
      correspondingSegmentArray: (NSMutableArray**) correspondingSegmentArray
{
    if (pixelSpacingX != 0 && pixelSpacingY != 0)
    {
        scale = scale < pixelSpacingY*2. ? pixelSpacingY*2. : scale;
        scale = scale < pixelSpacingX*2. ? pixelSpacingX*2. : scale;
        
        scale = scale > pixelSpacingY*20. ? pixelSpacingY*20. : scale;
        scale = scale > pixelSpacingX*20. ? pixelSpacingX*20. : scale;
    }
    
	// activated in the prefs
	if ([self isSpline] == NO)
        return [self points];
	
	// available only for ROI types : Open Polygon, Close Polygon, Pencil
	// for other types, returns the original points
	if (type != tOpenPolygon &&
        type != tClosedPolygon &&
        type != tPencil)
    {
        return [self points];
    }
	
	// available only for polygons with at least 3 points
	if ([points count] < 3)
        return [self points];
	
	int nb;
    int localType = type;
	
	if (mode == ROI_drawing)
		localType = tOpenPolygon;
	
	if (localType == tOpenPolygon)
        nb = [points count];
	else
        nb = [points count]+1;

	NSPoint pts[nb];
	
	for (int i=0; i<[points count]; i++)
		pts[i] = [[points objectAtIndex:i] point];
	
	if (localType != tOpenPolygon && [points count] > 0)
		pts[[points count]] = [[points objectAtIndex:0] point]; // we add the first point as the last one to smooth the spline
							
	NSPoint *splinePts;
	
	long newNb = 0;
	long *correspondingSegments = nil;
	
	if (correspondingSegmentArray)
		newNb = spline( pts, nb, &splinePts, &correspondingSegments, scale);
	else 
		newNb = spline( pts, nb, &splinePts, nil, scale);
	
	NSMutableArray *newPoints = [NSMutableArray array];
	for (long i=0; i<newNb; i++)
	{
		[newPoints addObject:[MyPoint point:splinePts[i]]];
	}
	
	if (correspondingSegmentArray)
	{
		*correspondingSegmentArray = [NSMutableArray array];
		
		for (long i=0; i<newNb; i++)
		{
			[*correspondingSegmentArray addObject: [NSNumber numberWithLong: correspondingSegments[ i]]];
		}
	}

	if (newNb)
        free(splinePts);
	
	if ([newPoints count] == 0)
		return [self points];
	
	return newPoints;
}

-(NSMutableArray*)splineZPositions;
{
	// activated in the prefs
	if ([self isSpline] == NO)
        return zPositions;
	
	// available only for ROI types : Open Polygon, Close Polygon, Pencil
	// for other types, returns the original points
	if (type!=tOpenPolygon && type!=tClosedPolygon && type!=tPencil)
        return zPositions;
	
	// available only for polygons with at least 3 points
	if ([points count]<3)
        return zPositions;
	
	int nb; // number of points
	if (type==tOpenPolygon)
        nb = [zPositions count];
	else
        nb = [zPositions count]+1;

	NSPoint pts[nb];
	
	for (long i=0; i<[zPositions count]; i++)
		pts[i] = NSMakePoint([[zPositions objectAtIndex:i] floatValue], i);
	
	if (type != tOpenPolygon && [zPositions count] > 0)
		pts[[zPositions count]] = NSMakePoint([[zPositions objectAtIndex:0] floatValue], 0.0); // we add the first point as the last one to smooth the spline
							
	NSPoint *splinePts;
	long newNb = spline(pts, nb, &splinePts, nil, 1);
	
	NSMutableArray *newPoints = [NSMutableArray array];
	for (long i=0; i<newNb; i++)
	{
		[newPoints addObject:[NSNumber numberWithFloat:splinePts[i].x]];
	}

	if (newNb)
        free(splinePts);
	
	return newPoints;
}

-(void)setNSColor:(NSColor*)nsColor {
	[self setNSColor:nsColor globally:YES];
}

-(NSColor*)NSColor
{
	return [NSColor colorWithCalibratedRed:color.red/0xffff
                                     green:color.green/0xffff
                                      blue:color.blue/0xffff
                                     alpha:opacity];
}

-(void)setNSColor:(NSColor*)nsColor
         globally:(BOOL)g
{
	[self setOpacity:[nsColor alphaComponent] globally:g];
    unsigned short rd = [nsColor redComponent]  *0xffff;
    unsigned short gr = [nsColor greenComponent]*0xffff;
    unsigned short bl = [nsColor blueComponent] *0xffff;
	RGBColor rgbColor = {rd,gr,bl};
	[self setColor:rgbColor globally:g];
}

- (NSString*) description
{
    [self computeROIIfNedeed];
    
    NSString *s = [NSString stringWithFormat:@"%@ %p t:%d <%@> mean:%.3f min:%.3fb max:%.3f tot:%.3f dev:%.3f, mode %d, %@",
                   [self class], self,
                   type, name, rmean, rmin, rmax, rtotal, rdev, mode, points];
    
    if ([curView blendingView])
    {
        @try {
            DCMPix *blendedPix = [[curView blendingView] curDCM];
            
            ROI *b = [[self copy] autorelease];
            b.pix = blendedPix;
            b.curView = curView.blendingView;
            [b setOriginAndSpacing: blendedPix.pixelSpacingX
                                  : blendedPix.pixelSpacingY
                                  : [DCMPix originCorrectedAccordingToOrientation: blendedPix]];
            [b computeROIIfNedeed];
            
            s = [s stringByAppendingFormat: @"\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f", b.mean, b.min, b.max, b.total, b.dev];
        }
        @catch (NSException *exception) {
            N2LogException( exception);
        }
    }
    
    return s;
}

@end
