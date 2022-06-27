using UnityEngine;

namespace _01_Bloom
{
    public class Bloom : PostEffectsBase
    {
        [SerializeField] private Shader _bloomShader;
        private Material _bloomMaterial = null;

        public Material BloomMaterial
        {
            get
            {
                //Check Shader
                _bloomMaterial = CheckShaderAndCreateMaterial(_bloomShader, _bloomMaterial);
                return _bloomMaterial;
            }
        }

        /// <summary>
        /// Blur iterations - larger number means more blur.
        /// </summary>
        [SerializeField][Range(0, 4)] private int _iterations = 3;

        /// <summary>
        /// Blur spread for each iteration - larger value means more blur
        /// </summary>
        [SerializeField][Range(0.2f, 3.0f)] private float _blurSpread = 0.6f;
    
        [SerializeField][Range(1, 8)] private int _downSample = 4;

        /// <summary>
        /// 閾値
        /// </summary>
        [SerializeField][Range(0.0f, 4.0f)] private float _luminanceThreshold = 0.6f;
    
        private void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            //check 
            if (BloomMaterial != null)
            {
                BloomMaterial.SetFloat("_LuminanceThreshold",_luminanceThreshold);

                int rtw = src.width / _downSample; // RenderTextureWidth
                int rth = src.height / _downSample; // RenderTextureHeight
            
                RenderTexture buffer0 = RenderTexture.GetTemporary(rtw,rth,0);
                buffer0.filterMode = FilterMode.Bilinear; 
                //Pass0 ExtractBright 元画像　-> buffer0
                Graphics.Blit(src,buffer0,BloomMaterial,0);

                for (int i = 0; i < _iterations; i++) //gaussianBlur
                {
                    //gaussianBlur の範囲
                    BloomMaterial.SetFloat("_BlurSize",1.0f + i * _blurSpread);
                    RenderTexture buffer1 = RenderTexture.GetTemporary(rtw, rth, 0);
                    //pass1 BlurVertical 結果はbuffer1 に格納される
                    Graphics.Blit(buffer0, buffer1, BloomMaterial, 1);
                    RenderTexture.ReleaseTemporary(buffer0);
                    buffer0 = buffer1;
       
                    buffer1 = RenderTexture.GetTemporary(rtw, rth, 0);
                    //pass2 BlurHorizontal 結果はbuffer1 に格納される
                    Graphics.Blit(buffer0, buffer1, BloomMaterial, 2);
                    RenderTexture.ReleaseTemporary(buffer0);
                    buffer0 = buffer1;
                }
            
     
                //buffer0 -> _Bloom Texture
                BloomMaterial.SetTexture("_Bloom" ,buffer0);
                // pass3 元画像とブレントする
                Graphics.Blit(src,dest,BloomMaterial,3);
                RenderTexture.ReleaseTemporary(buffer0);
            }
            else
            {
                Graphics.Blit(src, dest);//異常の場合、元画像を輸出
            }
        }
    }
}
