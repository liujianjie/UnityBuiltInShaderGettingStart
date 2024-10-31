Shader "Unity Shaders Book/Chapter 10/Glass Refraction" {
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Cubemap("Environment Cubemap", Cube) = "_Skybox" {}
        _Distortion("Distortion", Range(0, 100)) = 10
        _RefractAmount("Refract Amount", Range(0.0, 1.0)) = 1.0
    }
    SubShader
    {
        // Transparent 不透明的物体必须先得绘制完
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }

        // 这个pass 将会抓取屏幕纹理，在物体渲染到texture之后
        // 我们可以获取这个屏幕纹理 在下一个pass访问名称_RefractionText
		GrabPass { "_RefractionTex" }

        Pass{
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

			#include "UnityCg.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            samplerCUBE _Cubemap;
            float _Distortion;
            fixed _RefractAmount;
            sampler2D _RefractionTex;           // 对应grabpss时指定的纹理名称
            float4 _RefractionTex_TexelSize;    // 得到grabpss时的纹素大小 256 * 512=>纹素大小(1/256, 1/512)

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord: TEXCOORD0;
            };

            struct v2f{
                float4 pos :SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);     // 顶点位置
                // 得到被抓取的屏幕图像的采样坐标
                o.scrPos = ComputeGrabScreenPos(o.pos);
                // 传递uv
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

                float3 worldPos =  mul(unity_ObjectToWorld, v.vertex).xyz;    // 世界空间位置
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz); // 世界空间切线
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; // 世界空间副法线)

                // 得到从切线空间到世界空间的转换矩阵
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // 获取切线空间下的法线
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));

                // 获取切线空间下的偏移
                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                // 屏幕图像的采样坐标进行偏移，模拟折射效果。 （切线空间下的法线方向来进行偏移。法线方向：i.scrPos.z？)
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;

                // 对scrPos透视除法得到真正的屏幕坐标 并采样
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;

                // 转换切线空间的法线到世界空间
                // 将法线从切线到世界。就是3x3的矩阵乘以3x1的向量：矩阵的每一行与向量的点乘
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
                fixed3 reflDir = reflect(-worldViewDir, bump);
                fixed4 texColor = tex2D(_MainTex, i.uv.xy);

                // 从立方体贴图中获取反射颜色
                fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;

                // 反射(cubemap） * 系数 + 折射（屏幕纹理）+系数 
                fixed3 finalColor = reflCol * (1-_RefractAmount) + refrCol * _RefractAmount;

                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
	FallBack "Diffuse"
}

