#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform float u_Time;
uniform vec4 u_Color2;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

uniform mat4 u_ViewProj;
uniform vec4 u_CameraPosition;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

vec3 random3( vec3 p ) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 564.3)),
                 dot(p, vec3(269.5,183.3, 423.7)),
                 dot(p, vec3(419.2,371.9, 139.7))))
                 * 43758.5453);
}

float WorleyNoise(vec3 p) {
    vec3 pInt = floor(p);
    vec3 pFract = fract(p);
    float minDist = 1.0; // Minimum distance initialized to max.
    for(int z = -1; z <= 1; ++z) {
        for(int y = -1; y <= 1; ++y) {
            for(int x = -1; x <= 1; ++x) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3(pInt + neighbor);  // Get the Voronoi center point for this cell.
                vec3 diff = neighbor + point - pFract;  // Distance between fragment coord and neighbor's Voronoi point.
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    }
    return minDist;
}

float sawtoothWave(float x, float freq, float amplitude) {
    return (x * freq - floor(x * freq)) * amplitude; 
}

float bias(float b, float t) {
    return pow(t, log(b) / log(0.5));
}

float smootherstep(float edge0, float edge1, float x) {
    x = clamp((x - edge0)/(edge1 - edge0), 0., 1.);
    return x * x * x *( x * (x * 6. - 15.) + 10.);
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color ;//+ vec4(sin(u_Time), sin(u_Time), sin(u_Time), 0);
        //float diff = dot(normalize(fs_Nor), normalize(fs_LightVec));//= (u_CameraPosition*fs_Nor).z - fs_Nor.z;
        /*
        float diff = dot(normalize(fs_Nor.xyz), normalize(fs_Pos.xyz - u_CameraPosition.xyz));
        diff = clamp(diff,0.0,1.0);

        if (diff >= 2.0) {
            diffuseColor = u_Color;
        }
        if (diff < 2.0) {
            diffuseColor = u_Color + vec4(0, 0.0, 0.0, 0.0);
        }
        if (diff < 1.000000055555) {
            diffuseColor = u_Color + vec4(0.0, 0.5, 0.0, 0.0);
        }
        */

        vec4 flameColor = normalize(diffuseColor + mix(vec4(0.0, 0.0, 1.0, 1.0), vec4(1.0, 0.0, 0.0, 1.0), smoothstep(fs_Pos.y, .0, 1.0)));

        float dist = acos(dot(normalize(fs_Nor.xyz), normalize(u_CameraPosition.xyz))) / (1. * 3.14159);
        dist = smootherstep(0., dist, 0.1);
        diffuseColor = mix(diffuseColor, vec4(.9, .2, 0.0, 1.0), dist);

        diffuseColor = mix(u_Color2, diffuseColor, clamp(WorleyNoise(u_Time * 0.05 + fs_Pos.xyz), 0.5, 1.));
        //diffuseColor = mix(vec4(.9, .2, 0.0, 1.0), diffuseColor, smoothstep(fs_Pos.y - 0.5, 1., 0.6));
        diffuseColor = mix(flameColor, diffuseColor, bias(length(fs_Pos.xz), 0.2));

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_Nor));

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.
        
        // Apply Worley noise in 3D
        float noiseScale = 2.0;  // Adjust scale for how much noise affects color.
        float noiseValue = WorleyNoise(fs_Pos.xyz * noiseScale + u_Time);

        // Final color blending with noise
        vec3 noiseColor = vec3(noiseValue) + 1.0;  // Grayscale noise.
        vec3 finalColor = diffuseColor.rgb * noiseColor;//= mix(diffuseColor.rgb, noiseColor, 0.5);  // Blend diffuse with noise.

        finalColor.r = clamp(finalColor.r, .1, 1.0);
        if(WorleyNoise(fs_Pos.xyz * noiseValue) < .3 && fs_Pos.y > .5){
            //finalColor = vec3(0.2, 0.2, 0.2);
        }
        

        // Output the final shaded color
        out_Col = vec4(finalColor.rgb * lightIntensity, diffuseColor.a);





        //vec2 offset = vec2(WorleyNoise(fs_UV + 1) - WorleyNoise(fs_UV - 1), WorleyNoise(fs_UV + 1) - WorleyNoise(fs_UV - 1));
        //vec3 newOff = vec3(offset.x, offset.y, 1.f);
        // Compute final shaded color
        //out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
        //out_Col += newOff * cos(u_Time * .01) / 2;
}

