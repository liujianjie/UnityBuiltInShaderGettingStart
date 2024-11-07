Shader "Unity Shaders Book/Chapter 11/Billboard" {
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _Color("Color Tint", Color) = (1,1,1,1)
        _VerticalBillboarding("Vertical Restraints", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" "IgnoreProjector"="True" "DisableBatching"="True"}
        Pass{
            Tags{"LightMode" = "ForwardBase"}

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            fixed _VerticalBillboarding;

            struct a2v{
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
            struct v2f{
                float4 pos : SV_POSITION;
                float2 uv: TEXCOORD0;
            };
            
            v2f vert(a2v v)
            {
                v2f o;
                
                // 假设模型空间的中心点是固定的
                float3 center = float3(0, 0, 0);
                float3 viewer = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));      // 转换到模型空间的 观察者位置

                float3 normalDir = viewer - center;

                normalDir.y = normalDir.y * _VerticalBillboarding;
                normalDir = normalize(normalDir);

				float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
				float3 rightDir = normalize(cross(upDir, normalDir));           // float3写错成float
				upDir = normalize(cross(normalDir, rightDir));

                //
                float3 centerOffs = v.vertex.xyz - center;
                float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;

                o.pos = UnityObjectToClipPos(float4(localPos, 1));
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) :SV_Target{
                fixed4 c = tex2D(_MainTex, i.uv);
                c.rgb*=_Color.rgb;

                return c;
            }
            ENDCG
        }
    }
	FallBack "Transparent/VertexLit"
}

/*
一、
1.为什么要float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
2.为什么float3 centerOffs = v.vertex.xyz - center;
3.为什么float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;能够发生旋转

这是一个很好的问题。让我们逐一解释这三个点:

1. 为什么要 `float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);`

   这行代码是为了处理一个特殊情况。当 `normalDir` 几乎完全垂直（y分量接近1或-1）时，我们不能使用通常的 `float3(0, 1, 0)` 作为上方向，因为这会导致叉积计算出的右方向变为零向量。

   - 如果 `normalDir.y` 的绝对值大于0.999（非常接近1或-1），我们就把上方向设为 `float3(0, 0, 1)`（即z轴正方向）。
   - 否则，我们使用常规的上方向 `float3(0, 1, 0)`（即y轴正方向）。

   这样可以确保在所有情况下，我们都能得到一个有效的、与 `normalDir` 垂直的上方向。

2. 为什么 `float3 centerOffs = v.vertex.xyz - center;`

   这行代码计算了顶点相对于中心点的偏移量。在这个shader中，`center` 被设置为 `float3(0, 0, 0)`，即物体空间的原点。

   `centerOffs` 表示每个顶点相对于中心点的位置。这个偏移量稍后会被用来在新的坐标系中重建顶点位置。

3. 为什么 `float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;` 能够发生旋转

   这行代码实际上是在执行一个坐标系变换，从而实现了广告牌效果（billboard）。让我们详细解释：

   - `rightDir`、`upDir` 和 `normalDir` 构成了一个新的正交基（坐标系）。
   - `centerOffs.x`、`centerOffs.y` 和 `centerOffs.z` 是顶点在原始坐标系中相对于中心的坐标。
   - 这行代码将顶点的坐标从原始坐标系转换到新的坐标系中。

   结果是，整个平面（或者说广告牌）会旋转，使其始终面向摄像机。这就是广告牌效果的本质：无论从哪个角度看，平面都会旋转以面对观察者。

   旋转发生是因为新的坐标系（由 `rightDir`、`upDir` 和 `normalDir` 定义）是基于观察者位置动态计算的，而不是固定的世界空间坐标系。

这个shader的核心思想是通过动态计算一个面向摄像机的坐标系，然后将顶点转换到这个新的坐标系中，从而实现广告牌效果。这种技术常用于渲染总是面向摄像机的物体，如游戏中的2D树木、粒子效果等。


二、
normalDir.y = normalDir.y * _VerticalBillboarding;的作用

这是一个很好的问题。`normalDir.y = normalDir.y * _VerticalBillboarding;` 这行代码在广告牌shader中起着关键作用，它控制了垂直方向的广告牌效果。让我们详细解析一下：

1. `_VerticalBillboarding` 的作用：
   - 这是一个在 0 到 1 之间的属性值，用户可以在材质面板中调整。
   - 它控制广告牌在垂直方向上的行为。

2. 代码的效果：
   - 当 `_VerticalBillboarding = 1` 时：
     - `normalDir.y` 保持不变
     - 广告牌会完全面向摄像机，包括垂直方向
   
   - 当 `_VerticalBillboarding = 0` 时：
     - `normalDir.y` 变为 0
     - 广告牌只会在水平方向上旋转，垂直方向保持固定

   - 当 `_VerticalBillboarding` 在 0 和 1 之间时：
     - 会产生部分垂直广告牌效果

3. 为什么这样做：
   - 这提供了灵活性，允许在完全广告牌和垂直固定之间平滑过渡
   - 对于某些场景（如树木），可能希望它们在水平方向面向摄像机，但垂直方向保持固定

4. 工作原理：
   - 通过调整 `normalDir.y`，我们实际上在控制广告牌的"抬头"程度
   - 当 y 分量为 0 时，广告牌在垂直方向上不会旋转
   - 当 y 分量保持原值时，广告牌会完全面向摄像机

5. 在整体shader中的作用：
   - 这行代码影响了后续计算出的 `rightDir` 和 `upDir`
   - 最终，这会影响 `localPos` 的计算，从而决定顶点的最终位置

通过这种方式，shader 提供了一个简单但强大的机制来控制广告牌的行为，使其能够适应各种不同的场景需求。

为了更好地理解这个效果，我们可以通过可视化来展示不同 `_VerticalBillboarding` 值的效果。我会使用 DALL-E 生成一些图像来说明这个概念。


三、
我还是很想知道为什么_VerticalBillboarding = 0，会让广告牌只会在水平方向上旋转，垂直方向保持固定

您提出了一个非常好的问题，这确实需要更深入的解释。让我们一步步分析为什么当 `_VerticalBillboarding = 0` 时，广告牌只会在水平方向上旋转，而垂直方向保持固定。

1. 回顾关键代码：
   ```glsl
   float3 normalDir = viewer - center;
   normalDir.y = normalDir.y * _VerticalBillboarding;
   normalDir = normalize(normalDir);
   ```

2. 当 `_VerticalBillboarding = 0` 时：
   - `normalDir.y` 被设置为 0
   - 这意味着 `normalDir` 现在只有 x 和 z 分量

3. `normalDir` 的作用：
   - `normalDir` 代表从物体中心指向观察者的方向
   - 当 y 分量为 0 时，这个向量就被限制在了水平面内

4. 后续的坐标系构建：
   ```glsl
   float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
   float3 rightDir = normalize(cross(upDir, normalDir));
   upDir = normalize(cross(normalDir, rightDir));
   ```
   - 因为 `normalDir.y = 0`，`upDir` 总是 `float3(0, 1, 0)`
   - `rightDir` 是 `upDir` 和 `normalDir` 的叉积，所以总是在水平面内
   - 最后重新计算的 `upDir` 仍然保持垂直（因为它是水平向量的叉积）

5. 最终的顶点变换：
   ```glsl
   float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
   ```
   - `upDir` 始终指向世界空间的上方
   - `rightDir` 和 `normalDir` 在水平面内旋转
   - 这就导致了广告牌在水平方向上旋转，但垂直方向保持固定

6. 视觉效果：
   - 广告牌的顶部边缘始终保持水平
   - 但它会围绕其垂直轴旋转，始终面向摄像机的水平方向

为了更好地理解这个概念，让我为您生成一个视觉化的解释：
*/