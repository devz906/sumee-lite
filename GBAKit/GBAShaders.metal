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

// Shader
vertex VertexOut gba_vertex(unsigned int vid [[ vertex_id ]]) {
    const float4 positions[4] = {
        float4(-1.0,  1.0, 0.0, 1.0), // Top-Left
        float4(-1.0, -1.0, 0.0, 1.0), // Bottom-Left
        float4( 1.0,  1.0, 0.0, 1.0), // Top-Right
        float4( 1.0, -1.0, 0.0, 1.0)  // Bottom-Right
    };

    const float2 texCoords[4] = {
        float2(0.0, 0.0), // Top-Left
        float2(0.0, 1.0), // Bottom-Left
        float2(1.0, 0.0), // Top-Right
        float2(1.0, 1.0)  // Bottom-Right
    };

    VertexOut out;
    out.position = positions[vid];
    out.texCoord = texCoords[vid];
    return out;
}

// Shader de Fragmentos GBA
fragment float4 gba_fragment(VertexOut in [[stage_in]],
                               texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler textureSampler (mag_filter::nearest, min_filter::nearest);
    return texture.sample(textureSampler, in.texCoord);
}
