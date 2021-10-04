Shader "SupGames/Mobile/MobileMotionBlurUrp"
{
	Properties
	{
		[HideInInspector]_MainTex("Base (RGB)", 2D) = "white" {}
	}
	HLSLINCLUDE

	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#if defined(TEN) 
#define MULTIPLAYER 0.1h
#elif defined(EIGHT)
#define MULTIPLAYER 0.125h
#else
#define MULTIPLAYER 0.16666667h
#endif

	TEXTURE2D_X(_MainTex);
	SAMPLER(sampler_MainTex);
	TEXTURE2D_X(_BlurTex);
	SAMPLER(sampler_BlurTex);
	TEXTURE2D_X(_MaskTex);
	SAMPLER(sampler_MaskTex);

	half _Distance;
	half4x4 _CurrentToPreviousViewProjectionMatrix;

	struct AttributesDefault
	{
		half4 vertex : POSITION;
		half2 uv : TEXCOORD0;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f
	{
		half4 pos : SV_POSITION;
		half2 uv : TEXCOORD0;
		UNITY_VERTEX_OUTPUT_STEREO
	};

	struct v2fb
	{
		half4 pos : SV_POSITION;
		half4 uv : TEXCOORD0;
		half4 uv1 : TEXCOORD1;
		half4 uv2 : TEXCOORD2;
#if defined(EIGHT)
		half4 uv3 : TEXCOORD3;
#endif
#if defined(TEN)
		half4 uv4 : TEXCOORD4;
#endif
		UNITY_VERTEX_OUTPUT_STEREO
	};

	v2f vert(AttributesDefault v)
	{
		v2f o = (v2f)0;
		UNITY_SETUP_INSTANCE_ID(i);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, half4(v.vertex.xyz, 1.0h)));
		o.uv = v.uv;
		return o;
	}

	v2fb vertBlur(AttributesDefault v)
	{
		v2fb o = (v2fb)0;
		UNITY_SETUP_INSTANCE_ID(i);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, half4(v.vertex.xyz, 1.0h)));
		half4 projPos = half4(v.uv * 2.0h - 1.0h, _Distance, 1.0h);
		half4 previous = mul(_CurrentToPreviousViewProjectionMatrix, projPos);
		previous /= previous.w;
		half2 vel = (previous.xy - projPos.xy)*MULTIPLAYER*0.5h;
		o.uv.xy = v.uv;
		o.uv.zw = vel;
		o.uv1.xy = vel * 2.0h;
		o.uv1.zw = vel * 3.0h;
		o.uv2.xy = vel * 4.0h;
		o.uv2.zw = vel * 5.0h;
#if defined(EIGHT)
		o.uv3.xy = vel * 6.0h;
		o.uv3.zw = vel * 7.0h;
#endif
#if defined(TEN)
		o.uv4.xy = vel * 8.0h;
		o.uv4.zw = vel * 9.0h;
#endif
		return o;
	}

	half4 fragBlur(v2fb i) : COLOR
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
		half2 uv = UnityStereoTransformScreenSpaceTex(i.uv.xy);
		half4 result = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
		half col1A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv.zw).a;
		half col2A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv1.xy).a;
		half col3A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv1.zw).a;
		half col4A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv2.xy).a;
		half col5A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv2.zw).a;
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv.zw * col1A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv1.xy * col2A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv1.zw * col3A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv2.xy * col4A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv2.zw * col5A);
#if defined(EIGHT)
		half col6A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv3.xy).a;
		half col7A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv3.zw).a;
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv3.xy * col6A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv3.zw * col7A);
#endif
#if defined(TEN)
		half col8A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv4.xy).a;
		half col9A = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv4.zw).a;
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv4.xy * col8A);
		result += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + i.uv4.zw * col9A);
#endif
		return result * MULTIPLAYER;
	}

	half4 frag(v2f i) : COLOR
	{
		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
		half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(i.uv));
		half4 b = SAMPLE_TEXTURE2D(_BlurTex, sampler_BlurTex, UnityStereoTransformScreenSpaceTex(i.uv));
		return lerp(c, b, b.a);
	}
		
	ENDHLSL
	
	Subshader
	{
		Pass //0
		{
		  ZTest Always Cull Off ZWrite Off
		  Fog { Mode off }
		  HLSLPROGRAM
		  #pragma shader_feature EIGHT
		  #pragma shader_feature TEN
		  #pragma vertex vertBlur
		  #pragma fragment fragBlur
		  #pragma fragmentoption ARB_precision_hint_fastest
		  ENDHLSL
		}

		Pass //1
		{
		  ZTest Always Cull Off ZWrite Off
		  Fog { Mode off }
		  HLSLPROGRAM
		  #pragma vertex vert
		  #pragma fragment frag
		  #pragma fragmentoption ARB_precision_hint_fastest
		  ENDHLSL
		}

	}
}
