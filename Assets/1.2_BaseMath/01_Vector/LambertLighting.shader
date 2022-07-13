Shader "Wyt/LambertLighting"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"   "LightMode"="ForwardBase" }
        LOD 200
        
        pass
        {
            CGPROGRAM
            #pragma vertex vertLambert
            #pragma fragment fragLambert

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            
            struct v2f
            {
               float4  clipPos : SV_POSITION;
               float3 worldNormal : NORMAL; 
            };

            v2f vertLambert(appdata_full i)
            {
                v2f o ;
                o.clipPos = UnityObjectToClipPos(i.vertex);
                o.worldNormal =  UnityObjectToWorldNormal(i.normal);

                return o;
            }

            fixed4 _Diffuse;

            fixed4 fragLambert(v2f i):SV_Target
            {
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                float lambert = saturate(dot(worldLightDir,i.worldNormal));
                fixed3 diffuse  = _LightColor0.rgb * _Diffuse.rgb * lambert ;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 color = diffuse + ambient;
                return   fixed4(color,1.0);
                return   fixed4(diffuse,1.0);
            }
        
            ENDCG
        }
    }
}


