//
//  GLProgramOverlay.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLProgramOverlay.h"

#import "GLScene.h"

@implementation GLProgramOverlay

- (instancetype)init
{
    self = [super init];
    if (self)
    {
#ifdef WITH_OPENGL_32
        [self createShaderProgram:@"overlay"];

        _vertexAttribXY = glGetAttribLocation(self.programHandle, "aCoordsXY");
        _vertexAttribColor = glGetAttribLocation(self.programHandle, "aColorRGBA");
        assert(_vertexAttribXY != -1);
        assert(_vertexAttribColor != -1);

        _fragmentUniformSampler = glGetUniformLocation(self.programHandle, "uTextureS2D");
        _fragmentUniformColor = glGetUniformLocation(self.programHandle, "uColorRGBA");
        _fragmentModeV = glGetUniformLocation(self.programHandle, "uModeV");
        _fragmentModeF = glGetUniformLocation(self.programHandle, "uModeF");
        assert(_fragmentUniformSampler != -1);
        assert(_fragmentUniformColor != -1);
        assert(_fragmentModeV != -1);
        assert(_fragmentModeF != -1);

        glUseProgram(self.programHandle);
        #if 1 // temp
        _vertexUniformProjection = glGetUniformLocation(self.programHandle, "uProjectionM");
        _vertexUniformModelView = glGetUniformLocation(self.programHandle, "uModelViewM");
        #endif
        glm::mat4 Identity = glm::mat4(1.0);
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uProjectionM"];
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uModelViewM"];

//        [self setUniformi:SHADER_MODE_NORMAL name:"uModeV"];
//        [self setUniformi:SHADER_MODE_NORMAL name:"uModeF"];
//        glm::vec4 colorWhite(1,1,1,1);
//        [self SetUniform4f: glm::value_ptr(colorWhite) name:"uColorRGBA"];
#endif
    }

    return self;
}

- (void) setMode:(ShaderModeType) shaderMode
{
#ifdef WITH_OPENGL_32
    glUniform1i(_fragmentModeV, (GLint)shaderMode);
    //[self setUniformi:shaderMode name:"uModeV"];

    glUniform1i(_fragmentModeF, (GLint)shaderMode);
    //[self setUniformi:shaderMode name:"uModeF"];
#endif

    GLScene *s = [GLScene currentScene];
    s.currentShaderMode = shaderMode;
}

@end
