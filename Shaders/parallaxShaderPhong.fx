//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b0)
{
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;
}

//Texture2D txDiffuse : register(t0);
//Texture2D txNormal : register(t1);
//Texture2D txParallax : register(t2);
//SamplerState samLinear : register(s0);

Texture2D txDiffuse : register(t0);
Texture2D txSpecular : register(t1);
Texture2D txNormal : register(t2);
Texture2D txParallax : register(t3);
Texture2D shadowMap : register(t4);


SamplerState samLinear : register(s0)
{
    Filter = ANISOTROPIC;
    MaxAnisotropy = 4;

    AddressU = WRAP;
    AddressV = WRAP;
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
    bool UseNormal; // 4 bytes
    bool UseParallax; // 4 bytes
							//----------------------------------- (16 byte boundary)
    bool FlipNormX; // 4 bytes
    bool FlipNormY; // 4 bytes
    bool FlipNormZ; // 4 bytes
    float ParallaxHeight; // 4 bytes
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
    int2 Padding; // 8 bytes
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
};

// Helper func to convert world norms to tangent space
float3 VectorToTangentSpace(float3 vectorV, float3x3 TBN_inv)
{
    float3 tangentSpaceNormal = normalize(mul(vectorV, TBN_inv));
    return tangentSpaceNormal;
}

float2 ParallaxMapping(float2 texCoords, float3 viewDir)
{
    //float height_scale = 0.05f; // Sutible from 0.0 -> 0.5
    float height = txParallax.Sample(samLinear, texCoords).x;

    float2 p = viewDir.xy / viewDir.z * (height * Material.ParallaxHeight);
    // add bias if required
    return texCoords - p;
}


// Actually Parralax Occlusion mapping, with Steeep inside 
float2 SteepParallaxMapping(float2 texCoords, float3 viewDir)
{
    
    const float minLayers = 8.0;
    const float maxLayers = 32.0;
    float numLayers = lerp(maxLayers, minLayers, max(dot(float3(0.0, 0.0, 1.0), viewDir), 0.0));
    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
    // the amount to shift the texture coordinates per layer (from vector P)
    float2 P = viewDir.xy * Material.ParallaxHeight;
    float2 deltaTexCoords = P / numLayers;
    
    float2 currentTexCoords = texCoords;
    float currentDepthMapValue = txParallax.Sample(samLinear, currentTexCoords).x;

    [loop]
    while (currentLayerDepth < currentDepthMapValue)
    {
    // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;
    // get depthmap value at current texture coordinates
        currentDepthMapValue = txParallax.Sample(samLinear, currentTexCoords).x;

    // get depth of next layer
        currentLayerDepth += layerDepth;
    }
    
    // get texture coordinates before collision (reverse operations)
    float2 prevTexCoords = currentTexCoords + deltaTexCoords;

// get depth after and before collision for linear interpolation
    float afterDepth = currentDepthMapValue - currentLayerDepth;
    float beforeDepth = txParallax.Sample(samLinear, prevTexCoords).r - currentLayerDepth + layerDepth;

// interpolation of texture coordinates
    float weight = afterDepth / (afterDepth - beforeDepth);
  
    float2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);

    return finalTexCoords;
}


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output = (PS_INPUT) 0;
    output.Pos = mul(input.Pos, World);
    output.worldPos = output.Pos;
    output.Pos = mul(output.Pos, View);
    output.Pos = mul(output.Pos, Projection);
    output.Tex = input.Tex;
    
    output.tangent =    normalize(mul(input.tangent, (float3x3) World));
    output.binormal =   normalize(mul(input.binormal, (float3x3) World));
    output.Norm =       normalize(mul(input.Norm, (float3x3) World));
    
    return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS(PS_INPUT IN) : SV_TARGET
{
    float3 normalW = normalize(IN.Norm);
    normalW.x = -normalW.x;
    normalW.y = normalW.y;
    normalW.z = -normalW.z;
    float2 texCoords = IN.Tex;


    float3x3 texSpace = float3x3(
    normalize(IN.tangent),
    normalize(IN.binormal),
    normalize(IN.Norm));
    

    //texSpace = transpose(texSpace);
    
    // Used for lighting / Parallax
    float3 toEye = normalize(EyePosition - IN.worldPos);
    float3 lightVecNorm = normalize(Lights[0].Direction);
    
    // Used in parallax
    float3 viewDirW = normalize(-toEye);
    float3 viewDirTS = mul(viewDirW, transpose(texSpace));


    // Parallax
    if (Material.UseParallax == 1.0)
    {
        texCoords = SteepParallaxMapping(IN.Tex, viewDirTS);
       //if (texCoords.x > 1.0 || texCoords.y > 1.0 || texCoords.x < 0.0 || texCoords.y < 0.0) // Clips the texcoords
       //    discard;
        
        IN.Tex = texCoords;
    }
    
    // Material / Texture
    float4 textureColour = Material.Diffuse;
    if (Material.UseTexture == 1.0f)
        textureColour = txDiffuse.Sample(samLinear, IN.Tex);

    // Normal / bump mapping
    if (Material.UseNormal == 1.0)
    {
        float3 bumpMap = txNormal.Sample(samLinear, IN.Tex).rgb;
        
		// Expand the range of normal value from (0, +1) to (-1, +1).
        bumpMap.x = bumpMap.x * 2.0f - 1.0f;
        bumpMap.y = bumpMap.y * 2.0f - 1.0f;
        bumpMap.z = -bumpMap.z * 2.0f + 1.0f;
        
        //bumpMap = (bumpMap * 2.0f) - 1.0f;
        
        if (Material.FlipNormX)
            bumpMap.x = (-bumpMap.x * 2.0f) + 1.0f;
        if (Material.FlipNormY)
            bumpMap.y = (-bumpMap.y * 2.0f) + 1.0f;
        if (Material.FlipNormZ)
            bumpMap.z = (-bumpMap.z * 2.0f) + 1.0f;
        
        // Convert normal from normal map to texture space
        normalW = normalize(mul(bumpMap, texSpace));
    }
    
   

  
    float3 L = Lights[0].Position - IN.worldPos;
    float3 distanceToLight = length(L);
    float3 directionToLight = L / distanceToLight;
    L = normalize(L);
 
    float3 ambient = GlobalAmbient.rgb * Material.Diffuse.rgb;

    // Calcuate diffuse attenuation
    float att = 1.0f / (Lights[0].ConstantAttenuation + Lights[0].LinearAttenuation * distanceToLight + Lights[0].QuadraticAttenuation * pow(distanceToLight, 2));
    //float att = 1.0f / (1.0f + Lights[0].ConstantAttenuation * pow(distanceToLight, 2));
   
    // Calculate diffuse intensity
    float3 diffuse = Lights[0].Color.rgb * max(dot(L, normalW), 0.0f);
    //float4 diffuse = (textureColour.rgb * Material.Diffuse.rgb * Lights[0].Color.rgb) * att * max(0.0f, dot(L, normalW));
    
    // Calculate specular intensity
    float3 R = reflect(L, normalW);
    float3 specular = pow(max(0.0f, dot(viewDirW, R)), Material.SpecularPower) * Material.Specular.rgb * Lights[0].Color.rgb;
    
    // If there is no diffuse, there should be no specular
    if (diffuse.r <= 0.0f || diffuse.g <= 0.0f || diffuse.b <= 0.0f)
    {
        specular = 0.0f;
    }
       

    
    // Final color
    //return float4(saturate(diffuse.rgb + GlobalAmbient.rgb + specular), 1.0f);
    float3 result = ambient + att * (diffuse.rgb + specular.rgb) * textureColour.rgb;
    return float4(saturate(result.rgb), 1.0f);
}

//--------------------------------------------------------------------------------------
// PSSolid - render a solid color
//--------------------------------------------------------------------------------------
float4 PSSolid(PS_INPUT input) : SV_Target
{
    return vOutputColor;
}
