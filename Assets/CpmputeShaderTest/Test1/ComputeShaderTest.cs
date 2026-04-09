using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeShaderTest : MonoBehaviour
{
    public Texture2D inputTexture;
    public ComputeShader shader;
    private RenderTexture renderTexture;
    public Material material;
    void Start()
    {
        //material=GetComponent<MeshRenderer>().material;
        if (inputTexture!=null&&shader!=null&&material!=null)
        {
            renderTexture=new RenderTexture(inputTexture.width,inputTexture.height,0,RenderTextureFormat.ARGB32);
            renderTexture.enableRandomWrite = true;
            renderTexture.Create();
            material.mainTexture = renderTexture;
            int kernel = shader.FindKernel("CSMain");
            shader.SetTexture(kernel,"InputTexture",inputTexture);
            shader.SetTexture(kernel,"Result",renderTexture);
            shader.SetInt("width", inputTexture.width);
            shader.SetInt(Shader.PropertyToID("height"), inputTexture.height);
            shader.Dispatch(kernel,inputTexture.width/8,inputTexture.height/8,1);
        }
    }

    private void OnDestroy()
    {
        if (renderTexture!=null)
        {
            renderTexture.Release();
            DestroyImmediate(renderTexture);   
        }
    }
}
