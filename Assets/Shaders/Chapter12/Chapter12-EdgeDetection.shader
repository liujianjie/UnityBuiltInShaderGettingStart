
Shader "Unity Shaders Book/Chapter 12/Edge Detection" {
    Properties
    {
        _MainTex("Base (RGB)", 2D) = "white" {}
        _EdgeOnly("Edge Only", Float) = 1
        _EdgeColor("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor("Background Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Pass{
            
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            uniform half4 _MainTex_TexelSize;
            fixed _EdgeOnly;
            fixed4 _EdgeColor;
            fixed4 _BackgroundColor;

            struct v2f{
                float4 pos : SV_POSITION;
                half2 uv[9]: TEXCOORD0;
            };
            
            v2f vert(appdata_img v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                half2 uv = v.texcoord;

                o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
                o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
                o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
                o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
                o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
                o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
                o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
                o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
                o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);

                return o;
            }
            fixed luminance(fixed4 color){
                return 0.2135 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }
            half Sobel(v2f i){
                const half Gx[9] = {-1, 0, 1,
                                    -2, 0, 2,
                                    -1, 0, 1};
                const half Gy[9] = {-1, -2, -1,
                                    0, 0, 0,
                                    1, 2, 1};

                 half texColor;
                 half edgeX= 0;
                 half edgeY = 0;
                 for(int it = 0; it < 9; it++){
                     texColor = luminance(tex2D(_MainTex, i.uv[it]));
                     edgeX += texColor * Gx[it];
                     edgeY += texColor * Gy[it];
                 }

                 half edge = 1-abs(edgeX) - abs(edgeY);
                 return edge;
            }

            fixed4 frag(v2f i) :SV_Target{
                half edge = Sobel(i);

                fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);
                fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);

                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }
            ENDCG
        }
    }
    FallBack Off
}

/*
让我详细解释一下 `_MainTex_TexelSize` 这个变量的含义和用途。

`_MainTex_TexelSize` 是Unity内置的一个非常有用的变量，它包含了主纹理的像素相关信息。这是一个四维向量(half4/float4)，其中包含的信息如下：

```
_MainTex_TexelSize = (1/width, 1/height, width, height)
```

具体解释：
1. x分量 = 1/纹理宽度（texel的宽度）
2. y分量 = 1/纹理高度（texel的高度）
3. z分量 = 纹理宽度（像素单位）
4. w分量 = 纹理高度（像素单位）

### 实际应用示例：

1. **采样相邻像素**
```hlsl
fixed4 frag(v2f i) : SV_Target
{
    // 获取相邻像素的UV坐标
    float2 uv_up = i.uv + float2(0, _MainTex_TexelSize.y);    // 上方像素
    float2 uv_down = i.uv + float2(0, -_MainTex_TexelSize.y); // 下方像素
    float2 uv_right = i.uv + float2(_MainTex_TexelSize.x, 0); // 右方像素
    float2 uv_left = i.uv + float2(-_MainTex_TexelSize.x, 0); // 左方像素
    
    // 采样这些位置的颜色
    fixed4 color_up = tex2D(_MainTex, uv_up);
    fixed4 color_down = tex2D(_MainTex, uv_down);
    fixed4 color_right = tex2D(_MainTex, uv_right);
    fixed4 color_left = tex2D(_MainTex, uv_left);
}
```

2. **实现模糊效果**
```hlsl
fixed4 frag(v2f i) : SV_Target
{
    float2 texelSize = _MainTex_TexelSize.xy;
    fixed4 color = tex2D(_MainTex, i.uv) * 0.4;
    
    // 简单的5点模糊
    color += tex2D(_MainTex, i.uv + texelSize * float2(1, 0)) * 0.15;
    color += tex2D(_MainTex, i.uv + texelSize * float2(-1, 0)) * 0.15;
    color += tex2D(_MainTex, i.uv + texelSize * float2(0, 1)) * 0.15;
    color += tex2D(_MainTex, i.uv + texelSize * float2(0, -1)) * 0.15;
    
    return color;
}
```

### 使用场景：

1. **图像处理效果**：如模糊、锐化、边缘检测等
2. **后处理效果**：需要访问相邻像素时
3. **UV坐标计算**：需要精确的像素级操作时

### 注意事项：

1. `uniform` 关键字表示这是一个全局变量，Unity会自动设置其值
2. `half4` 是精度较低的浮点数类型，在移动平台上性能更好
3. 这个变量会随着纹理的分辨率变化而自动更新

这个变量在编写自定义shader时非常有用，特别是在需要进行像素级操作或者需要知道纹理分辨率的情况下。
*/
