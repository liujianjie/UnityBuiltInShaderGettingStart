
Shader "Unity Shaders Book/Chapter 9/Shadow" {
    Properties
    {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque"}
        
        // 处理平行光、 环境光、高光 逐顶点光照 SH光照。 但是这里有区域光
        Pass{
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
			#include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct v2f{
                float4 pos : SV_POSITION;			// 声明了阴影信息的宏（会使用上下文变量来进行相关计算），这个pos名称得固定，不能是pos2什么的 。
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
				SHADOW_COORDS(2)				// 用于对阴影纹理采样的坐标，2是可用的插值寄存器的索引值
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);     // 顶点位置

                o.worldNormal = UnityObjectToWorldNormal(v.normal); // 世界空间法线

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;    // 世界空间位置

				// 计算阴影纹理坐标
				TRANSFER_SHADOW(o);
                return o;
            }
            fixed4 frag(v2f i) : SV_TARGET{
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz); // 直接使用前向渲染的内置变量得到光的方向
                
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;// 直接使用前向渲染的内置变量得到环境光

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                fixed3 halfDir = normalize(worldLightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                fixed atten = 1.0;

				//fixed shadow = SHADOW_ATTENUATION(i);	// 从阴影纹理中获取阴影值
				fixed shadow = 1.0;
                return fixed4(ambient + (diffuse + specular) * atten * shadow, 1.0);
            }
            ENDCG
        }
        // 处理影响该物体的逐像素光源：点光源、聚光灯、区域光（但是这里没有区域光）
        Pass{
			Tags{"LightMode"="ForwardAdd"}

			Blend One One

			CGPROGRAM
			
			// Apparently need to add this declaration 
			// #pragma multi_compile_fwdbase	
			#pragma multi_compile_fwdadd		// 这个写错fwdbase不行。
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				#else
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif

			 	fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

			 	fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
			 	fixed3 halfDir = normalize(worldLightDir + viewDir);
			 	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

				#ifdef USING_DIRECTIONAL_LIGHT
					fixed atten = 1.0;
				#else
					#if defined (POINT)
						// 将世界坐标转换为光源空间坐标
						float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
						// 使用纹理作为查找表
						fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#elif defined (SPOT)
						float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
						fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * 
									tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#else
						fixed atten = 1.0;
					#endif
				#endif

				return fixed4((diffuse + specular) * atten, 1.0);
			}
			ENDCG
        }
    }
	FallBack "Specular"
}
