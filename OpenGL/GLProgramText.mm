//
//  GLProgramText.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLProgramText.h"

@implementation GLProgramText

- (instancetype)init
{
    self = [super init];
    if (self)
    {
#ifdef WITH_OPENGL_32
        [self createShaderProgram:@"font"];

        _vertexAttribXYUV = glGetAttribLocation(self.programHandle, "aVertXYUV");
        _fragmentUniformColor = glGetUniformLocation(self.programHandle, "uColorRGBA");
        _fragmentUniformSampler = glGetUniformLocation(self.programHandle, "uTextureS2D");
        assert(_vertexAttribXYUV != -1);
        assert(_fragmentUniformColor != -1);
        assert(_fragmentUniformSampler != -1);

        glUseProgram(self.programHandle);
        #if 1 // temp
        _vertexUniformProjection = glGetUniformLocation(self.programHandle, "uProjectionM");
        #endif
        glm::mat4 Identity = glm::mat4(1.0);
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uProjectionM"];
#endif
    }

    return self;
}
@end
