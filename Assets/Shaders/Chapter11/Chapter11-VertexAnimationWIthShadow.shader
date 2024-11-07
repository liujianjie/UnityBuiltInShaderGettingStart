Shader "Unity Shaders Book/Chapter 11/Vertex Animation With Shadow" {
    Properties
    {
        _MainTex("Main Tex", 2D) = "white" {}
        _Color("Color Tint", Color) = (1,1,1,1)
        _Magnitude("Distortion Magnitude", Float) = 1
        _Frequency("Distortion Frequency", Float) = 1
        _InvWaveLength("Distortion Inverse Wave Length", Float) = 10
        _Speed("Speed", Float) = 0.5
    }
    SubShader
    {
        // 因为顶点动画，需要禁用顶点动画
        Tags {  "DisableBatching"="True"}

        Pass{
            Tags{"LightMode" = "ForwardBase"}

            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float _Magnitude;
            float _Frequency;
            float _InvWaveLength;
            float _Speed;

            struct a2v{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};
            struct v2f{
                float4 pos : SV_POSITION;
                float2 uv: TEXCOORD0;
            };
            
            v2f vert(a2v v)
            {
                v2f o;

                float4 offset;
                offset.yzw = float3(0.0, 0.0, 0.0);
                // _Frequency * _Time.y控制正弦函数的频率，后续是为了不同的位置具有不同的位移 _Magnitude控制波动幅度
                offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
                o.pos = UnityObjectToClipPos(v.vertex + offset);

                o.uv = TRANSFORM_TEX(v.texcoord,  _MainTex);
                // 通过时间控制uv的偏移，实现水面波动效果
                o.uv += float2(0.0, _Time.y * _Speed);
                return o;
            }

            fixed4 frag(v2f i) :SV_Target{
                fixed4 c = tex2D(_MainTex, i.uv);
                c.rgb*=_Color.rgb;

                return c;
            }
            ENDCG
        }
        // 自定义投影Pass生成
        Pass{
            Tags{"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"

            float _Magnitude;
            float _Frequency;
            float _InvWaveLength;
            float _Speed;

            struct v2f{
                V2F_SHADOW_CASTER;
			};

            v2f vert(appdata_base v)
            {
                v2f o;

                float4 offset;
                offset.yzw = float3(0.0, 0.0, 0.0);
                // _Frequency * _Time.y控制正弦函数的频率，后续是为了不同的位置具有不同的位移 _Magnitude控制波动幅度
                offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
                // o.pos = UnityObjectToClipPos(v.vertex + offset);
                v.vertex = v.vertex + offset;

                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);

                return o;
            }

            fixed4 frag(v2f i) :SV_Target{
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
	FallBack "VertexLit"
}
