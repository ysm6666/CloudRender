using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SocialPlatforms;

[CreateAssetMenu(fileName = "Noise Tool", menuName = "Create Noise Tool")]
public class GenNoiseTool : ScriptableObject
{
    public enum ResolutionSetting
    { Resolution_32=32,
      Resolution_64=64, 
      Resolution_128=128, 
      Resolution_256=256, 
      Resolution_512=512
    }
    
    public enum  NoiseType
    {
        PerlinNoise=1,
        WorleyNoise=2,
        PerlinWorleyNoise=3,
        PerlinWorleyNoise3D=4,
        DetailNoise=5,
    }
    
    public enum NoiseMode
    {
        _2D=1,
        _3D=2,
    }
    public enum ColorSpace
    {
        Gamma=1,
        Linear=2,
    }
    
    public ComputeShader computeShader;
    private string kernelName;
    private const string frequencyName = "frequency";
    private const string resolutionSettingName = "resolution";
    private const string gammaName = "gamma";
    private int kernelID;
    private int noiseID;
    private int frequencyID;
    private int resolutionID;
    private int gammaID;
    private int slicedTexID;
    [Header("Noise Settings")]
    [Range(1.0f,20.0f)]
    public float frequency=10.0f;
    public ResolutionSetting resolutionSetting=ResolutionSetting.Resolution_128;
    public NoiseType noiseType = NoiseType.PerlinNoise;
    public ColorSpace colorSpace = ColorSpace.Linear;
    public NoiseMode noiseMode = NoiseMode._2D;
    [Range(0.0f,1.0f)]
    public float ZSliced = 0.5f;
    private RenderTexture renderTexture;
    private RenderTexture slicedTexture;
    public RenderTexture _RenderTexture
    {
        get
        {
            return renderTexture;
        }
    }
    public RenderTexture SlicedTexture
    {
        get
        {
            return slicedTexture;
        }
    }
    
    void ReleaseRenderTexture(ref RenderTexture rt)
    {
        rt?.Release();
        rt = null;
    }
    
    void GenRenderTexture(ref RenderTexture rt, int resolution, NoiseMode mode,RenderTextureFormat format)
    {
        if (rt!=null)ReleaseRenderTexture(ref rt);
        if (mode == NoiseMode._2D)
        {
            rt = new RenderTexture(resolution, resolution, 0, format,RenderTextureReadWrite.Linear);
        }
        else if (mode == NoiseMode._3D)
        {
            rt = new RenderTexture(resolution, resolution, 0, format,RenderTextureReadWrite.Linear);
            rt.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
            rt.volumeDepth = resolution;
        }
        rt.enableRandomWrite = true;
        rt.Create();
    }

    bool IfRenderTextureNeedsUpdate(ref RenderTexture rt,int  resolution,TextureDimension dimension)
    {
        if (rt ==null)
        {
            return true;
        }
        else if (rt.width != resolution || rt.height != resolution)
        {
            return true;
        }
        else if (rt.dimension!=dimension)
        {
            return true;
        }
        return false;
    }
    void GenerateNoise2D()
    {
       switch (noiseType)
        {
            case NoiseType.PerlinNoise:
                kernelName="PerlinMain"; break;
            case NoiseType.WorleyNoise:
                kernelName="WorleyMain"; break;
            case NoiseType.PerlinWorleyNoise:
                kernelName="PerlinWorleyMain"; break;
            case NoiseType.DetailNoise:
            case NoiseType.PerlinWorleyNoise3D:
                Debug.Log("not supported 3D texture");kernelName="PerlinMain"; break;
            default:kernelName="PerlinMain"; break;
        }
        
        gammaID=Shader.PropertyToID(gammaName);
        switch (colorSpace)
        {
            case ColorSpace.Gamma:
                computeShader.SetFloat(gammaID, 2.2f); break;
            case ColorSpace.Linear:
                computeShader.SetFloat(gammaID, 1.0f); break;
            default:computeShader.SetFloat(gammaID, 1.0f); break;
        }
        
        kernelID=computeShader.FindKernel(kernelName);
        noiseID=Shader.PropertyToID("_2DNoise");
        frequencyID=Shader.PropertyToID(frequencyName);
        resolutionID=Shader.PropertyToID(resolutionSettingName);
        int resolution=(int) resolutionSetting;
        if (IfRenderTextureNeedsUpdate(ref renderTexture,resolution,TextureDimension.Tex2D))
        {
            GenRenderTexture(ref renderTexture, resolution, noiseMode,RenderTextureFormat.ARGB32);
        }
        computeShader.SetTexture(kernelID,noiseID,renderTexture);
        computeShader.SetFloat(frequencyID,frequency);
        computeShader.SetInt(resolutionID,resolution);
        computeShader.Dispatch(kernelID,resolution/8,resolution/8,1);     
        Shader.SetGlobalTexture(noiseID,renderTexture);
    }

    
    void GenerateNoise3D()
    {
        switch (noiseType)
        {
            case NoiseType.PerlinNoise:
            case NoiseType.WorleyNoise:
            case NoiseType.PerlinWorleyNoise:
              Debug.LogError("Noise type not supported"); return;
            case NoiseType.PerlinWorleyNoise3D:
                kernelName="PerlinWorley3DMain"; break;
            case NoiseType.DetailNoise:
                kernelName="DetailNoiseMain";break;
            default:kernelName="PerlinWorley3DMain"; break;
        }
        
        gammaID=Shader.PropertyToID(gammaName);
        switch (colorSpace)
        {
            case ColorSpace.Gamma:
                computeShader.SetFloat(gammaID, 2.2f); break;
            case ColorSpace.Linear:
                computeShader.SetFloat(gammaID, 1.0f); break;
            default:computeShader.SetFloat(gammaID, 1.0f); break;
        }
        
        kernelID=computeShader.FindKernel(kernelName);
       
        noiseID=Shader.PropertyToID("_3DNoise");
        slicedTexID=Shader.PropertyToID("_2DNoise");
        
       
        frequencyID=Shader.PropertyToID(frequencyName);
        resolutionID=Shader.PropertyToID(resolutionSettingName);
        int resolution=(int) resolutionSetting;
        resolution=resolution>128 ? 128 : resolution;
        if (IfRenderTextureNeedsUpdate(ref renderTexture,resolution,TextureDimension.Tex3D))
        {
            GenRenderTexture(ref renderTexture, resolution, noiseMode,RenderTextureFormat.ARGB32);
            GenRenderTexture(ref slicedTexture, resolution, NoiseMode._2D,RenderTextureFormat.ARGB32);
        }
        computeShader.SetTexture(kernelID,noiseID,renderTexture);
        computeShader.SetFloat(frequencyID,frequency);
        computeShader.SetInt(resolutionID,resolution);
        computeShader.Dispatch(kernelID,resolution/8,resolution/8,resolution/8);
        
        kernelID=computeShader.FindKernel("GetSlicedTex");
        int zslicedID=Shader.PropertyToID("z_sliced");
        computeShader.SetFloat(zslicedID,ZSliced);
        computeShader.SetTexture(kernelID,slicedTexID,slicedTexture);
        computeShader.SetTexture(kernelID,noiseID,renderTexture);
        computeShader.SetInt(resolutionID,resolution);
        computeShader.Dispatch(kernelID,resolution/8,resolution/8,1);
    }
    
    public void GenerateNoise()
    {
        if (computeShader == null)
        {
            Debug.LogError("Compute shader is null");
            return;
        }

        if (noiseMode==NoiseMode._2D)
        {
            GenerateNoise2D();
        }
        else if (noiseMode == NoiseMode._3D)
        {
            GenerateNoise3D();
        }
        
    }
    
    
    void OnEnable()
    {
        GenerateNoise();
    }
    void OnValidate()
    {
        GenerateNoise();
    }

    void OnDisable()
    {
        if (slicedTexture!=null) ReleaseRenderTexture(ref slicedTexture);
        if (renderTexture!=null) ReleaseRenderTexture(ref renderTexture);
    }
    
    #if UNITY_EDITOR
    public void Bake3DNoise()
    {
        if (renderTexture==null||renderTexture.dimension!=TextureDimension.Tex3D)
        {
            Debug.LogWarning("Bake Error:Render texture is not set");
            return;
        }
        int resolution=renderTexture.width;
        var request=UnityEngine.Rendering.AsyncGPUReadback.Request(renderTexture);
        request.WaitForCompletion();
        if (request.hasError)
        {
            Debug.LogError("GPU readback error");
            return;
        }
        Texture3D texture3D=new Texture3D(resolution,resolution,resolution,TextureFormat.RGBA32,false);
        texture3D.wrapMode = TextureWrapMode.Repeat;
        texture3D.filterMode = FilterMode.Bilinear;
        var volumeData=new Unity.Collections.NativeArray<byte>(resolution*resolution*resolution*4, Unity.Collections.Allocator.Temp);
        for (int i = 0; i < resolution; i++)
        {
            var slicedData = request.GetData<Byte>(i);
            Unity.Collections.NativeArray<Byte>.Copy(slicedData,0,volumeData,i*resolution*resolution*4,resolution*resolution*4);
        }
        texture3D.SetPixelData(volumeData,0);
        texture3D.Apply();
        string path=UnityEditor.EditorUtility.SaveFilePanelInProject("保存3D纹理资产","New3DNoise","asset","选择保存在Asset下的路径");
        if (string.IsNullOrEmpty(path))return;
        UnityEditor.AssetDatabase.CreateAsset(texture3D,path);
        UnityEditor.AssetDatabase.SaveAssets();
        UnityEditor.AssetDatabase.Refresh();
    }
    #endif
}
