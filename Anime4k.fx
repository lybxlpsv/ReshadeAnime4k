/**
 * Anime4k ported to ReShade
 * Based on https://github.com/keijiro/UnityAnime4K
 */

#include "ReShadeUI.fxh"

uniform float _Strength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 5.0;
	ui_tooltip = "Strength.";
> = 0.3;

#include "ReShade.fxh"

float MinA(float4 a, float4 b, float4 c)
{
    return min(min(a.a, b.a), c.a);
}

float MaxA(float4 a, float4 b, float4 c)
{
    return max(max(a.a, b.a), c.a);
}

float MinA(float4 a, float4 b, float4 c, float4 d)
{
    return min(min(min(a.a, b.a), c.a), d.a);
}

float MaxA(float4 a, float4 b, float4 c, float4 d)
{
    return max(max(max(a.a, b.a), c.a), d.a);
}
float4 ComputeLum(float4 position : SV_Position,float2 texCoord : TexCoord) : SV_Target
{
    float4 c = tex2D(ReShade::BackBuffer, texCoord);
    float lum = (c[0] + c[0] + c[1] + c[1] + c[1] + c[2]) / 6;
    return float4(c.rgb, lum);
}

float4 Largest(float4 mc, float4 lightest, float4 a, float4 b, float4 c)
{
    float4 abc = lerp(mc, (a + b + c) / 3, 0.3);
    return abc.a > lightest.a ? abc : lightest;
}

float4 Push(float4 position : SV_Position, float2 texCoord : TexCoord) : SV_Target
{
    // [tl tc tr]
    // [ml mc mr]
    // [bl bc br]

    float4 duv = ReShade::PixelSize.xyxy * float4(1, 1, -1, 0);

    float4 tl = tex2D(ReShade::BackBuffer, texCoord - duv.xy);
    float4 tc = tex2D(ReShade::BackBuffer, texCoord - duv.wy);
    float4 tr = tex2D(ReShade::BackBuffer, texCoord - duv.zy);

    float4 ml = tex2D(ReShade::BackBuffer, texCoord - duv.xw);
    float4 mc = tex2D(ReShade::BackBuffer, texCoord);
    float4 mr = tex2D(ReShade::BackBuffer, texCoord + duv.xw);

    float4 bl = tex2D(ReShade::BackBuffer, texCoord + duv.zy);
    float4 bc = tex2D(ReShade::BackBuffer, texCoord + duv.wy);
    float4 br = tex2D(ReShade::BackBuffer, texCoord + duv.xy);

    float4 lightest = mc;

    // Kernel 0 and 4
    if (MinA(tl, tc, tr) > MaxA(mc, br, bc, bl))
        lightest = Largest(mc, lightest, tl, tc, tr);
    else if (MinA(br, bc, bl) > MaxA(mc, tl, tc, tr))
        lightest = Largest(mc, lightest, br, bc, bl);

    // Kernel 1 and 5
    if (MinA(mr, tc, tr) > MaxA(mc, ml, bc))
        lightest = Largest(mc, lightest, mr, tc, tr);
    else if (MinA(bl, ml, bc) > MaxA(mc, mr, tc))
        lightest = Largest(mc, lightest, bl, ml, bc);

    // Kernel 2 and 6
    if (MinA(mr, br, tr) > MaxA(mc, ml, tl, bl))
        lightest = Largest(mc, lightest, mr, br, tr);
    else if (MinA(ml, tl, bl) > MaxA(mc, mr, br, tr))
        lightest = Largest(mc, lightest, ml, tl, bl);

    //Kernel 3 and 7
    if (MinA(mr, br, bc) > MaxA(mc, ml, tc))
        lightest = Largest(mc, lightest, mr, br, bc);
    else if (MinA(tc, ml, tl) > MaxA(mc, mr, bc))
        lightest = Largest(mc, lightest, tc, ml, tl);

    return lightest;
}

float4 ComputeGradient(float4 position : SV_Position, float2 texCoord : TexCoord) : SV_Target
{
    float4 c0 = tex2D(ReShade::BackBuffer, texCoord);

    // [tl tc tr]
    // [ml    mr]
    // [bl bc br]

    float4 duv = ReShade::PixelSize.xyxy * float4(1, 1, -1, 0);

    float tl = tex2D(ReShade::BackBuffer, texCoord - duv.xy).a;
    float tc = tex2D(ReShade::BackBuffer, texCoord - duv.wy).a;
    float tr = tex2D(ReShade::BackBuffer, texCoord - duv.zy).a;

    float ml = tex2D(ReShade::BackBuffer, texCoord - duv.xw).a;
    float mr = tex2D(ReShade::BackBuffer, texCoord + duv.xw).a;

    float bl = tex2D(ReShade::BackBuffer, texCoord + duv.zy).a;
    float bc = tex2D(ReShade::BackBuffer, texCoord + duv.wy).a;
    float br = tex2D(ReShade::BackBuffer, texCoord + duv.xy).a;

    // Horizontal gradient
    // [-1  0  1]
    // [-2  0  2]
    // [-1  0  1]

    // Vertical gradient
    // [-1 -2 -1]
    // [ 0  0  0]
    // [ 1  2  1]

    float2 grad = float2(tr + mr * 2 + br - (tl + ml * 2 + bl),
                         bl + bc * 2 + br - (tl + tc * 2 + tr));

    // Computes the luminance's gradient and saves it in the unused alpha channel
    return float4(c0.rgb, 1 - saturate(length(grad)));
}

float4 Average(float4 mc, float4 a, float4 b, float4 c)
{
    return float4(lerp(mc, (a + b + c) / 3, _Strength).rgb, 1);
}

float4 PushGrad(float4 position : SV_Position, float2 texCoord : TexCoord) : SV_Target
{
    // [tl tc tr]
    // [ml mc mr]
    // [bl bc br]

    float4 duv = ReShade::PixelSize.xyxy * float4(1, 1, -1, 0);

    float4 tl = tex2D(ReShade::BackBuffer, texCoord - duv.xy);
    float4 tc = tex2D(ReShade::BackBuffer, texCoord - duv.wy);
    float4 tr = tex2D(ReShade::BackBuffer, texCoord - duv.zy);

    float4 ml = tex2D(ReShade::BackBuffer, texCoord - duv.xw);
    float4 mc = tex2D(ReShade::BackBuffer, texCoord);
    float4 mr = tex2D(ReShade::BackBuffer, texCoord + duv.xw);

    float4 bl = tex2D(ReShade::BackBuffer, texCoord + duv.zy);
    float4 bc = tex2D(ReShade::BackBuffer, texCoord + duv.wy);
    float4 br = tex2D(ReShade::BackBuffer, texCoord + duv.xy);

    // Kernel 0 and 4
    if (MinA(tl, tc, tr) > MaxA(mc, br, bc, bl)) return Average(mc, tl, tc, tr);
    if (MinA(br, bc, bl) > MaxA(mc, tl, tc, tr)) return Average(mc, br, bc, bl);

    // Kernel 1 and 5
    if (MinA(mr, tc, tr) > MaxA(mc, ml, bc    )) return Average(mc, mr, tc, tr);
    if (MinA(bl, ml, bc) > MaxA(mc, mr, tc    )) return Average(mc, bl, ml, bc);

    // Kernel 2 and 6
    if (MinA(mr, br, tr) > MaxA(mc, ml, tl, bl)) return Average(mc, mr, br, tr);
    if (MinA(ml, tl, bl) > MaxA(mc, mr, br, tr)) return Average(mc, ml, tl, bl);

    // Kernel 3 and 7
    if (MinA(mr, br, bc) > MaxA(mc, ml, tc    )) return Average(mc, mr, br, bc);
    if (MinA(tc, ml, tl) > MaxA(mc, mr, bc    )) return Average(mc, tc, ml, tl);

    return float4(mc.rgb, 1);
}

technique Anime4k
{
	pass pass0
	{
		VertexShader = PostProcessVS;
		PixelShader = ComputeLum;
	}

	pass pass1
	{
		VertexShader = PostProcessVS;
		PixelShader = Push;
	}

	pass pass2
	{
		VertexShader = PostProcessVS;
		PixelShader = ComputeGradient;
	}

	pass pass3
	{
		VertexShader = PostProcessVS;
		PixelShader = PushGrad;
	}

}

technique Anime4kNoPush
{
	pass pass0
	{
		VertexShader = PostProcessVS;
		PixelShader = ComputeLum;
	}

	pass pass1
	{
		VertexShader = PostProcessVS;
		PixelShader = ComputeGradient;
	}

	pass pass2
	{
		VertexShader = PostProcessVS;
		PixelShader = PushGrad;
	}
}
