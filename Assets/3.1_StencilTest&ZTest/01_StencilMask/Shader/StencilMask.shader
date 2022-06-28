Shader "Wyt/Stencil/StencilMask" 
{
	Properties{
 
		_ID("Mask ID", Int) = 1
	}
	
	SubShader
	{
		Tags
		{ 
			"RenderType" = "Opaque"
			"Queue" = "Geometry+1"  //default + 1
		}
		ColorMask 0 //RGBA RGB R,G,B,A,0
		ZWrite off	//  ZFail 防止	
		Stencil
		{
			Ref[_ID]
			Comp always //default always  いつも通過する
			Pass replace // default keep　そして値をキープする　
			//Fail keep
			//ZFail Keep
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
}