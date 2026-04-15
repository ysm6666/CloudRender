using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

[CreateAssetMenu(menuName ="Create Change Texture Tool", fileName = "New Change Texture Tool")]
public class ChangeTex : ScriptableObject
{
   public enum Channel
   {
      R=1,
      G=2,
      B=3,
      A=4
   }
   public Texture2D texture;
   public ComputeShader cs;
   public Channel channel=Channel.R;
   [Range(0,1)]
   public float targetVal = 1;
   [Range(1,20)]
   public float strength = 1;
   private RenderTexture rt;

   public RenderTexture RT
   {
      get
      {
         return rt;
      }
   }
   private int kernelId;

   void GenRenderTexture()
   {
      if (rt!=null)
      {
         rt.Release();
         rt=null;
      }
      rt = new RenderTexture(texture.width, texture.height, 0, RenderTextureFormat.ARGB32);
      rt.enableRandomWrite = true;
      rt.Create();
   }
   
   public void ChangeTexChannelColor()
   {
      if (texture==null||cs==null)
      {
         Debug.LogWarning("No texture selected or compute shader selected");
         return;
      }
      kernelId = cs.FindKernel("CSMain");
      if (rt ==null)
      {
         GenRenderTexture();
      }
      if (rt.width != texture.width || rt.height != texture.height)
      {
         GenRenderTexture();
      }
      cs.SetTexture(kernelId,Shader.PropertyToID("_MainTex"), texture);
      cs.SetTexture(kernelId,Shader.PropertyToID("Result"), rt);
      cs.SetFloat(Shader.PropertyToID("TargetVal"), targetVal);
      cs.SetInt(Shader.PropertyToID("Channel"), (int)channel);
      cs.SetFloat(Shader.PropertyToID("strength"), strength);
      float width = texture.width;
      float height = texture.height;
      cs.Dispatch(kernelId,(int)width/8,(int)height/8,1);
   }

   public void BakeTexture()
   {
      if (rt==null)
      {
         return;
      }
      var request=AsyncGPUReadback.Request(rt);
      request.WaitForCompletion();
      if (request.hasError)
      {
         Debug.Log("GPU Readback Error");
         return;
      }

      var data = request.GetData<Color32>();
      Texture2D tex = new Texture2D(rt.width, rt.height,TextureFormat.RGBA32, false);
      tex.SetPixelData(data,0);
      tex.Apply();
      byte[] bytes = tex.EncodeToPNG();
      string path=UnityEditor.EditorUtility.SaveFilePanelInProject("Save Texture", "New Texture", "png", "Save Texture");
      if (String.IsNullOrEmpty(path))return;
      File.WriteAllBytes(path, bytes);
      DestroyImmediate(tex);
   }
   public void freshTex()
   {
      ChangeTexChannelColor();
   }
   private void OnValidate()
   {
      ChangeTexChannelColor();
   }

   private void OnEnable()
   {
      ChangeTexChannelColor();
   }

   private void OnDisable()
   {
      rt?.Release();
      rt=null;
   }
}
