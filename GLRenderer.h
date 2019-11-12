//
//  GLRenderer.hpp
//  miele-lxiv
//
//  Copyright © 2019 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#ifndef GLRenderer_hpp
#define GLRenderer_hpp

#import <AppKit/AppKit.h>

int checkOpenGLErrors(int lineNo);
bool checkExtension(const char* ext);

#ifdef WITH_OPENGL_32
void checkShader(GLuint shader);
void checkProgram(GLuint program);
GLuint compileShader(GLenum type, NSString *file);
GLuint loadShaders(NSString *vertex, NSString *fragment);
GLuint getShaderProgram(NSString *shaderName);
#endif

#endif /* GLRenderer_hpp */
