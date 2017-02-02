Shader "MLF/PhysicsUpdateVelocity"
{
	Properties
	{
		Positions("Positions", 2D ) = "white" {}
		LastVelocitys ("LastVelocitys", 2D) = "white" {}
		Forces ("Forces", 2D) = "white" {}
		DeaccellerationSecs("DeaccellerationSecs", Range(0,1) ) = 0.2
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
			sampler2D LastVelocitys;
			sampler2D Forces;
			float DeaccellerationSecs;
	
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

		
			float3 CalcNewVelocity(float TimeDelta,float3 LastVelocity,float3 Position,float3 Force)
			{
				//	apply force
				float3 Velocity = LastVelocity;

				//	gr: Im sure this is supposed to be time corrected
				Velocity *= 1 - ( TimeDelta / max(0.0001f,DeaccellerationSecs) );

				//Velocity *= (DampenPerSec * TimeDelta);

				//	gr: I know this is wrong somewhere as you only apply a punch-force once which won't be frame compensated
				Velocity += Force * TimeDelta;

				return Velocity;
			}


			float4 frag (v2f i) : SV_Target
			{
				float TimeDelta = unity_DeltaTime.x;
				float3 LastVelocity = tex2D( LastVelocitys, i.uv );
				float3 Force = tex2D( Forces, i.uv );
				float3 Position = tex2D( Positions, i.uv );

				return float4( CalcNewVelocity( TimeDelta, LastVelocity, Position, Force ), 1 );
			}
			ENDCG
		}
	}
}
