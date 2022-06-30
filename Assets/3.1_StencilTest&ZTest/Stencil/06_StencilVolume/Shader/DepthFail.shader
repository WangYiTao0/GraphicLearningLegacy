Shader "Wyt/Stencil/DepthFail"
{
    Properties
    {
    }
    SubShader
    {
        //ShadowVolume レンダリング順番はGeometry以後　
        Tags { "RenderType"="Opaque" "Queue"="Geometry+1"}  
        LOD 100
        
        CGINCLUDE       
        #include "UnityCG.cginc"
        struct appdata
        {
            float4 vertex : POSITION;
        };

        struct v2fXray
        {
            UNITY_FOG_COORDS(1)
            float4 vertex : SV_POSITION;
        };

        v2fXray vert (appdata v)
        {
            v2fXray o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            UNITY_TRANSFER_FOG(o,o.vertex);
            return o;
        }
        
        fixed4 frag (v2fXray i) : SV_Target
        {
            // apply fog
            UNITY_APPLY_FOG(i.fogCoord, col);
            return fixed4(0.3,0.3,0.3,1);           //ShadowColor
        }
        ENDCG

        Pass
        {
            Cull Front          
            Stencil {           
                Ref 0           //0-255
                ZFail IncrWrap  //default:keep
            }

            ColorMask 0         //Color write Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            ENDCG
        }
        
        Pass
        {
            Cull Back          
            Stencil {
                Ref 0           //0-255
                ZFail DecrWrap  //default:keep
            }
            ColorMask 0        
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            ENDCG
        }

        Pass
        {
            Cull Back          //
            Stencil {
                Ref 1          //0-255
                Comp equal     //default:always
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            ENDCG
        }
    }
}
