//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Input vertex data, different for all executions of this shader.
layout(location = 0) in vec3 aCoordsXYZ; // vertex position modelspace
layout(location = 1) in vec2 aTexUV;

// Values that stay constant for the whole mesh.
uniform mat4 uProjectionM;
uniform mat4 uModelViewM;

// Output data, will be interpolated for each fragment.
out vec2 UV;

void main()
{
    // Output position of the vertex, in clip space : MVP * position
    gl_Position = uProjectionM * uModelViewM * vec4(aCoordsXYZ,1);

    // UV of the vertex. No special space for this one.
    UV = aTexUV;
}
