//
//  Shaders.metal
//  MetalRacingGame
//
//  Metal 3 shaders for PBR rendering
//

#include <metal_stdlib>
using namespace metal;

// Vertex input
struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

// Vertex output
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPosition;
    float3 normal;
};

// Uniforms
struct Uniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 modelMatrix;
    float3 cameraPosition;
    float3 lightDirection;
    float3 lightColor;
    float time;
};

// Vertex shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(0)]]) {
    VertexOut out;
    
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.texCoord = in.texCoord;
    out.normal = normalize((uniforms.modelMatrix * float4(0, 1, 0, 0)).xyz);
    
    return out;
}

// Advanced PBR functions
float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float distributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159 * denom * denom;
    
    return num / denom;
}

float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float geometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

// Fragment shader with advanced PBR (Cook-Torrance BRDF)
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(0)]]) {
    // PBR material properties
    float3 albedo = float3(0.8, 0.2, 0.2); // Red car color
    float metallic = 0.1;
    float roughness = 0.3;
    float ao = 1.0;
    
    // View direction
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    
    // Normal
    float3 normal = normalize(in.normal);
    
    // Light direction
    float3 lightDir = normalize(-uniforms.lightDirection);
    float3 lightColor = uniforms.lightColor;
    
    // Calculate Cook-Torrance BRDF
    float3 F0 = mix(float3(0.04), albedo, metallic);
    
    // Per-light radiance
    float3 radiance = lightColor;
    
    // Cook-Torrance BRDF
    float3 halfDir = normalize(viewDir + lightDir);
    
    // Calculate Fresnel
    float3 F = fresnelSchlick(max(dot(halfDir, viewDir), 0.0), F0);
    
    // Calculate normal distribution
    float NDF = distributionGGX(normal, halfDir, roughness);
    
    // Calculate geometry function
    float G = geometrySmith(normal, viewDir, lightDir, roughness);
    
    // Calculate specular
    float3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(normal, viewDir), 0.0) * max(dot(normal, lightDir), 0.0) + 0.0001;
    float3 specular = numerator / denominator;
    
    // Calculate diffuse
    float3 kS = F;
    float3 kD = (1.0 - kS) * (1.0 - metallic);
    float3 diffuse = kD * albedo / 3.14159;
    
    // Add contribution from this light
    float NdotL = max(dot(normal, lightDir), 0.0);
    float3 Lo = (diffuse + specular) * radiance * NdotL;
    
    // Ambient lighting (IBL approximation)
    float3 ambient = float3(0.03) * albedo * ao;
    
    // Final color
    float3 color = ambient + Lo;
    
    // Tone mapping (ACES approximation)
    color = color / (color + float3(1.0));
    
    // Gamma correction
    color = pow(color, float3(1.0 / 2.2));
    
    return float4(color, 1.0);
}

// Post-processing shaders
kernel void motion_blur(texture2d<float, access::read> input [[texture(0)]],
                        texture2d<float, access::read> velocity [[texture(1)]],
                        texture2d<float, access::write> output [[texture(2)]],
                        constant float& strength [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    float4 color = input.read(gid);
    float2 vel = velocity.read(gid).xy;
    
    // Sample along velocity vector
    int samples = 8;
    float4 result = color;
    
    for (int i = 1; i <= samples; ++i) {
        float2 offset = vel * (float(i) / float(samples)) * strength;
        uint2 samplePos = uint2(clamp(float2(gid) + offset, float2(0), float2(input.get_width() - 1, input.get_height() - 1)));
        result += input.read(samplePos);
    }
    
    result /= float(samples + 1);
    output.write(result, gid);
}

kernel void bloom(texture2d<float, access::read> input [[texture(0)]],
                  texture2d<float, access::write> output [[texture(1)]],
                  constant float& intensity [[buffer(0)]],
                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    float4 color = input.read(gid);
    
    // Extract bright areas
    float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float3 bloom = color.rgb * smoothstep(0.7, 1.0, brightness) * intensity;
    
    output.write(float4(bloom, color.a), gid);
}

kernel void tone_map(texture2d<float, access::read> input [[texture(0)]],
                     texture2d<float, access::write> output [[texture(1)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    float4 hdrColor = input.read(gid);
    
    // ACES tone mapping
    float3 x = hdrColor.rgb;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    float3 color = clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
    
    // Gamma correction
    color = pow(color, float3(1.0 / 2.2));
    
    output.write(float4(color, hdrColor.a), gid);
}

// Particle update compute shader (enhanced)
kernel void update_particles(device Particle* particles [[buffer(0)]],
                             constant float& deltaTime [[buffer(1)]],
                             constant float3& windDirection [[buffer(2)]],
                             uint id [[thread_position_in_grid]]) {
    if (id >= 10000) return;
    
    Particle& p = particles[id];
    
    if (p.life <= 0.0) return;
    
    // Update position
    p.position += p.velocity * deltaTime;
    
    // Apply gravity
    p.velocity.y -= 9.8 * deltaTime;
    
    // Apply wind
    p.velocity += windDirection * deltaTime * 2.0;
    
    // Air resistance
    p.velocity *= 0.98;
    
    // Update life
    p.life -= deltaTime;
    
    // Fade out based on life
    float lifeRatio = p.life / 1.0; // Assuming max life of 1.0
    p.color.a = lifeRatio;
    
    // Size variation
    p.size *= (1.0 + deltaTime * 0.1);
}

// Particle structure for compute shader
struct Particle {
    float3 position;
    float3 velocity;
    float4 color;
    float life;
    float size;
};

