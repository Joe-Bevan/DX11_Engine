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

	// Surrounding pixels
	float2 Tex1 : TEXCOORD1;
	float2 Tex2 : TEXCOORD2;
	float2 Tex3 : TEXCOORD3;
	float2 Tex4 : TEXCOORD4;
	float2 Tex5 : TEXCOORD5;
	float2 Tex6 : TEXCOORD6;
	float2 Tex7 : TEXCOORD7;
	float2 Tex8 : TEXCOORD8;
	float2 Tex9 : TEXCOORD9;
};


PS_INPUT VS(VS_INPUT input)
{
	// For fullscreen quad
	PS_INPUT output = (PS_INPUT)0;
	output.Pos = input.Pos;
	output.Tex = input.Tex;
	
	float texelWidth = 1.0f / screenWidth;
	float texelHeight = 1.0f / screenHeight;
	
    if (toggleBlur)
    {
        texelHeight *= blurStrength;
        texelWidth *= blurStrength;
		// Create UV coordinates for the pixel and its 9 neighbors surrounding it
		output.Tex1 = input.Tex + float2(texelWidth * -1.0f, texelHeight * -1.0f);
		output.Tex2 = input.Tex + float2(texelWidth * 0.0f, texelHeight * -1.0f);
		output.Tex3 = input.Tex + float2(texelWidth * 1.0f, texelHeight * -1.0f);
		output.Tex4 = input.Tex + float2(texelWidth * -1.0f, texelHeight * 0.0f);
		output.Tex5 = input.Tex + float2(texelWidth * 0.0f,  texelHeight * 0.0f);
		output.Tex6 = input.Tex + float2(texelWidth * 1.0f,  texelHeight * 0.0f);
		output.Tex7 = input.Tex + float2(texelWidth * -1.0f,  texelHeight * 1.0f);
		output.Tex8 = input.Tex + float2(texelWidth * 0.0f,  texelHeight * 1.0f);
		output.Tex9 = input.Tex + float2(texelWidth * 1.0f,  texelHeight * 1.0f);
    }
	return output;
}


float4 PS(PS_INPUT input) : SV_TARGET
{
/***********************************************
MARKING SCHEME: Simple Screen Space Effect
DESCRIPTION: Box blur effect
***********************************************/

    if (toggleBlur)
    {
		float weight0, weight1, weight2, weight3, weight4;
		float normalization;
		float4 color;

        weight0 = 0.25f;
        weight1 = 0.125f;
        weight2 = 0.00625f;
        weight3 = 0.125f;
        weight4 = 0.00625f;

		// Create a normalized value to average the weights out a bit.
        normalization = (weight0 + 1.0f * (weight1 + weight2 + weight3 + weight4));
        
		// Normalize the weights.
		weight0 = weight0 / normalization;
		weight1 = weight1 / normalization;
		weight2 = weight2 / normalization;
		weight3 = weight3 / normalization;
        weight4 = weight4 / normalization;
		
		// Initialize the color to our scene.
		color = float4(0, 0, 0, 0);

		// Add the nine pixels to the color by the specific weight of each.
		color += tex.Sample(samLinear, input.Tex1) * weight4;
		color += tex.Sample(samLinear, input.Tex2) * weight3;
		color += tex.Sample(samLinear, input.Tex3) * weight2;
		color += tex.Sample(samLinear, input.Tex4) * weight1;
		color += tex.Sample(samLinear, input.Tex5) * weight0;
		color += tex.Sample(samLinear, input.Tex6) * weight1;
		color += tex.Sample(samLinear, input.Tex7) * weight2;
		color += tex.Sample(samLinear, input.Tex8) * weight3;
        color += tex.Sample(samLinear, input.Tex9) * weight4;

		// Set the alpha channel to one.
		color.a = 1.0f;
		return float4(saturate(color.rgb), 1.0f);
    }
	
    float4 vColor = tex.Sample(samLinear, input.Tex);
    return float4(saturate(vColor.rgb), 1.0f);
}

