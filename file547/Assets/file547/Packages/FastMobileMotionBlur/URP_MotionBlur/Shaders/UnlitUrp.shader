Shader "SupGames/MotionUrp/UnlitUrp"
{
	Properties{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white" {}
	}
		SubShader
	{
		Tags {"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
		LOD 100

		Pass {
			HLSLPROGRAM
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			half4 _MainTex_ST;
			half4 _Color;

			struct appdata
			{
				half4 pos : POSITION;
				half2 uv : TEXCOORD0;
			};

			struct v2f
			{
				half4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
			};

			v2f vert(appdata i)
			{
				v2f o = (v2f)0;
				o.uv.xy = TRANSFORM_TEX(i.uv, _MainTex);
				o.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, half4(i.pos.xyz, 1.0h)));
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				return half4(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy).rgb , 0.0h)*_Color;
			}
			ENDHLSL
		}
	}
}