//
//  GLProgramLoupe.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLProgramLoupe.h"

@implementation GLProgramLoupe

- (instancetype)init
{
    self = [super init];
    if (self)
    {
#ifdef WITH_OPENGL_32
        [self createShaderProgram:@"loupe"];

        _vertexAttribXYZ = glGetAttribLocation(self.programHandle, "aCoordsXYZ");
        _vertexAttribUV0 = glGetAttribLocation(self.programHandle, "aTexUV");
        _vertexAttribUV1 = glGetAttribLocation(self.programHandle, "aTexUV1");
        _fragmentUniformSampler0 = glGetUniformLocation(self.programHandle, "uTexture0");
        _fragmentUniformSampler1 = glGetUniformLocation(self.programHandle, "uTexture1");
        _fragmentTextureCount = glGetUniformLocation(self.programHandle, "uTexCount");
        // Check that all uniform locations are valid.
        // They are -1 if either they are mispelled or they are not actually used in the shader
        assert(_vertexAttribXYZ != -1);
        assert(_vertexAttribUV0 != -1);
        assert(_vertexAttribUV1 != -1);
        assert(_fragmentUniformSampler0 != -1);
        assert(_fragmentUniformSampler1 != -1);
        assert(_fragmentTextureCount != -1);

        glUseProgram(self.programHandle);
        #if 1 // temp
        _vertexUniformProjection = glGetUniformLocation(self.programHandle, "uProjectionM");
        _vertexUniformModelView = glGetUniformLocation(self.programHandle, "uModelViewM");
        #endif
        glm::mat4 Identity = glm::mat4(1.0);
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uProjectionM"];
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uModelViewM"];
#endif
    }

    return self;
}
@end
