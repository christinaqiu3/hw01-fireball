#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;

uniform float u_Time;
uniform float u_Scale;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

float easeOutBounce(float x) {
    float n1 = 7.5625;
    float d1 = 2.75;

    if (x < 1.0 / d1) {
        return n1 * x * x;
    } else if (x < 2.0 / d1) {
        return n1 * (x - 1.5 / d1) * (x - 1.5 / d1) + 0.75;
    } else if (x < 2.5 / d1) {
        return n1 * (x - 2.25 / d1) * (x - 2.25 / d1) + 0.9375;
    } else {
        return n1 * (x - 2.625 / d1) * (x - 2.625 / d1) + 0.984375;
    }
}

///COMMENT OUT
/*
vec2 smoothF(vec2 uv)
{
    return uv*uv*(vec2(3.f, 3.f) - uv*2.f);
}

float noise(vec2 uv)
{
    const float k = 257.;
    vec4 l  = vec4(floor(uv), fract(uv));
    float u = l.x + l.y * k;
    vec4 v  = vec4(u, u+1.,u+k, u+k+1.);
    v       = fract(fract(v*1.23456789f)*v * (1.f/.987654321f));
    l.z    = smoothF(vec2(l.z, l.w)).r;
    l.w    = smoothF(vec2(l.z, l.w)).g;
    l.x     = mix(v.x, v.y, l.z);
    l.y     = mix(v.z, v.w, l.z);
    return    mix(l.x, l.y, l.w);
}

float fbm(vec2 uv)
{
    float a = 0.5;
    float f = 5.0;
    float n = 0.;
    int it = 8;
    for(int i = 0; i < 32; i++)
    {
        if(i<it)
        {
            n += noise(uv*f)*a;
            a *= .5;
            f *= 2.;
        }
    }
    return n;
}
*/

// procedural noise from IQ
vec2 hash( vec2 p )
{
	p = vec2( dot(p,vec2(127.1,311.7)),
			 dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
	const float K1 = 0.366025404; // (sqrt(3)-1)/2;
	const float K2 = 0.211324865; // (3-sqrt(3))/6;
	
	vec2 i = floor( p + (p.x+p.y)*K1 );
	
	vec2 a = p - i + (i.x+i.y)*K2;
	vec2 o = (a.x>a.y) ? vec2(1.0,0.0) : vec2(0.0,1.0);
	vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0*K2;
	
	vec3 h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	
	vec3 n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
	
	return dot( n, vec3(70.0) );
}

float fbm(vec2 uv)
{
	float f;
	mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
	f  = 0.5000*noise( uv ); uv = m*uv;
	f += 0.2500*noise( uv ); uv = m*uv;
	f += 0.1250*noise( uv ); uv = m*uv;
	f += 0.0625*noise( uv ); uv = m*uv;
	f = 0.5 + 0.5*f;
	return f;
}

float bias(float b, float t) {
    return pow(t, log(b) / log(0.5));
}

float gain(float g, float t) {
    if (t < 0.5) {
        return bias(1.-g, 2.*t) / 2.;
    } else {
        return 1. - bias(1.-g, 2.- 2.*t) / 2.;
    }
}

float triangleWave(float x, float freq, float amplitude) {
    return abs(mod((x * freq), amplitude) - (0.5 * amplitude));
}

float sawtoothWave(float x, float freq, float amplitude) {
    return (x * freq - floor(x * freq)) * amplitude; 
}

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

void main()
{
    float spedTime = u_Time * u_Scale;
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation
    fs_Pos = vs_Pos;
    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    vec4 modelposition = u_Model * vs_Pos;   // Temporarily store the transformed vertex positions for use below
    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies
    float t = easeOutBounce(abs(sin(spedTime)))/2.0;
    float yFactor = clamp((vs_Pos.y + 1.0) / 2.0, 0.0, 1.0);  // Maps y from [-1, 1] to [0, 1]
    float noise = fbm(vs_Pos.xy);
    
    // differnet freq displacements
    float largeDisplacement = sin(cos(spedTime / 50.0) * (15.0 + vs_Pos.z + vs_Pos.x ) ) * 0.5 * yFactor;
    float mediumDisplacement = cos(spedTime/100.0) * 0.5 * yFactor;
    float finerDisplacement = fbm((vs_Pos.xyz * 5.0 + cos(spedTime) * .5).xy) * 0.5 * yFactor;
    
    // Compute the final displacement by combining
    vec3 displacement = normalize(vs_Pos.xyz) * (largeDisplacement + mediumDisplacement);
    displacement.y *= 2.0;

    // Modify the vertex position
    //(x * freq - floor(x * freq)) * amplitude
    displacement.xy += (cos(spedTime)*.5 + 2.5) * yFactor * noise * 2.0;
    displacement.x -= bias(0.5, clamp(modelposition.y, 0.01, 1.)) * fbm(modelposition.xy);//sawtoothWave(5.0 * u_Time, 0.1, 1.0) * yFactor * 5.0 * noise;// - t * cos(u_Time * 3.14 * 5.0) * yFactor;
    displacement.x *= sin(spedTime)*.5+.5;
    
    vec3 modifiedPosition = vs_Pos.xyz + displacement; 

    modelposition.xyz = mix(modifiedPosition.xyz, modelposition.xyz, finerDisplacement)/2.0;
    //modelposition.x += .5 * bias(modelposition.y + 1., 0.6) * sin(modelposition.y * 10.0 - t) * WorleyNoise(modelposition.xyz);
    //modelposition.z += .5 * bias(modelposition.y + 1., 0.6) * cos(modelposition.y * 10.0 - t) * WorleyNoise(modelposition.xyz);

    modelposition.x *= 0.8 - bias(0.5, clamp(modelposition.y, 0.01, 1.)) * fbm(modelposition.xy);
    modelposition.z *= 0.8 - bias(0.5, clamp(modelposition.y, 0.01, 1.)) * fbm(modelposition.xy);

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
