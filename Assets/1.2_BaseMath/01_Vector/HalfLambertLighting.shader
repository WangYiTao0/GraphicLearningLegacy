Shader "Wyt/HalfLambertLighting" {
	Properties {
		_Diffuse (" Diffuse", Color) = (1,1,1,1)

	}
	SubShader {
		Tags { "RenderType"="Opaque" "LightingMode" = "ForwardBase" }
		LOD 200
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vertHalfLambert
			#pragma fragment fragHalfLambert

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

            struct v2f
            {
               float4  clipPos : SV_POSITION;
               float3 worldNormal : NORMAL; 
            };

			fixed4 _Diffuse;
			v2f vertHalfLambert(appdata_base i)
			{
				v2f o;
				o.clipPos = UnityObjectToClipPos(i.vertex);
				o.worldNormal = UnityObjectToWorldNormal(i.normal);
				
				return o;
			}

			fixed4 fragHalfLambert(v2f i):SV_Target
			{
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed halfLamerbert = dot(i.worldNormal,worldLightDir) * 0.5f + 0.5f;
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * halfLamerbert;
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 color = diffuse + ambient;
				return   fixed4(color,1.0);
				return fixed4(diffuse,1.0);
			}
			
			ENDCG
		}
	}
}