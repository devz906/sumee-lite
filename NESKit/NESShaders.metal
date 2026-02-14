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

// Shaders para NES (RGB565 -> RGBA)

vertex VertexOut nes_vertex(uint vertexID [[vertex_id]],
                             constant float4* positions [[buffer(0)]],
                             constant float2* texCoords [[buffer(1)]]) {
    VertexOut out;
    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 nes_fragment(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(mag_filter::nearest, min_filter::nearest);
    
    // Si la textura es B5G6R5Unorm (RGB565), Metal maneja la conversión a float automáticamente al samplear
    float4 color = texture.sample(s, in.texCoord);
    return float4(color.rgb, 1.0);
}
