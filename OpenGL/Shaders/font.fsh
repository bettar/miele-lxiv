//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

in vec2 UV;
out vec4 final_color;

//uniform sampler2D uTextureS2D; // for GL_TEXTURE_2D
uniform sampler2DRect uTextureS2D; // for GL_TEXTURE_RECTANGLE
uniform vec4 uColorRGBA;

void main(void) {
    //final_color = vec4(1, 1, 1, texture(uTextureS2D, UV).r) * uColorRGBA;
    final_color = texture(uTextureS2D, UV) * uColorRGBA;
}
