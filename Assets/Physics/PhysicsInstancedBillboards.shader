Shader "MLF/PhysicsInstancedBillboards"
{
	Properties
	{
		ParticleSize("ParticleSize",Range(0.001,1) ) = 0.1
		Radius("Radius", Range(0,1) ) = 0.5
		ParticleColour("ParticleColour", COLOR ) = (0,1,0,1)

		VelocityTexture("VelocityTexture", 2D ) = "white" {}
		PositionTexture("PositionTexture", 2D ) = "white" {}
		ForceTexture("ForceTexture", 2D ) = "white" {}

		DebugColour("DebugColour", Range(0,1) ) = 0
		RgbaScalar("RgbaScalar", Range(0,1) ) = 1

		ForceMax("ForceMax", Range(0,30) ) = 30
		VelocityMax("VelocityMax", Range(0,30) ) = 30
		ForceGlowRgbaScalar("ForceGlowRgbaScalar", Range(0,1) ) = 1
		VelocityGlowRgbaScalar("VelocityGlowRgbaScalar", Range(0,1) ) = 1

		AlphaMult("AlphaMult", Range(0,1) ) = 1
		FadeFromColour("FadeFromColour", COLOR ) = (0,0,0,0)
	}
		SubShader
	{
		Tags { "RenderType"="Transparent" }
		LOD 100
		Cull off
		//Blend Off
		Blend One One
		ZTest off
		ZWrite Off

		Pass
	{
		CGPROGRAM

		//	geometry shader needs GL ES 3+
		//	https://docs.unity3d.com/Manual/SL-ShaderCompileTargets.html
	#pragma target 3.5

	#pragma vertex vert
	#pragma fragment frag
	#pragma multi_compile_instancing

	#include "UnityCG.cginc"
	#include "../../PopUnityCommon/PopCommon.cginc"

	#define lengthsq(x)	dot( (x), (x) )
	#define squared(x)	( (x)*(x) )


		struct app2vert
	{
		float4 LocalPos : POSITION;
		fixed4 Rgba : COLOR;
		fixed3 Normal : NORMAL;
		fixed2 Uv : TEXCOORD0;
		fixed3 Bary : TEXCOORD1;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct FragData
	{
		float4 ScreenPos : SV_POSITION;
		fixed3 LocalOffset : TEXCOORD0;
		fixed4 Colour : TEXCOORD1;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	UNITY_INSTANCING_CBUFFER_START (MyProperties)
		UNITY_DEFINE_INSTANCED_PROP (float4, Colour)
		UNITY_DEFINE_INSTANCED_PROP (float4, Noise)
	UNITY_INSTANCING_CBUFFER_END

	float ParticleSize;
	float Radius;
	float4 ParticleColour;
	float DebugColour;
	float RgbaScalar;

	sampler2D VelocityTexture;
	sampler2D PositionTexture;
	sampler2D ForceTexture;
	float4 PositionTexture_TexelSize;


	float VelocityGlowRgbaScalar;
	float ForceGlowRgbaScalar;
	float VelocityMax;
	float ForceMax;
	float AlphaMult;
	float4 FadeFromColour;


	fixed3 GetParticleSize3()
	{
		return float3(ParticleSize,ParticleSize,ParticleSize);
		//	gr: thought it length of each row was scale but... doesn't seem to be. row vs col major issue?
		//float WorldScale = length(unity_ObjectToWorld[0]) + length(unity_ObjectToWorld[1]) + length(unity_ObjectToWorld[2]);
		//WorldScale /= 3.0;

		fixed3 OneTrans = mul( unity_ObjectToWorld, float4(1,0,0,0 ) );
		fixed3 ZeroTrans = mul( unity_ObjectToWorld, float4(0,0,0,0 ) );
		float WorldScale = length(OneTrans - ZeroTrans);
		fixed3 ParticleSize3 = float3( ParticleSize * WorldScale, ParticleSize * WorldScale, ParticleSize * WorldScale );
		return ParticleSize3;
	}

	FragData MakeFragData(fixed3 TriangleIndexer,float3 input_WorldPos,float3 input_LocalPos,fixed4 input_Rgba,fixed3 ParticleSize3)
	{
		FragData x = (FragData)0;

		x.LocalOffset = input_LocalPos;

		float3 x_WorldPos = mul( UNITY_MATRIX_V, float4(input_WorldPos,1) ) + (x.LocalOffset * ParticleSize3);
		//float3 x_WorldPos = mul( UNITY_MATRIX_V, float3(0,0,0) ) + (x.LocalOffset * ParticleSize3);
		x.ScreenPos = mul( UNITY_MATRIX_P, float4(x_WorldPos,1) );
		
		x.Colour = input_Rgba;
		//x.Colour = ParticleColour;
		/*
		x.Colour = lerp( x.Colour, input_Rgba, UseVertexColour );
		x.Colour = lerp( x.Colour, float4(TriangleIndexer,1), UseDebugColour );
		*/
		return x;
	}


	FragData MakeFragData(fixed3 TriangleIndexer,float3 input_WorldPos,fixed4 input_Rgba,fixed3 ParticleSize3)
	{
		fixed isa = TriangleIndexer.x ;
		fixed isb = TriangleIndexer.y ;
		fixed isc = TriangleIndexer.z ;

		//	gr: use maths to work out biggest circle 
		fixed Top = -0.6;
		fixed Bottom = 0.3;
		fixed Width = 0.5;
		float3 LocalOffset;
		LocalOffset = isa * fixed3( 0,Top,0 );
		LocalOffset += isb * fixed3( -Width,Bottom,0 );
		LocalOffset += isc * fixed3( Width,Bottom,0 );

		return MakeFragData( TriangleIndexer, input_WorldPos, LocalOffset, input_Rgba, ParticleSize3 );
	}


	float4 GetColour(float4 Rgba,float4 Noise4,float Scalar)
	{
		Rgba.xyz *= Noise4.y * Scalar;
 
		return Rgba;
	}

	FragData vert(app2vert v)
	{
		FragData o;
		UNITY_SETUP_INSTANCE_ID (v);
		UNITY_TRANSFER_INSTANCE_ID (v, o);
		float4 Rgba = UNITY_ACCESS_INSTANCED_PROP (Colour);
		float4 Noise4 = UNITY_ACCESS_INSTANCED_PROP (Noise);
		float2 ImageUv = Noise4.zw;

		float4 BaseColour = GetColour( Rgba, Noise4, RgbaScalar );


		float4 LocalPos = v.LocalPos;

		float3 WorldPos = mul( unity_ObjectToWorld, float4(0,0,0,1) );
		/*
		float3 NoiseOffset = GetNoiseOffset( Noise4 );
		float DistanceToGaze = GetDistanceToGaze( WorldPos );
		DistanceToGaze = min( 1, DistanceToGaze / DistanceToGazeMax );
		float GazeScore = 1 - DistanceToGaze;
		float NoiseWorldScale = lerp( NoiseScaleMin, NoiseScaleMax, GazeScore );
		WorldPos += NoiseOffset * NoiseWorldScale;
		*/
		fixed3 ParticleSize3 = GetParticleSize3();

		int PositionIndex = Noise4.x;
		float2 PhysicsUv;
		PhysicsUv.x = PositionIndex % PositionTexture_TexelSize.z;
		PhysicsUv.y = PositionIndex / PositionTexture_TexelSize.z;
		PhysicsUv *= PositionTexture_TexelSize.xy;
		//PhysicsUv.y = 1 - PhysicsUv.y;

		//	subsampling?
		//PhysicsUv += PositionTexture_TexelSize.xy * 0.5f;

		float3 PhysicsVelocity = tex2Dlod( VelocityTexture, float4( PhysicsUv, 0, 0 ) );
		float3 PhysicsPosition = tex2Dlod( PositionTexture, float4( PhysicsUv, 0, 0 ) );
		float3 PhysicsForce = tex2Dlod( ForceTexture, float4( PhysicsUv, 0, 0 ) );

		//WorldPos += Position;
		WorldPos = PhysicsPosition;

		//o = MakeFragData( v.Normal, WorldPos, v.Rgba.xyz, ParticleSize3 );
		o = MakeFragData( v.Bary, WorldPos, LocalPos, BaseColour, ParticleSize3 );

		//o.ScreenPos = UnityObjectToClipPos( LocalPos );
		/*
		o.Colour.xyz = NormalToRedGreen( 0 );
		o.Colour.xy = PhysicsUv;
		o.Colour.z = 0;
		*/

		//o.Colour.xy = 0;
		//o.Colour.z = PositionIndex / 16000.0f;
		float Forcef = min( 1, length(PhysicsForce) / ForceMax );
		float Velocityf = min( 1, length(PhysicsVelocity) / VelocityMax );
		float3 ForceColour = NormalToRedGreen( Forcef );
		float3 VelocityColour = NormalToRedGreen( Velocityf );

		float4 ForceGlowColour = GetColour( Rgba, Noise4, ForceGlowRgbaScalar );
		o.Colour = lerp( BaseColour, ForceGlowColour, Forcef );

		float4 VelocityGlowColour = GetColour( Rgba, Noise4, VelocityGlowRgbaScalar );
		o.Colour = lerp( BaseColour, VelocityGlowColour, Velocityf );

		o.Colour.xyz = lerp( o.Colour.xyz, ForceColour, DebugColour );


		o.Colour = lerp( FadeFromColour, o.Colour, AlphaMult );
		//o.Colour.xyz = lerp( float3(1,0,0), o.Colour.xyz, FadeInTime );

	
		return o;
	}


	fixed4 frag(FragData i) : SV_Target
	{
		UNITY_SETUP_INSTANCE_ID (i); 
		//return UNITY_ACCESS_INSTANCED_PROP (Colour);
		float4 Noise4 = UNITY_ACCESS_INSTANCED_PROP (Noise);

		float DistanceFromCenterSq = lengthsq(i.LocalOffset);

		if ( DistanceFromCenterSq > squared(Radius) )
			discard;

		return fixed4( i.Colour );
		}
		ENDCG
	}
	}
}
