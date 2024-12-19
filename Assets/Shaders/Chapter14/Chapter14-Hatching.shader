// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
// 这是一个实现素描风格渲染的shader
// 参考了2001年ACM发表的一篇关于实时素描渲染的论文
Shader "Unity Shaders Book/Chapter 14/Hatching" {
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)          // 整体颜色调整
        _TileFactor("Tile Factor", Float) = 1               // 控制素描纹理的平铺度
        _Outline ("Outline", Range(0, 1)) = 0.1               // 轮廓线宽度
        // 6张素描纹理，从疏到密
        _Hatch0 ("Hatch 0", 2D) = "white"{}                 // 最疏的素描纹理
        _Hatch1 ("Hatch 1", 2D) = "white"{}
        _Hatch2 ("Hatch 2", 2D) = "white"{}
        _Hatch3 ("Hatch 3", 2D) = "white"{}
        _Hatch4 ("Hatch 4", 2D) = "white"{}
        _Hatch5 ("Hatch 5", 2D) = "white"{}                 // 最密的素描纹理
    }
    SubShader
    {
        // 设置渲染类型和队列
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        
        // 使用轮廓线shader的pass
        UsePass "Unity Shaders Book/Chapter 14/Toon Shading/OUTLINE"

        Pass {
            Tags{"LightMode"="ForwardBase"}                 // 前向渲染路径的基础Pass

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase                   // 启用阴影等光照特性

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShaderVariables.cginc"


            // 变量声明
            fixed4 _Color;
            float _TileFactor;
            sampler2D _Hatch0;
            sampler2D _Hatch1;
            sampler2D _Hatch2;
            sampler2D _Hatch3;
            sampler2D _Hatch4;
            sampler2D _Hatch5;

            // 顶点着色器输入结构
            struct a2v{
                float4 vertex : POSITION;   // 顶点位置
                float4 tangent : TANGENT;   // 切线
                float3 normal : NORMAL;     // 顶点法线
                float2 texcoord:TEXCOORD0;  // uv坐标
            };

            // 顶点着色器输出结构
            struct v2f{
                float4 pos :SV_POSITION;            // 裁剪空间位置
                float2 uv : TEXCOORD0;              // UV坐标
                fixed3 hatchWeights0 : TEXCOORD1;   // 存储前3张素描纹理的权重
                fixed3 hatchWeights1 : TEXCOORD2;   // 存储后3张素描纹理的权重
                float3 worldPos : TEXCOORD3;         // 世界空间位置
                SHADOW_COORDS(4)                    // 阴影坐标
            };

            // 顶点着色器
            v2f vert(a2v v){
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex); // 转换到裁剪空间

                o.uv = v.texcoord.xy * _TileFactor;     // 计算UV坐标

                // 计算漫反射系数
                fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed diff = max(0, dot(worldLightDir, worldNormal));

                // 初始化纹理权重
                o.hatchWeights0 = fixed3(0, 0, 0);
                o.hatchWeights1 = fixed3(0, 0, 0);
                
                // 根据漫反射系数计算各个纹理的权重
                float hatchFactor = diff * 7.0;

                // 根据不同的光照强度区间设置不同的纹理权重
                if(hatchFactor > 6.0){
                    // 最亮区域，使用纯白色
                }else if(hatchFactor > 5.0){
                    o.hatchWeights0.x = hatchFactor - 5.0;
                }else if(hatchFactor > 4.0){
                    o.hatchWeights0.x = hatchFactor - 4.0;
                    o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;
                }else if(hatchFactor > 3.0){
                    o.hatchWeights0.y = hatchFactor - 3.0;
                    o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;
				} else if (hatchFactor > 2.0) {
					o.hatchWeights0.z = hatchFactor - 2.0;
					o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;
				} else if (hatchFactor > 1.0) {
					o.hatchWeights1.x = hatchFactor - 1.0;
					o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;
				} else {
					o.hatchWeights1.y = hatchFactor;
					o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;
				}

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;// 计算世界空间位置

                TRANSFER_SHADOW(o); // 传递阴影信息
                return o;
            }
            // 片元
            float4 frag(v2f i) : SV_Target{
                // 采样6张素描纹理并与对应权重相乘
                fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
                fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
				fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
				fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
				fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
				fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

                // 计算纯白色部分
                fixed4 whiteColor = fixed4(1, 1, 1, 1) *(1-i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z - 
							i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);
                            
                // 合并所有纹理结果
                fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor; 
                
                // 计算阴影衰减
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                
                // 返回最终颜色（结合色调和阴影）
                return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
            }
            ENDCG
        }
    }
	FallBack "Diffuse"
}
/*
模型空间-（world矩阵）世界空间-（view矩阵）-观察空间坐标-（project矩阵）裁剪空间-透视除法执行后才将裁剪坐标系变换到标准化设备坐标系- 视口变换视口变换将标准化设备坐标系到屏幕坐标
*/