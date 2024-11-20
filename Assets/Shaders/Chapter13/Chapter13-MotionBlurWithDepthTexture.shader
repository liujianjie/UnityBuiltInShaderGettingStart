// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Unity Shaders Book/Chapter 13/Motion Blur With Depth Texture" {
    Properties
    {
        _MainTex("Base (RGB)", 2D) = "white" {}
        _BlurSize("Blur Size", Float)  = 1.0
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"
        /*
         // _MainTex_TexelSize 是一个非常有用的内置变量,它提供了关于主纹理(_MainTex)的像素(texel)大小信息。这是一个float4类型的变量,其组成如下:
             x 分量: 1.0 / 纹理宽度
            y 分量: 1.0 / 纹理高度
            z 分量: 纹理宽度
            w 分量: 纹理高度
            例如,如果你的_MainTex纹理大小是512x512,那么_MainTex_TexelSize的值将会是(1/512, 1/512, 512, 512)。
        */
        /*
        为什么要 o.uv_depth.y = 1 - o.uv_depth.y:
        这行代码是为了处理不同图形API中纹理坐标系的差异。在Unity中,当使用DirectX等某些图形API时,纹理的UV坐标原点在左上角,而在OpenGL中,原点在左下角。

        UNITY_UV_STARTS_AT_TOP 宏用于检测当前使用的是哪种坐标系。如果是DirectX类型的坐标系(UV从顶部开始),我们需要翻转Y坐标以确保正确的采样。

        _MainTex_TexelSize.y < 0 这个条件检查进一步确认是否需要进行Y坐标翻转。当纹理被翻转时(在某些平台上会发生),_MainTex_TexelSize.y会是负值。

        通过执行 1 - o.uv_depth.y,我们实际上是垂直翻转了深度纹理的采样坐标,以确保在所有平台上都能正确采样深度纹理。
        */
        sampler2D _MainTex;
        half4 _MainTex_TexelSize;          
        sampler2D _CameraDepthTexture;
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;
        half _BlurSize;

        struct v2f{
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
        };

        v2f vert(appdata_img v){
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;
            o.uv_depth = v.texcoord;
            
            #if UNITY_UV_STARTS_AT_TOP
                if(_MainTex_TexelSize.y < 0){
                    o.uv_depth.y = 1 - o.uv_depth.y;
                }
            #endif
            return o;
        }
        fixed4 frag(v2f i) :SV_Target{
            // 从深度纹理中采样深度值
            // 屏幕空间/视口空间（NDC）中的深度值。范围通常在[0,1]之间
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);

            // H 是在齐次裁剪空间中的坐标,范围为 -1 到 1
            // 在齐次裁剪空间中的坐标，这个空间是一个标准化的立方体，x、y、z 分量都在 [-1, 1] 范围内。
            float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2- 1, d * 2-1, 1);       // d深度缓冲中存储的值通常在 [0, 1] 范围内。其中，0 表示最近的平面（近裁剪平面），1 表示最远的平面（远裁剪平面）,需要映射回-1,1

            // 通过View-Projection逆矩阵，将齐次坐标变化到世界坐标，这里有一个关键点：结果仍然是齐次坐标。
            float4 D = mul(_CurrentViewProjectionInverseMatrix, H);

             // 除以W，执行了透视除法，将齐次坐标转换为真正的世界空间坐标。
            float4 worldPos = D / D.w; 

            // 保存当前视口位置用于后续计算
            float4 currentPos = H;

            // 使用前一帧的视图投影矩阵将世界坐标转换到世界坐标。这里有一个关键点：结果仍然是齐次坐标。
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);

            // 除以W，执行了透视除法，将齐次坐标转换为真正的世界空间坐标。
			previousPos /= previousPos.w;

            // 通过当前和上一帧的位置得到速率
            float2 velocity = (currentPos.xy - previousPos.xy) / 2.0f;

            float2 uv = i.uv;

            float4 c = tex2D(_MainTex, uv);
            uv += velocity *_BlurSize;
            for(int it = 1; it < 3; it++, uv += velocity * _BlurSize){
                float4 currentColor = tex2D(_MainTex, uv);      // 偏移uv 来采样颜色来模糊效果
                c += currentColor;
            }
            c /= 3;

            return fixed4(c.rgb, 1.0);
        }

        ENDCG

         Pass{
			ZTest Always Cull Off ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDCG
        }
    }
    FallBack Off
}
/*
模型空间-（world矩阵）世界空间-（view矩阵）-观察空间坐标-（project矩阵）裁剪空间-
*/