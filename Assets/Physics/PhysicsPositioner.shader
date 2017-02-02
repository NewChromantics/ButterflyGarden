Shader "MLF/PhysicsPositioner"
{
	Properties
	{
		ParticleIndex("ParticleIndex", range(0,100) ) = 0
		ParticleIndexScalar("ParticleIndexScalar", range(1,1000) ) = 1
		ColourFast("ColourFast", COLOR ) = ( 0,1,0,1 )
		ColourSlow("ColourSlow", COLOR ) = ( 1,0,0,1 )
		VelocityMax("VelocityMax", Range(0,30000) ) = 1
		VelocityTailScalar("VelocityTailScalar", Range(0,2) ) = 0.4
		GeometryScalar("GeometryScalar", Range(1,100) ) = 1

		VelocityTexture("VelocityTexture", 2D ) = "white" {}
		PositionTexture("PositionTexture", 2D ) = "white" {}
		ForceTexture("ForceTexture", 2D ) = "white" {}

		BoundsSphere("BoundsSphere", VECTOR) = (0,0,0,999999)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		ZTest off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "../../PopUnityCommon/PopCommon.cginc"

			int ParticleIndex;
			float ParticleIndexScalar;
			sampler2D VelocityTexture;
			sampler2D PositionTexture;
			sampler2D ForceTexture;
			float4 PositionTexture_TexelSize;
			float GeometryScalar;

			float4 BoundsSphere;
		
			float4 ColourFast;
			float4 ColourSlow;
			float VelocityMax;
			float VelocityTailScalar;

			struct appdata
			{
				float4 LocalPos : POSITION;
			};

			struct v2f
			{
				float4 Colour : COLOR;
				float4 ScreenPos : SV_POSITION;
			};


			float2 GetPhysicsUv()
			{
				int Index = ParticleIndex * ParticleIndexScalar;

				float2 PhysicsUv;
				PhysicsUv.x = Index % PositionTexture_TexelSize.z;
				PhysicsUv.y = Index / PositionTexture_TexelSize.z;
				PhysicsUv *= PositionTexture_TexelSize.xy;
				return PhysicsUv;
			}

			float3 GetWorldPos()
			{
				float2 PhysicsUv = GetPhysicsUv();
				float3 WorldPos = tex2Dlod( PositionTexture, float4( PhysicsUv, 0, 0 ) );
				return WorldPos;
			}

			float3 GetVelocity()
			{
				float2 PhysicsUv = GetPhysicsUv();
				float3 Vel = tex2Dlod( VelocityTexture, float4( PhysicsUv, 0, 0 ) );
				return Vel;
			}

			float3 RestrictPositionToBounds(float3 Position)
			{
				float3 Center = BoundsSphere.xyz;
				float3 Radius3 = BoundsSphere.www;

				//	gr: act like the bounds in the editor
				Center = mul( UNITY_MATRIX_M, float4(Center,1) );
				Radius3 = mul( UNITY_MATRIX_M, float4(Radius3,0) );

				float Radius = max( max( Radius3.x, Radius3.y ), Radius3.z );


				float3 Delta = Position - Center;
				float Distance = min( Radius, length( Delta ) );
				Position = Center + (normalize(Delta) * Distance);
				return Position;
			}

			v2f vert (appdata v)
			{
				v2f o;

				float3 LocalPos = v.LocalPos;

				float Time = Range( -1, 1, LocalPos.z );
				float3 Velocity3 = GetVelocity();
				float3 PosHead = GetWorldPos();
				float3 PosTail = PosHead - (VelocityTailScalar * Velocity3);

				float3 WorldPos = lerp( PosTail, PosHead, Time );

				//	the geometry is scaled seperately
				LocalPos *= GeometryScalar;

				//	offset the world pos so we can position the swarm properly
				WorldPos = mul( UNITY_MATRIX_M, float4(WorldPos,1) );

				//WorldPos.xy += LocalPos.xy;
				WorldPos += LocalPos;

				WorldPos = RestrictPositionToBounds(WorldPos);

				o.ScreenPos = mul( UNITY_MATRIX_VP, float4(WorldPos,1) );

				float Velocity = min( 1, length( GetVelocity() ) / VelocityMax );
				float Speed = Velocity;
				o.Colour = lerp( ColourSlow, ColourFast, Speed );

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return i.Colour;
			}
			ENDCG
		}
	}
}
