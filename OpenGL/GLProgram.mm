//
//  GLProgram.mm
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first
#import "GLRenderer.h"

#import "GLProgram.h"

@implementation GLProgram

- (void) createShaderProgram: (NSString *)shaderName
{
    //NSLog(@"%s:%d ====== <%@> %@", __FUNCTION__, __LINE__, shaderName, [NSOpenGLContext currentContext]);

    if (self.programHandle != GL_ZERO)
        return;

    // Define and compile vertex, (geometry), and fragment shaders

    NSString *vertex   = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"vsh"];
    NSString *geometry = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"gsh"];
    NSString *fragment = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"fsh"];
    self.programHandle = loadShaders(vertex, geometry, fragment);
    assert(self.programHandle != 0);
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.programHandle = GL_ZERO;
    }
    return self;
}

- (void) Bind
{
    [self Bind: 0];
}

- (void) Bind: (int) fromLine;
{
#if 0 // ndef NDEBUG
    NSString *s = [NSString stringWithFormat:@" from line %d", fromLine];
    NSLog(@"%s %@ handle:%d%@", __FUNCTION__,
          NSStringFromClass([self class]),
          _programHandle,
          (fromLine>0) ? s : @"");
#endif

#ifdef WITH_OPENGL_32
    //glUseProgram(_programHandle);
    renderer_setProgram(_programHandle); // TODO: put the code inline here without calling renderer*() functions
#endif
}

- (void) EnableAttributeArray: (const char *) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetAttribLocation(_programHandle, name);
    assert(location != -1);
    glEnableVertexAttribArray(location);
#endif
}

- (void) DisableAttributeArray: (const char *) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetAttribLocation(_programHandle, name);
    assert(location != -1);
    glDisableVertexAttribArray(location);
#endif
}

- (void) setUniformi: (int) i
                name: (const char*) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetUniformLocation(_programHandle, name);
    assert(location != -1);
    glUniform1i(location, (GLint)i);
#endif
}

- (void) setUniformMatrix: (const GLfloat *) matrix
                     name: (const char*) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetUniformLocation(_programHandle, name);
    assert(location != -1);
    glUniformMatrix4fv(location, 1, GL_FALSE, matrix);
#endif
}

// input vector is v[2]
- (void) SetUniform2f: (const float *) v
                 name: (const char *) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetUniformLocation(_programHandle, name);
    assert(location != -1);
    glUniform2fv(location, 1, v); // 1 is correct because it's "one" vec2 in shader
#endif
}

// input vector is v[4]
- (void) SetUniform4f: (const float *) v
                 name: (const char *) name
{
#ifdef WITH_OPENGL_32
    GLint location = glGetUniformLocation(_programHandle, name);
    assert(location != -1);
    //glUniform4f(location, r, g, b, a);
    glUniform4fv(location, 1, v); // 1 is correct because it's "one" vec4 in shader
#endif
}

@end
