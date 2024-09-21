Shader "Unity Shaders Book/Chapter 7/Normal Map In World Space" 
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
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;

            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // 切线空间的法线、切线、副切线 到世界空间下
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);            // 世界空间的法线
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);         // 世界空间的切线
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;  // 世界空间的副切线，v.tangent.w是方向

                // 从世界空间到切线空间的变换矩阵：按行摆放
                //float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

                // 从切线空间到世界空间：按列摆放
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                // 世界空间的位置 = worldPos，但是没放在数据结构中。
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                fixed3 viewDir = normalize(UnityWorldSpaceLightDir(worldPos));

                // 在切线空间下获得法线
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));// 获得压缩的法线 = 像素值 并且// 解压法线：公式：normal = 2 * tex - 1
                bump.xy *= _BumpScale;

                bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy))); // 直接三角形求第三边公式：勾股定理？
                
                // 将法线从切线到世界。就是3x3的矩阵乘以3x1的向量：矩阵的每一行与向量的点乘
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                float3 diffuse = _LightColor0.rgb * albedo * max(0, dot(bump, lightDir));

                fixed3 halfDir = normalize(lightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Specular"
}
