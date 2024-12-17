// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Unity Shaders Book/Chapter 13/Fog With Depth Texture" {
    Properties
    {
        _MainTex("Base (RGB)", 2D) = "white" {}
        _FogDensity("Fog Density", Float)  = 1.0
        _FogColor("Fog Color", Color)  = (1, 1, 1,1)
        _FogStart("Fog Start", Float) = 0.0
        _FogEnd("Fog End", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"

        float4x4 _FrustumCornersRay;

        sampler2D _MainTex;
        half4 _MainTex_TexelSize;          
        sampler2D _CameraDepthTexture;
        half _FogDensity;
        fixed4 _FogColor;
        float _FogStart;
        float _FogEnd;

        struct v2f{
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
            float4 interpolatedRay : TEXCOORD2;
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

            // 屏幕后处理用的模型是一个四边形网格，所以只包含4个顶点。确定这4个顶点对应的下标-对应射线
            int index = 0;
            if(v.texcoord.x < 0.5 && v.texcoord.y < 0.5){
                index = 0;
            }else if(v.texcoord.x > 0.5 && v.texcoord.y < 0.5){
                index = 1;
            }else if(v.texcoord.x > 0.5 && v.texcoord.y > 0.5){
                index = 2;
            }else{
                index = 3;
            }
            #if UNITY_UV_STARTS_AT_TOP
            if(_MainTex_TexelSize.y < 0)
                index = 3-index;
            #endif

            o.interpolatedRay = _FrustumCornersRay[index];
            return o;
        }
        fixed4 frag(v2f i) :SV_Target{
            // 从深度纹理中采样深度值
            // 屏幕空间/视口空间（NDC）中的深度值。范围通常在[0,1]之间
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);

            // 得到视角空间下的线性深度值
            float linearDepth = LinearEyeDepth(d);
            // 该片段的世界位置 = 相机位置 + 线性深度值 * 插值射线
            float3 worldPos =_WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
            
            // 通过世界位置计算雾效
            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity);

            fixed4 finalColor = tex2D(_MainTex, i.uv);
            finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
           
            return finalColor;
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
模型空间-（world矩阵）世界空间-（view矩阵）-观察空间坐标-（project矩阵）裁剪空间-透视除法执行后才将裁剪坐标系变换到标准化设备坐标系- 视口变换视口变换将标准化设备坐标系到屏幕坐标
*/