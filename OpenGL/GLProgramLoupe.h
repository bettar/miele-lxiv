//
//  GLProgramLoupe.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "GLProgram.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLProgramLoupe : GLProgram

@property GLint vertexAttribXYZ; // Z used by loupe code
@property GLint vertexAttribUV0;
@property GLint vertexAttribUV1;
@property GLint vertexUniformProjection;
@property GLint vertexUniformModelView;
@property GLint fragmentUniformSampler0;  // uTextureS2D
@property GLint fragmentUniformSampler1;  // uTextureS2D
@property GLint fragmentTextureCount;

@end

NS_ASSUME_NONNULL_END
