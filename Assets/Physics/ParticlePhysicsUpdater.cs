using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ParticlePhysicsUpdater : MonoBehaviour {
	

	public RenderTexture	Velocitys;
	public RenderTexture	Positions;
	public Texture2D		PositionsOriginal2D;
	public RenderTexture	PositionsOriginal;
	public RenderTexture	Forces;
	public Material			UpdateForcesShader;
	public Material			UpdateVelocityShader;
	public Material			UpdatePositionShader;
	public Material			InitPositionShader;

	RenderTexture			LastVelocitys;
	RenderTexture			LastPositions;

	public bool				PositionsInitialised = false;


	Texture2D				PositionMap;
	int 					PositionCounter = 0;

	public bool				UpdateInCoroutine = false;


	void Start () {

		//	these should all be the same dimensions
		LastPositions = new RenderTexture (Positions.width, Positions.height, 0, Positions.format);
		LastVelocitys = new RenderTexture (Velocitys.width, Velocitys.height, 0, Velocitys.format);

		//	initialise everything
		Graphics.Blit( Texture2D.blackTexture, Velocitys );


		if (!PositionsInitialised)
		{
			if ( PositionsOriginal2D != null )
				Graphics.Blit (PositionsOriginal2D, Positions);
			else
				Graphics.Blit (Texture2D.blackTexture, Positions);
			PositionsInitialised = true;
		}

		//	gr: if shader provided, do it regardless
		if (InitPositionShader) {
			Graphics.Blit (null, Positions, InitPositionShader);
			PositionsInitialised = true;
		}

		Graphics.Blit( Positions, PositionsOriginal );
	}

	void Update () {

		if ( UpdateInCoroutine )
			StartCoroutine (IterationCoroutine());
		else
			Iteration ();

	}

	IEnumerator IterationCoroutine() 
	{
		yield return new WaitForEndOfFrame();
		Iteration();
	}

	void Iteration() 
	{
		Graphics.Blit (Positions, LastPositions);
		Graphics.Blit (Velocitys, LastVelocitys);

		UpdateForcesShader.SetTexture ("Positions", Positions);
		Graphics.Blit (null, Forces, UpdateForcesShader);

		UpdateVelocityShader.SetTexture ("LastVelocitys", LastVelocitys);
		UpdateVelocityShader.SetTexture ("Positions", Positions);
		UpdateVelocityShader.SetTexture ("Forces", Forces);
		Graphics.Blit (null, Velocitys, UpdateVelocityShader);

		UpdatePositionShader.SetTexture ("Velocitys", Velocitys);
		UpdatePositionShader.SetTexture ("LastPositions", LastPositions);
		Graphics.Blit (null, Positions, UpdatePositionShader);

	}


	public void InitPositions(List<Vector3> ParticlePositions,List<Vector4> ParticleColours,System.Action<int> SetNewPositionOffset)
	{
		if (PositionMap == null) {
			PositionMap = new Texture2D (Positions.width, Positions.height, TextureFormat.RGBAFloat, false);
			PositionMap.filterMode = FilterMode.Point;
			PositionCounter = 0;
		}

		SetNewPositionOffset.Invoke (PositionCounter);

		var ParticleCount = ParticlePositions.Count;
		var PixelCount = Positions.width * Positions.height;
	
		for ( int i=0;	i<ParticleCount;	i++ )
		{
			if (PositionCounter >= PixelCount) {
				Debug.Log ("ran out of position pixels; " + PositionCounter + "/" + PixelCount);
				break;
			}
			
			var Colour = new Color ();
			if ( i >= ParticleCount )
			{
				Colour.r = 0;
				Colour.g = 0;
				Colour.b = 1;
				Colour.a = 0;
			}
			else
			{
				var Position = ParticlePositions[i];
				Colour.r = Position.x;
				Colour.g = Position.y;
				Colour.b = Position.z;
				Colour.a = 1;
			}

			var x = PositionCounter % Positions.width;
			var y = PositionCounter / Positions.width;
			PositionMap.SetPixel( x, y, Colour );
			PositionCounter++;
		}

		PositionMap.Apply();

		if ( !PositionsInitialised )
			Graphics.Blit( PositionMap, Positions);
		
		Graphics.Blit( PositionMap, PositionsOriginal);
		PositionsInitialised = true;
	}


}
