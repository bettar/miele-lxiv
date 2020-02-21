//
//  GLProgramImage.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLProgramImage.h"

@implementation GLProgramImage

- (instancetype)init
{
    self = [super init];
    if (self)
    {
#ifdef WITH_OPENGL_32
        [self createShaderProgram:@"image"];

        _vertexAttribXYZ = glGetAttribLocation(self.programHandle, "aCoordsXYZ");
        _vertexAttribUV = glGetAttribLocation(self.programHandle, "aTexUV");
        _fragmentUniformSampler = glGetUniformLocation(self.programHandle, "uTextureS2D");

        // Check that all uniform locations are valid.
        // They are -1 if either they are mispelled or they are not actually used in the shader
        assert(_vertexAttribXYZ != -1);
        assert(_vertexAttribUV != -1);
        assert(_fragmentUniformSampler != -1);

        glUseProgram(self.programHandle);
#if 1 // temp
        _vertexUniformProjection = glGetUniformLocation(self.programHandle, "uProjectionM");
        _vertexUniformModelView = glGetUniformLocation(self.programHandle, "uModelViewM");
        _fragmentUniformCCM = glGetUniformLocation(self.programHandle, "uColorCorrectionM");
#endif
        glm::mat4 Identity = glm::mat4(1.0);
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uProjectionM"];
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uModelViewM"];
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uColorCorrectionM"];
#endif
    }

    return self;
}

@end
