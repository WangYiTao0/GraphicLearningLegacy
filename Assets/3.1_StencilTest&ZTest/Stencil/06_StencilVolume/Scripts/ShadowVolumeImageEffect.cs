using UnityEngine;

namespace _3._1_StencilTest_ZTest.Stencil._06_StencilVolume.Scripts
{
    public abstract class ShadowVolumeImageEffect : MonoBehaviour
    {
        public bool available = true;

        abstract public void DrawImageEffect(RenderTexture source, RenderTexture destination);
    }
}