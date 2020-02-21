//
//  GLProgramOverlayLine.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLProgramOverlayLine.h"

@implementation GLProgramOverlayLine

- (instancetype)init
{
    self = [super init];
    if (self)
    {
#ifdef WITH_OPENGL_32
        [self createShaderProgram:@"overlayLine"];

        _vertexAttribXY = glGetAttribLocation(self.programHandle, "aCoordsXY");
        _vertexAttribColor = glGetAttribLocation(self.programHandle, "aColorRGBA");
        //_geometryUniformLineWidth = glGetUniformLocation(self.programHandle, "lineWidthNVC");
        assert(_vertexAttribXY != -1);
        assert(_vertexAttribColor != -1);
        //assert(_geometryUniformLineWidth != -1);

        glUseProgram(self.programHandle);
        #if 1 // temp
        _vertexUniformProjection = glGetUniformLocation(self.programHandle, "uProjectionM");
        _vertexUniformModelView = glGetUniformLocation(self.programHandle, "uModelViewM");
        _geometryUniformLineWidth = glGetUniformLocation(self.programHandle, "lineWidthNVC");
        #endif
        glm::mat4 Identity = glm::mat4(1.0);
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uProjectionM"];
        [self setUniformMatrix: glm::value_ptr(Identity) name:"uModelViewM"];

        glm::vec2 lineWidth(1,1);
        //glUniform2fv(_geometryUniformLineWidth, 1, glm::value_ptr(lineWidth));
        [self SetUniform2f: glm::value_ptr(lineWidth) name:"lineWidthNVC"];
#endif
    }

    return self;
}

@end
