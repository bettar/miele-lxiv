//
//  GLRenderer.cpp
//  miele-lxiv
//
//  Copyright © 2019 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first

#import <Cocoa/Cocoa.h>
#include <string>
#import "GLRenderer.h"

int checkOpenGLErrors(int lineNo)
{
    int errorCount = 0;
#ifndef NDEBUG
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (!cgl_ctx)
        NSLog(@"%s %d, Warning: no context", __FUNCTION__, __LINE__);
    
    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR) {
        NSLog(@"Line %5d, OpenGL error 0x%04X, ctx:%p", lineNo, err, cgl_ctx);
        errorCount++;
        //[NSException raise:NSGenericException format:@"OpenGL error 0x%04X, ctx:%p", err, cgl_ctx];
    }
#endif
    return errorCount;
}

// Check extensions without using GLEW
bool checkExtension(const char* ext)
{
    if (!ext)
        return false;

#ifndef WITH_GLEW
    //[[NSOpenGLContext currentContext] makeCurrentContext];
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
#endif

    const GLubyte *v = glGetString(GL_VERSION);
    if (v[0] < '3') { // old API before OpenGL 3.0
        const GLubyte *strExtension = glGetString(GL_EXTENSIONS);
        return strstr((const char *)strExtension, ext) ? true : false;
    }
    
#ifdef WITH_OPENGL_32
    // New API since OpenGL 3.0
    GLint nExt = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, &nExt);
    
    for (GLuint i = 0; i < nExt; i++)
    {
        const GLubyte *s = glGetStringi(GL_EXTENSIONS, i);

        if (glGetError() == GL_INVALID_VALUE)
            break;

        if (!s)
            break;

        if (!strcmp((const char *)s, ext))
            return true;  // found
    }
#endif

    return false;  // not found
}

#ifdef WITH_OPENGL_32
#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

void checkShader(GLuint shader)
{
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if ( !success )
    {
        GLint infoLogLength;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLogLength);

        GLchar infoLog[infoLogLength+1];
        glGetShaderInfoLog(shader, infoLogLength, nullptr, infoLog);
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to compile shader %i\n%s", shader, infoLog];
    }
}

void checkProgram(GLuint program)
{
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if ( !success )
    {
        GLint infoLogLength;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLogLength);

        GLchar infoLog[infoLogLength+1];
        glGetProgramInfoLog(program, infoLogLength, nullptr, infoLog);
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to link program %i\n%s", program, infoLog];
    }
}

GLuint compileShader(GLenum type, NSString *file)
{
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];

    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to read shader file %@", file];
    }

    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    auto shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    checkShader(shader);
    return shader;
}

GLuint loadShaders(NSString *vertex, NSString *fragment)
{
    GLuint vs = compileShader(GL_VERTEX_SHADER, vertex);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fragment);

    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];

    // Attach the shaders
    auto programId = glCreateProgram();

    NSLog(@"%s %d, vertex:%u fragment:%u program:%u", __FUNCTION__, __LINE__, vs, fs, programId);

    glAttachShader(programId, vs);
    glAttachShader(programId, fs);
    glLinkProgram(programId);
    checkOpenGLErrors(__LINE__);

    checkProgram(programId);

#ifdef DISPLAY_TEXTURE_DATA
    glDetachShader(programId, vs);    checkOpenGLErrors(__LINE__);
    glDetachShader(programId, fs);    checkOpenGLErrors(__LINE__);
#endif

    glDeleteShader(vs);
    glDeleteShader(fs);    checkOpenGLErrors(__LINE__);

    return programId;
}

GLuint getShaderProgram(NSString *shaderName)
{
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);

    //static
    GLuint shaderProgram = GL_ZERO;

    if (shaderProgram != GL_ZERO)
        return shaderProgram;

    // 3. Define and compile vertex and fragment shaders


    NSString *vertex   = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"vsh"];
    NSString *fragment = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"fsh"];
    shaderProgram = loadShaders(vertex, fragment);

    return shaderProgram;
}

#endif // WITH_OPENGL_32
