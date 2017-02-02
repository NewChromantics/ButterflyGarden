using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[RequireComponent(typeof(TexturePointBlockCache))]
public class InitButterflyCloud : MonoBehaviour {

	[InspectorButton("GenerateRandomParticles")]
	public bool _GenerateRandomParticles;

	[Range(1,100)]
	public float		PointCountM = 1;
	public int			PointCount {	get { return (int)(PointCountM*1000000); } }
	
	[Range(0.1f,100.0f)]
	public float		Width = 10;
	[Range(0.1f,100.0f)]
	public float		Height = 10;

	public Bounds		BoundingBox
	{
		get
		{
			var bc = GetComponent<BoxCollider>();
			if ( bc != null )
				return bc.bounds;
			return new Bounds( this.transform.position - new Vector3(0,Height/2,0), new Vector3( Width, Height, Width ) );
		}
	}

	void GenerateRandomParticles()
	{
		var TPBC = GetComponent<TexturePointBlockCache>();

		var Bounds = BoundingBox;
		var Positions = new List<Vector3>();
		var Colours = new List<Color>();

		for (int i = 0; i < PointCount; i++)
		{
			var x = Mathf.Lerp( Bounds.min.x, Bounds.max.x, Random.Range( 0.0f, 1.0f ) );
			var y = Mathf.Lerp( Bounds.min.y, Bounds.max.y, Random.Range( 0.0f, 1.0f ) );
			var z = Mathf.Lerp( Bounds.min.z, Bounds.max.z, Random.Range( 0.0f, 1.0f ) );
			var r = Random.Range( 0.0f, 1.0f );
			var g = Random.Range( 0.0f, 1.0f );
			var b = Random.Range( 0.0f, 1.0f );
			var a = 1.0f;
			Positions.Add( new Vector3( x,y,z ) );
			Colours.Add( new Color( r,g,b,a ) );
		}

		TPBC.Clear();
		TPBC.AddBlock( Positions, Colours, Bounds, false );
	}

}
