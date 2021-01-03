
cbuffer ConstantShadowMapBuffer : register(b3)
{
    float4x4 projection;
    float4x4 view;
    float4 model;
}; 

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
	float4 pos : SV_POSITION;
};

PS_INPUT VS(VS_INPUT input)
{
    PS_INPUT output;
	float4 pos = float4(input.Pos.xyz, 1.0f);

	// Transform the vertex position into projected space.
	pos = mul(pos, model);
	pos = mul(pos, view);
	pos = mul(pos, projection);
	output.pos = pos;

	return output;
}

void PS(PS_INPUT input)
{
    discard;
}