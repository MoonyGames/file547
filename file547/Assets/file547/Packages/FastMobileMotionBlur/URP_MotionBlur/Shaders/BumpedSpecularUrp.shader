Shader "SupGames/MotionUrp/BumpedSpecularUrp"
{
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white" {}
		_BumpTex("Normal Map", 2D) = "bump" {}
		_SpecColor("Specular Color", Color) = (1,1,1,1)
		_Glossiness("Glossiness", Range(0.01,100)) = 0.03
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
			TEXTURE2D(_BumpTex);
			SAMPLER(sampler_BumpTex);
			half4 _MainTex_ST;
			half4 _BumpTex_ST;
			half _Glossiness;
			half4 _SpecColor;
			half4 _Color;

			struct appdata
			{
				half4 pos : POSITION;
				half4 uv : TEXCOORD0;
				half3 normal : NORMAL;
				half4 tangent : TANGENT;
			};

			struct v2f
			{
				half4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
				half4 normal : TEXCOORD1;
				half4 tangent : TEXCOORD2;
				half4 bitangent : TEXCOORD3;
#if defined(LIGHTMAP_ON)
				half2 lightmapUV : TEXCOORD4;
#else
				half3 vertexSH : TEXCOORD4;
#endif
#if defined(_MAIN_LIGHT_SHADOWS)
				half4 shadowCoord : TEXCOORD5;
#endif
			};

			v2f vert(appdata i)
			{
				v2f o = (v2f)0;
				o.uv = TRANSFORM_TEX(i.uv, _MainTex);
				half3 viewDirection = _WorldSpaceCameraPos - mul(unity_ObjectToWorld, i.pos).xyz;
				half4 ws = mul(unity_ObjectToWorld, half4(i.pos.xyz, 1.0h));
				o.normal = half4(normalize(mul(half4(i.normal, 0.0h), unity_WorldToObject).xyz), viewDirection.x);
				o.tangent = half4(normalize(mul(unity_ObjectToWorld, half4(i.tangent.xyz, 0.0h)).xyz), viewDirection.y);
				o.bitangent = half4(cross(o.normal.xyz, o.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w, viewDirection.z);
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
				half4 encodedNormal = SAMPLE_TEXTURE2D(_BumpTex, sampler_BumpTex, _BumpTex_ST.xy * i.uv.xy + _BumpTex_ST.zw);
				half3 viewDirection = half3(i.normal.w, i.tangent.w, i.bitangent.w);
				half3 normalDirection = normalize(mul(UnpackNormal(encodedNormal), half3x3(i.tangent.xyz, i.bitangent.xyz, i.normal.xyz)));
				half3 bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, normalDirection);;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF) && defined(RECEIVE_SHADOWS)
				half3 realtimeShadow = lerp(bakedGI, max(bakedGI - _MainLightColor.rgb * saturate(dot(_MainLightPosition.xyz, normalDirection)) * (1.0 - MainLightRealtimeShadow(i.shadowCoord)), _SubtractiveShadowColor.xyz), _MainLightShadowData.x);
				bakedGI = min(bakedGI, realtimeShadow);
#endif
				half3 diffuseReflection = bakedGI + _MainLightColor.rgb * max(0.0h, dot(normalDirection, _MainLightPosition.xyz));
				half3 specularReflection = _SpecColor.rgb * _MainLightColor.rgb * pow(saturate(dot(normalDirection, normalize(_MainLightPosition.xyz + viewDirection))), _Glossiness);
				half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
				return half4(specularReflection * (1.0h - color.a) + diffuseReflection * color.rgb, 0.0h)*_Color;
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