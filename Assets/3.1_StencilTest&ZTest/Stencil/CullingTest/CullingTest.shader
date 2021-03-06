Shader "Wyt/CullingTest"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		[Enum(UnityEngine.Rendering.CullMode)] _Mode("CullMode",Int) = 1
	}
	SubShader
	{
		Cull[_Mode]
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag		
 
			#include "UnityCG.cginc"
 
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};
 
			struct v2fXray
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};
 
			sampler2D _MainTex;
			float4 _MainTex_ST;
 
			v2fXray vert(appdata v)
			{
				v2fXray o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
 
			fixed4 frag(v2fXray i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				return col;
			}
			ENDCG
		}
	}
}