
Shader "Unity Shaders Book/Chapter 9/Forward Rendering" {
    Properties
    {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque"}

        Pass{
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct v2f{
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);     // 顶点位置

                o.worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;    // 世界空间位置

                return o;
            }
            // 处理平行光、 环境光、高光。
            fixed4 frag(v2f i) : SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz); // 直接使用前向渲染的内置变量得到光的方向
                
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;// 直接使用前向渲染的内置变量得到环境光

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                fixed atten = 1.0;

                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
            }
            ENDCG
        }
        // 处理影响该物体的逐像素光源：点光源、聚光灯、区域光
        // Pass{
        //     Tags{"LightMode"="ForwardAdd"}
        // }
    }
	FallBack "Specular"
}
