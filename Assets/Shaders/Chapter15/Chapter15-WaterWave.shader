Shader "Unity Shaders Book/Chapter 15/Water Wave" {
    Properties
    {
        _Color("Main Color", Color) = (0, 0.15, 0.115, 1)// 主颜色，用于着色。
        _MainTex("Base(RGB)", 2D) = "white" {}// 主要纹理。
        _WaveMap("Wave Map", 2D) = "bump" {}// 用于波动效果的法线贴图。
        _Cubemap("Environment Cubemap", Cube) = "_Skybox"{}// 环境反射使用的立方体贴图。
        _WaveXSpeed("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01// 波动横向移动速度。
        _WaveYSpeed("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01// 波动纵向移动速度。
        _Distortion("Distortion", Range(0, 100)) = 10// 波动导致的扭曲程度。
    }
    SubShader
    {
        // 需要在透明队列中渲染，以便在其它对象之后绘制。
        Tags { "RenderType"="Opaque" "Queue"="Transparent"}
        
        // 此pass用于获取屏幕上对象后的图像，并存储到纹理中。
        GrabPass{"_RefractionTex"}

        Pass {
            Tags{"LightMode"="ForwardBase"}                 // 前向渲染路径的基础Pass

            CGPROGRAM
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            #pragma multi_compile_fwdbase                   // 启用阴影等光照特性
            #pragma vertex vert
            #pragma fragment frag

            // 变量声明
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _WaveMap;
            float4 _WaveMap_ST;
            samplerCUBE _Cubemap;
            fixed _WaveXSpeed;
            fixed _WaveYSpeed;
            float _Distortion;
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;

            // 顶点着色器输入结构
            struct a2v{
                float4 vertex : POSITION;   // 顶点位置
                float3 normal : NORMAL;     // 顶点法线
                float4 tangent : TANGENT;   // 切线
                float4 texcoord:TEXCOORD0;  // uv坐标
            };

            // 顶点着色器输出结构
            struct v2f{
                float4 pos : SV_POSITION;     // 裁剪空间的位置
                float4 scrPos : TEXCOORD0;   // 屏幕空间位置，用于抓取纹理
                float4 uv : TEXCOORD1;      // 纹理坐标
                float4 TtoW0 : TEXCOORD2; 
                float4 TtoW1 : TEXCOORD3; 
                float4 TtoW2 : TEXCOORD4; 
            };

            // 顶点着色器
            v2f vert(a2v  v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex); // 转换为裁剪空间坐标
                o.scrPos = ComputeGrabScreenPos(o.pos); // 计算屏幕空间位置
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex); // 纹理坐标变换
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap); // 波动贴图坐标变换

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; // 转换到世界坐标
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal); // 世界法线
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz); // 世界切线
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; // 世界副法线， * v.tangent.w 是为了方向z正方向向内还是外

                // 切线空间到世界空间矩阵
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }
            // 片元
            float4 frag(v2f i) : SV_Target{
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);  // 提取世界坐标
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos)); // 视线方向
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);  // 波动速度计算

                // 获取切线空间法线
                fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;  // 采样水波噪声贴图
                fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;  // 采样水波噪声贴图
                fixed3 bump = normalize(bump1 + bump2);                     // 归一化组合后的法线

                // 在切线空间中计算偏移
                // 使用法线来扭曲屏幕采样坐标，产生折射效果
                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;            // * z是为了让远处的水偏移更明显
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb; // 折射颜色

                // 将法线转换到世界空间
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
                fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed); // 获取着色纹理颜色 - 水的主要颜色
                fixed3 reflDir = reflect(-viewDir, bump);           // 计算反射方向
                fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;    // 反射颜色

                fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);       // 计算菲涅尔效应
                fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);  // 最终颜色组合

                return fixed4(finalColor, 1);           // 返回最终颜色，alpha为1使其不透明
            }
            ENDCG
        }
        Pass{
            Tags{"LightMode" = "ShadowCaster"}
               
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"

            fixed _BurnAmount;      // 控制消融程度的参数
            sampler2D _BurnMap;     // 消融贴图
            float4 _BurnMap_ST;     // 消融贴图的缩放和偏移参数

            struct v2f{
                V2F_SHADOW_CASTER;
                float2 uvBurnMap : TEXCOORD1;
            };

            v2f vert(appdata_base v){
                v2f o;

                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);             // 计算阴影投射必需的数据, 给V2F_SHADOW_CASTER数据赋值

                o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);  // 计算消融贴图的UV坐标

                return o;
            }

            fixed4 frag(v2f i):SV_Target{
                fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;     // 采样消融贴图

                clip(burn.r - _BurnAmount);                         // 关键点：根据消融值裁剪片元

                SHADOW_CASTER_FRAGMENT(i);                          // 输出阴影信息  使用V2F_SHADOW_CASTER数据
                
            }
            ENDCG
        }
    }
	FallBack "Diffuse"
}
/*
模型空间-（world矩阵）世界空间-（view矩阵）-观察空间坐标-（project矩阵）裁剪空间-透视除法执行后才将裁剪坐标系变换到标准化设备坐标系- 视口变换视口变换将标准化设备坐标系到屏幕坐标
*/