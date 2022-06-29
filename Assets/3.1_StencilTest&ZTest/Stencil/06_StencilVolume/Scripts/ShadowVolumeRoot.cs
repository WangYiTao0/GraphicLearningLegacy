using UnityEngine;

namespace _3._1_StencilTest_ZTest.Stencil._06_StencilVolume.Scripts
{
    public class ShadowVolumeRoot : MonoBehaviour
    {
        [SerializeField]
        public Material _debugMtrl = null;
        public Material DebugMaterial
        {
            get
            {
                if(_debugMtrl == null)
                {
                    _debugMtrl = new Material(Shader.Find("Wyt/ShadowVolume/Debug"));
                }
                return _debugMtrl;
            }
        }
    }
}