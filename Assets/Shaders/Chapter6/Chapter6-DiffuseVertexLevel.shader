// Shader "Unity Shaders Book/Chapter 6/Diffuse Vertex-Level"
// {
//     Properties
//     {
//         _Diffuse("Diffuse", Color) = (1, 1, 1,1)
//     }
//     SubShader
//     {
//         Pass
//         {
//             Tags{"LightMode"="ForwardBase"}
//             CGPROGRAM
//             #pragma vertex vert
//             #pragma fragment frag

//             #include "Lighting.cginc"

//             fixed4 _Diffuse;
//         }

//     }
// }
