using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class RadialBlur : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Shader raialBlurShader;
        public int BlurAmount;
        [Range(0,1)]
        public float lightRadius;
        [Range(0.1f,1f)]
        public float LuminanceThreshold;
        public float lightStrength;
        public RenderPassEvent PassEvent;
        public Settings()
        {
            this.BlurAmount = 5;
            this.lightRadius = 2;
            this.raialBlurShader = null;
            LuminanceThreshold = 0.8f;
            this.lightStrength = 1.0f;
            this.PassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        }
    }
    class RadialRenderPass : ScriptableRenderPass
    {
        private Material radialBlurMaterial;
        private int blurAmount;
        private float lightRadius;
        private float lightStrength;
        private float luminanceThreshold;
        private RTHandle extractedRT;
        public RadialRenderPass(Settings settings)
        {
            this.renderPassEvent = settings.PassEvent;
            this.blurAmount = settings.BlurAmount;
            this.lightRadius = settings.lightRadius;
            this.luminanceThreshold = settings.LuminanceThreshold;
            this.lightStrength = settings.lightStrength;
            radialBlurMaterial = new Material(settings.raialBlurShader);
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            desc.colorFormat = RenderTextureFormat.ARGBHalf;
            RenderingUtils.ReAllocateIfNeeded(ref extractedRT,desc,name:"ExtractedRT");
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("RadialBlur");
            Light sunlight=RenderSettings.sun;
            Camera camera = renderingData.cameraData.camera;
            Vector3 sunWorldPosition = camera.transform.position-sunlight.transform.forward*camera.farClipPlane;
            Vector3 sunviewPortPosition = camera.WorldToViewportPoint(sunWorldPosition);
            if (sunviewPortPosition.z>=0)
            {
                RTHandle source=renderingData.cameraData.renderer.cameraColorTargetHandle;
                cmd.SetGlobalVector(Shader.PropertyToID("_sunPositionVS"), sunviewPortPosition);
                cmd.SetGlobalFloat(Shader.PropertyToID("_LightRadius"), lightRadius);
                cmd.SetGlobalInt(Shader.PropertyToID("_BlurAmount"), blurAmount);
                cmd.SetGlobalFloat(Shader.PropertyToID("_LightThreshold"), luminanceThreshold);
                cmd.SetGlobalFloat(Shader.PropertyToID("_LightStrength"), lightStrength);
                
                Blitter.BlitCameraTexture(cmd,source,extractedRT,radialBlurMaterial,0);
                Blitter.BlitCameraTexture(cmd,extractedRT,source,radialBlurMaterial,1);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }

        public void Dispose()
        {
            extractedRT?.Release();
            extractedRT = null;
        }
        
    }

    RadialRenderPass m_ScriptablePass;
    public Settings settings=new Settings();
    /// <inheritdoc/>
    public override void Create()
    {
        if (settings.raialBlurShader != null)
        {
            m_ScriptablePass = new RadialRenderPass(settings);
        }
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType==CameraType.Preview || cameraType==CameraType.Reflection)return;
        if (m_ScriptablePass == null)
        {
            Debug.LogError("Radial Blur Pass not set");
            return;
        }
        m_ScriptablePass.ConfigureInput(ScriptableRenderPassInput.Color);
        renderer.EnqueuePass(m_ScriptablePass);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_ScriptablePass?.Dispose();
    }
}


