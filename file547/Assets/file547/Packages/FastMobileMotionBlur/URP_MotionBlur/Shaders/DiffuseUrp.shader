Shader "SupGames/MotionUrp/DiffuseUrp"
{
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white" {}
		[Toggle(RECEIVE_SHADOWS)]
		_ReceiveShadows("Recieve Shadows", Float) = 0
	}
	SubShader
	{
		Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
		LOD 150

		Pass {
			Tags { "LightMode" = "universalForward" }
			HLSLPROGRAM
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma shader_feature RECEIVE_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_instancing

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			half4 _MainTex_ST;
			half4 _Color;

			struct appdata
			{
				half4 pos : POSITION;
				half4 uv : TEXCOORD0;
				half3 normal : NORMAL;
			};

			struct v2f
			{
				half4 pos : SV_POSITION;
				half4 uv : TEXCOORD0;
				half4 diff : TEXCOORD1;
#if defined(LIGHTMAP_ON)
				half2 lightmapUV : TEXCOORD2;
#else
				half3 vertexSH : TEXCOORD2;
#endif
#if defined(_MAIN_LIGHT_SHADOWS)
				half4 shadowCoord : TEXCOORD3;
#endif
			};

			v2f vert(appdata i)
			{
				v2f o = (v2f)0;
				half3 ndir = normalize(mul(half4(i.normal, 0.0h), unity_WorldToObject).xyz);
				o.uv.xy = TRANSFORM_TEX(i.uv, _MainTex);
				o.uv.zw = ndir.xy;
				o.diff.xyz = _MainLightColor.rgb * max(0.0h, dot(ndir, _MainLightPosition.xyz));
				o.diff.w = ndir.z;
				half4 ws = mul(unity_ObjectToWorld, half4(i.pos.xyz, 1.0h));
				o.pos = mul(unity_MatrixVP, ws);
#if defined(_MAIN_LIGHT_SHADOWS)
				o.shadowCoord = TransformWorldToShadowCoord(ws.xyz);
#endif
#if defined(LIGHTMAP_ON)
				o.lightmapUV = i.uv.zw * unity_LightmapST.xy + unity_LightmapST.zw;
#else
				o.vertexSH = SampleSHVertex(i.normal);
#endif
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				half3 normal = half3(i.uv.zw,i.diff.w);
				half3 bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, normal);
#if defined(_MAIN_LIGHT_SHADOWS) && defined(RECEIVE_SHADOWS)
				half3 realtimeShadow = lerp(bakedGI, max(bakedGI - i.diff * (1.0h - MainLightRealtimeShadow(i.shadowCoord)), _SubtractiveShadowColor.xyz), _MainLightShadowData.x);
				bakedGI = min(bakedGI, realtimeShadow);
#endif
				bakedGI += i.diff.xyz;
				return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).rgb * bakedGI, 0.0h)*_Color;
			}
			ENDHLSL
		}
		Pass
		{
			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual
			Cull[_Cull]

			HLSLPROGRAM
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _GLOSSINESS_FROM_BASE_ALPHA
			#pragma multi_compile_instancing
			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

			half3 _LightDirection;

			struct Attributes
			{
				float4 positionOS   : POSITION;
				float3 normalOS     : NORMAL;
				float2 texcoord     : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS   : SV_POSITION;
			};

			float4 GetShadowPositionHClip(Attributes input)
			{
				float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
				float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

			#if UNITY_REVERSED_Z
				positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
			#else
				positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
			#endif

				return positionCS;
			}

			Varyings ShadowPassVertex(Attributes input)
			{
				Varyings output;
				output.positionCS = GetShadowPositionHClip(input);
				return output;
			}

			half4 ShadowPassFragment(Varyings input) : SV_TARGET
			{
				return 0;
			}

			ENDHLSL
		}

	}
}