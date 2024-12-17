// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 14/Toon Shading" {
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)          // 整体颜色调整
        _MainTex ("Main Tex", 2D) = "white" {}               // 主纹理
        _Ramp ("Ramp Texture", 2D) = "white" {}              // 渐变纹理，用于控制卡通阴影效果
        _Outline ("Outline", Range(0, 1)) = 0.1               // 轮廓线宽度
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1) // 轮廓线颜色
        _Specular ("Specular", Color) = (1, 1, 1, 1)         // 高光颜色
        _SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01 // 高光范围调节
    }
    SubShader
    {
        // 设置渲染类型和渲染队列
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        // 第一个Pass：绘制轮廓线
        Pass {
            NAME "OUTLINE"
            Cull Front // 剔除正面，只渲染背面以产生轮廓效果

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float _Outline;
            fixed4 _OutlineColor;

            // 顶点着色器输入结构
            struct a2v{
                float4 vertex : POSITION;   // 顶点位置
                float3 normal : NORMAL;     // 顶点法线
            };

            // 顶点着色器输出结构
            struct v2f{
                float4 pos :SV_POSITION;
            };

            // 顶点着色器: 实现轮廓线效果
            v2f vert(a2v v){
                v2f o;

                // 将顶点转换为观察空间
                float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
                // 将法线转换到观察空间 UNITY_MATRIX_MV 是模型-视图矩阵 UNITY_MATRIX_IT_MV 主要用于法线变换。当我们需要将法线从模型空间转换到观察空间时，不能直接使用模型-视图矩阵，而应该使用其逆转置矩阵。
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);// UNITY_MATRIX_IT_MV 见md
                normal.z = -0.5f; // 调整法线z分量为一个定制，以免背面向外扩张时候遮挡正面面片
                // 沿法线方向扩展顶点,只在观察空间进行扩展。 见md，反正就是在观察空间扩展更好
                pos = pos + float4(normalize(normal), 0) * _Outline;
                // 转换到裁剪空间
                o.pos = mul(UNITY_MATRIX_P, pos);
                return o;
            }
            // 片元：设置轮廓线颜色
            float4 frag(v2f i) : SV_Target{
                return float4(_OutlineColor.rgb, 1);
            }
            ENDCG
        }

        // 第二个Pass：主要渲染过程
        Pass{
            Tags{"LightMode"="ForwardBase"}

            Cull Back // 剔除背面

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase   // 启用阴影等基础光照

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShaderVariables.cginc"

            // 声明变量
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Ramp;
            fixed4 _Specular;
            fixed _SpecularScale;

            // 顶点着色器输入结构
            struct a2v{
                float4 vertex :POSITION;
                float3 normal :NORMAL;
                float4 texcoord:TEXCOORD0;
                float4 tangent :TANGENT;
            };

            // 顶点着色器输出结构
            struct v2f{
                float4 pos :POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)    // 阴影坐标
            };

            v2f vert(a2v v){
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);// 转换到裁剪空间
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex); // 纹理坐标
                o.worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // 世界空间位置
                TRANSFER_SHADOW(o) // 传递阴影坐标
                return o;
            }

            float4 frag(v2f i) : SV_Target{
                // 准备基本光照
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);

                // 采样主文里
                fixed4 c = tex2D(_MainTex, i.uv);
                fixed3 albedo = c.rgb * _Color.rgb;

                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                // 计算阴影和衰减
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // 计算漫反射
                fixed diff = dot(worldNormal, worldLightDir);
                diff = (diff * 0.5 + 0.5) * atten;  // 将范围从[-1, 1] 映射到[0, 1]

                // 使用渐变纹理采样得到卡通化的漫反射效果
                fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;

                // 计算卡通化的高光效果
                fixed spec = dot(worldNormal, worldHalfDir);
                fixed w = fwidth(spec)*2.0;// 计算高光边界过渡带的宽度
                // 使用smoothstep创建
                fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);
                //specular = pow(max(0, dot(worldNormal, worldHalfDir)), 32);
                // 合并所有光照分量
                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG 
        }
    }
    FallBack Off
}
/*
模型空间-（world矩阵）世界空间-（view矩阵）-观察空间坐标-（project矩阵）裁剪空间-透视除法执行后才将裁剪坐标系变换到标准化设备坐标系- 视口变换视口变换将标准化设备坐标系到屏幕坐标
*/