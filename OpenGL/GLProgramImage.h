//
//  GLProgramImage.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import <Foundation/Foundation.h>
#import "GLProgram.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLProgramImage : GLProgram

@property GLint vertexAttribXYZ; // Z used by loupe code
@property GLint vertexAttribUV;
@property GLint vertexUniformProjection;
@property GLint vertexUniformModelView;
@property GLint fragmentUniformSampler;  // uTextureS2D
@property GLint fragmentUniformCCM;

@end

NS_ASSUME_NONNULL_END
