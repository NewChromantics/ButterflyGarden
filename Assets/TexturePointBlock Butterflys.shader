Shader "New Chromantics/TexturePointBlockButterflys"
{
	Properties
	{
		PositionTexture ("PositionTexture", 2D) = "white" {}
		OriginalPositionTexture ("OriginalPositionTexture", 2D) = "white" {}
		ColourTexture ("ColourTexture", 2D) = "white" {}
		SpriteMask ("SpriteMask", 2D) = "white" {}
		ParticleSize("ParticleSize",Range(0,2) ) = 1
		Radius("Radius", Range(0,2) ) = 1
		DebugRandomIndex("DebugRandomIndex", Range(0,1) ) = 0
		DebugSeamUv("DebugSeamUv", Range(0,1) ) = 0
		DebugWingUv("DebugWingUv", Range(0,1) ) = 0
		
			//DelayedViewMatrix("DelayedViewMatrix", Matrix )
		PerlinTexture("PerlinTexture", 2D ) = "white" {}
		PerlinOffsetScalar("PerlinOffsetScalar", Range(0,30) ) = 1

		InstanceCacheOffset("InstanceCacheOffset", Range(0,200) ) = 0
		InstanceCacheCount("InstanceCacheCount", Range(0,200) ) = 100

		RotationDegrees("RotationDegrees", Range(-180,180)) = 0
		TriangleOutlineWidth("TriangleOutlineWidth", Range(0,0.333) ) = 0.05

		FlapSpeed("FlapSpeed", Range(0,200) ) = 1
		FlapHeightMin("FlapHeightMin", Range(-3,3) ) = 1
		FlapHeightMaxA("FlapHeightMaxA", Range(-3,3) ) = 1
		FlapHeightMaxB("FlapHeightMaxB", Range(-3,3) ) = 1

		ColourAA("ColourAA", COLOR ) = (1,0,0,1)
		ColourAB("ColourAB", COLOR ) = (1,1,0,1)
		ColourBA("ColourBA", COLOR ) = (0,1,0,1)
		ColourBB("ColourBB", COLOR ) = (0,0,1,1)
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
		#define ENABLE_PERLIN_OFFSET
	
		//	generate data from instance cache data
		#define USE_INSTANCE_CACHES


		#if defined(USE_INSTANCE_CACHES)
		#define USE_BOUNDING_BOX_POSITION
		#endif

		
			#include "UnityCG.cginc"
			#include "../PopUnityCommon/PopCommon.cginc"
			#include "TexturePointBlock/TexturePointBlock.cginc"

			#define vector4	half4
			#define vector3	half3
			#define vector2	half2


			struct appdata
			{
				vector4 LocalPos : POSITION;
				float2 TriangleIndex_LocalPointIndex : TEXCOORD0;

			#if defined(INSTANCING)
				UNITY_VERTEX_INPUT_INSTANCE_ID
			#endif
			};

			struct v2f
			{
				vector4 ScreenPos : SV_POSITION;
				vector3 Colour : TEXCOORD0;
				vector3 LocalPos : TEXCOORD1;
				vector3 uvw : TEXCOORD2;
				vector2 SeamUv : TEXCOORD3;
				vector2 WingUv : TEXCOORD4;
				float3 Bary : TEXCOORD5;
				float Random : TEXCOORD6;

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
			sampler2D OriginalPositionTexture;
			float4 PositionTexture_TexelSize;
			#endif

			#if defined(SAMPLE_COLOUR)
			sampler2D ColourTexture;
			float4 ColourTexture_TexelSize;
			#endif
			
			sampler2D SpriteMask;

			float ParticleSize;
			float Radius;
			float RotationDegrees;
			float TriangleOutlineWidth;

			int DebugRandomIndex;
			int DebugSeamUv;
			int DebugWingUv;

			#if defined(ENABLE_LAGGED_VIEW)
			float4x4 DelayedViewMatrix;
			#endif

		
			#if defined(ENABLE_PERLIN_OFFSET)
			sampler2D PerlinTexture;
			float4 PerlinTexture_TexelSize;
			float PerlinOffsetScalar;
			float BrownianIndexScale;	//	random number scaling
			#endif

			float FlapSpeed;
			float FlapHeightMin;
			float FlapHeightMaxA;
			float FlapHeightMaxB;

			float3 ColourAA;
			float3 ColourAB;
			float3 ColourBA;
			float3 ColourBB;
		
			vector4 GetDataTexturePosition(int PointIndex,float3 BoundsMin,float3 BoundsMax)
			{
			#if defined(SAMPLE_POSITION)
				float width = PositionTexture_TexelSize.z;
				float x = fmod( PointIndex, width );
				float y = PointIndex / width;
				
				float2 uv = float2( x, y ) * PositionTexture_TexelSize.xy;
				vector4 Position = tex2Dlod( PositionTexture, float4(uv,0,0) );

				//	the physics blit's lose alpha, get the original
				Position.w = tex2Dlod( OriginalPositionTexture, float4(uv,0,0) ).w;
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

				
				#else
				return float3(0,0,0);
				#endif
			}


			float2 GetSeamAlignedUv(float2 uv)
			{
				//	need to essentially rotate the UV's 45 degrees so our uv goes along the seam
				//	-1,-1 topleft becomes -1,05
				//	1,-1 topright becomes 05,-1

				float s = sin ( radians(RotationDegrees) );
				float c = cos ( radians(RotationDegrees) );
				float2x2 rotationMatrix = float2x2( c, -s, s, c);
				/*
				rotationMatrix *=0.5;
				rotationMatrix +=0.5;
				rotationMatrix = rotationMatrix * 2-1;
				*/
				uv = mul ( uv, rotationMatrix );
				
				//	scale down as when we rotate we go out of bounds
				float Scale = hypotenuse(1,1);
				uv *= Scale;

				float u = Range( -1, 1, uv.x );
				float v = Range( -1, 1, uv.y );
				return float2( u,v );
			}

			float2 GetWingUv(float2 SeamAlignedUv)
			{
				float v = SeamAlignedUv.y;
				float u = SeamAlignedUv.x;
				
				if ( SeamAlignedUv.x < 0.5f )
					u = Range( 0.5f, 0, SeamAlignedUv.x );
				else
					u = Range( 0.5f, 1, SeamAlignedUv.x );
				u = clamp( 0, 1, u );
				v = clamp( 0, 1, v );

				return float2(u,v);
			}

			//	uv is -1 to 1
			float3 GetWingPos(float2 uv,float2 WingUv,float Random)
			{
				float Angle = lerp( 0, 360, Random );
				Angle += lerp( 0, 360, frac( _Time.x * FlapSpeed ) );
				float FlapTime = cos( radians(Angle) );
				
				//float FlapTime = 0;

				//float u = abs( uv.x );

				FlapTime = Range( -1, 1, FlapTime );
				float FlapHeightMax = lerp( FlapHeightMaxA, FlapHeightMaxB, Random );
				float FlapHeight = lerp( FlapHeightMin, FlapHeightMax, FlapTime );

				//	middle height = 0
				float y = WingUv.x * FlapHeight;
				//float y = 0;

				//	now square it
				float x = uv.x;
				float z = uv.y;

				return float3( x,y,z ) * ParticleSize;
			}


			v2f vert (appdata v)
			{
				v2f o;

				int TriangleIndex = v.TriangleIndex_LocalPointIndex.x;
				int LocalPointIndex = v.TriangleIndex_LocalPointIndex.y;


			#if defined(INSTANCING)
				UNITY_SETUP_INSTANCE_ID (v);
				UNITY_TRANSFER_INSTANCE_ID (v, o);	
				
				int ThisDataTextureIndexOffset = UNITY_ACCESS_INSTANCED_PROP (DataTextureIndexOffset).x;
				int ThisPointCount = UNITY_ACCESS_INSTANCED_PROP(PointCount).x;
				float3 ThisBoundsMin = UNITY_ACCESS_INSTANCED_PROP(BoundsMin).xyz;
				float3 ThisBoundsMax = UNITY_ACCESS_INSTANCED_PROP(BoundsMax).xyz;
				bool ThisVisible = UNITY_ACCESS_INSTANCED_PROP(Visible).x > 0;
				float ThisRandom = TriangleIndex / (float)ThisPointCount;
			#endif

				bool Degenerate = false;

			
				int BlockSubIndex;
				TTexturePointBlock Block = GetInvalidTTexturePointBlock();

				GetTexturePointBlock( Block, TriangleIndex, BlockSubIndex);
				Degenerate = !TTexturePointBlock_IsValid(Block);

				int ThisDataTextureIndexOffset = TTexturePointBlock_DataTextureIndexOffset(Block);
				int DataIndex = BlockSubIndex;
				int PointIndex = ThisDataTextureIndexOffset + BlockSubIndex;

				bool ThisVisible = true;
				float3 ThisBoundsMin = TInstanceCache_BoundsMin(Block);
				float3 ThisBoundsMax = TTexturePointBlock_BoundsMax(Block);
				

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


				vector3 LocalPos = v.LocalPos.xyz;
				o.LocalPos = LocalPos;
				o.uvw = o.LocalPos;
				o.SeamUv = GetSeamAlignedUv( o.LocalPos );
				o.WingUv = GetWingUv( o.SeamUv );

				//	data w is luminance (for when testing without colour sampling, or maybe later being used for a palette lookup, 
				//	but performance doesnt seem to make much difference with texture lookups, very fast on mobile. fill rate/tile touching hurts more
				vector4 DataPosition = GetDataTexturePosition( PointIndex, ThisBoundsMin, ThisBoundsMax );
				float Random = DataPosition.w;
				o.Colour = GetDataTextureColour( PointIndex, DataPosition.w );
				DataPosition.w = 1;

				float3 Barys[4] = 
				{ 
					float3(1,0,0),	//	top left - left triangle only
					float3(0,1,0),	//	top right
					float3(0,0,1),	//	bottom left
					float3(1,0,0),	//	bottom right - right triangle only
				};
				o.Bary = Barys[LocalPointIndex];
				o.Random = Random;

				LocalPos = GetWingPos( LocalPos, o.WingUv, Random );

				vector3 ParticleSize3 = float3( ParticleSize,ParticleSize,ParticleSize );
			
				vector3 WorldPos =  mul( unity_ObjectToWorld, DataPosition + LocalPos );
				o.ScreenPos = mul( UNITY_MATRIX_VP, float4(WorldPos,1) );
			
				if ( DebugRandomIndex )
					o.Colour.xyz = NormalToRedGreen( Random );

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
				if ( TriangleOutlineWidth > 0 )
					if ( min3( i.Bary.x,i.Bary.y,i.Bary.z ) < TriangleOutlineWidth )
						return float4(1,1,1,1);
			
			if ( i.SeamUv.x > 1 )	discard;
			if ( i.SeamUv.y > 1 )	discard;
			if ( i.SeamUv.x < 0 )	discard;
			if ( i.SeamUv.y < 0 )	discard;

				if ( DebugRandomIndex )
					return float4( i.Colour, 1);

				float3 Mask3 = tex2D( SpriteMask, i.SeamUv ).xyz;
				
				if ( Mask3.y < 0.5f && Mask3.x > 0.5f )
					discard;
				
				if ( length(i.LocalPos) > Radius )
					discard;

				/*
				if ( i.WingUv.x > 0.98f )
					return float4(0,1,0,1);

				if ( i.SeamUv.x > 0.98f )
					return float4(0,0,1,1);
				if ( i.SeamUv.x < 1-0.98f )
					return float4(0,0,1,1);
					*/
				if ( DebugSeamUv )
					return float4( i.SeamUv, 0, 1);

				if ( DebugWingUv )
					return float4( i.WingUv.xy,0, 0 );

				float3 ColourA = lerp( ColourAA, ColourAB, i.WingUv.y );
				float3 ColourB = lerp( ColourBA, ColourBB, i.WingUv.y );

				float3 rgb = lerp( ColourA, ColourB, i.Random );
				rgb *= Mask3;

				return float4( rgb, 1 );
				return vector4( i.uvw, 1 );
				return vector4( i.Colour, 1);
			}
			ENDCG
		}
	}
}
