using UnityEngine;
using UnityEngine.Serialization;

namespace _01_Bloom
{
    public class GodRay : PostEffectsBase
    {
        [SerializeField] private Shader _godRayShader;
        private Material _godRayMaterial = null;

        public Material GodRayMaterial
        {
            get
            {
                _godRayMaterial = CheckShaderAndCreateMaterial(_godRayShader, _godRayMaterial);
                return _godRayMaterial;
            }
        }

        // 閾値
        [SerializeField] private Color _colorThreshold = Color.gray;

        [SerializeField] private int _radialSampleCount = 6;
        // Light Color
        [SerializeField] private Color _lightColor = Color.white;

        // Light Power
        [SerializeField][Range(0.0f, 20.0f)] private float lightPower = 0.5f;

        // uv offset
        [SerializeField][Range(0.0f, 10.0f)] private float SamplerScale = 1;
        
        // BlurIteration回数
        [SerializeField][Range(1, 5)] private int _blurIteration = 2;
        
        [SerializeField][Range(1, 5)] private int _DownSample = 1;

        // Light　Position　
        [SerializeField]private Transform _lightTransform;

        // Light　Radius 
        [SerializeField][Range(0.0f, 5.0f)] private float _lightRadius = 2.0f;

        // 提取高亮结果Pow系数，用于适当降低颜色过亮的情况
        [SerializeField][Range(1.0f, 4.0f)] private float _lightPowFactor = 3.0f;

        private Camera _targetCamera = null;

        void Awake()
        {
            _targetCamera = GetComponent<Camera>();
        }

        void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            if (GodRayMaterial && _targetCamera)
            {
                int rtW = src.width / _DownSample;
                int rtH = src.height / _DownSample;
               
                RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0, src.format);

                
                //lightの　WorldPos -> viewPortPos
                Vector3 viewPortLightPos = _lightTransform == null
                    ? new Vector3(.5f, .5f, 0)
                    : _targetCamera.WorldToViewportPoint(_lightTransform.position);

                // Set　Shader　Value
                GodRayMaterial.SetVector("_ColorThreshold", _colorThreshold);
                GodRayMaterial.SetVector("_ViewPortLightPos",
                    new Vector4(viewPortLightPos.x, viewPortLightPos.y, viewPortLightPos.z, 0));
                GodRayMaterial.SetFloat("_LightRadius", _lightRadius);
                GodRayMaterial.SetInt("_RadialSampleCount", _radialSampleCount);
                
                GodRayMaterial.SetFloat("_LightPowFactor", _lightPowFactor);
                // Pass0 ExtractBright
                Graphics.Blit(src, buffer0, GodRayMaterial, 0); 
                
  

                // Radial Blur の　Sample　UV　Offset
                float samplerOffset = SamplerScale / src.width;

                // Radial Blur
                for (int i = 0; i < _blurIteration; i++)
                {
                    RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0, src.format);
                    float offset = samplerOffset * (i * 2 + 1);
                    GodRayMaterial.SetVector("_Offsets", new Vector4(offset, offset, 0, 0));
                    Graphics.Blit(buffer0, buffer1, GodRayMaterial, 1);

                    offset = samplerOffset * (i * 2 + 2);
                    GodRayMaterial.SetVector("_Offsets", new Vector4(offset, offset, 0, 0));
                    Graphics.Blit(buffer1, buffer0, GodRayMaterial, 1);
                    RenderTexture.ReleaseTemporary(buffer1);
                }

                
                // blurした結果　-> shader
                GodRayMaterial.SetTexture("_BlurTex", buffer0);
                GodRayMaterial.SetVector("_LightColor", _lightColor);
                GodRayMaterial.SetFloat("_LightPower", lightPower);

                // blend
                Graphics.Blit(src, dest, GodRayMaterial, 2);
                
                RenderTexture.ReleaseTemporary(buffer0);
            }
            else
            {
                Graphics.Blit(src, dest);
            }
        }

    }
}