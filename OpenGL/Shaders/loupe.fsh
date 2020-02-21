//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Interpolated values from the vertex shaders
//in vec2 UV;
in VertexData {
    vec2 UV0;   // mask
    vec2 UV1;   // image
} fs_in;

// Ouput data
out vec4 final_color;

uniform sampler2DRect uTexture0; // for GL_TEXTURE_RECTANGLE
uniform sampler2D uTexture1; // for GL_TEXTURE_2D
//uniform sampler2DRect uTexture1; // for GL_TEXTURE_RECTANGLE

uniform int uTexCount;

void main()
{
    vec4 texel0 = texture( uTexture0, fs_in.UV0 );
    vec4 texel1 = texture( uTexture1, fs_in.UV1 );

    //vec4 transformed_color;

    if (uTexCount == 2)
    {
        if (texel0.a == 0)
            discard;

        final_color = texel1;
    }
    else {
        final_color = texel0;
    }

    //final_color = transformed_color;
}
