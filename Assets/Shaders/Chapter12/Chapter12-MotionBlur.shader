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
            ColorMask RGB       // 只写入RGB通道

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragRGB

            ENDCG
        }

         Pass{
            Blend One Zero
            ColorMask A  // 只写入Alpha通道

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragA

            ENDCG
        }
    }
    FallBack Off
}
/*
让我详细解释这个运动模糊shader中两个Pass的作用和原理。

这个运动模糊效果是通过帧间混合实现的，两个Pass的设计非常巧妙：

### Pass 1 - RGB混合Pass
```glsl
Pass {
    Blend SrcAlpha OneMinusSrcAlpha  // 关键混合模式
    ColorMask RGB                     // 只写入RGB通道
    ...
    fragment fragRGB                  // 使用fragRGB片元着色器
}
```
第一个Pass的作用：
1. `Blend SrcAlpha OneMinusSrcAlpha` 设置混合模式为标准透明混合
2. `ColorMask RGB` 表示只写入RGB颜色通道，不写入Alpha通道
3. `fragRGB`返回的是：当前帧的RGB颜色和模糊系数(_BlurAmount)作为Alpha值
4. 这个Pass实现了当前帧和之前帧的颜色混合，混合比例由_BlurAmount控制

### Pass 2 - Alpha通道Pass
```glsl
Pass {
    Blend One Zero        // 直接覆盖
    ColorMask A           // 只写入Alpha通道
    ...
    fragment fragA        // 使用fragA片元着色器
}
```
第二个Pass的作用：
1. `ColorMask A` 表示只写入Alpha通道
2. `Blend One Zero` 表示直接覆盖原值，不进行混合
3. `fragA`直接返回原始纹理的采样结果
4. 这个Pass确保Alpha通道保持正确的值，不受混合影响

### 为什么需要两个Pass？

关键原因：
1. **分离处理**：需要分别处理RGB和A通道，因为它们的处理逻辑不同
   - RGB通道需要和上一帧混合，实现模糊效果
   - Alpha通道需要保持原值，不参与混合

2. **避免Alpha累积**：
   - 如果在一个Pass中同时处理RGB和A，Alpha值会随着帧的累积而改变
   - 错误的Alpha累积会导致图像逐渐变得过于透明或不透明

3. **正确的混合次序**：
   - 第一个Pass进行RGB的混合，使用_BlurAmount作为混合因子
   - 第二个Pass恢复正确的Alpha值，确保下一帧混合时有正确的透明度信息

### 工作流程示意：
```
原始图像 ---> Pass 1 (RGB混合) ---> Pass 2 (Alpha恢复) ---> 输出结果
                ↑                                           |
                |                                          |
                +------------------------------------------+
                        (用于下一帧的混合)
```

这种设计确保了运动模糊效果的正确实现，同时保持了适当的Alpha通道值，是一个非常精妙的shader设计。如果只用一个Pass，要么会导致错误的Alpha累积，要么无法正确实现运动模糊效果。
*/