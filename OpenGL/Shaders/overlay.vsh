//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

layout (location = 0) in vec2 aCoordsXY;  // attribute
layout (location = 1) in vec4 aColorRGBA; // attribute
layout (location = 2) in vec4 aVertXYUV;  // <vec2 pos, vec2 tex>

uniform mat4 uProjectionM;
uniform mat4 uModelViewM;
uniform int uModeV;

// interface block, to fragment shader 
out VertexData {
    vec4 vColor;
    vec2 UV;
} vs_out;

void main() {
    if (uModeV == 1 || uModeV == 3) { // texture RGBA OR texture LUMINANCE (brush)
        gl_Position = uProjectionM * uModelViewM * vec4(aVertXYUV.xy, 0.0, 1.0);
        vs_out.UV = aVertXYUV.zw; // same as .pq
    }
    else {
        gl_Position = uProjectionM * uModelViewM * vec4(aCoordsXY, 0.0, 1.0);
        vs_out.vColor = aColorRGBA;
    }

    //gl_Position = vec4(aCoordsXY, 0.0, 1.0);
//    vs_out.vColor = aColorRGBA;
}
