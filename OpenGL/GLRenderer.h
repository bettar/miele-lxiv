//
//  GLRenderer.hpp
//  miele-lxiv
//
//  Copyright © 2019 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File

#ifndef GLRenderer_hpp
#define GLRenderer_hpp

#import <AppKit/AppKit.h>
#import "glm/glm.hpp"

#import "mgl.h" // for WITH_OPENGL_32

@class GLScene;

void renderer_setScene(GLScene **s) __deprecated;

int checkOpenGLErrors(int lineNo);
bool checkOGLVersion();
bool checkExtension(const char* ext);

#ifdef WITH_OPENGL_32
void renderer_set_MV(glm::mat4 &m);
void renderer_reset_MV() __deprecated;
#endif
void renderer_reset_scale_MV(CGSize scaleFactor, GLuint fromLine=0);
void renderer_reset_scale_MV(CGSize scaleFactor, BOOL flipX, BOOL flipY, GLuint fromLine=0);

void renderer_reset_scale_translate_MV(CGSize scaleFactor, CGPoint translationOffset);
void renderer_reset_scale_translate_MV(CGSize scaleFactor, CGPoint translationOffset, BOOL flipX, BOOL flipY);

void renderer_reset_scale_rotate_MV(CGSize scaleFactor, float rotationAngleDeg, BOOL flipX, BOOL flipY);

#ifdef WITH_OPENGL_32
void renderer_setProgram(GLuint p, GLuint fromLine=0) __deprecated;

void checkShader(GLuint shader);
void checkProgram(GLuint program);
GLuint compileShader(GLenum type, NSString *file);
GLuint loadShaders(NSString *vertex, NSString *geometry, NSString *fragment);

void applyColorCorrectionMatrix(float bias, float scale);

//+ (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file;
void textureFromImage(NSImage* theImg, GLuint *texName); // See also "makeTextureObjectFromImage"
#endif

// With loupe shader
void renderer_setTextureCount(int count, GLuint fromLine=0);
void renderer_drawTriangleFan_xyz_uv_uv(NSArray *pArray);

// With image shader
void renderer_drawTriangleStrip_xyz_uv(NSArray *pArray);
void renderer_drawTriangleFan_xyz_uv(NSArray *pArray);

// With font shader
void renderer_drawQuad_xyuv(NSArray *pArray);
void renderer_drawQuadStrip_xyuv(NSArray *pArray);
void renderer_setTextColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
void renderer_set_rgba(GLfloat r, GLfloat g, GLfloat b, GLfloat a, GLuint fromLine=0);
void renderer_set_rgb(GLfloat r, GLfloat g, GLfloat b, GLuint fromLine=0);
void renderer_setLineWidth(GLfloat w);

void renderer_drawQuads_xyz(NSArray *pArray);
void renderer_drawLine_xyz(NSArray *pArray, GLenum lineMode);

void renderer_drawTriangles_xy(NSArray *pArray);
void renderer_drawLine_xy(NSArray *pArray, GLenum lineMode);
void renderer_drawPoints(NSArray *pArray, BOOL rounded=true);

void renderer_enable_blend_smooth();
void renderer_disable_blend_smooth();
void renderer_set_point_size(GLfloat size);

typedef struct _point3D_UV {
    glm::vec3 p;
    glm::vec2 t;
} Point_xyz_uv;

typedef struct _point3D_UV_UV {
    glm::vec3 p;
    glm::vec2 t0;
    glm::vec2 t1;
} Point_xyz_uv_uv;

typedef struct _point2D_RGB {
    glm::vec2 p;
    glm::vec3 c;
} Point_xy_rgb;

void renderer_drawPoints_xy_rgb(NSArray *pArray);
void renderer_drawLines_xy_rgb(NSArray *pArray);

typedef struct _point2D_RGBA {
    glm::vec2 p;
    glm::vec4 c;
} Point_xy_rgba;

void renderer_drawLineStrip_xy_rgba(NSArray *pArray);

void renderer_drawPolygon(NSArray *pArray);

#endif /* GLRenderer_hpp */
