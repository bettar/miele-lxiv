//
//  GLProgramOverlay.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "GLProgram.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ShaderModeType) {
    SHADER_MODE_NORMAL=0,
    SHADER_MODE_TEXTURE_RGBA=1,
    SHADER_MODE_ROUND_POINT=2,
    SHADER_MODE_TEXTURE_LUMINOSITY=3 // for brush
};

@interface GLProgramOverlay : GLProgram

@property GLint vertexUniformProjection;
@property GLint vertexUniformModelView;
@property GLint vertexAttribXY;
@property GLint vertexAttribColor;
@property GLint fragmentUniformSampler;  // uTextureS2D
@property GLint fragmentUniformColor;
@property GLint fragmentModeV __deprecated;
@property GLint fragmentModeF __deprecated;

- (void) setMode: (ShaderModeType) shaderMode;

@end

NS_ASSUME_NONNULL_END
