//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

layout (location = 0) in vec2 aCoordsXY;  // attribute
layout (location = 1) in vec4 aColorRGBA; // attribute

uniform mat4 uProjectionM;
uniform mat4 uModelViewM;

// interface block, to next shader (geometry or fragment)
out VertexData {
    vec4 vColor;
} vs_out;

void main() {
    gl_Position = uProjectionM * uModelViewM * vec4(aCoordsXY, 0.0, 1.0);
    vs_out.vColor = aColorRGBA;
}
