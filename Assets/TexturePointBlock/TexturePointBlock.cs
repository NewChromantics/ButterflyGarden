using System.Collections;
using System.Collections.Generic;
using UnityEngine;



[System.Serializable]
public class TTexturePointBlock
{
	//	uniforms in the same state as they were made (vec4s)
	public Matrix4x4	DataMatrix;

	Bounds _BoundsCache;
	bool _BoundsCacheValid = false;

	public TTexturePointBlock()
	{
		BoundsMin = Vector4.zero;
		BoundsMax = Vector4.zero;
		PointCount = 0;
		Lod = 1;
		DataTextureIndexOffset = -1;
		IsValid = true;
		Randomf = Random.Range (0, 1.0f);
	}

	public Vector3		BoundsMin {
		get	{ return DataMatrix.GetRow(0); }
		set	{ DataMatrix.SetRow(0, value);	_BoundsCacheValid = false; }
	}

	public Vector3		BoundsMax {
		get	{ return DataMatrix.GetRow(1); }
		set	{ DataMatrix.SetRow(1, value );	_BoundsCacheValid = false; }
	}

	public float		Randomf {
		get	{ return DataMatrix[3,0]; }
		set	{ DataMatrix[3,0] = value; }
	}

	public int			DataTextureIndexOffset
	{
		get	{ return (int)DataMatrix [2,0]; }
		set	{ DataMatrix [2,0] = (float)value; }
	}

	public int			PointCount
	{
		get	
		{
			return (int)DataMatrix.m21;
			return (int)DataMatrix [2,1]; 
		}
		set	
		{
			DataMatrix.m21 = (float)value; 
			//DataMatrix [2,1] = (float)value; 
		}
	}

	public float		Lod
	{
		get	{ 
			return DataMatrix.m22;
			//return DataMatrix [2,2]; 
		}
		set	{ 
			DataMatrix.m22 = value;
			//DataMatrix [2,2] = value; 
		}
	}

	public bool			IsValid
	{
		get	{ return DataMatrix [2,3]==0; }
		set	{ DataMatrix [2,3] = value ? 0 : -1; }
	}


	//	actual rendered point count when skipping
	public int			LodPointCount {
		get	{ return (int)(PointCount * Lod); }
	}

	public Bounds		BoundingBox {
		get {
			if (!_BoundsCacheValid) {
				_BoundsCache.SetMinMax (BoundsMin, BoundsMax);
				_BoundsCacheValid = true;
			}
			return _BoundsCache;
		}
		set {
			BoundsMin = value.min;
			BoundsMax = value.max;
		}
	}

};

