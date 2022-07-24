Shader "Roystan/Toon/Water"
{
    Properties
    {	
        _SurfaceNoise("Surface Noise", 2D) = "white" {}
        _SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.777
    	
	    _FoamMaxDistance("Foam Maximum Distance", Float) = 0.4
		_FoamMinDistance("Foam Minimum Distance", Float) = 0.04
    	
        _SurfaceNoiseScroll("Surface Noise Scroll Amount", Vector) = (0.03, 0.03, 0, 0)
        // Two channel distortion texture.
        _SurfaceDistortion("Surface Distortion", 2D) = "white" {}	
        // Control to multiply the strength of the distortion.
        _SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27
        // 水の色は深度によって変化する
        // Gradient で　色をコントロールする
        //　浅い部分のコントロール
        _DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725)
        // 深い部分のコントロール
        _DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749)
        //これより深い部分の色は変わらない
        _DepthMaxDistance("Depth Maximum Distance", Float) = 1
        
        _FoamColor("Foam Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags
        {
	        "Queue" = "Transparent"
        }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha   // Src *  Src.a + Dst * (1- SrcAlpha) Blend 透明物体
            ZWrite Off  // 关闭深度写人
            
			CGPROGRAM
			#define SMOOTHSTEP_AA 0.01
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

			float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				//blend on the alpha channel 
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

            struct appdata
            {
                float4 vertex : POSITION;
			    float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPosition : TEXCOORD2;
                float2 noiseUV : TEXCOORD0;
                float2 distortUV : TEXCOORD1;
            	float3 viewNormal : NORMAL;

            };

			float4 _DepthGradientShallow;
            float4 _DepthGradientDeep;

            float _DepthMaxDistance;

			//Camera View Depth Texture
            sampler2D _CameraDepthTexture;
			sampler2D _SurfaceNoise;
            float4 _SurfaceNoise_ST;

			//off set uv to do animation
			float2 _SurfaceNoiseScroll;
			
			float _SurfaceNoiseCutoff;
			float _FoamMaxDistance;
			float _FoamMinDistance;

			sampler2D _SurfaceDistortion;
            float4 _SurfaceDistortion_ST;

			sampler2D _CameraNormalsTexture;

            float _SurfaceDistortionAmount;

			float4 _FoamColor;


            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                //Convert Water Vertex to SceenPosition
                o.screenPosition = ComputeScreenPos(o.vertex);
                o.noiseUV = TRANSFORM_TEX(v.uv, _SurfaceNoise);//*_ST.xy scale + _ST.zw Tilling
                o.distortUV = TRANSFORM_TEX(v.uv, _SurfaceDistortion);
            	o.viewNormal = COMPUTE_VIEW_NORMAL;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //tex2Dproj will divide the input UV's xy coordinates by its w coordinate before sampling the texture. 
                float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
                //Clip Spaceの座標は（0,w）　/w return (0,1) 坐标从正交投影转换为透视投影。
                //近处的深度精度大 远处的深度精度小
                //float existingDepth01 = tex2D(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition.xy / i.screenPosition.w)).r;


            	
                float existingDepthLinear = LinearEyeDepth(existingDepth01); //把非线性Depth 变成线性 Depth
                //the depth of the water surface  [i.screenPosition.w]
                float depthDifference = existingDepthLinear - i.screenPosition.w;//当前深度 和 水面的差值
                //
                float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);//当前深度和最大深度的比例 Saturate in 0,1
                //Lerp value between
                float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);// Lerp Color

                // * 2 - 1 将(0,1) 范围 变成 (-1,1)
                float2 distortSample = (tex2D(_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;
                //offset uv todo animation
                //float2 noiseUV = float2(i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x, i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y);
                float2 noiseUV = float2((i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x) + distortSample.x, (i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y) + distortSample.y);
                float surfaceNoiseSample = tex2D(_SurfaceNoise, noiseUV).r;
            	
            	float3 existingNormal = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(i.screenPosition));
				float3 normalDot = saturate(dot(existingNormal, i.viewNormal));
            	float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
				float foamDepthDifference01 = saturate(depthDifference / foamDistance);
            	
                //float foamDepthDifference01 = saturate(depthDifference / _FoamDistance); //将 当前深度 和 海浪距离相关 
                float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;  //将Cutoff 和 深度相关
                //Any values darker than the cutoff threshold are simply ignored, while any values above are drawn completely white.
                //float surfaceNoise = surfaceNoiseSample > surfaceNoiseCutoff ? 1 : 0; // 大于这个值  白色，else 透明
            	//smoothstep is somewhat similar to lerp  Lerp 是直线  SmoothStep 是曲线
            	float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);
            	float4 surfaceNoiseColor = _FoamColor;
                //float4 surfaceNoiseColor = _FoamColor * surfaceNoise;
            	surfaceNoiseColor.a *= surfaceNoise;
				return alphaBlend(surfaceNoiseColor, waterColor);
				//return waterColor + surfaceNoiseColor;
            }
            ENDCG
        }
    }
}