//
//  GLProgramOverlayLine.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "GLProgram.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLProgramOverlayLine : GLProgram

@property GLint vertexUniformProjection;
@property GLint vertexUniformModelView;
@property GLint vertexAttribXY;
@property GLint vertexAttribColor;
@property GLint geometryUniformLineWidth;

@end

NS_ASSUME_NONNULL_END
