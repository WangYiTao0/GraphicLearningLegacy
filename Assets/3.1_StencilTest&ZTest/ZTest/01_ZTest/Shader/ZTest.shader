Shader "Wyt/ZTest"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
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
            
            fixed4 _Color;
            #pragma vertex vert
			#pragma fragment frag

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
            };
            
            v2f vert(appdata_base i)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(i.vertex);
                o.color = _Color;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
			{
				return i.color;
			}
            ENDCG
        }
        
    }
    FallBack "Diffuse"
}
