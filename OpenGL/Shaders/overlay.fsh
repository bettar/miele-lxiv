//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Interface block, from vertex shader
in VertexData {
    vec4 vColor;
    vec2 UV;
} fs_in;

uniform int uModeF; // can we get it from the vertex shader ?
uniform sampler2DRect uTextureS2D; // for GL_TEXTURE_RECTANGLE
uniform vec4 uColorRGBA;

out vec4 color;

void main()
{
    if (uModeF == 0) // normal
    {
        color = fs_in.vColor;
    }
    else if (uModeF == 1) // texture RGBA
    {
        color = texture(uTextureS2D, fs_in.UV) * uColorRGBA;
    }
    else if (uModeF == 2) // round point
    {
        vec2 circCoord = 2.0 * gl_PointCoord - 1.0;
        if (dot(circCoord, circCoord) > 1.0)
            discard;

        color = fs_in.vColor;
    }
    else if (uModeF == 3) // texture LUMINANCE (brush)
    {
        color = vec4(1, 1, 1, texture(uTextureS2D, fs_in.UV).r) * uColorRGBA;
    }
}
