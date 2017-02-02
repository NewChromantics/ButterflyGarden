using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TexturePointBlockCache : MonoBehaviour {

	public List<TTexturePointBlock>	Blocks;
	public Texture2D				BlockPositions;
	public Texture2D				BlockColours;

	public string					CacheAssetPath;
	[InspectorButton("LoadCache")]
	public bool						_LoadCache;
	[InspectorButton("SaveCache")]
	public bool						_SaveCache;
	[InspectorButton("ClearCache")]
	public bool						_ClearCache;

	[InspectorButton("WriteRandomW")]
	public bool						_WriteRandomW;

	[InspectorButton("ShuffleBlockPositions")]
	public bool						_ShuffleBlockPositions;


	//	would be nice to keep the texture square somehow, but we also need to work out platform limits (like 8192x8192)
	public int						DataWidth = 512;
	public int						MaxWidth = 8192;
	public int						MaxHeight = 8192;
	TextureFormat					PositionTextureFormat = TextureFormat.RGBAFloat;
	TextureFormat					ColourTextureFormat = TextureFormat.RGB24;

	public UnityEngine.Events.UnityEvent	OnChanged;

	public int						BlockPointSplit
	{
		get
		{
			var mf = GetComponent<MeshFilter>();
			var DumbTriangleMesh = mf ? mf.sharedMesh : null;
			if ( DumbTriangleMesh == null )
			{
				return 65000 / 3;
			}
			int PointSplit = DumbTriangleMesh.triangles.Length / 3;
			return PointSplit;
		}
	}


	public Bounds GetTotalBounds()
	{
		if (Blocks == null || Blocks.Count == 0)
			return new Bounds ();

		var bounds = Blocks [0].BoundingBox;
		foreach ( var Block in Blocks )
		{
			bounds.Encapsulate (Block.BoundingBox);
		}
		return bounds;
	}

	int GetUsedPointCount()
	{
		int NextFreeIndex = 0;

		//	assuming blocks might be out of order from sorting. (possibly not?)
		foreach ( var Block in Blocks )
		{
			int BlockStart = Block.DataTextureIndexOffset;
			int BlockEnd = BlockStart + Block.PointCount;
			NextFreeIndex = Mathf.Max( NextFreeIndex, BlockEnd+1 );
		}

		return NextFreeIndex;
	}

	int GetAllocatedPointCount()
	{
		if ( BlockPositions == null )
			return 0;
		return BlockPositions.width * BlockPositions.height;
	}		

	int GetBestPowerOf2(int Value)
	{
		if ( !Mathf.IsPowerOfTwo( Value ) )
			Value = Mathf.NextPowerOfTwo( Value );
		return Value;
	}

	static Texture2D ResizeTexture(Texture2D Old,int Width,int Height,TextureFormat Format)
	{
		var OldWidth = Old ? Old.width : 0;
		var OldHeight = Old ? Old.height : 0;

		if (OldWidth == Width && OldHeight == Height)
			return Old;
		
		var NewTexture = new Texture2D (Width, Height, Format, false);
		NewTexture.filterMode = FilterMode.Point;

		if (Old) 
		{
			var OldPixels = Old.GetPixels ();
			var NewPixels = new Color[Width * Height];
			OldPixels.CopyTo (NewPixels, 0);
			NewTexture.SetPixels (NewPixels);
		}

		return NewTexture;
	}

	void GrowData(int PointCount)
	{
		var DataSize = GetUsedPointCount () + PointCount;
		var AllocSize = GetAllocatedPointCount ();

		if (DataSize <= AllocSize)
			return;

		//	alloc new data
		int Allocation = DataSize;
		int Width = GetBestPowerOf2( DataWidth );
		int Height = (Allocation / Width) + 1;
		Height = GetBestPowerOf2 (Height);

		Width = Mathf.Min (Width, MaxWidth);
		Height = Mathf.Min (Height, MaxHeight);

		//	resize
		BlockPositions = ResizeTexture( BlockPositions, Width, Height, PositionTextureFormat );
		BlockColours = ResizeTexture( BlockColours, Width, Height, ColourTextureFormat );

	}

	static int InsertPixels(Texture2D Texture,List<Color> NewData,int TextureDataIndex)
	{
		var Data = Texture.GetPixels();

		//	clip data
		int DataWritten = Mathf.Min( NewData.Count, Data.Length - TextureDataIndex );

		NewData.CopyTo (0,Data,TextureDataIndex,DataWritten);

		Texture.SetPixels (Data);
		Texture.Apply ();

		return DataWritten;
	}

	public void Clear()
	{ 
		BlockPositions = null;
		BlockColours = null;
		Blocks.Clear();
	}


	void AddBlock(Bounds bounds,List<Color> NewPositionData,List<Color> NewColourData)
	{
		if (NewPositionData.Count == 0)
			return;

		//	auto split
		while ( NewPositionData.Count > BlockPointSplit )
		{
			//	pop top and add
			var TopPositionData = NewPositionData.GetRange(0, BlockPointSplit);
			var TopColourData = NewColourData.GetRange(0, BlockPointSplit);
			NewPositionData.RemoveRange( 0, BlockPointSplit );
			NewColourData.RemoveRange( 0, BlockPointSplit );
			AddBlock( bounds, TopPositionData, TopColourData );
		}
		
		GrowData (NewPositionData.Count);

		var Block = new TTexturePointBlock ();
		Block.DataTextureIndexOffset = GetUsedPointCount ();
		Block.BoundingBox = bounds;

		//	grab current data to inject into
		var PositionsWritten = InsertPixels( BlockPositions, NewPositionData, Block.DataTextureIndexOffset );
		var ColoursWritten = InsertPixels( BlockColours, NewColourData, Block.DataTextureIndexOffset );

		if (PositionsWritten != ColoursWritten)
			throw new System.Exception ("Expected positonswritten(" + PositionsWritten + ") to match colours written (" + ColoursWritten + ")");

		Block.PointCount = PositionsWritten;
		Blocks.Add (Block);
	}

	public void	AddBlock(List<Vector3> Positions,List<Color> Colours,Bounds BoundingBox,bool Normalise)
	{
		//	convert into colour data to put into the texture
		var PositionsAsColour = new List<Color>();
		Color PosColour;
		foreach (var Position in Positions) {

			var NormPosition = new Vector3 ();

			if ( Normalise )
			{
				NormPosition.x = PopMath.Range( BoundingBox.min.x, BoundingBox.max.x, Position.x );
				NormPosition.y = PopMath.Range( BoundingBox.min.y, BoundingBox.max.y, Position.y );
				NormPosition.z = PopMath.Range( BoundingBox.min.z, BoundingBox.max.z, Position.z );
			}
			else
			{
				NormPosition = Position;
			}
			PosColour.r = NormPosition.x;
			PosColour.g = NormPosition.y;
			PosColour.b = NormPosition.z;
			PosColour.a = 1;
			PositionsAsColour.Add (PosColour);
		}

		AddBlock (BoundingBox, PositionsAsColour, Colours);
	}

	public void ClearCache()
	{
		#if UNITY_EDITOR

		AssetWriter.DeleteAsset(CacheAssetPath + "/PositionData" );
		AssetWriter.DeleteAsset(CacheAssetPath + "/ColourData" );
		AssetWriter.DeleteAsset(CacheAssetPath + "/DumbTriangleMesh" );
		Blocks.Clear();

		var mf = GetComponent<MeshFilter>();
		if ( mf )
			mf.sharedMesh = null;

		#else
		throw new System.Exception("SaveCache only for editor");
		#endif
	}

	public void SaveCache()
	{
		#if UNITY_EDITOR

		//	save texture assets
		var mf = GetComponent<MeshFilter>();
		var DumbTriangleMesh = mf ? mf.sharedMesh : null;

		BlockPositions = AssetWriter.WriteAsset(CacheAssetPath + "/PositionData", BlockPositions );
		BlockColours = AssetWriter.WriteAsset(CacheAssetPath + "/ColourData", BlockColours );
		DumbTriangleMesh = AssetWriter.WriteAsset(CacheAssetPath + "/DumbTriangleMesh", DumbTriangleMesh );

		if ( mf )
			mf.sharedMesh = DumbTriangleMesh;

		#else
		throw new System.Exception("SaveCache only for editor");
		#endif
	}

	public void LoadCache()
	{
		#if UNITY_EDITOR
		System.Func<string,string> GetAssetPath = (name) =>
		{
			return "Assets/" + CacheAssetPath + name + ".asset";
		};

		BlockPositions = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D> (GetAssetPath("/PositionData"));
		BlockColours = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D> (GetAssetPath("/ColourData"));
		var DumbTriangleMesh = UnityEditor.AssetDatabase.LoadAssetAtPath<Mesh> (GetAssetPath("/DumbTriangleMesh"));

		var mf = GetComponent<MeshFilter> ();
		if (mf)
			mf.sharedMesh = DumbTriangleMesh;

		OnChanged.Invoke();
		#else
		throw new System.Exception("SaveCache only for editor");
		#endif
	}


	void WriteRandomW()
	{
		var Pixels = BlockPositions.GetPixels ();
		for (int i = 0;	i < Pixels.Length;	i++) {
			Pixels [i].a = Random.Range (0.0f, 1.0f);
		}
		BlockPositions.SetPixels (Pixels);
		BlockPositions.Apply ();
		OnChanged.Invoke();
	}


	void ShuffleBlockPositions_Block(TTexturePointBlock Block)
	{
		int First = Block.DataTextureIndexOffset;
		int Count = Block.PointCount;

		var PositionPixels = BlockPositions.GetPixels ();
		var ColourPixels = BlockColours.GetPixels ();

		//	grab a copy of all the pixels
		var BlockPositionPixels = new List<Color>();
		var BlockColourPixels = new List<Color>();
		for (int i = 0;	i < Count;	i++) {
			BlockPositionPixels.Add (PositionPixels [First + i]);
			BlockColourPixels.Add (ColourPixels [First + i]);
		}

		//	write back pixels at random removing the used ones as we go
		for (int i = 0;	i < Count;	i++) {
			var RandomIndex = Random.Range (0, BlockPositionPixels.Count - 1);
			PositionPixels [First + i] = BlockPositionPixels [RandomIndex];
			ColourPixels [First + i] = BlockColourPixels [RandomIndex];
			BlockPositionPixels.RemoveAt (RandomIndex);
			BlockColourPixels.RemoveAt (RandomIndex);
		}

		BlockPositions.SetPixels (PositionPixels);
		BlockPositions.Apply ();
		BlockColours.SetPixels (ColourPixels);
		BlockColours.Apply ();
	}

	void ShuffleBlockPositions()
	{
		#if UNITY_EDITOR
		var Title = "Shuffling block positions";
		UnityEditor.EditorUtility.DisplayProgressBar (Title, "Starting...", 0);

		try
		{
			for (int b=0;	b<Blocks.Count;	b++ ) 
			{
				var Block = Blocks[b];
				UnityEditor.EditorUtility.DisplayProgressBar (Title, "Shuffling block " + b + " (" + Block.PointCount + " points)", b/(float)Blocks.Count );
				ShuffleBlockPositions_Block (Block);
			}	
			UnityEditor.EditorUtility.ClearProgressBar ();
		}
		catch (System.Exception e)
		{
			Debug.LogException (e);
			UnityEditor.EditorUtility.ClearProgressBar ();
		}
		#endif
	}
}
