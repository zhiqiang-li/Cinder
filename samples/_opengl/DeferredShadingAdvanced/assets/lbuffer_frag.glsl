#version 400 core

const vec2 poissonDisk[ 16 ] = vec2[] (
	vec2( -0.06095261, -0.1337204 ),
	vec2(  0.4983526,  0.233555 ),
	vec2( -0.2842098, -0.5506849 ),
	vec2(  0.05801121, 0.6332615 ),
	vec2( -0.5088959, -0.003537838 ),
	vec2(  0.4832182, -0.2853011 ),
	vec2( -0.8192781, -0.2787592 ),
	vec2(  0.1339615, -0.6042675 ),
	vec2(  0.5493031, -0.8009133 ),
	vec2(  0.9285686,  0.146349 ),
	vec2( -0.2837186, -0.9508537 ),
	vec2(  0.5228189,  0.8005553 ),
	vec2( -0.4011278,  0.5258422 ),
	vec2( -0.2490727,  0.9233519 ),
	vec2( -0.8024328,  0.3718062 ),
	vec2( -0.6656654, -0.7041242 )
);

const uint MATERIAL_COUNT = 3;

uniform sampler2D		uSamplerAlbedo;
uniform usampler2D		uSamplerMaterial;
uniform sampler2D		uSamplerNormal;
uniform sampler2D		uSamplerPosition;
uniform sampler2DShadow uSamplerShadowMap;

uniform vec4	uLightColorAmbient;
uniform vec4	uLightColorDiffuse;
uniform vec4	uLightColorSpecular;
uniform float	uLightIntensity;
uniform vec3	uLightPosition;
uniform float	uLightRadius;

uniform float	uShadowBlurSize;
uniform bool	uShadowEnabled;
uniform mat4 	uShadowMatrix;
uniform float	uShadowSamples;

uniform mat4 	uViewMatrixInverse;
uniform vec2	uWindowSize;

struct Material
{
	vec4	ambient;
	vec4	diffuse;
	vec4	emissive;
	vec4	specular;
	float	shininess;
	float	twoSided;
	uint 	pad0; // std140
	uint 	pad1; // std140
};

uniform Materials
{
	Material uMaterials[ MATERIAL_COUNT ];
};

in Vertex
{
	vec2 	uv;
} vertex;

out vec4 	oColor;

float random( vec4 seed4 ) 
{
	return fract( sin( dot( seed4, vec4( 12.9898, 78.233, 45.164, 94.673 ) ) ) * 43758.5453 );
}

vec2 poisson( int index, float blurSize ) 
{
	return poissonDisk[ int( 16.0 * random( vec4( gl_FragCoord.xyy, index ) ) ) % 16 ] * blurSize;
}

float shadow( in vec4 position )
{
	vec4 shadowClip 	= uShadowMatrix * uViewMatrixInverse * position;
	vec3 shadowCoord 	= shadowClip.xyz / shadowClip.w;
	shadowCoord 		= shadowCoord * 0.5 + 0.5;

	float bias			= 0.86;
	float v 			= 0.0;
	float e				= 1.0 / float( uShadowSamples );
	if ( shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0 ) {
		for ( int i = 0; i < uShadowSamples; ++i ) {
			float depth	= texture( uSamplerShadowMap, shadowCoord + vec3( poisson( i, uShadowBlurSize ), 0.0 ) );
			if ( depth > shadowCoord.z - bias ) {
				v		+= e;
			}
		}
	}
	return v;
}

void main( void )
{
	vec2 uv				= gl_FragCoord.xy / uWindowSize;

	vec4 position 		= texture( uSamplerPosition, uv );
	vec3 L 				= uLightPosition - position.xyz;
	float d 			= length( L );
	if ( d > uLightRadius ) {
		discard;
	}
	L 					/= d;
	
	vec4 albedo 		= texture( uSamplerAlbedo, 		uv );
	uint materialId 	= texture( uSamplerMaterial, 	uv ).r;
	Material material 	= uMaterials[ materialId ];

	vec4 normalDepth 	= texture( uSamplerNormal, uv );
	vec3 N 				= normalize( normalDepth.xyz );
	vec3 V 				= normalize( -position.xyz );
	vec3 H 				= normalize( L + V );
	float NdotL 		= max( 0.0, dot( N, L ) );
	float HdotN 		= max( 0.0, dot( H, N ) );
	float Ks		 	= pow( HdotN, material.shininess );

	vec4 Ia 			= uLightColorAmbient * material.ambient;
	vec4 Id 			= NdotL * uLightColorDiffuse * albedo * material.diffuse;
	vec4 Ie 			= material.emissive;
	vec4 Is 			= Ks * uLightColorSpecular * material.specular;

	float att			= 1.0 / pow( ( d / ( 1.0 - pow( d / uLightRadius, 2.0 ) ) ) / uLightRadius + 1.0, 2.0 ); 

	oColor 				= Ia + att * ( Id + Is ) + Ie;
	if ( uShadowEnabled ) {
		oColor			*= shadow( position );
	}
	oColor				*= uLightIntensity;
}
