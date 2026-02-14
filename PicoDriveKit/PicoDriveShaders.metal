#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Shaders for PicoDrive (RGB565 -> RGBA or RGBA -> RGBA)

vertex VertexOut pico_vertex(uint vertexID [[vertex_id]],
                             constant float4* positions [[buffer(0)]],
                             constant float2* texCoords [[buffer(1)]]) {
    VertexOut out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 pico_fragment(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(mag_filter::nearest, min_filter::nearest);
    
    // Auto-conversion handled by Metal sampler for B5G6R5Unorm or BGRA8Unorm
    float4 color = texture.sample(s, in.texCoord);
    return float4(color.rgb, 1.0);
}
