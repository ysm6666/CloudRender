using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(ChangeTex))]
public class ChangeTexInspector : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        ChangeTex changeTex = (ChangeTex)target;
        RenderTexture rt= changeTex.RT;
        GUILayout.Space(10);
        GUILayout.Label("修改纹理通道颜色");
        if (rt != null)
        {
            float aspect = (float)rt.width / (float)rt.height;
            Rect rect = GUILayoutUtility.GetRect(512*aspect, 512);
            GUI.DrawTexture(rect, rt, ScaleMode.ScaleToFit,false);
        }

        bool isclick = GUILayout.Button("Update");
        bool isFresh = GUILayout.Button("Fresh");
        if (isclick)
        {
            changeTex.BakeTexture();
        }

        if (isFresh)
        {
            changeTex.freshTex();
        }
    }
}
