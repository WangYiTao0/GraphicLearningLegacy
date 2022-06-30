Shader "Wyt/ZTest/XRay"
{
    Properties
    {
        _MainTex ("Base 2D", 2D) = "white" {}
        _XRayColor ("XRay Color", Color) = (1,1,1,1)

    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        float4 _XRayColor;

        struct v2fXray
        {
            float4 pos : SV_Position;
            float3 Normal : NORMAL;
            float3 ViewDir : TEXCOORD;
            fixed4 Clr : COLOR;
        };

        v2fXray vertXray(appdata_base i)
        {
            v2fXray o;
            o.pos = UnityObjectToClipPos(i.vertex);
            //	objectSpace Camera.xyz - vertex.xyz
            o.ViewDir = ObjSpaceViewDir(i.vertex);
            o.Normal = i.normal;

            float3 normal = normalize(i.normal);
            float3 viewDir = normalize(o.ViewDir);
            //dot(normal,viewDir) normalとviewDirのなす角
            float rim = 1 - dot(normal,viewDir);
            //色をコントロールする
            o.Clr = _XRayColor * rim;
            return o;
        }

        float4 fragXray(v2fXray i) : SV_Target
        {
            return i.Clr;
        }

        sampler2D _MainTex;
        float4 _MainTex_ST; // Scale Tran

        struct v2fNormal
        {
            float4 pos : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        v2fNormal vertNormal(appdata_base  i)
        {
            v2fNormal o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv = TRANSFORM_TEX(i.texcoord,_MainTex);
            
            return o;
        }

        fixed4 fragNormal(v2fNormal i) : SV_Target
        {
           
            return tex2D(_MainTex,i.uv);
        }
        
        ENDCG
        
        Pass //RenderXray
        {
            Tags{"RenderType" = "Transparent" "Queue" = "Transparent"}
            Blend SrcAlpha One // 
            ZTest Greater
            ZWrite Off
            Cull Back
            
            CGPROGRAM
            #pragma vertex vertXray
            #pragma fragment fragXray
            ENDCG
        }
        
        Pass //Normal　Rendering
        {
            Tags{"RenderType" = "Opaque"}

            
            CGPROGRAM
            #pragma vertex vertNormal
            #pragma fragment fragNormal
            ENDCG
        }
  
    }

}
