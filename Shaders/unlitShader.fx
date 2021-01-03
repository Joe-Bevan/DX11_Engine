//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer ConstantBuffer : register(b0)
{
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;

    float screenWidth;
    float screenHeight;
    int toggleBlur;
    float blurStrength;
}

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

    float3x3 TBNinv : POSITION5;
};

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


    
	// multiply the normal by the world transform (to go from model space to world space)
    //output.Norm = mul(input.Norm, (float3x4) World);

    return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS(PS_INPUT IN) : SV_TARGET
{
    return saturate(float4(vOutputColor.rgb, 1.0f));
}

//--------------------------------------------------------------------------------------
// PSSolid - render a solid color
//--------------------------------------------------------------------------------------
float4 PSSolid(PS_INPUT input) : SV_Target
{
    return saturate(float4(vOutputColor.rgb, 1.0f));
}
