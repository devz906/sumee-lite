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
vertex VertexOut ds_vertex(unsigned int vid [[ vertex_id ]]) {
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

// Shader
fragment float4 ds_fragment(VertexOut in [[stage_in]],
                               texture2d<float> texture [[ texture(0) ]],
                               constant uint32_t &screenMode [[ buffer(0) ]],
                               constant uint32_t &filterMode [[ buffer(1) ]],
                               sampler textureSampler [[ sampler(0) ]]) {
    
    float2 uv = in.texCoord;
    
   
    if (screenMode == 0) {

        uv.y = uv.y * 0.5;
    } else if (screenMode == 1) {

        uv.y = 0.5 + uv.y * 0.5;
    }

    
    float4 color = texture.sample(textureSampler, uv);
    
    // LCD Grid Filter (filterMode == 1)
    if (filterMode == 1) {
  
        float gridBrightness = 0.50;
        
        float2 gridUV = uv;
        
        // Frecuencia de la grilla
        float gridX = abs(sin(uv.x * 256.0 * 3.14159 * 2.0));
        float gridY = abs(sin(uv.y * 384.0 * 3.14159 * 2.0));
        
       
        gridX = pow(gridX, 0.4);
        gridY = pow(gridY, 0.4);
        
        float grid = gridX * gridY;
        
        color.rgb *= (grid * (1.0 - gridBrightness) + gridBrightness);
        
   
    }

    
    return color;
}
