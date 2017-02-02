Shader "MLF/PhysicsUpdateForces"
{
	Properties
	{
		Positions("Positions", 2D ) = "white" {}
		Velocitys("Velocitys", 2D ) = "white" {}
		SpringPositions("SpringPositions", 2D ) = "white" {}
		Randoms("Randoms", 2D ) = "white" {}
		GravityUnitPerSec("GravityUnitPerSec", Range(0,8) ) = 0
		SpringForceUnitPerSec("SpringForceUnitPerSec", Range(0,10) ) = 2
		EnableFloor_Boolean("EnableFloor_Boolean", Range(0,1) ) = 0
		BounceScalar("BounceScalar", Range(0,100) ) = 1
		BounceRandomMin("BounceRandomMin", Range(0,1) ) = 1
		BounceRandomMax("BounceRandomMax", Range(0,1) ) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D Positions;
			sampler2D SpringPositions;
			sampler2D Velocitys;
			sampler2D Randoms;
			float GravityUnitPerSec;
			float SpringForceUnitPerSec;
			int EnableFloor_Boolean;
			float BounceScalar;
			float BounceRandomMin;
			float BounceRandomMax;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}


			float GetFloorY()
			{
				return 0;
			}

			float3 CalcNewForce(float3 Position,float3 SpringPosition,float3 Velocity,float3 Random)
			{
				//	apply force
				float3 Force = float3(0,0,0);

				//	calc gravity force
				float3 BounceForce = float3(0,0,0);
				float3 GravityForce = float3(0,-1,0) * GravityUnitPerSec;
				if ( EnableFloor_Boolean )
				{
					float Under = GetFloorY() - Position.y;
					if ( Under >= 0 )
					{
						GravityForce = 0;
						//BounceForce += float3(0,1,0) * Under;
						BounceForce += float3(0,1,0) * GravityUnitPerSec * BounceScalar;
						//BounceForce += -Velocity * BounceScalar;
						//BounceForce += -Velocity * BounceScalar;

						BounceForce *= lerp( BounceRandomMin, BounceRandomMax, Random.x );
					}
				}

				//	calc spring force
				float3 SpringForce = (SpringPosition-Position) * SpringForceUnitPerSec;

				//	combine forces
				Force += GravityForce;
				Force += SpringForce;
				Force += BounceForce;

				return Force;
			}


			float4 frag (v2f i) : SV_Target
			{
				float TimeDelta = unity_DeltaTime.x;
				float3 SpringPosition = tex2D( SpringPositions, i.uv );
				float3 Position = tex2D( Positions, i.uv );
				float3 Velocity = tex2D( Velocitys, i.uv );
				float3 Random = tex2D( Randoms, i.uv );

				return float4( CalcNewForce( Position, SpringPosition, Velocity, Random ), 1 );
			}
			ENDCG
		}
	}
}
