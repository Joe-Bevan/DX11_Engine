cbuffer ConstantBuffer : register(b0)
{
    matrix World;
    matrix View;
    matrix Projection;
    float4 vOutputColor;
}

Texture2D tex : register(t0);

SamplerState samLinear : register(s0)
{
	Filter = ANISOTROPIC;
	MaxAnisotropy = 4;

	AddressU = WRAP;
	AddressV = WRAP;
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
	float4 Pos : SV_POSITION;
	float2 Tex : TEXCOORD0;
};


PS_INPUT VS(VS_INPUT input)
{
	// For fullscreen quad
	PS_INPUT output = (PS_INPUT)0;
	output.Pos = input.Pos;
	output.Tex = input.Tex;

	return output;
}


float4 PS(PS_INPUT input) : SV_TARGET
{
	float4 vColor = tex.Sample(samLinear, input.Tex);
    return float4(saturate(vColor.rgb), 1.0f);
}

