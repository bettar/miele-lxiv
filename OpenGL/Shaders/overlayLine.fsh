//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

// Interface block, from previous shader (geometry or vertex)
in VertexData {
    vec4 vColor;
} fs_in;

out vec4 color;

void main()
{
    color = fs_in.vColor;
}
