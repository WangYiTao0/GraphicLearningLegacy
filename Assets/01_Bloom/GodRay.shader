Shader "Wyt/Unlit/GodRay"
{
    Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_BlurTex("Blur", 2D) = "white"{}
//		_ColorThreshold("_ColorThreshold",Vector) = (0,0,0,0)
//		_ViewPortLightPos("_ViewPortLightPos",Vector) = (0,0,0,0)
//		_LightRadius("_LightRadius",Float) = 0
//		_RadialSampleCount("_RadialSampleCount",Int) = 6
//		_Offsets("_Offsets",Vector) = (0,0,0,0)
//		_LightColor("_LightColor",Color) = (0,0,0,0)
//		_LightPower("_LightPower",Float) = 1
//		_LightPowFactor("_LightPowFactor",Float) = 1
	}
 
	CGINCLUDE

	#include "UnityCG.cginc"
	

	struct v2fExtractBright
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};
 

	struct v2fRadialBlur
	{
		float4 pos : SV_POSITION;
		float2 uv  : TEXCOORD0;
		float2 blurOffset : TEXCOORD1;
	};
 

	struct v2fGodRay
	{
		float4 pos : SV_POSITION;
		float2 uv1  : TEXCOORD0;
		float2 uv2 : TEXCOORD1;
	};


	sampler2D _MainTex;
	float4 _MainTex_TexelSize;
	sampler2D _BlurTex;
	//float4 _BlurTex_TexelSize;
	float4 _ViewPortLightPos;

	int _RadialSampleCount = 6;
	float4 _Offsets;
	float4 _ColorThreshold; 
	float4 _LightColor; 
	float _LightPower; 
	float _LightPowFactor; 
	float _LightRadius; 
	
	v2fExtractBright vertExtractBright(appdata_img v)
	{
		v2fExtractBright o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.texcoord.xy;

		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			o.uv.y = 1 - o.uv.y;
		#endif	
		return o;
	}
 

	fixed4 fragExtractBright(v2fExtractBright i) : SV_Target
	{
		fixed4 color = tex2D(_MainTex, i.uv);
		//view Pos
		float distFromLight = length(_ViewPortLightPos.xy - i.uv);
		float distanceControl = saturate(_LightRadius - distFromLight);

		// if color >_ColorThreshold
		float4 thresholdColor = saturate(color - _ColorThreshold) * distanceControl;
		float luminanceColor = Luminance(thresholdColor.rgb);
		luminanceColor = pow(luminanceColor, _LightPowFactor);
		return fixed4(luminanceColor, luminanceColor, luminanceColor, 1);
	}
 

	v2fRadialBlur vertRadialBlur(appdata_img v)
	{
		v2fRadialBlur o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.texcoord.xy;

		//Light方向　offset
		o.blurOffset = _Offsets * (_ViewPortLightPos.xy - o.uv);

		return o;
	}
 

	fixed4 fragRadialBlur(v2fRadialBlur i) : SV_Target
	{
		half4 color = half4(0,0,0,0);
		//iterator 
		for(int j = 0; j < _RadialSampleCount; j++)   
		{	
			color += tex2D(_MainTex, i.uv.xy);
			i.uv.xy += i.blurOffset; 	
		}
		//
		return color / _RadialSampleCount;
	}
 

	v2fGodRay vertGodRay(appdata_img v)
	{
		v2fGodRay o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv1.xy = v.texcoord.xy;
		o.uv2.xy = o.uv1.xy;
		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			o.uv1.y = 1 - o.uv1.y;
		#endif	
		return o;
	}


	fixed4 fragGodRay(v2fGodRay i) : SV_Target
	{
		fixed4 ori = tex2D(_MainTex, i.uv1);
		fixed4 blur = tex2D(_BlurTex, i.uv2);
		return ori + _LightPower * blur * _LightColor;
	}
 
	ENDCG
 
	SubShader
	{
		ZTest Always Cull Off ZWrite Off

		// ExtractBright
		Pass
		{
			CGPROGRAM
			#pragma vertex vertExtractBright
			#pragma fragment fragExtractBright
			ENDCG
		}
 
		// RadialBlur
		Pass
		{
			CGPROGRAM
			#pragma vertex vertRadialBlur
			#pragma fragment fragRadialBlur
			ENDCG
		}
 
		// blend
		Pass
		{
			CGPROGRAM
			#pragma vertex vertGodRay
			#pragma fragment fragGodRay
			ENDCG
		}
	}
}
