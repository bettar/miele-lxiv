//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Interpolated values from the vertex shaders
in vec2 UV;

// Ouput data
out vec4 final_color;

// Values that stay constant for the whole mesh.
uniform sampler2D uTextureS2D;  // for GL_TEXTURE_2D
//uniform sampler2DRect uTextureS2DRect; // for GL_TEXTURE_RECTANGLE

uniform mat4 uColorCorrectionM;

void main()
{
#if 0
    // Listing 11.23 of SuperBible
    //vec4 input_color = vec4(texture( uTextureS2D, UV ).rgb, 1.0 ); // no fusion blending
    vec4 input_color = vec4(texture( uTextureS2D, UV ).rgba );
    vec4 transformed_color = uColorCorrectionM * input_color;
    final_color = transformed_color / transformed_color.w;
#else
    // Listing 11.29 of SuperBible
    vec4 input_color = texture( uTextureS2D, UV);
    if (input_color.a < 0.1)
        discard;

    vec4 transformed_color = uColorCorrectionM * input_color;
    final_color = transformed_color;  // ok
#endif
}
