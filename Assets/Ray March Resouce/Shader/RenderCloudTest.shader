Shader "RayMarching/RenderCloudTest"
{
     Properties
    {
        _BoxCenter("Box Center",Vector)=(0,0,0,0)
        _BoxSize("Box Size",Vector)=(100,100,100,0)
        _StepSize("Step Size",Range(0.1,1))=0.5
        _MaxStepCount("Max Step Count",Int)=128
        [Header(Shape Setting)]
        _NoiseTex("3D Noise Tex",3D)="white"{}
        _ShapeNoiseWeight("Shape Noise Weight",Vector)=(1,1,1,1)
        _DensityOffset("Density Offset",Float)=0
        _NoiseScale("Noise Scale",Float)=0.001
        _WeatherMap("Weather Map",2D)="white"{}
        _FlowSpeed("Flow Speed (shape,detail,weather,mask) ",Vector)=(0.05,0.01,0.1,0)
        _EdgeFadeDis("Edge Fade Distance",Float)=10
        _DetailNoiseTex("Detail Noise Texture",3D)="white"{}
        _DetailWeight("Detail Weight",Float)=3
        _DetailNoiseWeight("Detail Noise Weight",Range(0,2))=1
        _DensityMultiplier("Density Multiplier",Float)=1
        [Header(BeerLambert Law)]
        _LightAbsorption("Light Absorption To Sun",Float)=1.0
        _LightAbsorptionToCamera("Light Absorption To Camera",Float)=0.3
        [Header(Cloud Color)]
        _CloudBrightColor("Cloud Bright Color",Color)=(0.8,0.5,0.5,1)
        _CloudDarkColor("Cloud Dark Color",Color)=(0.2,0.2,0.3,1)
        _DarkThreshold("Dark Threshold",Range(0,1))=0.1
        _ColorAOffset("ColorA Offset",Range(0,2))=1
        _ColorBOffset("ColorB Offset",Range(0,2))=0.5
        [Header(Mie Scaterring )]
        _PhaseParams("Phase Params (g1,g2,lerpFactor) ",Vector)=(0.7,-0.2,0.1,0)
    }
    SubShader
    {
        Tags {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
        }
        Cull Off
        ZWrite Off
        ZTest Always
        
        Pass
        {
             Tags
             {
                 "LightMode"="UniversalForward"
             }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           // #define PI 3.14159
            struct Atrributes
            {
                float4 positionOS:POSITION;
                float2 uv:TEXCOORD0;
                 uint vertexID:SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS:SV_POSITION;
                float2 uv:TEXCOORD0;
            };

            
             TEXTURE2D(_BlitTexture);
             SAMPLER(sampler_BlitTexture);
             TEXTURE3D(_NoiseTex);
             SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
            TEXTURE3D(_DetailNoiseTex);
            SAMPLER(sampler_DetailNoiseTex);
            
            CBUFFER_START(UnityPerMaterial)
            float4 _BoxCenter;
            float4 _BoxSize;
            float _StepSize;
            int _MaxStepCount;
            float _NoiseScale;
            float _LightAbsorption;
            float _DarkThreshold;
            float _ColorAOffset;
            float _ColorBOffset;
            float4 _CloudBrightColor;
            float4 _CloudDarkColor;
            float4 _PhaseParams;
            float4 _FlowSpeed;
            float4 _ShapeNoiseWeight;
            float _DensityOffset;
            float _LightAbsorptionToCamera;
            float _EdgeFadeDis;
            float _DetailWeight;
            float _DetailNoiseWeight;
            float _DensityMultiplier;
            CBUFFER_END

            Varyings Vert(Atrributes input)
            {
                Varyings output;
                // output.positionCS=TransformObjectToHClip(input.positionOS);
                // output.uv=input.uv;
                output.positionCS=GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv=GetFullScreenTriangleTexCoord(input.vertexID);
                return  output;
            }

            float remap(float original_val,float original_min,float original_max,float new_min,float new_max)
            {
                return new_min+(((original_val-original_min)/(original_max-original_min))*(new_max-new_min));
            }
            
            float SampleDensity(float3 pos)
            {
                float3 boundsMin=_BoxCenter.xyz-_BoxSize.xyz*0.5;
                float3 boundsMax=_BoxCenter.xyz+_BoxSize.xyz*0.5;
                bool insideX=pos.x>boundsMin.x&&pos.x<boundsMax.x;
                bool insideY=pos.y>boundsMin.y&&pos.y<boundsMax.y;
                bool insideZ=pos.z>boundsMin.z&&pos.z<boundsMax.z;
                if (!insideX||!insideY||!insideZ)
                {
                    return 0;
                }

                float3 shapeOffset=_Time.y*float3(_FlowSpeed.x,_FlowSpeed.x*0.2,0);
                float3 detailOffset=_Time.y*float3(_FlowSpeed.y,_FlowSpeed.y*0.2,0);
                float2 weatherOffset=_Time.y*float2(_FlowSpeed.z,0);
                
                float2 weatherUV=(pos.xz-boundsMin.xz)/max(_BoxSize.x,_BoxSize.z);
                //weatherUV+=_FlowSpeed.xy*_Time.y;
                float weatherHeight=SAMPLE_TEXTURE2D(_WeatherMap,sampler_WeatherMap,weatherUV+weatherOffset).r;
                float gmin=saturate(remap(weatherHeight,0,1,0.1,0.4));
                float heightPercent=(pos.y-boundsMin.y)/_BoxSize.y;
                float heightGradient=saturate(remap(heightPercent,0,max(weatherHeight,1e-4),1,0))*saturate(remap(heightPercent,0,gmin,0,1));
                //float heightGradient=saturate(remap(heightPercent,0,max(weatherHeight,1e-4),1,0));
                float dstFromEdgeX=min(_EdgeFadeDis,min(pos.x-boundsMin.x,boundsMax.x-pos.x));
                float dstFromEdgeZ=min(_EdgeFadeDis,min(pos.z-boundsMin.z,boundsMax.z-pos.z));
                float edgeWeight=min(dstFromEdgeX,dstFromEdgeZ)/_EdgeFadeDis;
                heightGradient*=edgeWeight;
                
                float3 uvw=pos.xyz*_NoiseScale;
                float4 noiseValue=SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,uvw+shapeOffset);
                float4 detailNoise=SAMPLE_TEXTURE3D(_DetailNoiseTex,sampler_DetailNoiseTex,uvw*15+detailOffset);
                float4 normalizeWeight=_ShapeNoiseWeight/dot(_ShapeNoiseWeight,1);
                float shapeFBM=dot(noiseValue,normalizeWeight)*heightGradient;
                float baseShapeDensity=shapeFBM+_DensityOffset*0.01;
                float density=max(0,baseShapeDensity);
                if (density>0)
                {
                    float detailFBM=pow(detailNoise.r,_DetailWeight);
                    float oneMinusDensity=1-density;
                    float detailErodeWeight=pow(oneMinusDensity,3);
                    density=density-detailFBM*detailErodeWeight*_DetailNoiseWeight;
                    return saturate(density*_DensityMultiplier);
                    //return density*_DensityMultiplier;
                }
                return 0;
            }
            
            float3 RestructWorldPos(float2 uv)
            {
                float depth=SampleSceneDepth(uv);
                
                #ifndef  UNITY_UV_STARTS_AT_TOP
                depth=depth*2-1;
                #endif
               
                float2 ndc_uv=uv*2-1;
                float4 ndcPos=float4(ndc_uv,depth,1.0);
                 
                 ndcPos.y*=_ProjectionParams.x;
                
                //viewPortPos=ClipPos/ClipPos.w
                float4 worldPos=mul(unity_MatrixInvVP,ndcPos);
                //worldPos.w=1/ClipPos.w
                worldPos=worldPos/worldPos.w;
                return worldPos.xyz;
                
            }

            float Random(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            float2 RayBoxDst(float3 boundsMin,float3 boundsMax,float3 rayOrigin,float3 invRayDir)
            {
                float3 t0=(boundsMin-rayOrigin)*invRayDir;
                float3 t1=(boundsMax-rayOrigin)*invRayDir;
                float3 tmin=min(t0,t1);
                float3 tmax=max(t0,t1);
                float disIn=max(max(tmin.x,tmin.y),tmin.z);
                float disOut=min(min(tmax.x,tmax.y),tmax.z);
                float disToBox=max(0,disIn);
                float disInBox=max(0,disOut-disToBox);
                return float2(disToBox,disInBox);
            }

            float3 LightMarch(float3 pos)
            {
                Light mainLight=GetMainLight();
                float3 dirToLight=mainLight.direction;
                float3 boundsMin=_BoxCenter-_BoxSize.xyz*0.5;
                float3 boundsMax=_BoxCenter+_BoxSize.xyz*0.5;
                float disInBox=RayBoxDst(boundsMin,boundsMax,pos,1/(dirToLight.xyz+1e-5)).y;
                float stepSize=disInBox/8;
                float totalDensity=0;
                for (int i=0;i<8;i++)
                {
                    pos+=stepSize*dirToLight;
                    totalDensity+=SampleDensity(pos);
                }
                float transmittance=exp(-1*totalDensity*_LightAbsorption)*(1-exp(-2*totalDensity*_LightAbsorption));
                transmittance=_DarkThreshold+(1-_DarkThreshold)*transmittance;
                //  float3 cloudColor=lerp(_CloudBrightColor,mainLight.color,saturate(transmittance*_ColorAOffset));
                // cloudColor=lerp(_CloudDarkColor,cloudColor,saturate(pow(transmittance*_ColorBOffset,3)));
                _ColorBOffset=clamp(_ColorBOffset,0.001,0.999);
                float3 cloudColor=lerp(lerp(_CloudDarkColor,_CloudBrightColor,min(transmittance,_ColorBOffset)/_ColorBOffset),mainLight.color,max(transmittance-_ColorBOffset,0)/(1-_ColorBOffset));
                return cloudColor;
            }
            

            //HG相函数用于模拟米氏散射，计算结果用于描述采样点处光有多少能量进行内散射
            //g为各向异性系数,cosTheta为光源方向与观察方向的夹角余弦值
            //此处观察方向是从相机到顶点的向量
            float HGPhaseFunc(float cosTheta,float g)
            {
                float g2=g*g;
                float denom=1+g2-2*g*cosTheta;
                return (1-g2)/(4*PI*pow(max(denom,1e-4),1.5));
            }

            //双瓣HG，模拟云既有较强的向前散射，也有较弱的向后散射的特性
            float DualHg(float cosTheta,float g1,float g2)
            {
                float blend = lerp(HGPhaseFunc(cosTheta,g1),HGPhaseFunc(cosTheta,g2),0.5);
                return  _PhaseParams.z+_PhaseParams.w*blend;
                //return blend;
            }
            
            float4 Frag(Varyings input):SV_Target
            {
               
                //half4 col=SAMPLE_TEXTURE2D(_BlitTexture,sampler_BlitTexture,input.uv);
                float3 cameraPos=_WorldSpaceCameraPos;
                float3 worldPos=RestructWorldPos(input.uv);
                float3 worldRayDir=normalize(worldPos-cameraPos);
                float  distanceToPixel=distance(worldPos,cameraPos);
                float3 boundsMin=_BoxCenter.xyz-_BoxSize.xyz*0.5;
                float3 boundsMax=_BoxCenter.xyz+_BoxSize.xyz*0.5;
                float3 invRayDir=1/(worldRayDir.xyz+1e-5);
                float2 disInfo=RayBoxDst(boundsMin,boundsMax,cameraPos,invRayDir);
                float disToBox=disInfo.x;
                float disInBox=disInfo.y;

                float3 lightDir = normalize(GetMainLight().direction); // 记得包含 Lighting.hlsl
                float cosTheta = dot(worldRayDir, lightDir);
                // 米氏散射
                float phaseVal=DualHg(cosTheta,_PhaseParams.x,_PhaseParams.y);
                //float phaseVal=HGPhaseFunc(cosTheta,_PhaseParams.x);
                
                if (disInBox<=0||disToBox>=distanceToPixel)
                {
                    return float4(0,0,0,1);
                }
                float3 currentPos=cameraPos+worldRayDir*disToBox;
                
                float offset = Random(input.uv);
                //float offset = 1;
                
                float totalStepDis=min(disInBox,distanceToPixel-disToBox);
                _StepSize=max(_StepSize,totalStepDis/float(_MaxStepCount));
                currentPos += worldRayDir *_StepSize* offset;
                
                float translength=1;//计算透光率
                
                float travledDis=_StepSize*offset;
                float3 lightEnergy=0;
                [loop]
                for (int i=0;i<_MaxStepCount;i++)
                {
                    if (travledDis>=totalStepDis)
                    {
                        break;
                    }
                    //totalDensity+=SampleDensity(currentPos);
                    float density=SampleDensity(currentPos);
                    if (density>0)
                    {
                        float3 lightCol=LightMarch(currentPos)*GetMainLight().color*phaseVal;
                        lightEnergy+=lightCol*translength*_StepSize*density;//计算内散射
                        //从相机到此采样点的透光率
                        translength*=exp(-1*density*_StepSize*_LightAbsorptionToCamera);
                    }
                    if (translength<0.01)
                    {
                        break;
                    }
                    currentPos+=worldRayDir*_StepSize;
                    travledDis+=_StepSize;
                }
                return float4(lightEnergy,translength);
                //float3 finalColor=col.rgb*translength+lightEnergy;
            }
            
            ENDHLSL
        }

        Pass
        {
            Blend One SrcAlpha
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal//ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS:POSITION;
                float2 uv:TEXCOORD0;
                uint vertexID:SV_VertexID;
            };

            struct Varyings
            {
                float2 uv:TEXCOORD0;
                float4 positionCS:SV_POSITION;
            };
            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS=GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv=GetFullScreenTriangleTexCoord(input.vertexID);
                return output;
            }

            float4 frag(Varyings input):SV_Target
            {
                float4 col=SAMPLE_TEXTURE2D(_BlitTexture,sampler_BlitTexture,input.uv);
                return col;
            }
            
            ENDHLSL
        }
    }
}
