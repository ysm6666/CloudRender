Shader "Custom/NoiseTest"
{
    Properties
    {
        _Scale("Scale",Float)=1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
       
        Pass
        {
           HLSLPROGRAM
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #pragma vertex vert
           #pragma fragment frag
           struct a2v
           {
               float4 positionOS:POSITION;
               float2 uv:TEXCOORD0;
           };

           struct v2f
           {
               float4 positonCS:SV_POSITION;
               float3 uv_and_offset:TEXCOORD0;
           };

           TEXTURE2D(_2DNoise);
           SAMPLER(sampler_LinearRepeat);
           float _Scale;
           v2f vert(a2v input)
           {
               v2f output;
               float noiseVal=SAMPLE_TEXTURE2D_LOD(_2DNoise,sampler_LinearRepeat,input.uv,0).r*2-1;
               float3 worldPos=TransformObjectToWorld(input.positionOS.xyz);
               worldPos.y+=noiseVal*_Scale;
               output.positonCS=TransformWorldToHClip(worldPos);
               output.uv_and_offset=float3(input.uv,noiseVal);
               return output;
           }
           
           float4 frag(v2f input):SV_Target
           {
               float offset=input.uv_and_offset.b*0.5+0.5;
               float4 col=lerp(float4(0,0,1,1),float4(1,1,0,1),offset);
               return col;
           }
           
           ENDHLSL
        }
    }
}
