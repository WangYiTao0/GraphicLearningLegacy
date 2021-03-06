Shader "Wyt/Stencil/StentilOutline"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_OutLineWidth("OutLineWidth",Float) = 0.01
		_OutLineColor("OutLineColor",Color) = (1,1,1,1)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
        Stencil {
             Ref 0          //0-255
             Comp Equal     //default:always
             Pass IncrSat   //default:keep
             Fail keep      //default:keep
             ZFail keep     //default:keep
        }
		/*
		Pass 1 オブジェクトをレンダリングする、
		そしてStencilTest通過して、IncrSat操作
		StencilBufferValue + 1
		*/
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2fXray
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2fXray vert (appdata v)
			{
				v2fXray o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2fXray i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
			    //return fixed4(1,1,0,1);
                return col;
			}
			ENDCG
		}
		/*
		Pass 2 頂点を拡大する
		StencilBufferValue　は　１ですから、StencilTestを失敗て。
		拡大の部分だけは現在StencilBufferValueは0の部分でレンダリングする
		*/
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 normal: NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2fXray
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _OutLineColor;
            float _OutLineWidth;


            v2fXray vert (appdata v)
            {
                v2fXray o;
            	// vertex を拡大
                o.vertex= v.vertex+ normalize(v.normal)*_OutLineWidth;
                o.vertex = UnityObjectToClipPos(o.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            fixed4 frag (v2fXray i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return _OutLineColor;
            }
            ENDCG
        }
	}
}

