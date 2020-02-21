//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

//#define PASS_THROUGH

uniform vec2 lineWidthNVC;

layout(lines) in;
#ifdef PASS_THROUGH
layout(line_strip, max_vertices = 2) out;
#else
layout(triangle_strip, max_vertices = 4) out;
#endif

// Interface block, from vertex shader
in VertexData {
    vec4 vColor;
} gs_in[2]; // input are lines: 2 points

// Output to fragment shader
out VertexData {
    vec4 vColor;
} gs_out;

void main()
{
    vec2 dummy = lineWidthNVC; // avoid optimizing it out

#ifdef PASS_THROUGH
    vec2 dummy = lineWidthNVC; // avoid optimizing it out
    for (int j = 0; j < gl_in.length(); j++) {
        gl_Position = gl_in[j].gl_Position;
        gs_out.vColor = gs_in[j].vColor;
        gs_out.UV = gs_in[j].UV;
        EmitVertex();

        // Consider every 2 vertices as an independent line
        if ((j%2)==1)
            EndPrimitive();
    }

#else // PASS_THROUGH

//    for (int i = 0; i < gl_in.length() ; i++)
//    {
//        gl_Position = gl_in[i].gl_Position;
//        vColor = gs_in[i].vColor;
//        UV = gs_in[i].UV;
//        EmitVertex();
//    }
//
//    EndPrimitive();
    
    // Compute the lines direction
    vec2 normal = normalize(gl_in[1].gl_Position.xy / gl_in[1].gl_Position.w -
                            gl_in[0].gl_Position.xy / gl_in[0].gl_Position.w);
    // Rotate 90 degrees
    normal = vec2(-1.0*normal.y, normal.x);
    
#if 0
    for (int j = 0; j < 4; j++)
    {
        int i = j/2;

        gl_Position = vec4(gl_in[i].gl_Position.xy + (lineWidthNVC*normal)*((j+1)%2 - 0.5)*gl_in[i].gl_Position.w,
                           0.0,//gl_in[i].gl_Position.z,
                           1.0);//gl_in[i].gl_Position.w);
        gs_out.vColor = gs_in[i].vColor;
        gs_out.UV = gs_in[i].UV;
        EmitVertex();
    } // for
#else
    gl_Position = vec4(gl_in[0].gl_Position.xy - lineWidthNVC*normal, 0.0, 1.0);
    gs_out.vColor = gs_in[0].vColor;
    //gs_out.UV = gs_in[0].UV;
    EmitVertex();

    gl_Position = vec4(gl_in[0].gl_Position.xy + lineWidthNVC*normal, 0.0, 1.0);
    gs_out.vColor = gs_in[0].vColor;
    //gs_out.UV = gs_in[0].UV;
    EmitVertex();

    gl_Position = vec4(gl_in[1].gl_Position.xy - lineWidthNVC*normal, 0.0, 1.0);
    gs_out.vColor = gs_in[1].vColor;
    //gs_out.UV = gs_in[1].UV;
    EmitVertex();

    gl_Position = vec4(gl_in[1].gl_Position.xy + lineWidthNVC*normal, 0.0, 1.0);
    gs_out.vColor = gs_in[1].vColor;
    //gs_out.UV = gs_in[1].UV;
    EmitVertex();
#endif

#endif // PASS_THROUGH
    
    EndPrimitive();
}
