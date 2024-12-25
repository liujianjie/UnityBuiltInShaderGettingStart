Shader "Unity Shaders Book/Chapter 15/Dissolve" {
    Properties
    {
        _BurnAmount("Burn Amount", Range(0.0, 1.0)) = 0.0   // 控制燃烧程度
        _LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1 // 控制燃烧边缘宽度
        _MainTex("Base(RGB)", 2D) = "white"{}                // 主纹理
        _BumpMap("Normal Map", 2D) = "bump"{}                // 法线贴图
        _BurnFirstColor("Burn First Color", Color) = (1, 0, 0, 1) // 燃烧的第一种颜色
        _BurnSecondColor("Burn Second Color", Color) = (1, 1, 0, 1) // 燃烧的第二种颜色
        _BurnMap("Burn Map", 2D) = "white"{}                 // 燃烧效果的贴图
    }
    SubShader
    {
        // 设置渲染类型和队列
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        

        Pass {
            Tags{"LightMode"="ForwardBase"}                 // 前向渲染路径的基础Pass

            Cull Off // 关闭背面剔除

            CGPROGRAM

            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
            #pragma multi_compile_fwdbase                   // 启用阴影等光照特性

            #pragma vertex vert
            #pragma fragment frag

            // 变量声明
            fixed _BurnAmount;
            fixed _LineWidth;
            sampler2D _MainTex;
            sampler2D _BumpMap;
            fixed4 _BurnFirstColor;
            fixed4 _BurnSecondColor;
            sampler2D _BurnMap;

            // 纹理的缩放和偏移参数
            float4 _MainTex_ST;
            float4 _BumpMap_ST;
            float4 _BurnMap_ST;

            // 顶点着色器输入结构
            struct a2v{
                float4 vertex : POSITION;   // 顶点位置
                float3 normal : NORMAL;     // 顶点法线
                float4 tangent : TANGENT;   // 切线
                float2 texcoord:TEXCOORD0;  // uv坐标
            };

            // 顶点着色器输出结构
            struct v2f{
                float4 pos : SV_POSITION;     // 裁剪空间的位置
                float2 uvMainTex : TEXCOORD0; // 主纹理的UV坐标
                float2 uvBumpMap : TEXCOORD1; // 法线贴图的UV坐标
                float2 uvBurnMap : TEXCOORD2; // 燃烧贴图的UV坐标
                float3 lightDir : TEXCOORD3;  // 切线空间下的光照方向
                float3 worldPos : TEXCOORD4;  // 世界空间位置
                SHADOW_COORDS(5)              // 阴影相关的坐标
            };

            // 顶点着色器
            v2f vert(a2v  v){ // appdata_tan是Unity内置的包含切线信息的顶点输入结构
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex); // 转换到裁剪空间

                o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex); // 计算主纹理的UV坐标
                o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap); // 计算法线贴图的UV坐标
                o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap); // 计算燃烧贴图的UV坐标

                // 计算切线空间的变换矩阵
                TANGENT_SPACE_ROTATION;
                // 将光照方向从世界空间转换到切线空间
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz; 
                
                // 计算阴影坐标
                TRANSFER_SHADOW(o); // 传递阴影信息
                return o;
            }
            // 片元
            float4 frag(v2f i) : SV_Target{
                float3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb; // 采样燃烧贴图

                // 根据燃烧值和阙值进行裁剪
                clip(burn.r - _BurnAmount); // 小于0被丢弃，采样的燃烧贴图灰白色靠近1，黑色靠近0，所以黑色先消失

                // 采样法线贴图并且解码法线
                float3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));

                // 计算漫反射光照
                fixed3 lightDir = normalize(i.lightDir);
                float3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, lightDir));
                
                // 计算边缘发光效果
                fixed burnLine = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);     // 被消失的像素（边缘）burnline是靠近1，远离消失的像素（边缘）burnline是靠近0.8
                fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, burnLine);       // 靠近被消失范围的圈是第二种颜色，远离的是第一种颜色
                burnColor = pow(burnColor, 5);

                // 计算阴影衰减
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // 最终颜色计算
                fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, burnLine); // 靠近被消失范围的圈是burnColor，远离的是正常环境光漫反射颜色
                return fixed4(finalColor, 1.0);
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