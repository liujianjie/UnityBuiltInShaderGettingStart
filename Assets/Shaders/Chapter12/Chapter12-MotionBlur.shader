// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Unity Shaders Book/Chapter 12/Motion Blur" {
    Properties
    {
        _MainTex("Base (RGB)", 2D) = "white" {}
        _BlurAmount("Blur Amount", Float)  = 1.0
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        float _BlurAmount;

        struct v2f{
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2f vert(appdata_img v){
            v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;
            return o;
        }
        fixed4 fragRGB(v2f i) :SV_Target{
            return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
        }

        half4 fragA(v2f i):SV_Target{
			return tex2D(_MainTex, i.uv);
		}

        ENDCG
            
        ZTest Always Cull Off ZWrite Off
        // 混合A 通道，但是a 不写入到渲染纹理中，所以有两个pass。第一个混合a，第二个采样第一个输出的结果
        Pass{
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragRGB

            ENDCG
        }

         Pass{
            Blend One Zero
            ColorMask A

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragA

            ENDCG
        }
    }
    FallBack Off
}

/*
 非常抱歉我之前的解释还不够清晰。您提出了一个很好的问题，让我们更深入地分析这个算法过程，特别是如何实现将不够亮的像素值最终变为小于0（实际上是0）。

让我们一步步分解这个过程：

1. 首先，我们有原始的像素颜色 c，假设它是一个 float4 类型，表示 RGBA 值。

2. 计算亮度：
   ```glsl
   float pixelLuminance = luminance(c);
   ```
   这里 luminance() 函数计算像素的亮度，通常使用公式：
   0.299 * R + 0.587 * G + 0.114 * B

3. 计算亮度差值：
   ```glsl
   float luminanceDifference = pixelLuminance - _LuminanceThreshold;
   ```
   这一步是关键。如果像素亮度低于阈值，luminanceDifference 将为负值。

4. 使用 clamp 函数：
   ```glsl
   float val = clamp(luminanceDifference, 0.0, 1.0);
   ```
   这里是算法实现"小于0"的关键步骤：
   - 如果 luminanceDifference 小于 0（即像素不够亮），clamp 函数会将其设置为 0
   - 如果 luminanceDifference 在 0 到 1 之间，保持原值
   - 如果 luminanceDifference 大于 1，设置为 1

5. 最后的乘法操作：
   ```glsl
   fixed4 result = c * val;
   ```
   这一步确保了不够亮的像素最终变为黑色（0,0,0,0）：
   - 对于不够亮的像素，val 为 0，所以 c * 0 = (0,0,0,0)
   - 对于足够亮的像素，val 大于 0，颜色会被保留或略微变暗

算法过程示例：

假设我们有一个像素，其 RGB 值为 (0.2, 0.2, 0.2)，而 _LuminanceThreshold 设置为 0.5：

1. 计算亮度：
   luminance = 0.299 * 0.2 + 0.587 * 0.2 + 0.114 * 0.2 ≈ 0.2

2. 计算亮度差值：
   luminanceDifference = 0.2 - 0.5 = -0.3

3. 应用 clamp 函数：
   val = clamp(-0.3, 0.0, 1.0) = 0.0

4. 最终乘法：
   result = (0.2, 0.2, 0.2, 1.0) * 0.0 = (0, 0, 0, 0)

这个过程展示了如何将一个不够亮的像素（亮度为0.2，小于阈值0.5）最终变为黑色（0,0,0,0）。

关键点在于 clamp 函数将负值转换为0，然后乘法操作将这个0传播到所有颜色通道，实现了将不够亮的像素置为黑色的目的。
 
 */