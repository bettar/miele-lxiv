//
//  GLProgram.h
//  miele-lxiv
//
//  Copyright © 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import <Foundation/Foundation.h>

#import "mgl.h" // include first
#import "GLRenderer.h"

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface GLProgram : NSObject
{
    NSString *shaderName;
}

@property GLuint programHandle;

- (void) createShaderProgram: (NSString *)shaderName;

- (void) Bind;
- (void) Bind: (int) fromLine;

- (void) EnableAttributeArray: (const char *) name;
- (void) DisableAttributeArray: (const char *) name;

- (void) setUniformi: (int) i
                name: (const char*) name;

- (void) setUniformMatrix: (const GLfloat *) matrix
                     name: (const char*) name;

- (void) SetUniform2f: (const float *) v
                 name: (const char *) name;

- (void) SetUniform4f: (const float *) v
                 name: (const char *) name;

@end

NS_ASSUME_NONNULL_END
