//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b0)
{
    //matrix World;
    //matrix View;
    //matrix Projection;
    //float3 vOutputColor;
    //float Gamma;
    
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;
    
    float screenWidth;
    float screenHeight;
    int toggleBlur;
    float blurStrength;
}


Texture2D txDiffuse : register(t0);
Texture2D txSpecular : register(t1);
Texture2D txNormal : register(t2);
Texture2D txParallax : register(t3);
Texture2D shadowMap : register(t4);

//SamplerState samLinear : register(s0);


SamplerState samLinear : register(s0)
{
    Filter = ANISOTROPIC;
    MaxAnisotropy = 4;

    AddressU = clamp;   // was wrap
    AddressV = clamp; // was wrap
};


SamplerComparisonState shadowSampler : register(s1)
{
    //Filter = ANISOTROPIC;
    //MaxAnisotropy = 4;
    Filter = COMPARISON_MIN_MAG_MIP_LINEAR;
    AddressU = clamp;   // Might want clamp?
    AddressV = clamp; // Might want clamp?
    ComparisonFunc = LESS_EQUAL;
};

#define MAX_LIGHTS 1
// Light types.
#define DIRECTIONAL_LIGHT 0
#define POINT_LIGHT 1
#define SPOT_LIGHT 2

struct _Material
{
    float4 Emissive; // 16 bytes
							//----------------------------------- (16 byte boundary)
    float4 Ambient; // 16 bytes
							//------------------------------------(16 byte boundary)
    float4 Diffuse; // 16 bytes
							//----------------------------------- (16 byte boundary)
    float4 Specular; // 16 bytes
							//----------------------------------- (16 byte boundary)
    float SpecularPower; // 4 bytes
    bool UseTexture; // 4 bytes
    bool UseSpecular; // 4 bytes
    bool UseNormal; // 4 bytes
							//----------------------------------- (16 byte boundary)
    bool UseParallax; // 4 bytes
    float ParallaxHeight; // 4 bytes
    bool CastShadows; // 4 bytes
    int Padding1; // 4 bytes
                            //----------------------------------- (16 byte boundary)
}; // Total:               // 96 bytes ( 6 * 16 )

cbuffer MaterialProperties : register(b1)
{
    _Material Material;
};

struct Light
{
    float4 Position; // 16 bytes
										//----------------------------------- (16 byte boundary)
    float4 Direction; // 16 bytes
										//----------------------------------- (16 byte boundary)
    float4 Color; // 16 bytes
										//----------------------------------- (16 byte boundary)
    float SpotAngle; // 4 bytes
    float ConstantAttenuation; // 4 bytes
    float LinearAttenuation; // 4 bytes
    float QuadraticAttenuation; // 4 bytes
										//----------------------------------- (16 byte boundary)
    int LightType; // 4 bytes
    bool Enabled; // 4 bytes
    float lightBias; // 4 bytes
    float Gamma; // 4 bytes
										//----------------------------------- (16 byte boundary)
}; // Total:                           // 80 bytes (5 * 16)

cbuffer LightProperties : register(b2)
{
    float4 EyePosition; // 16 bytes
										//----------------------------------- (16 byte boundary)
    float4 GlobalAmbient; // 16 bytes
										//----------------------------------- (16 byte boundary)
    Light Lights[MAX_LIGHTS]; // 80 * 8 = 640 bytes
}; 

cbuffer ConstantShadowMapBuffer : register(b3)
{
    float4x4 lprojection;
    float4x4 lview;
    float4 lmodel;
};


//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float4 Pos : POSITION;
    float3 Norm : NORMAL;
    float2 Tex : TEXCOORD0;
    float3 tangent : TANGENT;
    float3 binormal : BINORMAL;
};

struct PS_INPUT
{
    float4 Pos : SV_POSITION;
    float4 worldPos : POSITION;
    float3 Norm : NORMAL;
    float2 Tex : TEXCOORD0;
    
    float3 tangent : TANGENT;
    float3 binormal : BINORMAL;
    
    float4 lightSpacePos : POSITION1;
};

// Helper func to convert world norms to tangent space
float3 VectorToTangentSpace(float3 vectorV, float3x3 TBN_inv)
{
    float3 tangentSpaceNormal = normalize(mul(vectorV, TBN_inv));
    return tangentSpaceNormal;
}

// Simple Parallax effect
float2 ParallaxMapping(float2 texCoords, float3 viewDir)
{
    float texHeight = txParallax.Sample(samLinear, texCoords).x;
    float2 parallax = viewDir.xy / viewDir.z * (texHeight * Material.ParallaxHeight);
    return texCoords - parallax;
}

// Parallax Occlusion mapping
float2 ParallaxOccMapping(float2 texCoords, float3 viewDir)
{
    const float minLayers = 8.0; // Samples when were head on facing texture
    const float maxLayers = 32.0; // Samples when viewing at extreme angles
    // lerp between the number number of samples required based on our view angle
    float numLayers = lerp(maxLayers, minLayers, max(dot(float3(0.0, 0.0, 1.0), viewDir), 0.0)); 
    float2 parallaxAmmount = viewDir.xy * Material.ParallaxHeight; // the amount to shift the texture coordinates per layer
    float2 deltaTexCoords = parallaxAmmount / numLayers;
    float layerSize = 1.0 / numLayers; // Get the size of each layer
    
    float2 currTexCoords = texCoords;
    float currParallaxMapValue = txParallax.Sample(samLinear, currTexCoords).x;

    float currentLayerDepth = 0.0;
    [loop]
    while (currentLayerDepth < currParallaxMapValue) // shift texture coordinates along each layer
    {
        currTexCoords -= deltaTexCoords; 
        currParallaxMapValue = txParallax.Sample(samLinear, currTexCoords).x; // get depthmap value at current texture coordinates
        currentLayerDepth += layerSize; // increase our layer depth (do another step)
    }
    
    float2 beforeCollisionCoords = currTexCoords + deltaTexCoords; // get previous texture coordinates

    // get collision depth upper and lower bounds for linear interpolation
    float afterCollisionCoords = currParallaxMapValue - currentLayerDepth;
    float beforeDepth = txParallax.Sample(samLinear, beforeCollisionCoords).r - currentLayerDepth + layerSize;

    // interpolation of texture coordinates
    float weight = afterCollisionCoords / (afterCollisionCoords - beforeDepth);
    float2 POMTexCoords = beforeCollisionCoords * weight + currTexCoords * (1.0 - weight);
    return POMTexCoords;
}


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output = (PS_INPUT) 0;
    
    // MVP matrix
    output.Pos = mul(input.Pos, World);
    output.worldPos = output.Pos;
    output.Pos = mul(output.Pos, View);
    output.Pos = mul(output.Pos, Projection);
    output.Tex = input.Tex;
    
    // Transform the vertex position into projected space from the POV of the light
    //float4 lightSpacePos = mul(output.worldPos, lview);
    //lightSpacePos = mul(lightSpacePos, lprojection);
    //output.lightSpacePos = lightSpacePos;
    
   output.lightSpacePos = mul(input.Pos, World);
   output.lightSpacePos = mul(output.lightSpacePos, lview);
   output.lightSpacePos = mul(output.lightSpacePos, lprojection);
    
    
    // Create TBN matrix
    output.tangent = normalize(mul(input.tangent, (float3x3) World));
    output.binormal = normalize(mul(input.binormal, (float3x3) World));
    output.Norm = normalize(mul(input.Norm, (float3x3) World));
    
    return output;
}

// Used as a helper for shadow mapping
float2 texOffset(int u, int v, float2 shadowMapSize)
{
    return float2(u * 1.0f / shadowMapSize.x, v * 1.0f / shadowMapSize.y);
}

float3 GammaCorrection(float3 color)
{
    return pow(color.rgb, float3(1.0 / Lights[0].Gamma, 1.0 / Lights[0].Gamma, 1.0 / Lights[0].Gamma));
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS(PS_INPUT IN) : SV_TARGET
{
    // renormalize model normals 
    float3 normalW = normalize(IN.Norm);
    normalW.x = -normalW.x;
    normalW.y = -normalW.y;
    normalW.z = -normalW.z;
    float2 texCoords = IN.Tex;

    // TBN matrix
    float3x3 texSpace = float3x3(
    normalize(IN.tangent),
    normalize(IN.binormal),
    normalize(IN.Norm));
    
    // Phong lighting 
    float3 L = Lights[0].Position - IN.worldPos;
    float3 distanceToLight = length(L);
    float3 directionToLight = L / distanceToLight;
    L = normalize(L);
    float NdotL = dot(L, normalW);
    

    // Compute shadow tex coords & pixel depth
    float2 shadowTexCoords;
    shadowTexCoords.x =  IN.lightSpacePos.x / IN.lightSpacePos.w / 2.0f + 0.5f; 
    shadowTexCoords.y = -IN.lightSpacePos.y / IN.lightSpacePos.w / 2.0f + 0.5f; 
    float pixelDepth = IN.lightSpacePos.z / IN.lightSpacePos.w;
    pixelDepth -= Lights[0].lightBias; // Apply bias to account for floating point inaccuracy

    // Used for lighting / Parallax
    float3 toEye = normalize(EyePosition - IN.worldPos);
    float3 lightVecNorm = normalize(Lights[0].Direction);
    
    // Used in parallax
    float3 viewDirW = normalize(-toEye);
    float3 viewDirTS = mul(viewDirW, transpose(texSpace));

    //
    // Parallax Mapping
    //
    if (Material.UseParallax == 1.0)
    {
        // Standard Parallax mapping
        //texCoords = ParallaxMapping(IN.Tex, viewDirTS);
        
        // Parallax Occulusion mapping
        texCoords = ParallaxOccMapping(IN.Tex, viewDirTS);
        IN.Tex = texCoords;
    }
    
    //
    // Material / Texture
    //
    float4 textureColour = Material.Diffuse;
    if (Material.UseTexture == 1.0f)
    {
        textureColour = txDiffuse.Sample(samLinear, IN.Tex); 
    }

    //
    // Normal mapping
    //
    if (Material.UseNormal == 1.0)
    {
        float4 bumpMap = txNormal.Sample(samLinear, IN.Tex);

		// Expand the range of normal value from (0, +1) to (-1, +1).
        bumpMap.x = bumpMap.x * 2.0f - 1.0f;
        bumpMap.y = bumpMap.y * 2.0f - 1.0f;
        bumpMap.z = -bumpMap.z * 2.0f + 1.0f;

        
        // Convert normal from normal map to texture space
        normalW = normalize(mul(bumpMap.rgb, texSpace));
        NdotL = dot(normalW,L);
    }

    //
    // Phong lighting
    //
    
    float3 ambient = GlobalAmbient.rgb * textureColour.rgb * Material.Diffuse.rgb;

    //Calcuate diffuse attenuation
    float att = 1.0f / (Lights[0].ConstantAttenuation + Lights[0].LinearAttenuation * distanceToLight + Lights[0].QuadraticAttenuation * pow(distanceToLight, 2));
    
    // Calculate diffuse intensity
    float3 diffuse = max(dot(normalW, L), 0.0);
    diffuse *= Lights[0].Color.rgb;
    diffuse = GammaCorrection(diffuse);
    

    // Calculate specular intensity
    float3 R = reflect(L, normalW);
    float3 specular = Material.Specular;
    if (Material.UseSpecular)
    {
        float4 specularTex = txSpecular.Sample(samLinear, IN.Tex);
        specular = pow(max(dot(viewDirW, R), 0.0f), Material.SpecularPower);
        specular *= Material.Specular.rgb * Lights[0].Color.rgb * specularTex.rgb;
    }
    else
    {
        specular = pow(max(0.0f, dot(viewDirW, R)), Material.SpecularPower) * Material.Specular.rgb * Lights[0].Color.rgb;
    }
    specular = GammaCorrection(specular);
    
    // If there is no diffuse, there should be no specular
    if (diffuse.r <= 0.0f || diffuse.g <= 0.0f || diffuse.b <= 0.0f)
    {
        specular = float3(0.0f, 0.0f, 0.0f);
        return float4(ambient, 1.0f);
    }


    // Check if our obj casts shadows before doing any shadow work
    if (!Material.CastShadows)
    {
        float3 result = (ambient + diffuse.rgb + specular.rgb) * textureColour.rgb; // without attenuation
        return float4(saturate(result.rgb), 1.0f);
    }
    
    
    // Shadows
    // Check if the pixel texture coordinate is in the view frustum of the 
    // light before doing any shadow work.
    if (!(saturate(shadowTexCoords.x) == shadowTexCoords.x) && !(saturate(shadowTexCoords.y) == shadowTexCoords.y)) {
        return float4(ambient, 1.0f);
    }
    else
    {
        //Perform PCF (percentage-closer filtering) on a 4 x 4 texel neighborhood
        float sum = 0;
        for (float y = -1.5; y <= 1.5; y++)
        {
            for (float x = -1.5; x <= 1.5; x++)
            {
                sum += shadowMap.SampleCmpLevelZero(shadowSampler, shadowTexCoords + texOffset(x, y, float2(1024, 1024)), pixelDepth);
                //sum += shadowMap.Sample(samLinear, shadowTexCoords).r;
            }
        }
        float shadowAmm = sum / 16.0;

       
        // Pixel is in shadow
        if (shadowAmm < pixelDepth)
        {
           return float4(ambient, 1.0f);
        }

        // Pixel is in light
        //float3 result = ambient +  att * (diffuse.rgb + specular.rgb) * textureColour.rgb; // with attenuation
        float3 result = (ambient + diffuse.rgb + specular.rgb) * textureColour.rgb; // without attenuation
        return float4(saturate(result.rgb), 1.0f);
    }
}
