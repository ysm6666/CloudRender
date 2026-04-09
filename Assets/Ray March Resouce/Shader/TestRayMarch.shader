Shader "RayMarching/TestRayMarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BoxCenter("Box Center",Vector)=(0,0,0,0)
        _BoxSize("Box Size",Vector)=(100,100,100,0)
        _StepSize("Step Size",Range(0.1,1))=0.5
        _MaxStepCount("Max Step Count",Int)=128
        [Header(Shape Setting)]
        _noiseTex("3D Noise Tex",3D)="white"{}
        _ShapeNoiseWeight("Shape Noise Weight",Vector)=(1,1,1,1)
        _DensityOffset("Density Offset",Float)=0
        _NoiseThreshold("Noise Threshold",Range(0,1))=0.3
         _shapeTiling("_shapeTiling",Float)=0.001
        _WeatherMap("Weather Map",2D)="white"{}
        _xy_Speed_zw_Warp("_xy_Speed_zw_Warp",Vector)=(0.05,0.01,0,0)
        [Header(BeerLambert Law)]
        _lightAbsorptionTowardSun("_lightAbsorptionTowardSun",Float)=0.16
        _LightAbsorptionToCamera("Light Absorption To Camera",Float)=0.3
        [Header(Cloud Color)]
        _colA("Cloud Bright Color",Color)=(0.8,0.5,0.5,1)
        _colB("Cloud Dark Color",Color)=(0.2,0.2,0.3,1)
        _DarkThreshold("Dark Threshold",Range(0,1))=0.1
        _colorOffset1("ColorA Offset",Range(0,2))=0.86
        _colorOffset2("ColorB Offset",Range(0,2))=0.85
        [Header(Mie Scaterring )]
        _phaseParams("Phase Params (g1,g2,lerpFactor) ",Vector)=(0.7,-0.2,0.1,0)
    }
    HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

             TEXTURE2D(_MainTex);
             SAMPLER(sampler_MainTex);
             TEXTURE2D(_BlitTexture);
             SAMPLER(sampler_BlitTexture);
             TEXTURE3D(_noiseTex);
             SAMPLER(sampler_noiseTex);
            TEXTURE2D(_WeatherMap);
            SAMPLER(sampler_WeatherMap);
           
            CBUFFER_START(UnityPerMaterial)
            float4 _BoxCenter;
            float4 _BoxSize;
            float _StepSize;
            int _MaxStepCount;
            float  _shapeTiling;
            float _NoiseThreshold;
            float _lightAbsorptionTowardSun;
            float _DarkThreshold;
            float _colorOffset1;
            float _colorOffset2;
            float4 _colA;
            float4 _colB;
            float4 _phaseParams;
            float4 _xy_Speed_zw_Warp;
            float4 _ShapeNoiseWeight;
            float _DensityOffset;
            float _LightAbsorptionToCamera;
            CBUFFER_END

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

            //计算世界空间坐标
            float3 RestructWorldPos(float2 uv)
            {
                float depth=SampleSceneDepth(uv);
                float2 ndc_uv=uv*2-1;
                float4 viewPortPos=float4(ndc_uv,depth,1.0);

                 #if UNITY_UV_STARTS_AT_TOP
                 viewPortPos.y=-viewPortPos.y;
                 #endif
                
                //viewPortPos=ClipPos/ClipPos.w
                float4 worldPos=mul(unity_MatrixInvVP,viewPortPos);
                //worldPos.w=1/ClipPos.w
                worldPos=worldPos/worldPos.w;
                return worldPos.xyz;
                
            }

            // Linear falloff.
            float CalcAttenuation(float d, float falloffStart, float falloffEnd)
            {
                return saturate((falloffEnd - d) / (falloffEnd - falloffStart));
            }

            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
            {
                return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
            }

            // Henyey-Greenstein
            float hg(float a, float g) {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }

            float phase(float a) {
                float blend = .5;
                float hgBlend = hg(a, _phaseParams.x) * (1 - blend) + hg(a, -_phaseParams.y) * blend;
                return _phaseParams.z + hgBlend * _phaseParams.w;
                //return  hgBlend;
            }

            float sampleDensity(float3 rayPos) 
            {
                float3 _boundsMax=_BoxCenter+_BoxSize.xyz*0.5;
                float3 _boundsMin=_BoxCenter-_BoxSize.xyz*0.5;
                float3 boundsCentre = (_boundsMax + _boundsMin) * 0.5;
                float3 size = _boundsMax - _boundsMin;
                float speedShape = _Time.y * _xy_Speed_zw_Warp.x;
                float speedDetail = _Time.y * _xy_Speed_zw_Warp.y;

                //float3 uvwShape  = rayPos * _shapeTiling + float3(speedShape, speedShape * 0.2,0);
                //float3 uvwDetail = rayPos * _detailTiling + float3(speedDetail, speedDetail * 0.2,0);

                 //float3 uvwShape  = rayPos * _shapeTiling+_Time.y*_xy_Speed_zw_Warp.xyz;
                float3 uvwShape  = rayPos * _shapeTiling;
                // float3 uvwDetail = rayPos * _detailTiling;

                 float2 uv = (size.xz * 0.5f + (rayPos.xz - boundsCentre.xz) ) /size.xz;
                //uv+=_Time.y*_xy_Speed_zw_Warp.xy;
                // float2 uv =(rayPos.xz-_boundsMin.xz)/size.xz;
                //float4 maskNoise = tex2Dlod(_maskNoise, float4(uv + float2(speedShape * 0.5, 0), 0, 0));
                 float4 weatherMap = SAMPLE_TEXTURE2D(_WeatherMap,sampler_WeatherMap,uv);

                // float4 maskNoise = float4(1,1,1,1);
                // float4 weatherMap = float4(1,1,1,1);

                // float4 shapeNoise = tex3Dlod(_noiseTex, float4(uvwShape + (maskNoise.r * _xy_Speed_zw_Warp.z * 0.1), 0));
                // float4 detailNoise = tex3Dlod(_noiseDetail3D, float4(uvwDetail + (shapeNoise.r * _xy_Speed_zw_Warp.w * 0.1), 0));

                float4 shapeNoise = SAMPLE_TEXTURE3D(_noiseTex,sampler_noiseTex,uvwShape);
               // float4 detailNoise = tex3Dlod(_noiseDetail3D, float4(uvwDetail, 0));

                //边缘衰减
                // const float containerEdgeFadeDst = 10;
                // float dstFromEdgeX = min(containerEdgeFadeDst, min(rayPos.x - _boundsMin.x, _boundsMax.x - rayPos.x));
                // float dstFromEdgeZ = min(containerEdgeFadeDst, min(rayPos.z - _boundsMin.z, _boundsMax.z - rayPos.z));
                // float edgeWeight = min(dstFromEdgeZ, dstFromEdgeX) / containerEdgeFadeDst;
                //
                // float gMin = remap(weatherMap.x, 0, 1, 0.1, 0.6);
                // float gMax = remap(weatherMap.x, 0, 1, gMin, 0.9);
                 float heightPercent = (rayPos.y - _boundsMin.y) / size.y;
                // float heightGradient = saturate(remap(heightPercent, 0.0, gMin, 0, 1)) * saturate(remap(heightPercent, 1, gMax, 0, 1));
                // float heightGradient2 = saturate(remap(heightPercent, 0.0, weatherMap.r, 1, 0)) * saturate(remap(heightPercent, 0.0, gMin, 0, 1));
                // heightGradient = saturate(lerp(heightGradient, heightGradient2,_heightWeights));
                 float heightGradient=saturate(remap(heightPercent,0,weatherMap.r,1,0));
                //heightGradient *= edgeWeight;
                
                // float4 normalizedShapeWeights = _ShapeNoiseWeight / dot(_ShapeNoiseWeight, 1);
                // float shapeFBM = dot(shapeNoise, normalizedShapeWeights) * heightGradient;
                // float baseShapeDensity = shapeFBM + _DensityOffset * 0.01;
                float baseShapeDensity=shapeNoise;
                return baseShapeDensity;
                //return shapeNoise;
                // if (baseShapeDensity > 0)
                // {
                //     float detailFBM = pow(detailNoise.r, _detailWeights);
                //     float oneMinusShape = 1 - baseShapeDensity;
                //     float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
                //     float cloudDensity = baseShapeDensity - detailFBM * detailErodeWeight * _detailNoiseWeight;
                //    // float cloudDensity = baseShapeDensity;
                //
                //     return saturate(cloudDensity * _densityMultiplier);
                // }
                // return 0;
            }
                                    
                            //边界框最小值       边界框最大值         
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, 
                            //世界相机位置      反向世界空间光线方向
                            float3 rayOrigin, float3 invRaydir) 
            {
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }
            // case 1: 射线从外部相交 (0 <= dstA <= dstB)
            // dstA是dst到最近的交叉点，dstB dst到远交点
            // case 2: 射线从内部相交 (dstA < 0 < dstB)
            // dstA是dst在射线后相交的, dstB是dst到正向交集
            // case 3: 射线没有相交 (dstA > dstB)

            float3 lightmarch(float3 position ,float dstTravelled)
            {
                float _boundsMax=_BoxCenter+_BoxSize.xyz*0.5;
                float _boundsMin=_BoxCenter-_BoxSize.xyz*0.5;
                 Light mainLight=GetMainLight();
                float3 dirToLight = mainLight.direction.xyz;

                //灯光方向与边界框求交，超出部分不计算
                float dstInsideBox = rayBoxDst(_boundsMin, _boundsMax, position, 1 / dirToLight).y;
                float stepSize = dstInsideBox / 8;
                float totalDensity = 0;

                for (int step = 0; step < 8; step++) { //灯光步进次数
                    position += dirToLight * stepSize; //向灯光步进
                    //totalDensity += max(0, sampleDensity(position) * stepSize);                     totalDensity += max(0, sampleDensity(position) * stepSize);
                    totalDensity += max(0, sampleDensity(position));

                }
                float transmittance = exp(-totalDensity * _lightAbsorptionTowardSun);

                //将重亮到暗映射为 3段颜色 ,亮->灯光颜色 中->ColorA 暗->ColorB
                float3 cloudColor = lerp(_colA, mainLight.color.rgb, saturate(transmittance * _colorOffset1));
                cloudColor = lerp(_colB, cloudColor, saturate(pow(transmittance * _colorOffset2, 3)));
                float _darknessThreshold=0.0;
                return _darknessThreshold + transmittance * (1 - _darknessThreshold) * cloudColor;
                //return transmittance * cloudColor;
            }

            Varyings Vert(Atrributes input)
            {
                Varyings output;
                // output.positionCS=TransformObjectToHClip(input.positionOS);
                // output.uv=input.uv;
                output.positionCS=GetFullScreenTriangleVertexPosition(input.vertexID);
                output.uv=GetFullScreenTriangleTexCoord(input.vertexID);
                return  output;
            }
            
			float4 Frag(Varyings input) : SV_Target
			{
                 half4 col=SAMPLE_TEXTURE2D(_BlitTexture,sampler_BlitTexture,input.uv);
                float3 cameraPos=_WorldSpaceCameraPos;
                float3 worldPos=RestructWorldPos(input.uv);
                float3 worldRayDir=normalize(worldPos-cameraPos);
                float  distanceToPixel=distance(worldPos,cameraPos);
                float3 boundsMin=_BoxCenter.xyz-_BoxSize.xyz*0.5;
                float3 boundsMax=_BoxCenter.xyz+_BoxSize.xyz*0.5;
                float3 invRayDir=1/(worldRayDir.xyz+1e-5);
                float2 disInfo=rayBoxDst(boundsMin,boundsMax,cameraPos,invRayDir);
                float disToBox=disInfo.x;
                float disInBox=disInfo.y;

                float3 lightDir = normalize(GetMainLight().direction); // 记得包含 Lighting.hlsl
                float cosTheta = dot(worldRayDir, lightDir);
                // 米氏散射
                float phaseVal=phase(cosTheta);
                //float phaseVal=HGPhaseFunc(cosTheta,_PhaseParams.x);
                
                if (disInBox<=0||disToBox>=distanceToPixel)
                {
                    return col;
                }
                float3 currentPos=cameraPos+worldRayDir*disToBox;
                
                //float offset = Random(input.uv);
                float offset = 1;
                
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
                    float density=sampleDensity(currentPos);
                    if (density>0)
                    {
                        float3 lightCol=lightmarch(currentPos,0);
                        lightEnergy+=lightCol*translength*_StepSize*density*phaseVal;//计算内散射
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
                float3 finalColor=col.rgb*translength+lightEnergy;
                return float4(finalColor,col.a);
			}

            // float DownsampleDepth(VaryingsDefault i) : SV_Target
            // {
            //     float2 texelSize = 0.5 * _CameraDepthTexture_TexelSize.xy;
            //     float2 taps[4] = { 	float2(i.texcoord + float2(-1,-1) * texelSize),
            //                         float2(i.texcoord + float2(-1,1) * texelSize),
            //                         float2(i.texcoord + float2(1,-1) * texelSize),
            //                         float2(i.texcoord + float2(1,1) * texelSize)};
            //
            //     float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, taps[0]);
            //     float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, taps[1]);
            //     float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, taps[2]);
            //     float depth4 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, taps[3]);
            //
            //     float result = min(depth1, min(depth2, min(depth3, depth4)));
            //
            //     return result;
            // }
            //
            // float4 FragCombine(VaryingsDefault i) : SV_Target
            // {
            //     float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
            //     float4 cloudColor = SAMPLE_TEXTURE2D(_DownsampleColor, sampler_DownsampleColor, i.texcoord);
            //
            //     color.rgb *= cloudColor.a;
            //     color.rgb += cloudColor.rgb;
            //     return color;
            // }

            


            ENDHLSL


            SubShader
            {
                Cull Off ZWrite Off ZTest Always

                Pass
                {
                    HLSLPROGRAM

                    #pragma vertex Vert
                    #pragma fragment Frag

                    ENDHLSL
                }

//                Pass
//                {
//                     Cull Off ZWrite Off ZTest Always
//
//                     HLSLPROGRAM
//                     #pragma vertex VertDefault
//                     #pragma fragment DownsampleDepth
//                     ENDHLSL
//                }
//
//                Pass
//                {
//                    HLSLPROGRAM
//
//                    #pragma vertex VertDefault
//                    #pragma fragment FragCombine
//
//                    ENDHLSL
//                }

            }
}
