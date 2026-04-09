using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

public class ParticleRenderFeature : ScriptableRendererFeature
{
    class ParticleRenderPass : ScriptableRenderPass
    {

        struct Particle
        {
            public Vector3 position;
            public Vector3 velocity;
            public float lifetime;
        };
        
        private ComputeShader computeShader;
        private Material particleMaterial;
        private ComputeBuffer  particleBuffer;
        private int particleBufferId;
        private int kernelId;
        private int TimeId;
        private int DeltaTimeId;
        private int RadiusId;
        private Particle[] particleArray;
        private int particleCount;
        private float Radius;
        public ParticleRenderPass(ComputeShader computeShader, Shader particleShader,int particleCount, float Radius=10.0f)
        {
            this.computeShader = computeShader;
            this.particleMaterial = new Material(particleShader);
            particleBufferId = Shader.PropertyToID("_ParticleBuffer");
            kernelId=computeShader.FindKernel("CSMain");
            TimeId = Shader.PropertyToID("_Time");
            DeltaTimeId = Shader.PropertyToID("_DeltaTime");
            RadiusId = Shader.PropertyToID("_Radius");
            particleBuffer = new ComputeBuffer(particleCount, Marshal.SizeOf<Particle>());
            this.particleCount = particleCount;
            this.Radius = Radius;
            particleArray = new Particle[particleCount];
            for (int i = 0; i < particleCount; i++)
            {
                particleArray[i].position=Random.insideUnitSphere*Radius;
                particleArray[i].velocity=Vector3.zero;
                particleArray[i].lifetime=Random.value;
            }
            particleBuffer.SetData(particleArray);  
        }

        public void Dispose()
        {
            particleBuffer.Release();
            DestroyImmediate(particleMaterial);
        }
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("ParticleRender");
            cmd.SetComputeBufferParam(computeShader,kernelId,particleBufferId,particleBuffer);
            cmd.SetComputeFloatParam(computeShader,TimeId,Time.time);
            cmd.SetComputeFloatParam(computeShader,DeltaTimeId,Time.deltaTime);
            cmd.SetComputeFloatParam(computeShader,RadiusId,Radius);
            cmd.DispatchCompute(computeShader,kernelId,particleCount/64,1,1);
            particleMaterial.SetBuffer(particleBufferId,particleBuffer);
            cmd.DrawProcedural(Matrix4x4.identity, particleMaterial,0,MeshTopology.Points,particleCount);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    ParticleRenderPass m_ScriptablePass;
    public ComputeShader computeShader;
    public Shader particleShader;
    public int particleCount;
    public float Radius=10.0f;
    public RenderPassEvent renderPassEvent=RenderPassEvent.AfterRenderingTransparents;
    /// <inheritdoc/>
    public override void Create()
    {
        if (computeShader == null||particleShader == null)
        {
            Debug.LogError("Particle shader And compute shader  need to be assigned!");
            return;
        }
        m_ScriptablePass?.Dispose();
        m_ScriptablePass = new ParticleRenderPass(computeShader, particleShader,particleCount,Radius);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = renderPassEvent;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (m_ScriptablePass == null)
        {
            Debug.LogError("Particle shader And compute shader  need to be assigned!");
            return;
        }
        renderer.EnqueuePass(m_ScriptablePass);
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass?.Dispose();
    }
}


