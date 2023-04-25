//
//  GLRenderer.mm
//  miele-lxiv
//
//  Copyright © 2019 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#import "mgl.h" // include first

//#include "glm/glm.hpp"
//#include "glm/gtc/matrix_transform.hpp"
//#include "glm/gtc/type_ptr.hpp"

#import <Cocoa/Cocoa.h>
#import <assert.h>
#include <string>

#import "GLScene.h"

#import "GLRenderer.h"

static GLScene *sScene = nil;

//#ifndef NDEBUG
void renderer_setScene(GLScene **s)
{
    sScene = *s;
}
//#endif

void renderer_setProgram(GLuint p, GLuint fromLine)
{
    if (sScene && sScene.currentProgram == p)
    {
  #ifdef DEBUG_RENDERER_CALLS
        NSString *s = [NSString stringWithFormat:@" from line %d", fromLine];
        NSLog(@"%s, program %d already selected,%@", __FUNCTION__, p,
        (fromLine>0) ? s : @"");
  #endif
        return;
    }

  #ifdef DEBUG_RENDERER_CALLS
    NSString *s = [NSString stringWithFormat:@" from line %d", fromLine];
    NSLog(@"%s, change program from %d to %d,%@ %@", __FUNCTION__,
          sScene.currentProgram,
          p,
          (fromLine>0) ? s : @"",
          [NSOpenGLContext currentContext]);
  #endif

    sScene.currentProgram = p;

#ifdef WITH_OPENGL_32
    glUseProgram(p);
#endif
}

#pragma mark - Matrix operations

// Eliminate rotation
void renderer_reset_scale_translate_MV(CGSize scaleFactor, CGPoint translationOffset)
{
    renderer_reset_scale_translate_MV(scaleFactor, translationOffset, FALSE, FALSE);
}

// Eliminate rotation
void renderer_reset_scale_translate_MV(CGSize scaleFactor,
                                       CGPoint translationOffset,
                                       BOOL flipX,
                                       BOOL flipY)
{
    float signX = flipX ? -1.0 : 1.0;
    float signY = flipY ? -1.0 : 1.0;

#ifdef WITH_OPENGL_32
  #ifdef DEBUG_RENDERER_CALLS
    NSLog(@"%s %d, currentProgram:%d, scale:%@", __FUNCTION__, __LINE__, sScene.currentProgram, NSStringFromSize(scaleFactor));
  #endif

    assert(sScene != nil && sScene.currentProgram != 0);
    GLint MVLocation = glGetUniformLocation(sScene.currentProgram, "uModelViewM");

    assert((MVLocation != -1));
    //if (MVLocation != -1)
    {
        glm::mat4 MV = glm::mat4(1.0);
        MV = glm::scale(MV, glm::vec3(signX * 2.0f / scaleFactor.width,
                                     -signY * 2.0f / scaleFactor.height,
                                      1.0f));

        MV = glm::translate(MV, glm::vec3(translationOffset.x / 2.0f,
                                          translationOffset.y / 2.0f,
                                          0.0f));

        glUniformMatrix4fv(MVLocation, 1, GL_FALSE, glm::value_ptr(MV));
    }
#else
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    glLoadIdentity();
    glScalef(signX * 2.0f / scaleFactor.width,
            -signY * 2.0f / scaleFactor.height,
             1.0f);
    glTranslatef(translationOffset.x / 2.0f, // TODO: check division by 2.0
                 translationOffset.y / 2.0f,
                 0.0f);
#endif
}

#ifdef WITH_OPENGL_32
void renderer_set_MV(glm::mat4 &m)
{
    assert(sScene != nil && sScene.currentProgram != 0);
    GLint MVLocation = glGetUniformLocation(sScene.currentProgram, "uModelViewM");

    assert((MVLocation != -1));
    glUniformMatrix4fv(MVLocation, 1, GL_FALSE, glm::value_ptr(m));
}

void renderer_reset_MV()
{
    assert(sScene != nil && sScene.currentProgram != 0);
    GLint MVLocation = glGetUniformLocation(sScene.currentProgram, "uModelViewM");

    assert((MVLocation != -1));
    glm::mat4 MV = glm::mat4(1.0);
    glUniformMatrix4fv(MVLocation, 1, GL_FALSE, glm::value_ptr(MV));
}
#endif // WITH_OPENGL_32

void renderer_reset_scale_MV(CGSize scaleFactor, GLuint fromLine)
{
    renderer_reset_scale_MV(scaleFactor, FALSE, FALSE, fromLine);
}

void renderer_reset_scale_MV(CGSize scaleFactor, BOOL flipX, BOOL flipY, GLuint fromLine)
{
    float signX = flipX ? -1.0 : 1.0;
    float signY = flipY ? -1.0 : 1.0;

#ifdef WITH_OPENGL_32
  #ifdef DEBUG_RENDERER_CALLS
    NSString *s = [NSString stringWithFormat:@" from line %d", fromLine];
    NSLog(@"%s %d, currentProgram:%d, scale factor:%@%@", __FUNCTION__, __LINE__,
          sScene.currentProgram,
          NSStringFromSize(scaleFactor),
          (fromLine>0) ? s : @"");
  #endif

    assert(sScene != nil && sScene.currentProgram != 0);
    GLint MVLocation = glGetUniformLocation(sScene.currentProgram, "uModelViewM");

    assert((MVLocation != -1));
    glm::mat4 MV = glm::scale(glm::mat4(1.0), glm::vec3(signX * 2.0f / scaleFactor.width,
                                                       -signY * 2.0f / scaleFactor.height,
                                                        1.0f));
    
    glUniformMatrix4fv(MVLocation, 1, GL_FALSE, glm::value_ptr(MV));
#else
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    glLoadIdentity();
    glScalef( signX * 2.0f / scaleFactor.width,
             -signY * 2.0f / scaleFactor.height,
              1.0f);
#endif
    checkOpenGLErrors(__LINE__);
}

void renderer_reset_scale_rotate_MV(CGSize scaleFactor,
                                    float rotationAngleDeg,
                                    BOOL flipX,
                                    BOOL flipY)
{
    float signX = flipX ? -1.0 : 1.0;
    float signY = flipY ? -1.0 : 1.0;

#ifdef WITH_OPENGL_32

    assert(sScene != nil && sScene.currentProgram != 0);
    GLint MVLocation = glGetUniformLocation(sScene.currentProgram, "uModelViewM");

    assert((MVLocation != -1));

    #ifdef DEBUG_RENDERER_CALLS
    NSLog(@"%s %d, currentProgram:%d, scale:%@, rotation(deg):%.1f, MV loc:%i", __FUNCTION__, __LINE__,
          sScene.currentProgram,
          NSStringFromSize(scaleFactor),
          rotationAngleDeg,
          MVLocation);
    #endif

    //if (MVLocation != -1)
    {
        glm::mat4 MV = glm::mat4(1.0);
        MV = glm::scale(MV, glm::vec3(signX * 2.0f / scaleFactor.width,
                                     -signY * 2.0f / scaleFactor.height,
                                      1.0f));
        MV = glm::rotate(MV, glm::radians(rotationAngleDeg), glm::vec3(0,0,1));
        glUniformMatrix4fv(MVLocation, 1, GL_FALSE, glm::value_ptr(MV));
    }
#else
    //NSLog(@"%s %d, scale:%@, rotation(deg):%f", __FUNCTION__, __LINE__, NSStringFromSize(scaleFactor), rotationAngleDeg);

    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
    
    glLoadIdentity();
    glScalef( signX * 2.0f / scaleFactor.width,
             -signY * 2.0f / scaleFactor.height,
              1.0f);
    glRotatef(rotationAngleDeg, 0.0f, 0.0f, 1.0f);
#endif
}

#pragma mark -

int checkOpenGLErrors(int lineNo)
{
    int errorCount = 0;
#ifndef NDEBUG
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (!cgl_ctx)
        NSLog(@"%s %d, Warning: no context", __FUNCTION__, __LINE__);
    
    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR) {
        NSLog(@"GLRenderer.mm from line %5d, OpenGL error 0x%04X, ctx:%p", lineNo, err, cgl_ctx);
        errorCount++;
        //[NSException raise:NSGenericException format:@"OpenGL error 0x%04X, ctx:%p", err, cgl_ctx];
    }
#endif
    return errorCount;
}

// Return true if legacy version (< 3.x)
bool checkOGLVersion()
{
#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
#endif
    const GLubyte *v = glGetString(GL_VERSION);
    NSLog(@"OpenGL version <%s> %@", v, [NSOpenGLContext currentContext]);
    
    // GL_VERSION_3_0
    if (v[0] >= '3') {
//        GLint major, minor;
//        glGetIntegerv(GL_MAJOR_VERSION, &major);
//        glGetIntegerv(GL_MINOR_VERSION, &minor);
//        NSLog(@"GL_MAJOR_VERSION.GL_MINOR_VERSION %d.%d", major, minor);
        return false;
    }
    
    return true;
}

// Check extensions without using GLEW
bool checkExtension(const char* ext)
{
    if (!ext)
        return false;

#if !defined( WITH_GLEW) && !defined(WITH_OPENGL_32)
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

#pragma mark - Shaders

#ifdef WITH_OPENGL_32
#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

void checkShader(GLuint shader)
{
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
    NSString *sourceString = [NSString stringWithContentsOfFile:file
                                                       encoding:NSASCIIStringEncoding
                                                          error:nil];

    sourceString = [sourceString stringByReplacingOccurrencesOfString:@"//Miele::System"
                                                           withString:@"#version 330 core"];

    const GLchar *source = (const GLchar *)[sourceString cStringUsingEncoding:NSASCIIStringEncoding];

    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException
                    format:@"Failed to read shader file %@", file];
    }

#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
#endif
    auto shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    checkShader(shader);
    return shader;
}

GLuint loadShaders(NSString *vertex, NSString *geometry, NSString *fragment)
{
    GLuint vs = compileShader(GL_VERTEX_SHADER, vertex);
    GLuint gs = 0;
    if (geometry.length > 0) gs = compileShader(GL_GEOMETRY_SHADER, geometry);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, fragment);

#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
#endif

    // Attach the shaders
    auto programId = glCreateProgram();

    //NSLog(@"%s %d, vertex:%u (geometry:%u) fragment:%u program:%u", __FUNCTION__, __LINE__, vs, gs, fs, programId);

    glAttachShader(programId, vs);
    if (geometry.length > 0) glAttachShader(programId, gs);
    glAttachShader(programId, fs);

    glLinkProgram(programId);
    checkOpenGLErrors(__LINE__);

    checkProgram(programId);

#ifdef DISPLAY_TEXTURE_DATA
    glDetachShader(programId, vs);    checkOpenGLErrors(__LINE__);
    glDetachShader(programId, gs);    checkOpenGLErrors(__LINE__);
    glDetachShader(programId, fs);    checkOpenGLErrors(__LINE__);
#endif

    glDeleteShader(vs);
    if (geometry.length > 0) glDeleteShader(gs);
    glDeleteShader(fs);
    checkOpenGLErrors(__LINE__);

    return programId;
}
#endif // WITH_OPENGL_32

#pragma mark -

void renderer_setTextColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a)
{
    checkOpenGLErrors(__LINE__);
#ifndef WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

#ifndef DEBUG_TEXTURE_WITH_SHADER
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
#endif

#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    assert(((sScene.currentProgram == sScene.overlayProgram.programHandle) &&
                (sScene.currentShaderMode == SHADER_MODE_TEXTURE_RGBA ||
                 sScene.currentShaderMode == SHADER_MODE_TEXTURE_LUMINOSITY)) ||
           (sScene.currentProgram == sScene.fontShaderProgram.programHandle));

    GLint fragmentUniformColor = glGetUniformLocation(sScene.currentProgram, "uColorRGBA");
    assert(fragmentUniformColor != -1);
    glUniform4f(fragmentUniformColor, r, g, b, a);
#else // WITH_OPENGL_32
    glColor4f(r, g, b, a);
#endif // WITH_OPENGL_32
}

void renderer_set_rgba(GLfloat r, GLfloat g, GLfloat b, GLfloat a, GLuint fromLine)
{
#ifdef WITH_OPENGL_32
  #ifdef DEBUG_RENDERER_CALLS
    NSString *s = [NSString stringWithFormat:@" from line %d", fromLine];
    NSLog(@"%s %d, currentProgram:%d, mode:%ld, color:(%.1f,%.1f,%.1f, %.1f)%@", __FUNCTION__, __LINE__,
          sScene.currentProgram, (long)sScene.currentShaderMode, r,g,b,a, s);
  #endif
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    checkOpenGLErrors(__LINE__);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    assert(((sScene.currentProgram == sScene.overlayProgram.programHandle) &&
                (sScene.currentShaderMode != SHADER_MODE_TEXTURE_RGBA &&
                 sScene.currentShaderMode != SHADER_MODE_TEXTURE_LUMINOSITY)) ||
           (sScene.currentProgram == sScene.overlayLineProgram.programHandle));
    
    GLint vertexAttribColor = glGetAttribLocation(sScene.currentProgram, "aColorRGBA");
    assert(vertexAttribColor != -1);
    //glDisableVertexAttribArray(vertexAttribColor); //cannot do it here uses currently bound vertex array object for the operation,
    glVertexAttrib4f(vertexAttribColor, r, g, b, a);

#else // WITH_OPENGL_32
    glColor4f(r, g, b, a);
#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
}

void renderer_enable_blend_smooth()
{
#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (!cgl_ctx)
        return;
#endif
    
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
    glEnable(GL_BLEND);

    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POLYGON_SMOOTH);
#ifndef WITH_OPENGL_32
    glEnable(GL_POINT_SMOOTH);
#endif
}

void renderer_disable_blend_smooth()
{
    glDisable(GL_LINE_SMOOTH);
    glDisable(GL_POLYGON_SMOOTH);
#ifndef WITH_OPENGL_32
    glDisable(GL_POINT_SMOOTH);
#endif
    
    glDisable(GL_BLEND);
}

void renderer_set_rgb(GLfloat r, GLfloat g, GLfloat b, GLuint fromLine)
{
    //glDisable(GL_BLEND);

#ifdef WITH_OPENGL_32
    renderer_set_rgba(r, g, b, 1.0, fromLine);  // TODO: confirm
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glColor3f(r, g, b);
#endif
    checkOpenGLErrors(__LINE__);
}

#pragma mark - overlayLine shader

// TODO: make this a member of class GLProgramOverlayLine
void renderer_setLineWidth(GLfloat w)
{
#ifdef WITH_OPENGL_32
    //NSLog(@"%s %d, width: %.1f", __FUNCTION__, __LINE__, w);

    assert(sScene.currentProgram == sScene.overlayLineProgram.programHandle);

    GLint viewport[4]; // XYWH
    glGetIntegerv(GL_VIEWPORT, viewport);
    checkOpenGLErrors(__LINE__);
    //NSLog(@"%s %d, WH:%.1d,%.1d", __FUNCTION__, __LINE__, viewport[2], viewport[3]);
    glm::vec2 lineWidth(w/viewport[2], w/viewport[3]); // VTK does this

    GLint geometryUniformLineWidth = glGetUniformLocation(sScene.currentProgram, "lineWidthNVC");
    assert(geometryUniformLineWidth != -1);
    glUniform2fv(geometryUniformLineWidth, 1, glm::value_ptr(lineWidth));
    // TODO: [self SetUniform2f: glm::value_ptr(lineWidth) name:"lineWidthNVC"];
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glLineWidth(w);
#endif
    checkOpenGLErrors(__LINE__);
}

// Used for tArrow
// 'pArray' is an array of glm::vec2
// OpenGL Legacy draws with GL_TRIANGLES
// OpenGL Core draws with GL_TRIANGLES
// The triangle gets "filled"
void renderer_drawTriangles_xy(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    //NSLog(@"%s %d, count: %lu", __FUNCTION__, __LINE__, (unsigned long)[pArray count]);
    assert(sScene.currentProgram == sScene.overlayProgram.programHandle);
    assert([pArray count] % 3 == 0); // 3 points for each triangle

    const int dimV = 2;         // number of components in the vertex array: X,Y
    const int nVertPerLine = 1; // each line or point drawn requires one vertex
    const int nPoints = [pArray count];
    GLfloat vertex[nPoints*nVertPerLine*dimV];

    int n=0;
    for (long i = 0; i < nPoints; i++) {
        glm::vec2 p;
        [pArray[i] getValue:&p];
        vertex[n++] = p.x;
        vertex[n++] = p.y;
    }
    
    // Give array to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    assert(indexCoords != -1);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);
    
    glDrawArrays(GL_TRIANGLES, 0, nPoints*nVertPerLine);
    
    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_TRIANGLES);
    {
        for (long i = 0; i < [pArray count]; i++) {
            glm::vec2 p;
            [pArray[i] getValue:&p];
            glVertex2f(p.x, p.y);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
}

// 'pArray' is an array of glm::vec3
// TODO: introduce lineMode parameter
void renderer_drawLine_xyz(NSArray *pArray, GLenum lineMode)
{
#ifdef WITH_OPENGL_32
    // TODO: Check what range of Z values we get first. If all Z are the same there is no point in doing extra work
#ifndef NDEBUG
    assert(sScene != nil && sScene.currentProgram != 0);
    //assert(sScene.currentProgram == sScene.sStatus.ep.image);
#endif
    // TODO: see renderer_drawLine_xy
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(lineMode);
    {
        for (long i = 0; i < [pArray count]; i++) {
            glm::vec3 p;
            [pArray[i] getValue:&p];
            glVertex3f(p.x, p.y, p.z);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
}

// 'pArray' is an array of glm::vec3
// OpenGL Legacy draws with GL_QUADS
// OpenGL Core draws with GL_TRIANGLES
void renderer_drawQuads_xyz(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
#ifndef NDEBUG
    assert(sScene.currentProgram == sScene.imageProgram.programHandle);
    assert([pArray count] == 4);
    GLfloat firstZ;
#endif
    // see renderer_drawQuad_xyuv() and renderer_drawTriangles_xy()
    // check if we do just 1 quad or the pArray size is > 4 in which case we need to do some % 4 and % 6 indexing
    
    const int dimV = 3;         // number of components in the vertex array: X,Y,Z
    const int nVertPerLine = 1; // each line or point drawn requires one vertex
    const int nPoints = 6;
    const int arrayNumElements = nPoints*nVertPerLine*dimV;

    GLfloat vertex[arrayNumElements];
    
    // The input array was prepared for GL_QUADS (OpenGL Legacy)
    // but here we are using GL_TRIANGLES (OpenGL Core)
    // Prepare a buffer containing two triangles
    // TODO: instead of repeating the points use glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,) and glDrawElements()
    const int idx[nPoints] = {3,2,1, 3,1,0};

    int nv=0;
    glm::vec3 p;
    for (long i = 0; i < nPoints; i++) {
        [pArray[idx[i]] getValue:&p];
        vertex[nv++] = p.x;
        vertex[nv++] = p.y;
        vertex[nv++] = p.z;
#ifndef NDEBUG
        // Check what range of Z values we get first.
        // If all Z are the same we can eliminate Z from shader
        if (i==0) {
            firstZ = p.z;
            assert(0 == p.z);
        }
        else
            assert(firstZ == p.z);

#endif
    }
    
    assert(nv == arrayNumElements);
    checkOpenGLErrors(__LINE__);

    // Give array to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    assert(indexCoords != -1);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);
    
    glDrawArrays(GL_TRIANGLES, 0, nPoints*nVertPerLine);
    
    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_QUADS);
    {
        for (long i = 0; i < [pArray count]; i++) {
            glm::vec3 p;
            [pArray[i] getValue:&p];
            glVertex3f(p.x, p.y, p.z);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
}

#pragma mark -

// pArray is an array of glm::vec2
// 'lineMode' is GL_LINE_STRIP or GL_LINE_LOOP or GL_LINES
void renderer_drawLine_xy(NSArray *pArray, GLenum lineMode)
{
    if ([pArray count] == 0)
        return;

#ifdef WITH_OPENGL_32
#ifndef NDEBUG
    assert(sScene != nil && sScene.currentProgram != 0);
    // Make sure we are using an overlay program which has "aColorRGBA"
    assert(((sScene.currentProgram == sScene.overlayProgram.programHandle) &&
                (sScene.currentShaderMode == SHADER_MODE_NORMAL)) ||
            (sScene.currentProgram == sScene.overlayLineProgram.programHandle));
#endif

    const int dimV = 2; // number of components in the vertex array: X,Y
    const int nPoints = [pArray count];
    GLfloat vertex[nPoints*dimV];
    
    int n=0;
    for (long i = 0; i < nPoints; i++) {
        glm::vec2 p;
        [pArray[i] getValue:&p];
        vertex[n++] = p.x;
        vertex[n++] = p.y;
    }

    // Give array to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    assert(indexCoords != -1);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);

    glDrawArrays(lineMode, 0, nPoints);

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];

    glBegin(lineMode);
    {
        for (long i = 0; i < [pArray count]; i++) {
            glm::vec2 p;
            [pArray[i] getValue:&p];
            glVertex2f(p.x, p.y);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
}

#pragma mark -

// pArray is an array of glm::vec2
// OpenGL Legacy draws with GL_POINTS
// OpenGL Core draws with GL_POINTS
void renderer_drawPoints(NSArray *pArray, BOOL rounded)
{
    if ([pArray count] == 0)
        return;

    //NSLog(@"%s %d, count:%lu", __FUNCTION__, __LINE__, (unsigned long)[pArray count]);

#ifdef WITH_OPENGL_32
    assert(sScene.currentProgram == sScene.overlayProgram.programHandle);
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

#ifdef WITH_OPENGL_32
    const int dimV = 2; // number of components in the vertex array: X,Y
    const int nVertPerLine = 1; // each point drawn requires one vertex (GL_POINTS)
    const int nPoints = [pArray count];
    GLfloat pointVertex[nPoints*nVertPerLine*dimV];

    int nv=0;
    for (long i = 0; i < nPoints; i++) {
        glm::vec2 p;
        [pArray[i] getValue:&p];
        pointVertex[nv++] = p.x;
        pointVertex[nv++] = p.y;
    }

    checkOpenGLErrors(__LINE__);

    // Give array to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");  // on
    GLint indexColor  = glGetAttribLocation(sScene.currentProgram, "aColorRGBA"); // off
    assert(indexCoords != -1);
    assert(indexColor != -1);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);

    glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"

    glDrawArrays(GL_POINTS, 0, nPoints*nVertPerLine);

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
     glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else
    if (rounded) {
        // Make the shape round instead of square
        glEnable(GL_POINT_SMOOTH);
        glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
    }

    glBegin(GL_POINTS);
    {
        for (long i = 0; i < [pArray count]; i++) {
            glm::vec2 p;
            [pArray[i] getValue:&p];
            glVertex2f(p.x, p.y);
        }
    }
    glEnd();
#endif
    checkOpenGLErrors(__LINE__);
}

#pragma mark - loupeShader

void renderer_setTextureCount(int count, GLuint fromLine)
{
#ifdef WITH_OPENGL_32
    GLint countLocation = glGetUniformLocation(sScene.currentProgram, "uTexCount");
    assert((countLocation != -1));
    glUniform1i(countLocation, (GLint)count);
#endif
}

// Multitexturing done with shaders
// 'pArray' is an array of Point_xyz_uv_uv
void renderer_drawTriangleFan_xyz_uv_uv(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    assert(sScene.currentProgram == sScene.loupeProgram.programHandle); // Samplers in the shader are for GL_TEXTURE_RECTANGLE
    const int dimV = 3; // number of components in the vertex array: X,Y,Z
    const int dimT = 2; // number of components in the array: U,V
    
    const int nPoints = [pArray count];
    GLfloat vertex_buffer_data[nPoints*dimV];
    GLfloat uv0_buffer_data[nPoints*dimT];
    GLfloat uv1_buffer_data[nPoints*dimT];

    for (long i = 0; i < nPoints; i++) {
        Point_xyz_uv_uv pt;
        [pArray[i] getValue:&pt];
        vertex_buffer_data[i*dimV] = pt.p.x;
        vertex_buffer_data[i*dimV+1] = pt.p.y;
        vertex_buffer_data[i*dimV+2] = pt.p.z;

        uv0_buffer_data[i*dimT] = pt.t0.s;
        uv0_buffer_data[i*dimT+1] = pt.t0.t;
        
        uv1_buffer_data[i*dimT] = pt.t1.s;
        uv1_buffer_data[i*dimT+1] = pt.t1.t;
    }
    
    // Give array to OpenGL
    checkOpenGLErrors(__LINE__);
    
    GLuint vao = 0;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    checkOpenGLErrors(__LINE__);
    
    const int nVBO = 3;
    GLuint vbo[nVBO];
    glGenBuffers(nVBO, vbo);
    
    GLint indexXYZ = glGetAttribLocation(sScene.currentProgram, "aCoordsXYZ");
    GLint indexUV0 = glGetAttribLocation(sScene.currentProgram, "aTexUV");
    GLint indexUV1 = glGetAttribLocation(sScene.currentProgram, "aTexUV1");
    assert(indexXYZ != -1);
    assert(indexUV0 != -1);
    assert(indexUV1 != -1);
    
#if 1 // Is this the right place ?
    GLint fragmentUniformSampler0 = glGetUniformLocation(sScene.currentProgram, "uTexture0");
    GLint fragmentUniformSampler1 = glGetUniformLocation(sScene.currentProgram, "uTexture1");
    assert(fragmentUniformSampler0 != -1);
    assert(fragmentUniformSampler1 != -1);
    glUniform1i(fragmentUniformSampler0, 0); // for GL_TEXTURE0
    glUniform1i(fragmentUniformSampler1, 1); // for GL_TEXTURE1
#endif

    glEnableVertexAttribArray(indexXYZ);
    glEnableVertexAttribArray(indexUV0);
    glEnableVertexAttribArray(indexUV1);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_buffer_data), vertex_buffer_data, GL_STATIC_DRAW);
    glVertexAttribPointer(indexXYZ, dimV, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(uv0_buffer_data), uv0_buffer_data, GL_STATIC_DRAW);
    glVertexAttribPointer(indexUV0, dimT, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(uv1_buffer_data), uv1_buffer_data, GL_STATIC_DRAW);
    glVertexAttribPointer(indexUV1, dimT, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);

    checkOpenGLErrors(__LINE__);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, nPoints);
    checkOpenGLErrors(__LINE__);
    
    // Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(nVBO, vbo);
    glDisableVertexAttribArray(indexXYZ);
    glDisableVertexAttribArray(indexUV0);
    glDisableVertexAttribArray(indexUV1);
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
    checkOpenGLErrors(__LINE__);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin (GL_QUAD_STRIP);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            Point_xyz_uv_uv pt;
            [value getValue:&pt];

            // specify more than one texture coordinate per vertex
            glMultiTexCoord2f(GL_TEXTURE1, pt.t1.s, pt.t1.t);
            glMultiTexCoord2f(GL_TEXTURE0, pt.t0.s, pt.t0.t);
            glVertex3d(pt.p.x, pt.p.y, pt.p.z);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
}

#pragma mark - imageShader

// Used for drawing DICOM images with "imageShader"
// Used for drawing DICOM loupe ring with "loupeShader"
// 'pArray' is an array of Point_xyz_uv
// Using two separate VBOs for the vertex data
// TODO: maybe revert to not using Z now that we have the loupe shader
void renderer_draw_xyz_uv(NSArray *pArray, GLenum mode)
{
#ifdef DEBUG_RENDERER_CALLS
    NSLog(@"%s %d, %@, program:%d, shader mode:%ld", __FUNCTION__, __LINE__,
          [NSOpenGLContext currentContext],
          sScene.currentProgram,
          (long)sScene.currentShaderMode);
#endif

#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    assert(sScene.currentProgram == sScene.imageProgram.programHandle || // 1 sampler in the shader
           sScene.currentProgram == sScene.loupeProgram.programHandle);  // 2 samplers in the shader
    assert([pArray count] == 4);
    const int dimV = 3; // number of components in the vertex array: X,Y,Z
    const int dimT = 2; // number of components in the array: U,V
    
    const int nPoints = [pArray count];
    GLfloat vertex_buffer_data[nPoints*dimV];
    GLfloat uv_buffer_data[nPoints*dimT];

    for (long i = 0; i < nPoints; i++) {
        Point_xyz_uv pt;
        [pArray[i] getValue:&pt];
        vertex_buffer_data[i*dimV] = pt.p.x;
        vertex_buffer_data[i*dimV+1] = pt.p.y;
        vertex_buffer_data[i*dimV+2] = pt.p.z;

        uv_buffer_data[i*dimT] = pt.t.s;
        uv_buffer_data[i*dimT+1] = pt.t.t;
    }

    // Give array to OpenGL
    checkOpenGLErrors(__LINE__);
    
    GLuint vao = 0;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    checkOpenGLErrors(__LINE__);
    
    const int nVBO = 2;
    GLuint vbo[nVBO];
    glGenBuffers(nVBO, vbo);
    
    GLint indexXYZ = glGetAttribLocation(sScene.currentProgram, "aCoordsXYZ");
    GLint indexUV = glGetAttribLocation(sScene.currentProgram, "aTexUV");
    assert(indexXYZ != -1);
    assert(indexUV != -1);

    glEnableVertexAttribArray(indexXYZ);
    glEnableVertexAttribArray(indexUV);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_buffer_data), vertex_buffer_data, GL_STATIC_DRAW);
    glVertexAttribPointer(indexXYZ, dimV, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(uv_buffer_data), uv_buffer_data, GL_STATIC_DRAW);
    glVertexAttribPointer(indexUV, dimT, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);
    checkOpenGLErrors(__LINE__);
    
    glDrawArrays(mode, 0, nPoints);
    checkOpenGLErrors(__LINE__);
    
    // Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(nVBO, vbo);
    glDisableVertexAttribArray(indexXYZ);
    glDisableVertexAttribArray(indexUV);
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
    checkOpenGLErrors(__LINE__); // GL_INVALID_FRAMEBUFFER_OPERATION  0x0506
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_TRIANGLE_STRIP);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            Point_xyz_uv pt;
            [value getValue:&pt];
            glTexCoord2f(pt.t.s, pt.t.t);
            glVertex2f(pt.p.x, pt.p.y);
        }
    }
    glEnd();
#endif
}

void renderer_drawTriangleStrip_xyz_uv(NSArray *pArray)
{
    renderer_draw_xyz_uv(pArray, GL_TRIANGLE_STRIP);
}

void renderer_drawTriangleFan_xyz_uv(NSArray *pArray)
{
    renderer_draw_xyz_uv(pArray, GL_TRIANGLE_FAN);
}

#pragma mark -

// Used for drawing text with "fontShader"
// 'pArray' is an array of glm::vec4
// Using a single VBO for the vertex data
// Used for GL_QUADS and textures
// OpenGL Legacy draws with GL_QUADS
// OpenGL Core draws with GL_TRIANGLES
void renderer_drawQuad_xyuv(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    assert(sScene.currentProgram == sScene.fontShaderProgram.programHandle ||
           sScene.currentProgram == sScene.overlayProgram.programHandle);
    assert([pArray count] == 4);
    const int dimVT = 4; // number of components in the vertex array: XYUV

    GLsizei stride = (dimVT)*sizeof(GLfloat);
    const int nVertPerLine = 1; // each line drawn requires one vertex (GL_QUADS)
    const int nPoints = 6;
    const int arrayNumElements = nPoints*nVertPerLine*dimVT;
    
    GLfloat pointVertex[arrayNumElements];

    // The input array was prepared for GL_QUADS (OpenGL Legacy)
    // but here we are using GL_TRIANGLES (OpenGL Core)
    // Prepare a buffer containing two triangles
    // TODO: instead of repeating the points use glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,) and glDrawElements()
    const int idx[nPoints] = {3,2,1, 3,1,0};
    int nv=0;
    glm::vec4 p;
    for (int i=0; i < nPoints; i++) {
        [pArray[idx[i]] getValue:&p];
        pointVertex[nv++] = p.x;
        pointVertex[nv++] = p.y;
        pointVertex[nv++] = p.p;
        pointVertex[nv++] = p.q;
    }

    assert(nv == arrayNumElements);
    checkOpenGLErrors(__LINE__);

    // Give array to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    GLuint vbo;
    glGenBuffers(1, &vbo);
    
    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aVertXYUV");
    //GLint indexTexture = glGetAttribLocation(sScene.currentProgram, "aTexUV");
    assert(indexCoords != -1);
    //assert(indexTexture != -1);
   
#if 0  // It doesn't seem to matter either way
    //GLint fragmentMode = glGetUniformLocation(sStatus->currentProgram, "uMode");
    if (sStatus->currentShaderMode == SHADER_MODE_TEXTURE_RGBA) { // SHADER_MODE_TEXTURE_RGBA is for overlay program only
        GLint indexColor = glGetAttribLocation(sStatus->currentProgram, "aColorRGBA");
        assert(indexColor != -1);
        glDisableVertexAttribArray(indexColor);
        
        GLint indexCoords = glGetAttribLocation(sStatus->currentProgram, "aCoordsXY");
        assert(indexCoords != -1);
        glDisableVertexAttribArray(indexCoords);
    }
#endif
    
    // Set our "uTextureS2D" sampler to user Texture Unit 0
    GLint fragmentUniformSampler = glGetUniformLocation(sScene.currentProgram, "uTextureS2D");
    assert(fragmentUniformSampler != -1);
    glUniform1i(fragmentUniformSampler, (GLint)0); // for GL_TEXTURE0
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);

    glEnableVertexAttribArray(indexCoords);
    //glEnableVertexAttribArray(indexTexture);
    glVertexAttribPointer(indexCoords, dimVT, GL_FLOAT, GL_FALSE, stride, 0);
    //GLintptr vertex_color_offset = dimVT * sizeof(GLfloat);
    //glVertexAttribPointer(indexTexture, dimT, GL_FLOAT, GL_FALSE, stride, (GLvoid*)vertex_color_offset);

#if 0 //def DEBUG_TEXTURE_WITH_SHADER
//    glPointSize(5.0);
//    glDrawArrays(GL_POINTS, 0, nPoints);
//    glDrawArrays(GL_LINE_STRIP, 0, nPoints);
#else
    glDrawArrays(GL_TRIANGLES, 0, nPoints*nVertPerLine);
#endif

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexTexture);
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_QUADS);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            glm::vec4 vert;
            [value getValue:&vert];
            glTexCoord2f(vert.z, vert.w);
            glVertex2f(vert.x, vert.y);
        }
    }
    glEnd();
#endif
}

// Used for drawing 'tLayerROI'
// pArray is an array of glm::vec4
// OpenGL Legacy draws with GL_QUAD_STRIP
// OpenGL Core draws with GL_TRIANGLE_FAN
void renderer_drawQuadStrip_xyuv(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    assert(sScene.currentProgram == sScene.overlayProgram.programHandle); // 1 sampler in the shader, GL_TEXTURE_RECTANGLE
    assert(sScene.currentShaderMode == SHADER_MODE_TEXTURE_RGBA ||
           sScene.currentShaderMode == SHADER_MODE_TEXTURE_LUMINOSITY);
    assert([pArray count] == 4);
    const int dimVT = 4; // number of components in the vertex array: XYUV

    GLsizei stride = (dimVT)*sizeof(GLfloat);
    const int nVertPerLine = 1; // each line drawn requires one vertex (GL_QUADS)
    const int nPoints = 4;
    const int arrayNumElements = nPoints*nVertPerLine*dimVT;
    GLfloat pointVertex[arrayNumElements];

    // The input array was prepared for GL_QUAD_STRIP (OpenGL Legacy)
    // but here we are using GL_TRIANGLE_FAN (OpenGL Core)
    // therefore we swap index 2 and 3
    const int idx[nPoints] = {0,1,3,2};
    int nv=0;
    glm::vec4 pc;
    for (int i=0; i < nPoints; i++) {
        [pArray[idx[i]] getValue:&pc];
        pointVertex[nv++] = pc.x;
        pointVertex[nv++] = pc.y;
        pointVertex[nv++] = pc.p;
        pointVertex[nv++] = pc.q;
    }

    assert(nv == arrayNumElements);

    // Give array to OpenGL
    checkOpenGLErrors(__LINE__);
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    GLuint vbo;
    glGenBuffers(1, &vbo);
    
    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aVertXYUV");
    assert(indexCoords != -1);

    // Set our "uTextureS2D" sampler to user Texture Unit 0
    GLint fragmentUniformSampler = glGetUniformLocation(sScene.currentProgram, "uTextureS2D");
    assert(fragmentUniformSampler != -1);
    glUniform1i(fragmentUniformSampler, (GLint)0); // for GL_TEXTURE0
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);

    glEnableVertexAttribArray(indexCoords);
    //glEnableVertexAttribArray(indexTexture);
    glVertexAttribPointer(indexCoords, dimVT, GL_FLOAT, GL_FALSE, stride, 0);
    //GLintptr vertex_color_offset = dimVT * sizeof(GLfloat);
    //glVertexAttribPointer(indexTexture, dimT, GL_FLOAT, GL_FALSE, stride, (GLvoid*)vertex_color_offset);

    glDrawArrays(GL_TRIANGLE_FAN, 0, nPoints*nVertPerLine);

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexTexture);
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_QUAD_STRIP);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            glm::vec4 vert;
            [value getValue:&vert];
            glTexCoord2f(vert.z, vert.w);
            glVertex2f(vert.x, vert.y);
        }
    }
    glEnd();
#endif
    checkOpenGLErrors(__LINE__);
}

#pragma mark -

// pArray is an array of Point_xy_rgb
// Used for GL_POINTS and GL_LINES
static void renderer_draw_xy_rgb(NSArray *pArray, GLenum mode)
{
#ifdef WITH_OPENGL_32
    #ifdef DEBUG_RENDERER_CALLS
    NSLog(@"%s %d, mode: %d", __FUNCTION__, __LINE__, mode);
    #endif
    assert(sScene != nil && sScene.currentProgram != 0);
    glDisable(GL_BLEND);

    const int dimV = 2; // number of components in the vertex array: X,Y
    const int dimC = 3; // r,g,b
    const int nVertPerLine = 1; // each point drawn requires one vertex (GL_POINTS)
    const int nPoints = [pArray count];
    GLfloat pointVertex[nPoints*nVertPerLine*dimV];
    GLfloat pointColor[ nPoints*nVertPerLine*dimC];

    int nv=0;
    int nc=0;
    for (long i = 0; i < nPoints; i++)
    {
        NSValue *value = pArray[i];
        Point_xy_rgb pc;
        [value getValue:&pc];
        
        pointVertex[nv++] = pc.p.x;
        pointVertex[nv++] = pc.p.y;

        pointColor[nc++] = pc.c.r;
        pointColor[nc++] = pc.c.g;
        pointColor[nc++] = pc.c.b;
    }

    // Give arrays to OpenGL
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    const int numVbo = 2;  // vert,col
    GLuint vbo[numVbo];
    glGenBuffers(numVbo, vbo);
    
    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    GLint indexColor  = glGetAttribLocation(sScene.currentProgram, "aColorRGBA");
    assert(indexCoords != -1);
    assert(indexColor != -1);
    
    // Position
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);
    
    // Color
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointColor), pointColor, GL_STATIC_DRAW);
    glVertexAttribPointer(indexColor, dimC, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexColor);
    
    glDrawArrays(mode, 0, nPoints*nVertPerLine);

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(numVbo, vbo);
    
    glDisableVertexAttribArray(indexCoords);
    glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(mode);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            Point_xy_rgb pc;
            [value getValue:&pc];
            
#ifdef USE_COLOR_UB
            glColor3ub(pc.c.r, pc.c.g, pc.c.b);
#else
            glColor3f(pc.c.r, pc.c.g, pc.c.b);
#endif
            glVertex2f(pc.p.x, pc.p.y);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
}

// pArray is an array of Point_xy_rgb
void renderer_drawPoints_xy_rgb(NSArray *pArray)
{
    GLScene *s = [GLScene currentScene];
    [s.overlayProgram Bind];
    [s.overlayProgram setMode: SHADER_MODE_ROUND_POINT];

    renderer_draw_xy_rgb(pArray, GL_POINTS);
}

// pArray is an array of Point_xy_rgb
void renderer_drawLines_xy_rgb(NSArray *pArray)
{
    renderer_draw_xy_rgb(pArray, GL_LINES);
}

#pragma mark -

// pArray is an array of Point_xy_rgba
void renderer_drawLineStrip_xy_rgba(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    const int dimV = 2; // number of components in the vertex array: XY
    const int dimC = 4; // number of components in the vertex array: RGBA
    const int nVertPerLine = 1; // each line drawn requires one vertex (GL_LINE_STRIP)
    const int nPoints = [pArray count];
    GLfloat pointVertex[nPoints*nVertPerLine*(dimV+dimC)];

    int nv=0;
    for (long i = 0; i < nPoints; i++) {
        Point_xy_rgba pc;
        [pArray[i] getValue:&pc];
        pointVertex[nv++] = pc.p.x;
        pointVertex[nv++] = pc.p.y;

        pointVertex[nv++] = pc.c.r;
        pointVertex[nv++] = pc.c.g;
        pointVertex[nv++] = pc.c.b;
        pointVertex[nv++] = pc.c.a;
    }
    
    // Give array to OpenGL
    checkOpenGLErrors(__LINE__);
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    GLint indexColor  = glGetAttribLocation(sScene.currentProgram, "aColorRGBA");
    assert(indexCoords != -1);
    assert(indexColor != -1);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);

    glEnableVertexAttribArray(indexCoords);
    glEnableVertexAttribArray(indexColor);
    GLsizei stride = (dimV+dimC)*sizeof(GLfloat);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, stride, 0);
    GLintptr vertex_color_offset = dimV * sizeof(GLfloat);
    glVertexAttribPointer(indexColor, dimC, GL_FLOAT, GL_FALSE, stride, (GLvoid*)vertex_color_offset);

    glDrawArrays(GL_LINE_STRIP, 0, nPoints*nVertPerLine); // not filled but the geometry is right

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_LINE_STRIP);
    {
        for (long i = 0; i < [pArray count]; i++) {
            NSValue *value = pArray[i];
            Point_xy_rgba pc;
            [value getValue:&pc];
            glColor4f(pc.c.r, pc.c.g, pc.c.b, pc.c.a);
            glVertex2f(pc.p.x,pc.p.y);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
}

// pArray is an array of glm::vec2
// OpenGL Legacy draws with GL_POLYGON
// OpenGL Core draws with GL_TRIANGLE_FAN
// The inside is filled
void renderer_drawPolygon(NSArray *pArray)
{
#ifdef WITH_OPENGL_32
    assert(sScene != nil && sScene.currentProgram != 0);
    const int dimV = 2; // number of components in the vertex array: X,Y
    const int nVertPerLine = 1; // each line drawn requires one vertex (GL_POLYGON)
    const int nPoints = [pArray count];
    GLfloat pointVertex[nPoints*nVertPerLine*dimV];

    int nv=0;
    for (long i = 0; i < nPoints; i++) {
        glm::vec2 p;
        [pArray[i] getValue:&p];
        pointVertex[nv++] = p.x;
        pointVertex[nv++] = p.y;
    }

    // Give array to OpenGL
    checkOpenGLErrors(__LINE__);
    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    
    GLuint vbo;
    glGenBuffers(1, &vbo);

    GLint indexCoords = glGetAttribLocation(sScene.currentProgram, "aCoordsXY");
    //GLint indexColor  = glGetAttribLocation(sScene.currentProgram, "aColorRGBA");
    assert(indexCoords != -1);
    //assert(indexColor != -1);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(pointVertex), pointVertex, GL_STATIC_DRAW);
    glVertexAttribPointer(indexCoords, dimV, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(indexCoords);
    checkOpenGLErrors(__LINE__);

    // GL_POLYGON not available in 4.1 ?
    //glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    //glDrawArrays(GL_TRIANGLE_STRIP, 0, nPoints*nVertPerLine); // filled but the geometry is not right
    //glDrawArrays(GL_LINE_LOOP, 0, nPoints*nVertPerLine); // not filled but the geometry is right
    glDrawArrays(GL_TRIANGLE_FAN, 0, nPoints*nVertPerLine);
    checkOpenGLErrors(__LINE__);

    // Final Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glDeleteBuffers(1, &vbo);
    
    glDisableVertexAttribArray(indexCoords);
    //glDisableVertexAttribArray(indexColor);  // back to "same color for all vertices"
    
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &vao);
#else // WITH_OPENGL_32
    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
    glBegin(GL_POLYGON);
    {
        for (long i = 0; i < [pArray count]; i++) {
            //NSValue *value = pArray[i];
            glm::vec2 p;
            [pArray[i] getValue:&p];
            glVertex2f(p.x, p.y);
        }
    }
    glEnd();
#endif // WITH_OPENGL_32
    checkOpenGLErrors(__LINE__);
}
