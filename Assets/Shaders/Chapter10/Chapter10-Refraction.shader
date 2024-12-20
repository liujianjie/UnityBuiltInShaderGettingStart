Shader "Unity Shaders Book/Chapter 10/Refraction" {
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _RefractColor("Refraction Color", Color) = (1, 1, 1, 1)
        _RefractAmount("Refraction Amount", Range(0, 1)) = 1       // _ReflectAmount写错成_RflectAmount
        _RefractRatio("Refraction Ratio", Range(0.1, 1)) = 0.5
        _Cubemap("Refraction Cubemap", Cube) = "_Skybox" {}
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
            fixed4 _RefractColor;
            float _RefractAmount;
            fixed _RefractRatio;
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
                fixed3 worldRefr : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);     // 顶点位置

                o.worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;    // 世界空间位置

                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);

                //o.worldRefr = reflect(-o.worldViewDir, o.worldNormal);  // 计算世界空间下的反射向量
                o.worldRefr = refract(-normalize(o.worldViewDir), normalize(o.worldNormal), _RefractRatio);  // 计算世界空间下的折射向量))

			 	TRANSFER_SHADOW(o);
                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(i.worldViewDir);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // rgb 写错成 rbg
                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0, dot(worldNormal, worldLightDir));
                
                // 使用世界空间下的反射向量去采样Cubemap
                fixed3 refraction = texCUBE(_Cubemap, i.worldRefr).rgb * _RefractColor.rgb;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                fixed3 color = ambient + lerp(diffuse, refraction, _RefractAmount) * atten;

                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
	FallBack "Reflective/VertexLit" 
}
