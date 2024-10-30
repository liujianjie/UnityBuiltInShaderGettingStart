Shader "Unity Shaders Book/Chapter 10/Fresnel" {
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _FresnelScale("Fresnel Scale", Range(0, 1)) = 1       // _ReflectAmount写错成_RflectAmount
        _Cubemap("Reflection Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        Pass{
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
			#pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
			#include "AutoLight.cginc"

            fixed4 _Color;
            fixed _FresnelScale;
            samplerCUBE _Cubemap;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct v2f{
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                fixed3 worldNormal : TEXCOORD1;
                fixed3 worldViewDir : TEXCOORD2;
                fixed3 worldRefl : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);     // 顶点位置

                o.worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;    // 世界空间位置

                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);

                o.worldRefl = reflect(-o.worldViewDir, o.worldNormal);  // 计算世界空间下的反射向量

			 	TRANSFER_SHADOW(o);
                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(i.worldViewDir);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // 使用世界空间下的反射向量去采样Cubemap
                fixed3 reflection = texCUBE(_Cubemap, i.worldRefl).rgb;

                fixed fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(worldViewDir, worldNormal), 5);

                // rgb 写错成 rbg
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0, dot(worldNormal, worldLightDir));

                // 就是漫反射 和 采样天空盒的反射 进行混合，混合系数就是菲涅尔
                fixed3 color = ambient + lerp(diffuse, reflection, saturate(fresnel)) * atten;

                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
	FallBack "Reflective/VertexLit" 
}

/*
dot(worldViewDir, worldNormal):
这是视线方向与表面法线的点积。
当视线垂直于表面时，这个值接近1。
当视线与表面平行（即看向边缘）时，这个值接近0。
1 - dot(worldViewDir, worldNormal):
这个操作反转了上面的结果。
当看向边缘时，这个值接近1。
当垂直看向表面时，这个值接近0。
pow(..., 5):
这个幂运算加强了效果，使边缘更加明显。
_FresnelScale:
这是一个可调节的参数，控制整体效果的强度。
现在，让我们看看这个公式如何产生边缘发光效果：

边缘效果：
当视线接近表面边缘时，dot(worldViewDir, worldNormal) 接近0。
因此，1 - dot(...) 接近1。
经过幂运算后，这个值仍然接近1。
结果是，在边缘处 fresnel 值较大。
中心效果：
当直视表面时，dot(worldViewDir, worldNormal) 接近1。
因此，1 - dot(...) 接近0。
经过幂运算后，这个值变得更接近0。
结果是，在中心处 fresnel 值较小。
平滑过渡：
幂运算（pow(..., 5)）创造了从中心到边缘的平滑过渡。
可调节性：
_FresnelScale 允许调整基础反射率，影响整体效果的强度。
实际应用：

这个 fresnel 值通常用作混合因子或强度系数。
可以用它来混合反射颜色、调整透明度，或者直接作为发光强度。
*/
