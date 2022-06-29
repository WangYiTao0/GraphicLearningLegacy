using System;
using UnityEngine;

namespace _3._1_StencilTest_ZTest.Stencil._06_StencilVolume.Scripts
{
    public class ShadowVolumeObject : MonoBehaviour
    {
        public GameObject Source = null;
        
        public MeshFilter SourceMeshFilter = null;
        
        public MeshRenderer SourceMeshRenderer = null;
        
        public MeshFilter MeshFilter = null;
        
        public Matrix4x4 L2w;

        public Vector3 WPos;



        public bool IsVisible()
        {
            return SourceMeshFilter == null || SourceMeshRenderer == null || MeshFilter == null ? false : SourceMeshRenderer.isVisible;
        }
    }
}