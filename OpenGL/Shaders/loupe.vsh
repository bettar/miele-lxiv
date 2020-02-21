//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Input vertex data, different for all executions of this shader.
layout(location = 0) in vec3 aCoordsXYZ; // vertex position modelspace
layout(location = 1) in vec2 aTexUV;
layout(location = 2) in vec2 aTexUV1;

// Values that stay constant for the whole mesh.
uniform mat4 uProjectionM;
uniform mat4 uModelViewM;

// Interface block, to next shader (geometry or fragment)
// Output data, will be interpolated for each fragment.
out VertexData {
    out vec2 UV0;
    out vec2 UV1;
} vs_out;

void main()
{
    // Output position of the vertex, in clip space : MVP * position
    gl_Position = uProjectionM * uModelViewM * vec4(aCoordsXYZ,1);

    // UV of the vertex. No special space for this one.
    vs_out.UV0 = aTexUV;
    vs_out.UV1 = aTexUV1;
}
