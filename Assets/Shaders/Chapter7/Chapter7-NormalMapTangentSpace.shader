Shader "Unity Shaders Book/Chapter 7/Normal Map In Tangent Space" 
{
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Bump Scale", Float) = 1.0
        _Specular("Specular", Color) = (1, 1, 1,1)
        _Gloss("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass{
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;     // 纹理的属性
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };
            struct v2f{
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;

            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                // 切线空间的法线、切线、副切线 到世界空间下
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);            // 世界空间的法线
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);         // 世界空间的切线
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;  // 世界空间的副切线，v.tangent.w是方向

                // 从世界空间到切线空间的变换矩阵
                float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

                // 将light和view从世界到切线空间
                o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
                o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangenViewDir = normalize(i.viewDir);

                // 从法线贴图中获取法线
                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);// 获得压缩的法线= 像素值
                fixed3 tangentNormal;

                tangentNormal = UnpackNormal(packedNormal);     // 解压法线：公式：normal = 2 * tex - 1

                tangentNormal.xy *= _BumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal. xy)));   // 直接三角形求第三边公式：勾股定理？

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                float3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

                fixed3 halfDir = normalize(tangentLightDir + tangenViewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Specular"
}
