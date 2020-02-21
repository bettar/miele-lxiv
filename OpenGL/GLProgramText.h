//
//  GLProgramText.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "GLProgram.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLProgramText : GLProgram

@property GLint vertexAttribXYUV;
@property GLint vertexUniformProjection;
@property GLint fragmentUniformSampler;  // uTextureS2D
@property GLint fragmentUniformColor;

@end

NS_ASSUME_NONNULL_END
