Shader "Custom/TessShader"
{
    Properties
    {
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            //hull domain
            #pragma hull hullProgram
            #pragma domain domain
           
            #pragma vertex tessVert
            #pragma fragment frag

            #include "UnityCG.cginc"
            //Tessellation　HeadFile
            #include "Tessellation.cginc" 

            #pragma target 5.0
            
            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            //Domain　Shaderの内で空間変換する
            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.tangent = v.tangent;
                o.normal = v.normal;
                return o;
            }

            //Tessを使うことができない可能性があります。
            #ifdef UNITY_CAN_COMPILE_TESSELLATION
   
                struct TessVertex{
                    float4 vertex : INTERNALTESSPOS;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float2 uv : TEXCOORD0;
                };

                //Hull Shader の内で使います
                struct OutputPatchConstant { 
                    //patchの属性
                    //Tessellation Factor和Inner Tessellation Factor
                    float edge[3] : SV_TESSFACTOR;//矩形の場合は４になる
                    float inside  : SV_INSIDETESSFACTOR;
                };

                //
                TessVertex tessVert (VertexInput v){
                    //空間変換は不要. hull　shaderに直接入力する
                    TessVertex o;
                    o.vertex  = v.vertex;
                    o.normal  = v.normal;
                    o.tangent = v.tangent;
                    o.uv      = v.uv;
                    return o;
                }

                float _TessellationUniform;
                OutputPatchConstant hsConst (InputPatch<TessVertex,3> patch){
                    OutputPatchConstant o;
                    o.edge[0] = _TessellationUniform;
                    o.edge[1] = _TessellationUniform;
                    o.edge[2] = _TessellationUniform;
                    o.inside  = _TessellationUniform;
                    return o;
                }

                [UNITY_domain("tri")]//primitiveを定義する，quad,triangle
                [UNITY_partitioning("fractional_odd")]//分割のルール　equal_spacing,fractional_odd,fractional_even
                [UNITY_outputtopology("triangle_cw")]// 頂点の順番　時計回り・逆時計回り　Clockwise/Counterclockwise　/triangle_cw/triangle_ccw
                [UNITY_patchconstantfunc("hsConst")]//上の関数　を指定する
                [UNITY_outputcontrolpoints(3)]      
              
                TessVertex hullProgram (InputPatch<TessVertex,3> patch,uint id : SV_OutputControlPointID){
                    return patch[id];
                }

                [UNITY_domain("tri")]//primitiveを定義する，quad,triangle
                VertexOutput domain (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3>patch,float3 bary :SV_DOMAINLOCATION)
                //bary:中心座標
                {
                    VertexInput v;
                    v.vertex = patch[0].vertex * bary.x + patch[1].vertex*bary.y + patch[2].vertex*bary.z;
			        v.tangent = patch[0].tangent*bary.x + patch[1].tangent*bary.y + patch[2].tangent*bary.z;
			        v.normal = patch[0].normal*bary.x + patch[1].normal*bary.y + patch[2].normal*bary.z;
			        v.uv = patch[0].uv*bary.x + patch[1].uv*bary.y + patch[2].uv*bary.z;

                    VertexOutput o = vert (v);
                    return o;
                }
            #endif

            float4 frag (VertexOutput i) : SV_Target
            {
                return float4(1.0,1.0,1.0,1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
