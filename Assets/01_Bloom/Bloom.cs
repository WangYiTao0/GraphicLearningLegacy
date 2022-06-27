using UnityEngine;

public class Bloom : PostEffectsBase
{
    public Shader _BloomShader;
    private Material _bloomMaterial = null;

    public Material _BloomMaterial
    {
        get
        {
            //Check Shader
            _bloomMaterial = CheckShaderAndCreateMaterial(_BloomShader, _bloomMaterial);
            return _bloomMaterial;
        }
    }

    /// <summary>
    /// Blur iterations - larger number means more blur.
    /// </summary>
    [Range(0, 4)] public int _Iterations = 3;

    /// <summary>
    /// Blur spread for each iteration - larger value means more blur
    /// </summary>
    [Range(0.2f, 3.0f)] public float _BlurSpread = 0.6f;
    
    [Range(1, 8)] public int _DownSample = 4;

    /// <summary>
    /// 閾値
    /// </summary>
    [Range(0.0f, 4.0f)] public float _LuminanceThreshold = 0.6f;
    
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        //check 
        if (_BloomMaterial != null)
        {
            _BloomMaterial.SetFloat("_LuminanceThreshold",_LuminanceThreshold);

            int rtw = src.width / _DownSample; // RenderTextureWidth
            int rth = src.height / _DownSample; // RenderTextureHeight
            
            RenderTexture buffer0 = RenderTexture.GetTemporary(rtw,rth,0);
            buffer0.filterMode = FilterMode.Bilinear; 
            //Pass0 ExtractBright 元画像　-> buffer0
            Graphics.Blit(src,buffer0,_BloomMaterial,0);

            for (int i = 0; i < _Iterations; i++) //gaussianBlur
            {
                //gaussianBlur の範囲
                _BloomMaterial.SetFloat("_BlurSize",1.0f + i * _BlurSpread);
                RenderTexture buffer1 = RenderTexture.GetTemporary(rtw, rth, 0);
                //pass1 BlurVertical 結果はbuffer1 に格納される
                Graphics.Blit(buffer0, buffer1, _BloomMaterial, 1);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
       
                buffer1 = RenderTexture.GetTemporary(rtw, rth, 0);
                //pass2 BlurHorizontal 結果はbuffer1 に格納される
                Graphics.Blit(buffer0, buffer1, _BloomMaterial, 2);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
            
     
            //buffer0 -> _Bloom Texture
            _BloomMaterial.SetTexture("_Bloom" ,buffer0);
            // pass3 元画像とブレントする
            Graphics.Blit(src,dest,_BloomMaterial,3);
            RenderTexture.ReleaseTemporary(buffer0);
        }
        else
        {
            Graphics.Blit(src, dest);//異常の場合、元画像を輸出
        }
    }
}
