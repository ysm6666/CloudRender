using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(GenNoiseTool))]
public class GenNoiseInspector : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        GenNoiseTool gennoise = (GenNoiseTool)target;
        GUILayout.Space(15);
        if (GUILayout.Button("刷新纹理", GUILayout.Height(30)))
        {
            gennoise.GenerateNoise();
            Repaint();
        }
        GUILayout.Space(15);
        GUILayout.Label("噪声图预览", EditorStyles.boldLabel);
        if (gennoise.noiseMode==GenNoiseTool.NoiseMode._2D)
        {
            RenderTexture renderTexture = gennoise._RenderTexture;
            if (renderTexture != null)
            {
                Rect rect = GUILayoutUtility.GetRect(512, 512);
                GUI.DrawTexture(rect, renderTexture, ScaleMode.ScaleToFit,false);
            }
        }
        else
        {
            RenderTexture renderTexture = gennoise.SlicedTexture;
            if (renderTexture != null)
            {
                Rect rect = GUILayoutUtility.GetRect(512, 512);
                GUI.DrawTexture(rect, renderTexture, ScaleMode.ScaleToFit,false);
            }
        }
        GUILayout.Space(15);
        if (GUILayout.Button("烘焙纹理",GUILayout.Height(30)))
        {
            if (gennoise.noiseMode == GenNoiseTool.NoiseMode._3D)
            {
                gennoise.Bake3DNoise();
            }
            else
            {
                Debug.Log("not support 2D mode");
            }
        }
        
    }
}
