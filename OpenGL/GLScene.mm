//
//  GLScene.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

/*
    The purpose of this class is to manage shader programs
    In Legacy code the context is switched between threads and we can
        - create the context
        - make it current
        - ask for the current one
    In Core code the abstraction is to extend the context with the concept of
    a scene
 */

#import "GLScene.h"

static GLScene *_currentScene = nil;

@implementation GLScene

#pragma mark - class methods

// Conceptually similar to '[[self openGLContext] makeCurrentContext]'
+ (void) setCurrentScene: (GLScene **) s
{
    _currentScene = *s;

    renderer_setScene(s); // TODO: deprecate it, the renderer can get it from this class every time it needs it
}

// Conceptually similar to '[NSOpenGLContext currentContext]'
+ (GLScene *) currentScene
{
    return _currentScene;
}

#pragma mark - instance methods

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _currentProgram = 0;
        _currentShaderMode = SHADER_MODE_NORMAL;
    }

    return self;
}

- (void) addProgramFont
{
    _fontShaderProgram = [GLProgramText new];
    //_sStatus.ep.font = _fontShaderProgram.programHandle;
}

- (void) addProgramImage
{
    _imageProgram = [GLProgramImage new];
    //_sStatus.ep.image = _imageProgram.programHandle;
}

- (void) addProgramLoupe
{
    _loupeProgram = [GLProgramLoupe new];
    //_sStatus.ep.loupe = _loupeProgram.programHandle;
}

- (void) addProgramOverlay
{
    _overlayProgram = [GLProgramOverlay new];
    //_sStatus.ep.overlay = _overlayProgram.programHandle;
}

- (void) addProgramOverlayLine
{
    _overlayLineProgram = [GLProgramOverlayLine new];
    //_sStatus.ep.overlayLine = _overlayLineProgram.programHandle;
}

@end
