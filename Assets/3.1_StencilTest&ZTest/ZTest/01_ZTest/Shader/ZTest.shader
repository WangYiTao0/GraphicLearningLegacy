Shader "Wyt/ZTest"
{
    Properties
    {
        _MainTex("Texture",2D) = "white"{}
        _MainColor ("Color", Color) = (1,1,1,1)
        [Enum(Off, 0, On, 1)]
        _ZWrite("ZWrite", Float) = 1            // Off
        [Enum(UnityEngine.Rendering.CompareFunction)]
         _ZTestOperation("Z Test Operation", Float) = 4
    }
    SubShader
    {

        ZWrite[_ZWrite]
        ZTest[_ZTestOperation]

        pass
        {
            CGPROGRAM

            #include "UnityCG.cginc"
            
       
            #pragma vertex vert
			#pragma fragment frag

            struct v2fXray
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };
            sampler2D _MainTex;
            float4 _MainColor;
            float4 _MainTex_ST;
    
            v2fXray vert(appdata_full i)
            {
                v2fXray o;
                o.vertex = UnityObjectToClipPos(i.vertex);
                o.color = _MainColor;
                o.uv = TRANSFORM_TEX(i.texcoord,_MainTex);
                return o;
            }

            fixed4 frag(v2fXray i) : SV_Target
			{
                fixed4 color = _MainColor;
			    
				return color;
			}
            ENDCG
        }
        
    }
    FallBack "Diffuse"
}
