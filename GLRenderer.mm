//
//  GLRenderer.cpp
//  miele-lxiv
//
//  Copyright © 2019 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first

#import <Cocoa/Cocoa.h>
#include <string>
#include "GLRenderer.h"

int checkOpenGLErrors(int lineNo)
{
    int errorCount = 0;
#if 1 //ndef NDEBUG
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (!cgl_ctx)
        NSLog(@"%s %d, Warning: no context", __FUNCTION__, __LINE__);
    
    GLenum err;  // 0x500 GL_INVALID_ENUM
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

void checkOGLVersion()
{
#ifndef NDEBUG
#if 0
    const GLubyte *strVersion = glGetString(GL_VERSION); // get version string
    
    // Get just the non-vendor specific part of version string
    enum { kShortVersionLength = 32 };

    GLubyte strShortVersion[kShortVersionLength];

    short i = 0;
    while ((((strVersion[i] <= '9') && (strVersion[i] >= '0')) || (strVersion[i] == '.')) &&
           (i < kShortVersionLength)) // get only basic version info (until first space)
    {
        strShortVersion[i] = strVersion[i];
        i++;
    }
    strShortVersion[i] = 0; // Truncate string
    
    NSLog(@"%s %d OpenGL %s", __FUNCTION__, __LINE__, strShortVersion);
#endif
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    NSLog(@"GLRenderer.mm:%d OpenGL context:%p", __LINE__, cgl_ctx);
    
    NSLog(@"%s %d, OpenGL version %s", __FUNCTION__, __LINE__, glGetString(GL_VERSION));

    NSLog(@"OpenGL renderer: %s", glGetString(GL_RENDERER));

    // Check two mutually exclusive extensions
    NSLog(@"checkExtension\n\t GL_ARB_color_buffer_float:%d \n\t GL_ARB_blend_func_extended:%d \n\t GL_APPLE_packed_pixel:%d \n\t GL_EXT_packed_pixels:%d",  // ok
          checkExtension("GL_ARB_color_buffer_float"),    // 1 for 2.1
          checkExtension("GL_ARB_blend_func_extended"),    // 0 for 2.1, only 4.1
          checkExtension("GL_APPLE_packed_pixel"),  // 1 for 2.1
          checkExtension("GL_EXT_packed_pixels"));  // 0 for 2.1
    
#ifdef WITH_GLEW
    NSLog(@"glewIsSupported\n\t GL_ARB_color_buffer_float:%d \n\t GL_ARB_blend_func_extended:%d \n\t GL_APPLE_packed_pixel:%d \n\t GL_EXT_packed_pixels:%d",
          glewIsSupported("GL_ARB_color_buffer_float"),    // 1 for 2.1
          glewIsSupported("GL_ARB_blend_func_extended"),  // 0 for 2.1, only 4.1
          glewIsSupported("GL_APPLE_packed_pixel"), // 0 for 2.1
          glewIsSupported("GL_EXT_packed_pixels")); // 0 for 2.1

    checkOpenGLErrors(__LINE__);
    
    NSLog(@"GL_ARB_color_buffer_float:%d, GL_ARB_blend_func_extended:%d",
          GL_ARB_color_buffer_float,    // only 2.1
          GL_ARB_blend_func_extended);  // only 4.1
    checkOpenGLErrors(__LINE__);
    
    NSLog(@"GLEW_ARB_color_buffer_float:%d, GLEW_ARB_blend_func_extended:%d",
          GLEW_ARB_color_buffer_float,    // only 2.1
          GLEW_ARB_blend_func_extended);  // only 4.1
#endif // WITH_GLEW
    
#if 0
    NSLog(@"GLEW_VERSION_1_1: %d, GL_VERSION_1_1: %d, glewIsSupported: %d,%d",  // 1, 1, 0 0
          GLEW_VERSION_1_1, GL_VERSION_1_1, glewIsSupported("GLEW_VERSION_1_1"), glewIsSupported("GL_VERSION_1_1"));
    
    NSLog(@"GLEW_VERSION_1_2: %d, GL_VERSION_1_2: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_1_2, GL_VERSION_1_2, glewIsSupported("GLEW_VERSION_1_2"), glewIsSupported("GL_VERSION_1_2"));
    
    NSLog(@"GLEW_VERSION_2_0: %d, GL_VERSION_2_0: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_2_0, GL_VERSION_2_0, glewIsSupported("GLEW_VERSION_2_0"), glewIsSupported("GL_VERSION_2_0"));
    
    NSLog(@"GLEW_VERSION_3_0: %d, GL_VERSION_3_0: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_3_0, GL_VERSION_3_0, glewIsSupported("GLEW_VERSION_3_0"), glewIsSupported("GL_VERSION_3_0"));
    
    NSLog(@"GLEW_VERSION_3_1: %d, GL_VERSION_3_1: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_3_1, GL_VERSION_3_1, glewIsSupported("GLEW_VERSION_3_1"), glewIsSupported("GL_VERSION_3_1"));
    
    NSLog(@"GLEW_VERSION_3_2: %d, GL_VERSION_3_2: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_3_2, GL_VERSION_3_2, glewIsSupported("GLEW_VERSION_3_2"), glewIsSupported("GL_VERSION_3_2"));
    
    NSLog(@"GLEW_VERSION_4_1: %d, GL_VERSION_4_1: %d, glewIsSupported: %d,%d",  // 1, 1, 0 1
          GLEW_VERSION_4_1, GL_VERSION_4_1, glewIsSupported("GLEW_VERSION_4_1"), glewIsSupported("GL_VERSION_4_1"));
    
    NSLog(@"GLEW_VERSION_4_2: %d, GL_VERSION_4_2: %d, glewIsSupported: %d,%d",  // 0, 1, 0 0
          GLEW_VERSION_4_2, GL_VERSION_4_2, glewIsSupported("GLEW_VERSION_4_2"), glewIsSupported("GL_VERSION_4_2"));
#endif
    //NSLog(@"GLRenderer.mm:%d %@ ", __LINE__, [self class]);
    //NSLog(@"GLRenderer.mm:%d OpenGL context:%p", __LINE__, cgl_ctx);
    //printf("GLRenderer.mm:%d version %s\n", __LINE__, glGetString(GL_VERSION));
    checkOpenGLErrors(__LINE__);
    #endif // NDEBUG
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
    // 4. Attach the shaders
    auto programId = glCreateProgram();

    // checkPoint[3] = 1;
    NSLog(@"DCMView.mm:%d loadShader() [2] vertex:%u fragment:%u program:%u", __LINE__, vs, fs, programId);

    glAttachShader(programId, vs);
    glAttachShader(programId, fs);
    glLinkProgram(programId);
    checkOpenGLErrors(__LINE__);

#if 0
    // Too early here. It causes:
    //  "Validation Failed: Current draw framebuffer is invalid."
    glValidateProgram(programId);
#endif

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
    NSLog(@"DCMView.mm:%d %s", __LINE__, __PRETTY_FUNCTION__);

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
