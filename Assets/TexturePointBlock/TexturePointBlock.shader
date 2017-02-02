Shader "MLF/TexturePointBlock"
{
	Properties
	{
		PositionTexture ("PositionTexture", 2D) = "white" {}
		ColourTexture ("ColourTexture", 2D) = "white" {}
		ParticleSize("ParticleSize",Range(0,2) ) = 1
		ParticleSizeMax("ParticleSizeMax",Range(0,2) ) = 1
		ParticleSizeMaxRand("ParticleSizeMaxRand",Range(0,2) ) = 1
		Radius("Radius", Range(0,1) ) = 1
		Density("Density", Range(0,1) ) = 1
		FogColour("FogColour", COLOR ) = (0,0,0,1)
		FogDistanceNear("FogDistanceNear", Range(0,99) ) = 20 
		FogDistanceFar("FogDistanceFar", Range(0,100) ) = 100

		BlobScreenRadius("BlobScreenRadius", Range(0,1) ) = 0.5
		DebugBlob("DebugBlob", Range(0,1) ) = 0
		DebugRandomIndex("DebugRandomIndex", Range(0,1) ) = 0
		//DelayedViewMatrix("DelayedViewMatrix", Matrix )
		BrownianTexture ("BrownianTexture", 2D) = "white" {}
		BrownianTimeScale("BrownianTimeScale", Range(0,10) ) = 1
		BrownianSizeScale("BrownianSizeScale", Range(0,20) ) = 1
		BrownianIndexScale("BrownianIndexScale", Range(1,50) ) = 10
		PerlinTexture("PerlinTexture", 2D ) = "white" {}
		PerlinOffsetScalar("PerlinOffsetScalar", Range(0,30) ) = 1

		InstanceCacheOffset("InstanceCacheOffset", Range(0,200) ) = 0
		InstanceCacheCount("InstanceCacheCount", Range(0,200) ) = 100
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Cull Off

		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers gles

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

		//#define INSTANCING
		#define SAMPLE_POSITION

		//	remove branch by disabling
		//	gr: performance much better ditching polygon
		//#define DEGENERATE_OOB	//	gr: dont need it when all meshes are 100%
		//#define ENABLE_VISIBLE_TEST	//	gr: not needed when we discard by matrix list clipping

		#define SAMPLE_COLOUR
		//#define ENABLE_DENSITY
		#define ENABLE_LAGGED_VIEW
		//#define ENABLE_BROWNIAN_BLOB_PATH
		#define ENABLE_PERLIN_OFFSET
		#define ENABLE_BLOBBING


		//	generate data from instance cache data
		#define USE_INSTANCE_CACHES


		#if defined(USE_INSTANCE_CACHES)
		#define USE_BOUNDING_BOX_POSITION
		#endif

		#if !SHADER_API_MOBILE
		#define ENABLE_DEBUG_BLOB
		#endif

			#include "UnityCG.cginc"
			#include "../../PopUnityCommon/PopCommon.cginc"
			#include "TexturePointBlock.cginc"

			#define vector4	half4
			#define vector3	half3


			struct appdata
			{
				vector4 LocalPos : POSITION;
				float TriangleIndex : TEXCOORD0;

			#if defined(INSTANCING)
				UNITY_VERTEX_INPUT_INSTANCE_ID
			#endif
			};

			struct v2f
			{
				vector4 ScreenPos : SV_POSITION;
				vector3 Colour : TEXCOORD0;
				vector3 LocalPos : TEXCOORD1;

			#if defined(INSTANCING)
				UNITY_VERTEX_INPUT_INSTANCE_ID
			#endif
			};

			#if defined(INSTANCING)
			UNITY_INSTANCING_CBUFFER_START (MyProperties)
				UNITY_DEFINE_INSTANCED_PROP (float4, DataTextureIndexOffset)
				UNITY_DEFINE_INSTANCED_PROP (float4, PointCount)
				UNITY_DEFINE_INSTANCED_PROP (float4, BoundsMin)
				UNITY_DEFINE_INSTANCED_PROP (float4, BoundsMax)
				UNITY_DEFINE_INSTANCED_PROP (float4, Visible)
			UNITY_INSTANCING_CBUFFER_END
			#else
			int DataTextureIndexOffset;
			float3 BoundsMin;
			float3 BoundsMax;
			int PointCount;
			#endif

			#if defined(SAMPLE_POSITION)
			sampler2D PositionTexture;
			float4 PositionTexture_TexelSize;
			#endif

			#if defined(SAMPLE_COLOUR)
			sampler2D ColourTexture;
			float4 ColourTexture_TexelSize;
			#endif

			float ParticleSize;
			float Radius;

			#if defined(ENABLE_DENSITY)
			float Density;
			#endif

			float3 FogColour;
			float FogDistanceNear;
			float FogDistanceFar;

			//	two max's
			float ParticleSizeMax;
			float ParticleSizeMaxRand;
			float BlobScreenRadius;

			#if defined(ENABLE_DEBUG_BLOB)
			int DebugBlob;
			int DebugRandomIndex;
			#else
			#define DebugBlob	0
			#define DebugRandomIndex	0
			#endif

			#if defined(ENABLE_LAGGED_VIEW)
			float4x4 DelayedViewMatrix;
			#endif

			#if defined(ENABLE_BROWNIAN_BLOB_PATH)
			sampler2D BrownianTexture;
			float4 BrownianTexture_TexelSize;
			float BrownianTimeScale;
			float BrownianSizeScale;
			float BrownianIndexScale;	//	random number scaling
			#endif

			#if defined(ENABLE_PERLIN_OFFSET)
			sampler2D PerlinTexture;
			float4 PerlinTexture_TexelSize;
			float PerlinOffsetScalar;
			float BrownianIndexScale;	//	random number scaling
			#endif


		
			vector4 GetDataTexturePosition(int PointIndex,float3 BoundsMin,float3 BoundsMax)
			{
			#if defined(SAMPLE_POSITION)
				float width = PositionTexture_TexelSize.z;
				float x = fmod( PointIndex, width );
				float y = PointIndex / width;
				
				float2 uv = float2( x, y ) * PositionTexture_TexelSize.xy;
				vector4 Position = tex2Dlod( PositionTexture, float4(uv,0,0) );
			#endif

				/*
			#if !defined(USE_BOUNDING_BOX_POSITION)
				//	bounds is in world space, we need to scale to the bounds size, and offset from the middle of it, but not MOVE to the middle
				vector3 BoundsCenter = lerp( BoundsMin, BoundsMax, 0.5f );
				BoundsMax -= BoundsCenter;
				BoundsMin -= BoundsCenter;
			#endif
				//	BoundsMax = mul( unity_ObjectToWorld, float4(BoundsMax,0 ) );


				Position.xyz *= BoundsMax - BoundsMin;
				Position.xyz += BoundsMin;
				//Position.xyz += BoundsMax;
				*/
				return Position;			
			}

			vector3 GetDataTextureColour(int PointIndex,float PositionDataW)
			{
			#if defined(SAMPLE_COLOUR)
				float width = ColourTexture_TexelSize.z;
				float x = fmod( PointIndex, width );
				float y = PointIndex / width;
				
				float2 uv = float2( x, y ) * ColourTexture_TexelSize.xy;
				return tex2Dlod( ColourTexture, float4(uv,0,0) );
			#else
				return vector3(PositionDataW,PositionDataW,PositionDataW);
			#endif
			}

			float GetBlobFactor(float4 WorldPos)
			{
				//	get -1...1

				#if defined(ENABLE_LAGGED_VIEW)
				float4x4 ViewProjection = mul( UNITY_MATRIX_P, DelayedViewMatrix );
				#else
				float4x4 ViewProjection = UNITY_MATRIX_VP;
				//float4x4 ViewProjection = mul( UNITY_MATRIX_P, UNITY_MATRIX_V );
				#endif

				float4 ScreenPos4 = mul( ViewProjection, WorldPos );
				float2 ScreenPos = ScreenPos4.xy / ScreenPos4.w;

				float Radius = length(ScreenPos);
				float RadiusMax = hypotenuse( 1, 1 );
				float BlobTime = Range( BlobScreenRadius, RadiusMax, Radius );
				BlobTime = max( BlobTime, 0.0f );

				//	when using the deffered view matrix, anything that WAS outside the viewport will be massive, so clamp
				BlobTime = min( BlobTime, 1.0f );

				return BlobTime;
			}


			float3 GetFoggedColour(float3 Rgb,float3 ParticlePosition,float3 CameraPosition)
			{
				float ParticleDistance = distance( ParticlePosition, CameraPosition );
				float FogTime = Range( FogDistanceNear, FogDistanceFar, ParticleDistance );
				FogTime = max( 0, min( FogTime, 1 ) );
				return lerp( Rgb, FogColour, FogTime );
			}

			float2 GetUvFromU(float u,float4 TexelSize)
			{
				float2 uv;
				uv.x = frac( u );
				uv.y = floor( u ) / TexelSize.w;
				uv.y = frac( uv.y );
				return uv;
			}

			float3 GetNoiseOffset(float ParticleOffset)
			{
				#if defined(ENABLE_PERLIN_OFFSET)

				ParticleOffset *= BrownianIndexScale;

				float2 Perlinuv = GetUvFromU( ParticleOffset * BrownianIndexScale, PerlinTexture_TexelSize );
				float3 offset = tex2Dlod( PerlinTexture, float4( Perlinuv, 0, 0 ) ).xyz;

				offset -= 0.5f;

				offset *= PerlinOffsetScalar;
				return offset;

				#elif defined(ENABLE_BROWNIAN_BLOB_PATH)

				float2 BrownianSize = BrownianTexture_TexelSize.zw;
				float Time = _Time.x * BrownianTimeScale;
				Time += ParticleOffset * BrownianIndexScale;
				float u = frac( Time );
				float v = floor(Time) / BrownianSize.y;
				v = frac(v);
				float3 Offset = tex2Dlod( BrownianTexture, float4(u,v,0,0) );
				Offset *= BrownianSizeScale;
				Offset *= BlobFactor;
				return Offset;

				#else
				return float3(0,0,0);
				#endif
			}



			v2f vert (appdata v)
			{
				v2f o;
			#if defined(INSTANCING)
				UNITY_SETUP_INSTANCE_ID (v);
				UNITY_TRANSFER_INSTANCE_ID (v, o);	
						
				int ThisDataTextureIndexOffset = UNITY_ACCESS_INSTANCED_PROP (DataTextureIndexOffset).x;
				int ThisPointCount = UNITY_ACCESS_INSTANCED_PROP(PointCount).x;
				float3 ThisBoundsMin = UNITY_ACCESS_INSTANCED_PROP(BoundsMin).xyz;
				float3 ThisBoundsMax = UNITY_ACCESS_INSTANCED_PROP(BoundsMax).xyz;
				bool ThisVisible = UNITY_ACCESS_INSTANCED_PROP(Visible).x > 0;
				float ThisRandom = v.TriangleIndex / (float)ThisPointCount;
			#endif

				bool Degenerate = false;

			
				int BlockSubIndex;
				TTexturePointBlock Block = GetInvalidTTexturePointBlock();
				GetTexturePointBlock( Block, v.TriangleIndex, BlockSubIndex);
				Degenerate = !TTexturePointBlock_IsValid(Block);

				int ThisDataTextureIndexOffset = TTexturePointBlock_DataTextureIndexOffset(Block);
				int DataIndex = BlockSubIndex;
				int PointIndex = ThisDataTextureIndexOffset + BlockSubIndex;

				bool ThisVisible = true;
				float3 ThisBoundsMin = TInstanceCache_BoundsMin(Block);
				float3 ThisBoundsMax = TTexturePointBlock_BoundsMax(Block);
				float ThisRandom = TTexturePointBlock_Randomf(Block);


			#if defined(DEGENERATE_OOB)
				if ( Degenerate )
				{
					return (v2f)0;
				}
			#endif

			#if defined(ENABLE_VISIBLE_TEST)
				if ( !ThisVisible )
				{
					return (v2f)0;
				}
			#endif

			#if defined(ENABLE_DENSITY)
				#if defined(USE_INSTANCE_CACHES)
				#error can't do ENABLE_DENSITY and USE_INSTANCE_CACHES
				#endif
				float Indexf = DataIndex / (float)ThisPointCount;
				Indexf *= 1.0f / Density;
				if ( Indexf > 1 )
				{
					return (v2f)0;
				}
			#endif

				vector3 LocalPos = v.LocalPos.xyz;
				o.LocalPos = LocalPos;

				//	data w is luminance (for when testing without colour sampling, or maybe later being used for a palette lookup, 
				//	but performance doesnt seem to make much difference with texture lookups, very fast on mobile. fill rate/tile touching hurts more
				vector4 DataPosition = GetDataTexturePosition( PointIndex, ThisBoundsMin, ThisBoundsMax );
				o.Colour = GetDataTextureColour( PointIndex, DataPosition.w );
				DataPosition.w = 1;


				vector4 WorldPos = mul( unity_ObjectToWorld, DataPosition );

			#if defined(ENABLE_BLOBBING)
				//	scale the particle size by blobbing, which is based on screen pos
				//	gr: scale before noise
				float BlobScalar = GetBlobFactor( WorldPos );

				float3 Offset = GetNoiseOffset( ThisRandom );
				float NoiseBlobScalar = BlobScalar;
				WorldPos.xyz += Offset * NoiseBlobScalar;

				//	rescale again so particles flying into the middle of our view don't obscure us
				BlobScalar = GetBlobFactor( WorldPos );

				float ParticleSizeMixed = lerp( ParticleSizeMax, ParticleSizeMaxRand, ThisRandom );
				float ParticleSized = lerp( ParticleSize, ParticleSizeMixed, BlobScalar );
				vector3 ParticleSize3 = mul( unity_ObjectToWorld, vector4( ParticleSized,ParticleSized,ParticleSized,0 ) );
			#else
				vector3 ParticleSize3 = float3( ParticleSize,ParticleSize,ParticleSize );
			#endif
				//	gr: todo: cap SCREEN space size (in frag?)

				//	+ offset here is billboarding in view space
				vector4 ViewPos = mul( UNITY_MATRIX_V, WorldPos ) + vector4( LocalPos * ParticleSize3, 1 );
				o.ScreenPos = mul( UNITY_MATRIX_P, ViewPos );


				o.Colour.xyz = GetFoggedColour( o.Colour.xyz, WorldPos.xyz, _WorldSpaceCameraPos );

				if ( DebugBlob )
					o.Colour.xyz = NormalToRedGreen( GetBlobFactor(WorldPos) );

				if ( DebugRandomIndex )
					o.Colour.xyz = NormalToRedGreen( ThisRandom );

				//o.Colour.xyz = NormalToRedGreen( DataIndex/2000.0f );
				//o.Colour.xyz = NormalToRedGreen( v.TriangleIndex/20000.0f );

				//	debug our random value
				//o.Colour.xyz = ThisRandom;

				if ( Degenerate )
				{
					o.Colour.xyz = float3(0,0,1);
				}
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				if ( length(i.LocalPos) > Radius )
					discard;

				return vector4( i.Colour, 1);
			}
			ENDCG
		}
	}
}
