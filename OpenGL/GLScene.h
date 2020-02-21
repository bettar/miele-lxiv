//
//  GLScene.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import <Foundation/Foundation.h>

#import "GLRenderer.h" // for ShaderModeType

#import "GLProgramImage.h"
#import "GLProgramOverlay.h"
#import "GLProgramOverlayLine.h"
#import "GLProgramLoupe.h"
#import "GLProgramText.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLScene : NSObject

@property (retain) GLProgramImage *imageProgram;
@property (retain) GLProgramOverlay *overlayProgram;
@property (retain) GLProgramOverlayLine *overlayLineProgram;
@property (retain) GLProgramLoupe *loupeProgram;
@property (retain) GLProgramText *fontShaderProgram;

@property GLuint currentProgram;
@property ShaderModeType currentShaderMode;

@property float bias;
@property float scale;

+ (void) setCurrentScene: (GLScene *_Nonnull *_Nonnull) cs;
+ (GLScene *) currentScene;

- (void) addProgramFont;
- (void) addProgramImage;
- (void) addProgramLoupe;
- (void) addProgramOverlay;
- (void) addProgramOverlayLine;

@end

NS_ASSUME_NONNULL_END
