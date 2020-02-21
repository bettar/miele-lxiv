//  Copyright (c) 2020 Alex Bettarini. All rights reserved.
//  License GPLv3.0 -- see License File
//Miele::System

layout (location = 0) in vec4 aVertXYUV;  // <vec2 pos, vec2 tex>

uniform mat4 uProjectionM;
//uniform mat4 uModelViewM;

out vec2 UV;

void main(void) {
  //gl_Position = vec4(aVertXYUV.xy, 0, 1);
  gl_Position = uProjectionM * vec4(aVertXYUV.xy, 0, 1);
  //gl_Position = uProjectionM * uModelViewM * vec4(aVertXYUV.xy, 0, 1);
  UV = aVertXYUV.zw; // same as .pq
}
