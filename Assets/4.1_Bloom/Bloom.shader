Shader "Wyt/Unlit/Bloom"
{
    Properties
    {
        _MainTex("Base(RGB)", 2D) = "white"{}
        _Bloom("Bloom(RGB)",2D) ="black" {}
        _LuminanceThreshold("Luminance Threshold" ,Float) = 0.5
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        sampler2D _Bloom;
        float _LuminanceThreshold;
        float _BlurSize;

        struct v2fExtractBright
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };
        
        v2fExtractBright vertExtractBright(appdata_img i)
        {
            v2fExtractBright o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv  = i.texcoord;

            return o;
        }
        //Brightness計算
        float luminance(fixed4 color)
        {
            return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
        }
        
        float4 fragExtractBright(v2fExtractBright i) : SV_TARGET0
        {
            fixed4 color = tex2D(_MainTex,i.uv);
            //閾値で明るい部分を抽出する
            fixed val = clamp(luminance(color) - _LuminanceThreshold,0.0,1.0);
            //通過しない部分は0になる
            return  color * val;
        }

        struct v2fBlur
        {
            float4 pos : SV_POSITION;
            half2 uv[5] : TEXCOORD0;//5x5 
        };

        v2fBlur vertBlurVertical(appdata_img i)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(i.vertex);
            half2 uv  = i.texcoord;

            o.uv[0] = uv;
            o.uv[1] = uv + float2(0.0,_MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[2] = uv - float2(0.0,_MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[3] = uv + float2(0.0,_MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.uv[4] = uv - float2(0.0,_MainTex_TexelSize.y * 2.0) * _BlurSize;
            return o;
        }

        v2fBlur vertBlurHorizontal(appdata_img i)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(i.vertex);
            half2 uv  = i.texcoord;

            o.uv[0] = uv;
            o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            return o;
        }

        float4 fragBlur(v2fBlur i) : SV_Target
        {
            //元カウスカーネル{0.0545,0.0242,0.4026, 0.2442, 0.0545}
            float weight[3] = {0.4026,0.2442,0.0545};
            //blur後の値
            fixed3 sum = tex2D(_MainTex,i.uv[0]).rgb * weight[0];
            
            //畳み込み計算
            /*
            i = 1：uv[1]*weight[1]  uv[2]*weight[1]
            i = 2：uv[3]*weight[2]  uv[4]*weight[2]
            */
            for (int it = 1; it < 3; it++)
            {
                sum += tex2D(_MainTex, i.uv[it*2-1]).rgb * weight[it];
                sum += tex2D(_MainTex, i.uv[it*2]).rgb * weight[it];
            }

            return fixed4(sum,1.0);
        }

        struct v2fBloom
        {
            float4 pos : SV_POSITION;
            //_MainTex uv と　_Bloom uv
            half4 uv : TEXCOORD0;
        };

        v2fBloom vertBloom(appdata_img i)
        {
            v2fBloom o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv.xy  = i.texcoord;
            o.uv.zw  = i.texcoord;
            //プラットフォームに応じた処理
            #if UNITY_UV_STARTS_AT_TOP
                if(_MainTex_TexelSize.y <0.0)
                {
                    o.uv.w = 1.0 - o.uv.w;
                }
            #endif
            
            return o;
        }

        fixed4 fragBloom(v2fBloom i) : SV_Target
        {
            return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom,i.uv.zw);
        }
        
        ENDCG
        

        ZTest Always
        Cull Off
        ZWrite Off
        //1. 閾値で明るい部分を抽出する
        Pass
        {
            CGPROGRAM
            #pragma vertex vertExtractBright
            #pragma fragment fragExtractBright
            ENDCG
        }
        //2. 縦方向のガウスブラー
        Pass
        {
            CGPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
            ENDCG
        }
        //3.横方向のガウスブラー
        Pass
        {
            CGPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            ENDCG
        }
        //4 元画像とブレントする
        Pass
        {
            CGPROGRAM
            #pragma vertex vertBloom
            #pragma fragment fragBloom
            ENDCG
        }
    }

}
