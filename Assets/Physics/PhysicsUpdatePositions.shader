Shader "MLF/PhysicsUpdatePositions"
{
	Properties
	{
		LastPositions ("LastPositions", 2D) = "white" {}
		Velocitys ("Velocitys", 2D) = "white" {}
		MaxPositionDistance("MaxPositionDistance", Range(0,9999) ) = 9999
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

			sampler2D LastPositions;
			sampler2D Velocitys;
			float MaxPositionDistance;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}


			float3 CalcNewPosition(float TimeDelta,float3 LastPosition,float3 Velocity)
			{
				float3 Position = LastPosition;
				Position += Velocity * TimeDelta;

				float PosLength = length( Position );
				if ( PosLength > MaxPositionDistance )
				{
					Position = normalize( Position ) * MaxPositionDistance;
				}

				return Position;
			}


			float4 frag (v2f i) : SV_Target
			{
				float TimeDelta = unity_DeltaTime.x;
				float3 LastPosition = tex2D( LastPositions, i.uv );
				float3 Velocity = tex2D( Velocitys, i.uv );
		
				return float4( CalcNewPosition( TimeDelta, LastPosition, Velocity ), 1 );
			}
			ENDCG
		}
	}
}
