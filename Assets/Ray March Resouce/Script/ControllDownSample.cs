using System.Collections;
using System.Collections.Generic;
using UnityEngine.UI;
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class ControllDownSample : MonoBehaviour
{
    public Slider slider;
    public UniversalRendererData rendererData;
    private CloudRenderFeature cloudRenderFeature;
    
    void Start()
    {
        if(slider != null) slider.onValueChanged.AddListener(onSliderChanged);
        foreach (var renderfeature in rendererData.rendererFeatures)
        {
            if (renderfeature is CloudRenderFeature)
            {
                cloudRenderFeature = renderfeature as CloudRenderFeature;
                break;
            }
        }
    }

    public void onSliderChanged(float value)
    {
        int downSampleVal = (int)(value * 3 + 1);
        if (cloudRenderFeature!=null)
        {
            cloudRenderFeature.SetDownsample(downSampleVal);
        }
    }
}
