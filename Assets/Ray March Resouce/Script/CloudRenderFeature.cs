using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CloudRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Material CloudMaterial;
        public RenderPassEvent Event = RenderPassEvent.BeforeRenderingPostProcessing;
        [Range(1,4)]
        public int downsample = 1;
    }
    
   class CloudPass : ScriptableRenderPass
    {
        Material CloudMaterial;
        int downsample;
        public CloudPass(Settings settings)
        {
            this.CloudMaterial = settings.CloudMaterial;
            this.renderPassEvent = settings.Event;
            this.downsample = settings.downsample;
        }

        public void SetDownsample(int downsample)
        {
            this.downsample = downsample;
        }
        
        RTHandle renderCloudRT;
        
        public void Dispose()
        {
            renderCloudRT?.Release();
            renderCloudRT = null;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
           var desc = renderingData.cameraData.cameraTargetDescriptor;
           desc.depthBufferBits = 0;
           //desc.colorFormat = RenderTextureFormat.DefaultHDR;
           desc.colorFormat = RenderTextureFormat.ARGBHalf;
           desc.width /= downsample;
           desc.height /= downsample;
           RenderingUtils.ReAllocateIfNeeded(ref renderCloudRT,desc,name:"TempRT");
           renderCloudRT.rt.filterMode = FilterMode.Bilinear;
        }

        void SetAmbientProbe(CommandBuffer cmd)
        {
            SphericalHarmonicsL2 sh = RenderSettings.ambientProbe;
            cmd.SetGlobalVector("unity_SHAr",new Vector4(sh[0,0],sh[0,1],sh[0,2],sh[0,3]));
            cmd.SetGlobalVector("unity_SHAg",new Vector4(sh[1,0],sh[1,1],sh[1,2],sh[1,3]));
            cmd.SetGlobalVector("unity_SHAb",new Vector4(sh[2,0],sh[2,1],sh[2,2],sh[2,3]));
            cmd.SetGlobalVector("unity_SHBr",new Vector4(sh[0,4],sh[0,5],sh[0,6],sh[0,7]));
            cmd.SetGlobalVector("unity_SHBg",new Vector4(sh[1,4],sh[1,5],sh[1,6],sh[1,7]));
            cmd.SetGlobalVector("unity_SHBb",new Vector4(sh[2,4],sh[2,5],sh[2,6],sh[2,7]));
            cmd.SetGlobalVector("unity_SHC",new Vector4(sh[0,8],sh[1,8],sh[2,8],1.0f));
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("CloudRender");
            SetAmbientProbe(cmd);
            context.SetupCameraProperties(renderingData.cameraData.camera);
            var source=renderingData.cameraData.renderer.cameraColorTargetHandle;
            Blitter.BlitCameraTexture(cmd, source,renderCloudRT,CloudMaterial,0);
            Blitter.BlitCameraTexture(cmd, renderCloudRT, source,CloudMaterial,1);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            //Dispose();
        }
    }
    public Settings settings = new Settings();
    CloudPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        if (settings.CloudMaterial == null)
        {
            return;
        }
        m_ScriptablePass = new CloudPass(settings);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType==CameraType.Preview || cameraType==CameraType.Reflection)
        {
            return;
        }
        if (settings.CloudMaterial && m_ScriptablePass!=null)
        {
            m_ScriptablePass.ConfigureInput(ScriptableRenderPassInput.Color); 
            renderer.EnqueuePass(m_ScriptablePass);    
        }
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass?.Dispose();
    }

    public void SetDownsample(int downsample)
    {
        m_ScriptablePass?.SetDownsample(downsample);
    }
}


