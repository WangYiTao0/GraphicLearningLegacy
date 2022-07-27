Shader "Roystan/Grass"
{
    Properties
    {
		[Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
		_TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
    	_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
    	_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
    	
    	_BladeWidth("Blade Width", Float) = 0.05
		_BladeWidthRandom("Blade Width Random", Float) = 0.02
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3
    	
    	_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
		_WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
    	_WindStrength("Wind Strength", Float) = 1
    	
    	//计算弯曲
    	_BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
    }

	CGINCLUDE
	#include "Shaders/CustomTessellation.cginc"
	#include "UnityCG.cginc"
	#include "Autolight.cginc"

	#define BLADE_SEGMENTS 3
	
	struct geometryOutput
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : NORMAL;
		//After Unity renders a shadow map from the perspective of a shadow casting light,
		//it will run a pass "collecting" the shadows into a screen space texture.
		unityShadowCoord4 _ShadowCoord : TEXCOORD1; // 对阴影贴图进行采样
	};

	float _BendRotationRandom;

	float _BladeHeight;
	float _BladeHeightRandom;	
	float _BladeWidth;
	float _BladeWidthRandom;

	sampler2D _WindDistortionMap;
	float4 _WindDistortionMap_ST;

	float2 _WindFrequency;
	float _WindStrength;

	float _BladeForward;
	float _BladeCurve;
	
	geometryOutput VertexOutput(float3 pos, float2 uv, float3 normal)
	{
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos);////updating output vertex positions to be offsets from the input point
		o.uv = uv;
		o._ShadowCoord = ComputeScreenPos(o.pos);
		#if UNITY_PASS_SHADOWCASTER
			// Applying the bias prevents artifacts from appearing on the surface.
			o.pos = UnityApplyLinearShadowBias(o.pos);
		#endif
		o.normal = UnityObjectToWorldNormal(normal);
		return o;
	}
	
	
	// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}
	
	// Construct a rotation matrix that rotates around the provided axis, sourced from:
	// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

	////Fuc to calculate grassplane vertex
	geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height,
		float forward, // 
		float2 uv, float3x3 transformMatrix)
	{
		float3 tangentPoint = float3(width, forward, height);
		
		//当草叶的曲率大于1时，每个顶点的切线Z位置将被传递到GenerateGrassVertex函数中的前量所抵消。
		//我们将使用这个值来按比例缩放我们法线的Z轴
		//When Blade Curvature Amount is greater than 1, each vertex will have its tangent Z position
		//offset by the forward amount passed in to the GenerateGrassVertex function.
		//We'll use this value to proportionally scale the Z axis of our normals.
		float3 tangentNormal = normalize(float3(0, -1, forward));
		// illumination = N * L
		//float3 tangentNormal = float3(0, -1, 0);
		float3 localNormal = mul(transformMatrix, tangentNormal);

		float3 localPosition = vertexPosition + mul(transformMatrix, tangentPoint);
		
		return VertexOutput(localPosition, uv, localNormal);
	}

	//[maxvertexcount(3)]//we will emit (but are not required to) at most 3 vertices.
	[maxvertexcount(BLADE_SEGMENTS * 2 + 1)] //输出更多三角形
	void geometryProgram(triangle vertexOutput IN[3]: SV_POSITION,//take in a single triangle (composed of three points) as our input
		inout TriangleStream<geometryOutput> triStream //sets up our shader to output a stream of triangles,
		)
	{
		float3 pos = IN[0].vertex;

		//Cross to Calculate Binormal
		float3 vNormal = IN[0].normal;
		float4 vTangent = IN[0].tangent;
		float3 vBinormal = cross(vNormal, vTangent) * vTangent.w; //Unity simply grabs each binormal's direction and assigns it to the tangent's w coordinate.

		//  construct a matrix to transform between tangent and local space
		//TBN
		float3x3 tangentToLocal = float3x3(
			vTangent.x, vBinormal.x, vNormal.x,
			vTangent.y, vBinormal.y, vNormal.y,
			vTangent.z, vBinormal.z, vNormal.z
		);

		//使用pos 进行采样
		float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
		//对 Distortion Map 进行采样 通过力度控制
		float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
		float3 wind = normalize(float3(windSample.x, windSample.y, 0));
		float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);
		
		//根据顶点位置 计算出一个随机数 * 2π 保证360 度旋转 绕着上方向轴旋转
		float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
		//用顶点位置 计算处一个随机数 * 0.5π , 确保旋转（０，９０）的随机范围 ，绕着X轴转
		float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

		float3x3 transformationMatrix =
			mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix);

		//固定底部两个顶点 防止 旋转导致 插入地面
		float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);

		//o.pos = float4(0.5, 0, 0, 1); // Screen Space
		//takes over responsibility from the vertex shader to ensure vertices are outputted in clip space.
		//o.pos = UnityObjectToClipPos( float4(0.5, 0, 0, 1)); // Clip Space

		// 限制范围在 0 ~ 1
		float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
		float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

		float forward = rand(pos.yyz) * _BladeForward;

		//循环增加顶点
		for (int i = 0; i < BLADE_SEGMENTS; i++)
		{
			//This variable will hold a value, from 0...1, representing how far we are along the blade.
			float t = i / (float)BLADE_SEGMENTS;
			float segmentHeight = height * t; // 越高 越窄
			float segmentWidth = width * (1 - t);
			float segmentForward = pow(t, _BladeCurve) * forward;
			//顶部不需要旋转矩阵
			float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;
			//添加顶点
			triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward,float2(0, t), transformMatrix));
			triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
			//i = 0 时 添加两个底部的顶点 pos, segmentWidth = 1, segmentHeight = 0
			//i = 1 时 添加第二层的顶点 pos
		}

		//insert the vertex at the tip of the blade.
		triStream.Append(GenerateGrassVertex(pos, 0, height, float2(0.5, 1),forward, transformationMatrix));

		// triStream.Append(GenerateGrassVertex(pos, width, 0, float2(0, 0), transformationMatrixFacing));//left
		// triStream.Append(GenerateGrassVertex(pos, -width, 0, float2(1, 0), transformationMatrixFacing)); // right
		// triStream.Append(GenerateGrassVertex(pos, 0, height, float2(0.5, 1), transformationMatrix));// top In tangent space top usually (0,0,1)
	}
	ENDCG

    SubShader
    {
		Cull Off

        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hull
			#pragma domain domain
            #pragma geometry geometryProgram
			#pragma target 4.6
            #pragma multi_compile_fwdbase // 接受阴影相关
            
			#include "Lighting.cginc"

			float4 _TopColor;
			float4 _BottomColor;
			float _TranslucentGain;

			float4 frag (geometryOutput i,
				//The fixed facing argument will return a positive number,
				//if we are viewing the front of the surface, and a negative if we are viewing the back. 
				fixed facing : VFACE 
				) : SV_Target
            {	
    
            	float3 normal = facing > 0 ? i.normal : -i.normal; // 翻转法线

				float shadow = SHADOW_ATTENUATION(i);
				float NdotL = saturate(saturate(dot(normal, _WorldSpaceLightPos0)) + _TranslucentGain) * shadow;

				float3 ambient = ShadeSH9(float4(normal, 1));
				float4 lightIntensity = NdotL * _LightColor0 + float4(ambient, 1);
				float4 col = lerp(_BottomColor, _TopColor * lightIntensity, i.uv.y);

				return col;

            	//return lerp(_BottomColor,_TopColor,i.uv.y);
        		// visualize shadow
            	//return SHADOW_ATTENUATION(i);
				//visualize normal
				//return float4(normal * 0.5 + 0.5, 1);
            }
            ENDCG
        }
    	// Add below the existing Pass.
		Pass
		{
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geometryProgram
			#pragma fragment frag
			#pragma hull hull
			#pragma domain domain
			#pragma target 4.6
			#pragma multi_compile_shadowcaster

			float4 frag(geometryOutput i,fixed facing : VFACE) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}

			ENDCG
		}
    }
}