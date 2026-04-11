Shader "RayMarching/RenderCloudTest_Shape"
{
     Properties
    {
        [Toggle(_Sphere_Box_Mode)]_SphereBoxMode("Is Sphere Box Mode",Float)=0
        [Header(Sphere Box Setting)]
        [Space(10)]
        _EarthRadius("Earth Radius",Float)=6471000
        _CloudHeightMin("Cloud Layer Min Height",Float)=1500
        _CloudHeightMax("Cloud Layer Max Height",Float)=4000
        [Header(AABB Setting)]
        [Space(10)]
        _BoxCenter("Box Center",Vector)=(0,0,0,0)
        _BoxSize("Box Size",Vector)=(100,100,100,0)
        [Space(10)]
        [Header(Step Setting)]
        [Space(10)]
        _StepSize("Step Size",Range(0.1,80))=40
        _MaxStepCount("Max Step Count",Int)=128
        _MaxTotalStepDis("Max Total Step Distance",Float)=8000
        [Header(Base Shape Setting)]
        _NoiseTex("3D Noise Tex",3D)="white"{}
        _NoiseScale("Noise Scale",Float)=0.001
        _BaseNoiseWeight("Base Noise Weight",Vector)=(0.625,0.25,0.125,0)
        _DensityOffset("Density Offset",Range(0,1))=0.5
        _DensityMuti("_Density Muti",Range(0,2))=1
        [Header(Detail Shape Setting)]
        _DetailNoiseTex("Detail NoiseTex",3D)="white"{}
        _DetailNoiseWeight("Detail Noise Weight",Vector)=(1,0.625,0.25,0.125)
        _DetailNoiseStrength("Detail Noise Strength",Float)=5
        _DetailScale("Detail Scale",Float)=15
        [Header(Weather Setting)]
        _WeatherMap("Weather Map",2D)="white"{}
        _WeatherScale("Weather Scale",Float)=1
        _CloudType("Cloud Type (积云——层云)",Range(0,1))=1
        _UVOffsetStrength("UV Offset Strength",Range(0,1))=0.3
        [Header(Flow Setting)]
        _FlowSpeed_Shape_And_Weather("FlowSpeed Shape (x,y) And Weather (z,w)",Vector)=(1,0,1,0)
        [Header(BeerLambert Law)]
        _LightAbsorption("Light Absorption To Sun",Float)=1.0
        _LightAbsorptionToCamera("Light Absorption To Camera",Float)=0.3
        _PowderStrength("Powder Strength",Range(1,10))=2
        _PowderWeight("Powder Weight",Range(0,1))=1
        [Header(Cloud Color)]
        _CloudBrightColor("Cloud Bright Color",Color)=(0.8,0.5,0.5,1)
        _CloudDarkColor("Cloud Dark Color",Color)=(0.2,0.2,0.3,1)
        _DarkThreshold("Dark Threshold",Range(0,1))=0.1
        _ColorOffset("Color Offset",Range(0,1))=0.5
        _AmbientWeight("Ambient Weight",Range(0,1))=0.2
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
            #pragma target 3.5
            #pragma shader_feature_local  _Sphere_Box_Mode
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
            TEXTURE2D(_CloudBackBuffer);
            SAMPLER(sampler_CloudBackBuffer);
            
            CBUFFER_START(UnityPerMaterial)
            float4 _BoxCenter;
            float4 _BoxSize;
            float _StepSize;
            int _MaxStepCount;
            float _NoiseScale;
            float _LightAbsorption;
            float _DarkThreshold;
            float _ColorOffset;
            float4 _CloudBrightColor;
            float4 _CloudDarkColor;
            float4 _PhaseParams;
            float _LightAbsorptionToCamera;
            float _EdgeFadeDis;
            float _DensityMultiplier;
            float  _WeatherScale;
            float _CloudType;
            float4 _BaseNoiseWeight;
            float4 _DetailNoiseWeight;
            float  _DensityOffset;
            float _DetailScale;
            float _DetailNoiseStrength;
            float _DensityMuti;
            float _PowderStrength;
            float _PowderWeight;
            float _EarthRadius;
            float _CloudHeightMin;
            float _CloudHeightMax;
            float _AmbientWeight;
            float _MaxTotalStepDis;
            float4 _FlowSpeed_Shape_And_Weather;
            float _UVOffsetStrength;

            int _FrameIndex;
            float4x4 _PreVPMatrix;
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

            float Random(float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898f, 78.233f))) * 43758.5453f);
            }
            
            float2 RaySphereDst(float3 sphereCenter,float sphereRadius,float3 pos,float3 rayDir)
            {
                float3 centerToPosVector=pos-sphereCenter;
                float b=dot(rayDir,centerToPosVector); //b`=2*dot(rayDir,centerToPosVector)  b=dot(rayDir,centerToPosVector=b`/2
                float c=dot(centerToPosVector,centerToPosVector)-sphereRadius*sphereRadius;
                float delta=b*b-c; //delta=b`*b`-4*a*c 判别公式  b`=2b  a=1 c=co²-r²     
                if (delta<0) //delta<0   射线与球没有交点
                {
                    return float2(0,0);
                }
                float d=sqrt(delta);
                float disToSphere=max(0,-b-d);
                float disInSphere=max(-b+d-disToSphere,0);
                return float2(disToSphere,disInSphere);
            }

            float2 RaySphereCloudLayerDst(float3 sphereCenter,float earthRadius,float heightMin,float heightMax,float3 pos,float3 rayDir)
            {
                float2 cloudDstMin=RaySphereDst(sphereCenter,earthRadius+heightMin,pos,rayDir);
                float2 cloudDstMax=RaySphereDst(sphereCenter,earthRadius+heightMax,pos,rayDir);
                float disToCloudLayer=0;
                float disInCloudLayer=0;
                if (pos.y<=heightMin)
                {
                    float3 startPos=pos+rayDir*cloudDstMin.y;
                    if (startPos.y>=0)  //防止rayDir看向地面
                    {
                        disToCloudLayer=cloudDstMin.y;
                        disInCloudLayer=cloudDstMax.y-cloudDstMin.y;
                    }
                }
                else if (pos.y>heightMin&&pos.y<=heightMax)
                {
                    disToCloudLayer=0;
                    disInCloudLayer=cloudDstMin.y>0?cloudDstMin.x:cloudDstMax.y;
                }
                else
                {
                    disToCloudLayer=cloudDstMax.x;
                    disInCloudLayer=cloudDstMin.x>0?cloudDstMin.x-cloudDstMax.x:cloudDstMax.y;
                }
                return float2(disToCloudLayer,disInCloudLayer);
            }

            // float CalHeightGradient(float heightPercent,float cloudType)
            // {
            //     // Stratus(层云): 0.0, Stratocumulus(层积云): 0.5, Cumulus(积雨云): 1.0
            //     float stratus = saturate(remap(heightPercent, 0, 0.1, 0, 1)) 
            //                   * saturate(remap(heightPercent, 0.2, 0.3, 1, 0));
            //     
            //     float cumulus = saturate(remap(heightPercent, 0, 0.3, 0, 1)) 
            //                   * saturate(remap(heightPercent, 0.7, 1, 1, 0));
            //     
            //     return lerp(stratus,cumulus,cloudType);
            // }

            float CalHeightGradientWithWeatherMap(float heightPercent,float coverage,float cloudType)
            {
                float gMin = remap(coverage, 0, 1, 0.1, 0.6);
                float gMax = remap(coverage, 0, 1, gMin, 0.9);
                float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1)) * saturate(remap(heightPercent, 1, gMax, 0, 1));
                float heightGradient2 = saturate(remap(heightPercent,0 , coverage, 1, 0)) * saturate(remap(heightPercent, 0.0, gMin, 0, 1));
                heightGradient = saturate(lerp(heightGradient, heightGradient2,cloudType));
                return heightGradient;
            }
            
            float SampleDensity(float3 pos)
            {
                float2 weather_flow_offset=_Time.y*_WeatherScale*_FlowSpeed_Shape_And_Weather.zw;
                
                float  flowUpSpeed=length(_FlowSpeed_Shape_And_Weather.xy)*0.7;
                float3 shape_offset=float3(_FlowSpeed_Shape_And_Weather.x,flowUpSpeed,_FlowSpeed_Shape_And_Weather.y)*_Time.y*_NoiseScale;
                
                float2 weatherUV=pos.xz*_WeatherScale;
                //解决云的重复排列问题
                float weatherOffsetVal=SAMPLE_TEXTURE2D(_WeatherMap,sampler_WeatherMap,weatherUV*0.1).r;
                float2 offsetUV=weatherOffsetVal*float2(1,1.2)*_UVOffsetStrength;
               
                float3 weather_data=SAMPLE_TEXTURE2D(_WeatherMap,sampler_WeatherMap,weatherUV+offsetUV+weather_flow_offset).rgb;
                
                float heightPercent=0;
                #ifndef _Sphere_Box_Mode
                    float3 boundsMin=_BoxCenter.xyz-_BoxSize.xyz*0.5;
                    heightPercent=(pos.y-boundsMin.y)/_BoxSize.y;
                #else
                    float3 sphereCenter=float3(_WorldSpaceCameraPos.x,-_EarthRadius,_WorldSpaceCameraPos.z);
                    float disToCenter=length(pos-sphereCenter);
                    heightPercent=(disToCenter-_EarthRadius-_CloudHeightMin)/(_CloudHeightMax-_CloudHeightMin);
                    heightPercent=saturate(heightPercent);
                #endif
                
                float3 shapePos=pos*_NoiseScale+shape_offset;
                float heightGradient=CalHeightGradientWithWeatherMap(heightPercent,weather_data.r,_CloudType);
                float4 shapeNoiseData=SAMPLE_TEXTURE3D(_NoiseTex,sampler_NoiseTex,shapePos);
                _BaseNoiseWeight.yzw=_BaseNoiseWeight.yzw/max(0.0001,dot(_BaseNoiseWeight.yzw,1));
                float shapeFBM=dot(shapeNoiseData.gba,_BaseNoiseWeight.yzw);
                float base_density=remap(shapeNoiseData.r,-1*(1-shapeFBM),1,0,1);
                base_density*=heightGradient;
                
                float cloud_coverage=weather_data.r;
                float cloud_with_coverage=base_density-(1-cloud_coverage)* _DensityOffset;
                if (cloud_with_coverage>0)
                {
                    float3 detailNoise=SAMPLE_TEXTURE3D(_DetailNoiseTex,sampler_DetailNoiseTex,shapePos*_DetailScale).rgb;
                    _DetailNoiseWeight=_DetailNoiseWeight/(max(dot(_DetailNoiseWeight,1),0.0001));
                    float detailFBM=dot(detailNoise,_DetailNoiseWeight.rgb);
                    float oneMinusBaseShape=pow(1-base_density,3);
                    float final_density=cloud_with_coverage-(detailFBM)*oneMinusBaseShape*_DetailNoiseStrength;
                    
                    return max(0,final_density)*_DensityMuti;
                }
                return  0;
            }
            
            float4 RestructWorldPos(float2 uv)
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
                return float4(worldPos.xyz,depth);
                
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

            float Beer(float density,float absorption)
            {
                return exp(-1*density*absorption);
            }

            float BeerPowder(float density,float absorption)
            {
                float beer=Beer(density,absorption);
                return lerp(beer,_PowderStrength*beer*(1-exp(-2*density*absorption)),_PowderWeight);
            }
            
            float3 LightMarch(float3 pos)
            {
                Light mainLight=GetMainLight();
                float3 dirToLight=mainLight.direction;
                float disInBox=0;
                #ifndef _Sphere_Box_Mode
                    float3 boundsMin=_BoxCenter-_BoxSize.xyz*0.5;
                    float3 boundsMax=_BoxCenter+_BoxSize.xyz*0.5;
                    disInBox=RayBoxDst(boundsMin,boundsMax,pos,1/(dirToLight.xyz+1e-5)).y;
               #else
                    float3 sphereCenter=float3(_WorldSpaceCameraPos.x,-_EarthRadius,_WorldSpaceCameraPos.z);
                    disInBox=RaySphereCloudLayerDst(sphereCenter,_EarthRadius,_CloudHeightMin,_CloudHeightMax,pos,dirToLight).y;
                #endif
                float stepSize=disInBox/8;
                float totalDensity=0;
                for (int i=0;i<8;i++)
                {
                    pos+=stepSize*dirToLight;
                    totalDensity+=SampleDensity(pos)*stepSize;
                }
                float transmittance=BeerPowder(totalDensity,_LightAbsorption);
                transmittance=_DarkThreshold+(1-_DarkThreshold)*transmittance;
                return transmittance;
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

            static  const int OrderMaxtrix[16]={
                0,8,2,10,
                12,4,14,6,
                3,11,1,9,
                15,7,13,5
            };
            
            
            float4 Frag(Varyings input):SV_Target
            {
                float2 pixelPos=float2(input.positionCS.xy);
                #if UNITY_UV_STARTS_AT_TOP
                    pixelPos.y=_ScreenParams.y-pixelPos.y;
                #endif
                int2 groupPos=int2(pixelPos.x%32/8,pixelPos.y%32/8);
                int pixelIndex=groupPos.y%4*4+groupPos.x%4;
                pixelIndex=OrderMaxtrix[pixelIndex];
                if (pixelIndex != _FrameIndex)
                {
                  
                    float4 currentworldPos_And_Depth=RestructWorldPos(input.uv);
    
                    float3 cameraPos = _WorldSpaceCameraPos;                    
                    float3 worldRayDir = normalize(currentworldPos_And_Depth.xyz - cameraPos);
                    
                    float reprojectionDist = _ProjectionParams.z;
                    
                    #ifndef _Sphere_Box_Mode
                        float3 boundsMin = _BoxCenter.xyz - _BoxSize.xyz * 0.5;
                        float3 boundsMax = _BoxCenter.xyz + _BoxSize.xyz * 0.5;
                        float2 boxInfo = RayBoxDst(boundsMin, boundsMax, cameraPos, 1 / (worldRayDir.xyz + 1e-5));
                        if (boxInfo.y > 0) reprojectionDist = boxInfo.x;
                    #else
                        float3 sphereCenter = float3(cameraPos.x, -_EarthRadius, cameraPos.z);
                        float2 sphereInfo = RaySphereCloudLayerDst(sphereCenter, _EarthRadius, _CloudHeightMin, _CloudHeightMax, cameraPos, worldRayDir);
                        if (sphereInfo.y > 0) reprojectionDist = sphereInfo.x;
                    #endif
                    
                    // 这是云层的真正虚拟物理位置！
                    float3 cloudAnchorPos = cameraPos + worldRayDir * reprojectionDist;
                    float4 preClipPos=mul(_PreVPMatrix,float4(cloudAnchorPos,1));
                    
                   // float4 preClipPos=mul(_PreVPMatrix,float4(currentworldPos_And_Depth.xyz,1));
                    float4 preNdcPos=preClipPos/preClipPos.w;
                    float2 preUV=preNdcPos.xy*0.5+0.5;
                    bool isOutOfBounds = (preUV.x < 0.0 || preUV.x > 1.0 || preUV.y < 0.0 || preUV.y > 1.0);
                    if (!isOutOfBounds)
                    {
                        float4 col = SAMPLE_TEXTURE2D(_CloudBackBuffer,sampler_CloudBackBuffer,preUV);
                        return col;
                    }
                }
                // return float4(0,1,0,0);
                float3 cameraPos=_WorldSpaceCameraPos;
                float4 worldPosAndDepth=RestructWorldPos(input.uv);
                float3 worldPos=worldPosAndDepth.xyz;
                float depth=worldPosAndDepth.w;
                bool isSky=false;
                #ifdef UNITY_REVERSED_Z
                    isSky=depth<1e-5;
                #else
                    isSky=depth>0.99;
                #endif
                float3 worldRayDir=normalize(worldPos-cameraPos);
                float  distanceToPixel=isSky?1e6:distance(worldPos,cameraPos);
                float2 disInfo=float2(0,0);
                #ifndef _Sphere_Box_Mode
                    float3 boundsMin=_BoxCenter.xyz-_BoxSize.xyz*0.5;
                    float3 boundsMax=_BoxCenter.xyz+_BoxSize.xyz*0.5;
                    float3 invRayDir=1/(worldRayDir.xyz+1e-5);
                    disInfo=RayBoxDst(boundsMin,boundsMax,cameraPos,invRayDir);
                #else
                    float3 sphereCenter=float3(cameraPos.x,-_EarthRadius,cameraPos.z);
                    disInfo=RaySphereCloudLayerDst(sphereCenter,_EarthRadius,_CloudHeightMin,_CloudHeightMax,cameraPos,worldRayDir);
                #endif
                
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
                //float offset = 0;
                
                float totalStepDis=min(disInBox,distanceToPixel-disToBox);
                totalStepDis=min(totalStepDis,_MaxTotalStepDis);//防止步长太大，在计算光照时，因为步长太大而使得lightenerge爆炸
                _StepSize=max(_StepSize,totalStepDis/float(_MaxStepCount));
                currentPos += worldRayDir *_StepSize* offset;
                
                float trans_strength=1;//计算透光率
                float totalDensity=0;
                float travledDis=_StepSize*offset;
                float lightEnergy=0;

                //动态步长
                float originalStep=_StepSize;
                float bigStep=_StepSize*4;
                int zeroCounter=0;
                float isSearching=true;
                _StepSize=bigStep;
                
                [loop]
                for (int i=0;i<_MaxStepCount;i++)
                {
                    if (travledDis>=totalStepDis)
                    {
                        break;
                    }
                    if (isSearching)
                    {
                        float density=SampleDensity(currentPos);
                        if (density>0.001)
                        {
                            travledDis-=_StepSize;
                            currentPos-=worldRayDir*_StepSize;
                            isSearching=false;
                            _StepSize=originalStep;
                        }
                    }
                    else
                    {
                        float density=SampleDensity(currentPos);
                        if (density>0.001)
                        {
                            totalDensity+=density*_StepSize;
                            float lightTrans=LightMarch(currentPos);
                            lightEnergy+=_StepSize*density*trans_strength*lightTrans*phaseVal;//计算内散射
                            //从相机到此采样点的透光率
                            trans_strength=Beer(totalDensity,_LightAbsorptionToCamera);
                        }
                        else
                        {
                            zeroCounter++;
                            if (zeroCounter>8)
                            {
                                isSearching=true;
                                _StepSize=bigStep;
                            }
                        }
                    }
                    if (trans_strength<0.01)
                    {
                        break;
                    }
                    currentPos+=worldRayDir*_StepSize;
                    travledDis+=_StepSize;
                }
                float3 ambientColor=SampleSH(float3(0,1,0));
                // float3 ambientColor=unity_AmbientSky;
                lightEnergy=1-exp(-1*max(lightEnergy,0));
                float3 mainLightCol=GetMainLight().color;
                float t1=saturate(min(lightEnergy,_ColorOffset)/_ColorOffset);
                float t2=saturate((lightEnergy-_ColorOffset)/(1-_ColorOffset));
                _CloudBrightColor.rgb = _CloudBrightColor.rgb*mainLightCol.rgb;
                _CloudDarkColor.rgb = _CloudDarkColor.rgb*mainLightCol.rgb;
                float3 darkToBright=lerp(_CloudDarkColor,_CloudBrightColor,t1);
                float3 cloudColor=lerp(darkToBright,mainLightCol.rgb,t2)+_AmbientWeight*ambientColor;
                return float4(cloudColor,trans_strength);
            }
            
            ENDHLSL
        }

        Pass
        {
            Blend OneMinusSrcAlpha SrcAlpha
            
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
