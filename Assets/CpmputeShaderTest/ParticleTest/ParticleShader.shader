Shader "Custom/ParticleShader"
{
   
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        
        Pass
        {
            ZWrite Off
            Blend One One
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            struct Particle
            {
                float3 pos;
                float3 vel;
                float lifetime;
            };

            StructuredBuffer<Particle> _ParticleBuffer;
            
            struct v2f
            {
                float4 pos:SV_POSITION;
                float4 color:COLOR;
            };

            v2f vert(uint id : SV_VertexID)
            {
                v2f output;
                Particle particle =_ParticleBuffer[id];
                output.pos=TransformWorldToHClip(particle.pos);
                float speed=length(particle.vel);
                output.color=float4(lerp(float3(0.1,0.4,1),float3(1,0.2,0.5),speed),particle.lifetime);
                return output;
            }

            float4 frag(v2f input):SV_Target
            {
                return input.color;
            }
            
            ENDHLSL
        }
    }
}
