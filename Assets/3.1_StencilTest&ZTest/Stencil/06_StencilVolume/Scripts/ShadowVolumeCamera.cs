using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace _3._1_StencilTest_ZTest.Stencil._06_StencilVolume.Scripts
{
        [ExecuteInEditMode]
        [RequireComponent(typeof(Camera))]
        public class ShadowVolumeCamera : MonoBehaviour
        {

            public Color ShadowColor = new Color(0.5f, 0.5f, 0.5f, 1.0f);

            public bool IsTwoSideStencil = false;

            public bool IsRenderTextureComposite = false;

            public bool Anti_aliasing = true;

            public float ShadowDistance = 0.0f;

            public bool ShadowDistanceFade = false;


            public float ShadowDistanceFadeLength = 3.0f;

            private const string CB_NAME = "Shadow Volume Drawing CommandBuffer";

        private Material _drawingMtrl = null;

        private ACommandBuffer _cbBeforeOpaque = null;

        private ACommandBuffer _cbAfterAlpha = null;

        private Camera _mainCam = null;

        private Mesh _screenMesh = null;

        private int _shadowColorUniformName = 0;

        private RenderTexture _sceneViewRT = null;

        private RenderTexture _mainCamRT = null;

        private RenderTexture _compositeRT = null;

        private int _shadowVolumeRT = 0;

        private int _shadowVolumeFadeRT = 0;

	    private int _shadowVolumeColorRT = 0;

        private int _shadowDistanceUniformId = 0;

        private SMAA smaa = null;

        private bool sceneViewFirstTime = false;

        private List<ImageEffectItem> imageEffects = null;

        private ShadowVolumeObject[] static_svos = null;

        private ShadowVolumeCombined[] static_combinedSVOs = null;

        private bool boundsNeedUpdate = true;

        private TRI_VALUE isSceneViewCam = TRI_VALUE.UNDEFINED;

    #if UNITY_EDITOR
        public static void DrawAllCameras_Editor()
        {
            ShadowVolumeCamera asvc = null;
            ShadowVolumeCamera[] svcs = FindObjectsOfType<ShadowVolumeCamera>();
            foreach (var svc in svcs)
            {
                svc.Update();
                svc.UpdateCommandBuffers();
                asvc = svc;
            }

            Camera[] sceneViewCams = SceneView.GetAllSceneCameras();
            foreach (var sceneViewCam in sceneViewCams)
            {
                ShadowVolumeCamera svc = sceneViewCam.GetComponent<ShadowVolumeCamera>();
                if (svc != null)
                {
                    SyncShadowVolumeCamera(asvc, svc);
                    svc.Update();
                    svc.UpdateCommandBuffers();
                }
            }
        }

        private static void SyncShadowVolumeCamera(ShadowVolumeCamera source, ShadowVolumeCamera destination)
        {
            if(source == null || destination == null)
            {
                return;
            }

            destination.ShadowColor = source.ShadowColor;
            destination.IsTwoSideStencil = source.IsTwoSideStencil;
            destination.IsRenderTextureComposite = source.IsRenderTextureComposite;
            destination.Anti_aliasing = source.Anti_aliasing;
            destination.ShadowDistance = source.ShadowDistance;
            destination.ShadowDistanceFade = source.ShadowDistanceFade;
            destination.ShadowDistanceFadeLength = source.ShadowDistanceFadeLength;
        }
    #endif

	    private void UpdateCommandBuffers()
        {
            ACommandBuffer cbBeforeOpaque = GetBeforeOpaqueCB();

            CollectImageEffects();

            cbBeforeOpaque.AddToCamera(_mainCam);

            _mainCam.allowMSAA = IsRenderTextureComposite ? false : Anti_aliasing;
            _mainCam.allowHDR = false; // HDR is not supported

            cbBeforeOpaque.CB.Clear();
            if (IsRenderTextureComposite)
            {
                cbBeforeOpaque.CB.SetRenderTarget(GetMainCamRT());
                cbBeforeOpaque.CB.ClearRenderTarget(true, true, new Color(0, 0, 0, 0), 1.0f);
                if (IsSceneViewCamera())
                { 
                    cbBeforeOpaque.CB.Blit(_sceneViewRT, GetMainCamRT());
                }
            }

            UpdateCommandBuffer_AfterAlpha(null);

            if (!IsRenderTextureComposite)
            {
                ReleaseRenderTextureCompositeResources();
            }
        }

        private void UpdateCommandBuffer_AfterAlpha(ShadowVolumeObject[] svos)
        {
            ACommandBuffer cbAfterAlpha = GetAfterAlphaCB();

            cbAfterAlpha.AddToCamera(_mainCam);

            cbAfterAlpha.CB.Clear();
            if (IsRenderTextureComposite)
            {
                RenderTexture mainCamRT = GetMainCamRT();
                cbAfterAlpha.CB.GetTemporaryRT(_shadowVolumeRT, mainCamRT.width, mainCamRT.height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
                cbAfterAlpha.CB.SetRenderTarget(_shadowVolumeRT, mainCamRT);
                cbAfterAlpha.CB.ClearRenderTarget(false, true, Color.white);

                if(IsShadowDistanceFadeEnabled())
                {
                    cbAfterAlpha.CB.GetTemporaryRT(_shadowVolumeFadeRT, mainCamRT.width, mainCamRT.height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGB32);
                    cbAfterAlpha.CB.SetRenderTarget(_shadowVolumeFadeRT, mainCamRT);
                    cbAfterAlpha.CB.ClearRenderTarget(false, true, Color.white);
                }
            }

            ReleaseSVOs();

            int pass_two_side_stencil = IsShadowDistanceFadeEnabled() ? 10 : 4;
            int pass_back_face = IsShadowDistanceFadeEnabled() ? 7 : 0;
            int pass_front_face = IsShadowDistanceFadeEnabled() ? 8 : 1;
            int pass_zero_stencil = 3;
            int pass_draw_shadow = IsRenderTextureComposite ? (IsShadowDistanceFadeEnabled() ? 9 : 6) : 2;
            int pass_composite_shadow = 5;

            ShadowVolumeCombined[] combinedObjs = static_combinedSVOs == null || !Application.isPlaying ? FindObjectsOfType<ShadowVolumeCombined>() : static_combinedSVOs;
            static_combinedSVOs = combinedObjs;
            if (combinedObjs != null && combinedObjs.Length > 0)
            {
                cbAfterAlpha.CB.DrawMesh(_screenMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_zero_stencil);
                foreach (var combinedObj in combinedObjs)
                {
                    MeshFilter mf = combinedObj.GetComponent<MeshFilter>();
                    if (mf != null && mf.sharedMesh != null)
                    {
                        if (IsTwoSideStencil)
                        {
                            cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_two_side_stencil);
                        }
                        else
                        {
                            cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_back_face);
                            cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_front_face);
                        }
                    }
                }
                if (IsShadowDistanceFadeEnabled())
                {
                    cbAfterAlpha.CB.SetRenderTarget(_shadowVolumeRT, _mainCamRT);
                }
                cbAfterAlpha.CB.DrawMesh(_screenMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_draw_shadow);
            }
            else
            {
                cbAfterAlpha.CB.DrawMesh(_screenMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_zero_stencil);
                ShadowVolumeObject[] svObjs = svos == null || !Application.isPlaying ? FindObjectsOfType<ShadowVolumeObject>() : svos;
                static_svos = svObjs;
                UpdateBounds();
                if (svObjs != null)
                {
                    Vector3 camWPos = _mainCam.transform.position;
                    Vector3 camWForward = _mainCam.transform.forward;
                    bool isShadowDistanceEnabled = IsShadowDistanceEnabled();

                    foreach (var svObj in svObjs)
                    {
                        if(IsShadowVolulmeObjectVisible(svObj, isShadowDistanceEnabled, ref camWPos, ref camWForward))
                        {
                            MeshFilter mf = svObj.MeshFilter;
                            if (mf != null && mf.sharedMesh != null)
                            {
							    Matrix4x4 l2w = svObj.L2w;
                                bool twoSubMeshes = mf.sharedMesh.subMeshCount == 2;
                                if (IsTwoSideStencil)
                                {
                                    cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 0, pass_two_side_stencil);
                                    if (twoSubMeshes)
                                    {
                                        cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 1, pass_two_side_stencil);
                                    }
                                }
                                else
                                {
                                    cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 0, pass_back_face);
                                    if (twoSubMeshes)
                                    {
                                        cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 1, pass_back_face);
                                    }
                                    cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 0, pass_front_face);
                                    if (twoSubMeshes)
                                    {
                                        cbAfterAlpha.CB.DrawMesh(mf.sharedMesh, l2w, _drawingMtrl, 1, pass_front_face);
                                    }
                                }
                            }
                        }
                    }
                }
                if (IsShadowDistanceFadeEnabled())
                {
                    cbAfterAlpha.CB.SetRenderTarget(_shadowVolumeRT, _mainCamRT);
                }
                cbAfterAlpha.CB.DrawMesh(_screenMesh, Matrix4x4.identity, _drawingMtrl, 0, pass_draw_shadow);
            }

            if (IsRenderTextureComposite)
            {
                cbAfterAlpha.CB.SetGlobalTexture(_shadowVolumeColorRT, GetMainCamRT());
                cbAfterAlpha.CB.Blit(null, GetCompositeRT(), _drawingMtrl, pass_composite_shadow);
                cbAfterAlpha.CB.ReleaseTemporaryRT(_shadowVolumeRT);

                if(IsShadowDistanceFadeEnabled())
                {
                    cbAfterAlpha.CB.ReleaseTemporaryRT(_shadowVolumeFadeRT);
                }
            }
        }

        private void OnEnable()
        {
            if (_mainCam != null)
            {
                Update();
                UpdateCommandBuffers();
                SetSceneViewCamsEnabled(true);
            }
        }

        private void OnDisable()
        {
            RemoveCBFromCamera();
            ReleaseRenderTextureCompositeResources();
            SetSceneViewCamsEnabled(false);
        }

        private void OnPreRender()
        {
            if(_mainCam == null)
            {
                return;
            }

            if (IsRenderTextureComposite)
            {
                InitSceneViewRT();

			    bool sizeChanged = false;
			    _mainCam.targetTexture = GetMainCamRT(out sizeChanged);
			    if(sizeChanged || sceneViewFirstTime)
			    {
                    sceneViewFirstTime = false;
				    UpdateCommandBuffers();
			    }
                else
                {
                    UpdateSVOS();
                }
            }
            else
            {
                UpdateSVOS();
            }
        }

        private void OnPostRender()
        {
            if (_mainCam == null)
            {
                return;
            }

            if (IsRenderTextureComposite)
            {
                if (IsSceneViewCamera())
                {
                    _mainCam.targetTexture = _sceneViewRT;
                    RenderTexture imageEffectRT = DrawImageEffects(_compositeRT);
                    if (Anti_aliasing)
                    {
                        GetSMAA().OnRenderImage(_mainCam, imageEffectRT, _sceneViewRT);
                    }
                    else
                    {
                        Graphics.Blit(imageEffectRT, _sceneViewRT);
                    }
                    if(imageEffectRT != _compositeRT)
                    {
                        RenderTexture.ReleaseTemporary(imageEffectRT);
                    }
                }
                else
                {
                    RenderTexture mainCamRT = GetMainCamRT();

                    _mainCam.targetTexture = null;
                    RenderTexture imageEffectRT = DrawImageEffects(_compositeRT);
                    if (Anti_aliasing)
                    {
                        GetSMAA().OnRenderImage(_mainCam, imageEffectRT, mainCamRT);
                    }
                    else
                    {
                        Graphics.Blit(imageEffectRT, mainCamRT);
                    }
                    Graphics.Blit(mainCamRT, null as RenderTexture);
                    if(imageEffectRT != _compositeRT)
                    {
                        RenderTexture.ReleaseTemporary(imageEffectRT);
                    }
                }
            }
        }

        private void UpdateSVOS()
        {
            if (static_svos == null)
            {
                return;
            }

            UpdateCommandBuffer_AfterAlpha(static_svos);
        }

        private void UpdateBounds()
        {
            if(static_svos == null || !boundsNeedUpdate || !Application.isPlaying)
            {
                return;
            }

            boundsNeedUpdate = false;

            int numSVOs = static_svos.Length;
            for(int i = 0; i < numSVOs; ++i)
            {
                ShadowVolumeObject svo = static_svos[i];
                if(svo.SourceMeshFilter != null && svo.SourceMeshFilter.sharedMesh != null && 
                    svo.MeshFilter != null && svo.MeshFilter.sharedMesh != null)
                {
                    svo.SourceMeshFilter.sharedMesh.bounds = svo.MeshFilter.sharedMesh.bounds;
                }
            }
        }

        private void OnValidate()
        {
            SetupSceneViewCameras();
        }

        private void Update()
        {
            UpdateMaterialUniforms();
             
    #if UNITY_EDITOR
            ImageEffectsChecking();
    #endif
        }

    #if UNITY_EDITOR
        private void ImageEffectsChecking()
        {
            if(imageEffects == null)
            {
                return;
            }

            // Delete destroied ImageEffects
            int numEffects = imageEffects.Count;
            for(int i = 0; i < numEffects; ++i)
            {
                if(imageEffects[i].mono == null)
                {
                    imageEffects.RemoveAt(i);
                    --i;
                    --numEffects;
                }
            }

            // Add new ImageEffects
            if(Selection.activeGameObject == gameObject)
            {
                CollectImageEffects();

                Camera[] sceneViewCams = SceneView.GetAllSceneCameras();
                foreach(var sceneViewCam in sceneViewCams)
                {
                    ShadowVolumeCamera svc = sceneViewCam.GetComponent<ShadowVolumeCamera>();
                    if(svc != null)
                    {
                        svc.CollectImageEffectsDelay_Editor();
                    }
                }
            }
        }
    #endif

        private void Start()
        {
            InitMaterialUniformNames();

            _cbAfterAlpha = new ACommandBuffer("Shadow Volume After Alpha CB", CameraEvent.AfterForwardAlpha);
            _cbBeforeOpaque = new ACommandBuffer("Shadow Volume Before Opaque CB", CameraEvent.BeforeForwardOpaque);

            _drawingMtrl = new Material(Shader.Find("Hidden/ShadowVolume/Drawing"));
            _drawingMtrl.name = "Shadow Volume Drawing Material";

            _shadowVolumeRT = Shader.PropertyToID("_ShadowVolumeRT");
            _shadowVolumeFadeRT = Shader.PropertyToID("_ShadowVolumeFadeRT");
            _shadowVolumeColorRT = Shader.PropertyToID("_ShadowVolumeColorRT");
            _shadowDistanceUniformId = Shader.PropertyToID("_ShadowVolumeDistance");

            _mainCam = GetComponent<Camera>();

            sceneViewFirstTime = IsSceneViewCamera();

            InitSceneViewRT();

            CreateScreenMesh();

            UpdateCommandBuffers();

            SetupSceneViewCameras();
        }

        private void OnDestroy()
        {
            if(_drawingMtrl != null)
            {
                DestroyImmediate(_drawingMtrl);
                _drawingMtrl = null;
            }

            if (_mainCam != null)
            {
                DestroySceneViewCameras();
                _mainCam.targetTexture = null;
                _mainCam = null;
            }

            DestroyScreenMesh();
            ReleaseRenderTextureCompositeResources();
            ReleaseImageEffects();

            if(_cbAfterAlpha != null)
            {
                _cbAfterAlpha.Destroy();
                _cbAfterAlpha = null;
            }

            if(_cbBeforeOpaque != null)
            {
                _cbBeforeOpaque.Destroy();
                _cbBeforeOpaque = null;
            }
        }

        private void SetupSceneViewCameras()
        {
    #if UNITY_EDITOR
            if (IsSceneViewCamera())
            {
                return;
            }

            Camera[] sceneViewCams = SceneView.GetAllSceneCameras();
            foreach (var sceneViewCam in sceneViewCams)
            {
                ShadowVolumeCamera svc = sceneViewCam.GetComponent<ShadowVolumeCamera>();
                if (svc == null)
                {
                    svc = sceneViewCam.gameObject.AddComponent<ShadowVolumeCamera>();
                }
                SyncShadowVolumeCamera(this, svc);
            }
    #endif
        }

        private void DestroySceneViewCameras()
        {
    #if UNITY_EDITOR
            if (IsSceneViewCamera())
            {
                return;
            }

            Camera[] sceneViewCams = SceneView.GetAllSceneCameras();
            foreach (var sceneViewCam in sceneViewCams)
            {
                ShadowVolumeCamera svc = sceneViewCam.GetComponent<ShadowVolumeCamera>();
                if (svc != null)
                {
                    DestroyImmediate(svc);
                }
            }
    #endif
        }

        private void SetSceneViewCamsEnabled(bool enabled)
        {
    #if UNITY_EDITOR
            if(IsSceneViewCamera())
            {
                return;
            }

            Camera[] sceneViewCams = SceneView.GetAllSceneCameras();
            foreach (var sceneViewCam in sceneViewCams)
            {
                ShadowVolumeCamera svc = sceneViewCam.GetComponent<ShadowVolumeCamera>();
                if (svc != null)
                {
                    svc.enabled = enabled;
                }
            }
    #endif
        }

        private void InitMaterialUniformNames()
        {
            _shadowColorUniformName = Shader.PropertyToID("_ShadowColor");
        }

        private void UpdateMaterialUniforms()
        {
            if(_drawingMtrl != null)
            {
                if (IsShadowDistanceFadeEnabled())
                {
                    _drawingMtrl.SetVector(_shadowDistanceUniformId, new Vector4(ShadowDistance, ShadowDistanceFadeLength, ShadowDistance - ShadowDistanceFadeLength, 0));
                }
                _drawingMtrl.SetColor(_shadowColorUniformName, ShadowColor);
            }
        }

        private void CreateScreenMesh()
        {
            if (_screenMesh == null)
            {
                _screenMesh = new Mesh();
                _screenMesh.name = "ShadowVolume ScreenQuad";
                _screenMesh.vertices = new Vector3[] {
                    new Vector3(-1, -1, 0), new Vector3(-1, 1, 0), new Vector3(1, 1, 0), new Vector3(1, -1, 0)
                };
                _screenMesh.uv = new Vector2[] {
                    new Vector2(0, 0), new Vector2(0, 1), new Vector2(1, 1), new Vector2(1, 0)
                };
                _screenMesh.triangles = new int[] { 0, 1, 2, 2, 3, 0 };
            }
        }

        private void DestroyScreenMesh()
        {
            if (_screenMesh != null)
            {
                DestroyImmediate(_screenMesh);
                _screenMesh = null;
            }
        }

        private ACommandBuffer GetAfterAlphaCB()
        {
            if(_cbAfterAlpha == null)
            {
                _cbAfterAlpha = new ACommandBuffer("Shadow Volume After Alpha CB", CameraEvent.AfterForwardAlpha);
            }
            return _cbAfterAlpha;
        }

        private ACommandBuffer GetBeforeOpaqueCB()
        {
            if (_cbBeforeOpaque == null)
            {
                _cbBeforeOpaque = new ACommandBuffer("Shadow Volume Before Opaque CB", CameraEvent.BeforeForwardOpaque);
            }
            return _cbBeforeOpaque;
        }

        private void RemoveCBFromCamera()
        {
            if(_cbAfterAlpha != null)
            {
                _cbAfterAlpha.RemoveFromCamera();
            }
            if(_cbBeforeOpaque != null)
            {
                _cbBeforeOpaque.RemoveFromCamera();
            }
        }

        private void InitSceneViewRT()
        {
            _sceneViewRT = IsSceneViewCamera() ? _mainCam.targetTexture : null;
        }

	    private RenderTexture GetMainCamRT()
	    {
		    bool sizeChanged = false;
		    RenderTexture rt = GetMainCamRT(out sizeChanged);
		    return rt;
	    }

	    private RenderTexture GetMainCamRT(out bool sizeChanged)
        {
		    sizeChanged = _mainCamRT != null && (_mainCamRT.width != _mainCam.pixelWidth || _mainCamRT.height != _mainCam.pixelHeight);
		    if (_mainCamRT == null || sizeChanged)
            {
                ReleaseMainCamRT();
			    _mainCamRT = new RenderTexture(_mainCam.pixelWidth, _mainCam.pixelHeight, 24, RenderTextureFormat.ARGB32);
                _mainCamRT.name = "Shadow Volume Main Camera RT";
            }
            return _mainCamRT;
        }

        private void ReleaseMainCamRT()
        {
            if (_mainCamRT != null)
            {
                DestroyImmediate(_mainCamRT);
                _mainCamRT = null;
            }
        }

        private RenderTexture GetCompositeRT()
        {
		    if(_compositeRT == null || (_compositeRT.width != _mainCam.pixelWidth || _compositeRT.height != _mainCam.pixelHeight))
            {
                ReleaseCompositeRT();
			    _compositeRT = new RenderTexture(_mainCam.pixelWidth, _mainCam.pixelHeight, 0, RenderTextureFormat.ARGB32);
                _compositeRT.name = "Shadow Volume Composite RT";
            }
            return _compositeRT;
        }

        private void ReleaseCompositeRT()
        {
            if(_compositeRT != null)
            {
                DestroyImmediate(_compositeRT);
                _compositeRT = null;
            }
        }

        private SMAA GetSMAA()
        {
            if(smaa == null)
            {
                smaa = new SMAA();
            }
            return smaa;
        }

        private void ReleaseSMAA()
        {
            if(smaa != null)
            {
                smaa.Destroy();
                smaa = null;
            }
        }

        private void ReleaseRenderTextureCompositeResources()
        {
            ReleaseMainCamRT();
            ReleaseCompositeRT();
            ReleaseSMAA();
        }

        private RenderTexture DrawImageEffects(RenderTexture source)
        {
            if(imageEffects == null || imageEffects.Count == 0)
            {
                return source;
            }
            else
            {
                RenderTexture src = source;
                RenderTexture dest = null;

                int numEffects = imageEffects.Count;
                for(int i = 0; i < numEffects; ++i)
                {
                    MonoBehaviour mono = imageEffects[i].mono;
                    if(mono == null)
                    {
                        continue;
                    }

                    ShadowVolumeImageEffect imageEffect = imageEffects[i].effect;
                    if (imageEffect.available)
                    {
                        if(src == null)
                        {
                            src = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGB32);
                        }
                        if(dest == null)
                        {
                            dest = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.ARGB32);
                        }

                        imageEffect.DrawImageEffect(src, dest);

                        RenderTexture temp = src;
                        src = dest;
                        dest = src;
                    }
                }

                if(src == null || dest == null)
                {
                    return source;
                }
                else
                {
                    return src == source ? dest : src;
                }
            }
        }

    #if UNITY_EDITOR
        private void CollectImageEffectsDelay_Editor()
        {
            EditorApplication.delayCall += _CollectImageEffectsDelay_Editor;
        }

        private void _CollectImageEffectsDelay_Editor()
        {
            EditorApplication.delayCall -= _CollectImageEffectsDelay_Editor;
            CollectImageEffects();
            SceneView.RepaintAll();
        }
    #endif

        private void CollectImageEffects()
        {
            if(_mainCam == null)
            {
                return;
            }
            if(imageEffects == null)
            {
                imageEffects = new List<ImageEffectItem>();
            }
            imageEffects.Clear();

            MonoBehaviour[] monos = gameObject.GetComponents<MonoBehaviour>();
            if(monos != null)
            {
                foreach(var mono in monos)
                {
                    if(mono is ShadowVolumeImageEffect)
                    {
                        ImageEffectItem iei = new ImageEffectItem();
                        iei.effect = mono as ShadowVolumeImageEffect;
                        iei.mono = mono;
                        imageEffects.Add(iei);

                        if(IsRenderTextureComposite)
                        {
                            mono.enabled = false;
                        }
                        else
                        {
                            mono.enabled = iei.effect.available;
                        }
                    }
                }
            }
        }

        private void ReleaseImageEffects()
        {
            if(imageEffects != null)
            {
                imageEffects.Clear();
                imageEffects = null;
            }
        }

        public bool IsShadowDistanceEnabled()
        {
            return ShadowDistance > 0.0001f;
        }

        private bool IsShadowDistanceFadeEnabled()
        {
            return IsRenderTextureComposite && IsShadowDistanceEnabled() && ShadowDistanceFade;
        }

        private bool IsShadowVolulmeObjectVisible(ShadowVolumeObject svo, bool isShadowDistanceEnabled, ref Vector3 camWPos, ref Vector3 camWForward)
        {
            bool visible = svo.IsVisible();

            if(isShadowDistanceEnabled)
            {
                float dist = Vector3.Dot(svo.WPos - camWPos, camWForward);
                visible = dist < ShadowDistance;
            }

            return visible;
        }

        private void ReleaseSVOs()
        {
            static_svos = null;
        }

        private bool IsSceneViewCamera()
        {
    #if UNITY_EDITOR
            if (isSceneViewCam == TRI_VALUE.UNDEFINED)
            {
                Camera[] sceneViewCames = SceneView.GetAllSceneCameras();
                isSceneViewCam = System.Array.IndexOf(sceneViewCames, _mainCam) != -1 ? TRI_VALUE.YES : TRI_VALUE.NO;
            }
            return isSceneViewCam == TRI_VALUE.YES ? true : false;
    #else
            return false;
    #endif
        }

        private enum TRI_VALUE
        {
            UNDEFINED,
            YES,
            NO
        }

        private class ImageEffectItem
        {
            public ShadowVolumeImageEffect effect = null;

            public MonoBehaviour mono = null;
        }

        private class ACommandBuffer
        {
            private CommandBuffer cb = null;
            public CommandBuffer CB
            {
                get
                {
                    return cb;
                }
            }

            private bool isAdded = false;

            private Camera cam = null;

            private CameraEvent camEvent;

            public ACommandBuffer(string name, CameraEvent camEvent)
            {
                cb = new CommandBuffer();
                cb.name = name;
                this.camEvent = camEvent;
            }

            public void AddToCamera(Camera cam)
            {
                if(cam == null)
                {
                    return;
                }
                if(cam != this.cam && isAdded)
                {
                    RemoveFromCamera();
                }
                if(isAdded)
                {
                    return;
                }

                isAdded = true;
                this.cam = cam;
                cam.AddCommandBuffer(camEvent, cb);
            }

            public void RemoveFromCamera()
            {
                if(!isAdded)
                {
                    return;
                }

                isAdded = false;

                cam.RemoveCommandBuffer(camEvent, cb);
                cam = null;
            }

            public void Destroy()
            {
                if(cb != null)
                {
                    RemoveFromCamera();

                    cb.Clear();
                    cb.Release();
                    cb.Dispose();
                    cb = null;
                }
            }
        }
    }
    
}