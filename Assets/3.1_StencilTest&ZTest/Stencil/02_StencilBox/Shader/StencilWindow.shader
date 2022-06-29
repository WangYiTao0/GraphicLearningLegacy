Shader "Wyt/Stencil/StencilWindow"
 {
	Properties
	{
			_Color ("Color", Color) = (1,1,1,1)
			_StencilRef("Stencil Ref",float) = 1
			[Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Int) = 8
			[Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Int) = 2
	}
	SubShader
	{
		Tags 
		{
			"RenderType" = "Opaque"
			"Queue" = "Geometry+1"
		}
		ColorMask 0
		ZWrite off
		
		Stencil
		{
			Ref[_StencilRef]
			Comp[SComp]
			Pass[_SOp]
		}
		
		Pass
		{
			CGINCLUDE
			#include "UnityCG.cginc"
			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 pos : SV_POSITION;
			};
 
 
			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				return o;
			}
			half4 frag(v2f i) : SV_Target
			{
	 
				return half4(1,1,1,1);
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}