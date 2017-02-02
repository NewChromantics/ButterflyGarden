using System.Collections;
using System.Collections.Generic;
using UnityEngine;



public class TTexturePointBlockAndScore
{
	public TTexturePointBlock	Block;
	public float				DotToCamera;
	public float				DistanceSq;
	public bool					FrustumVisible = false;
	public bool 				DistanceVisible = false;
};


[System.Serializable]
public class UnityEvent_TexturePointBlockFilter : UnityEngine.Events.UnityEvent <List<TTexturePointBlock>,bool,List<TTexturePointBlockAndScore>> {}

[System.Serializable]
public class UnityEvent_IntMesh : UnityEngine.Events.UnityEvent <int,Mesh> {}




[ExecuteInEditMode]
[RequireComponent(typeof(TexturePointBlockCache))]
public class TexturePointBlockRenderer : MonoBehaviour {

	public enum PointType
	{
		Triangle,
		Quad,
	};

	const int TTEXTUREPOINTBLOCK_MAX = 60;

	[InspectorButton("OnTexturePointBlockDataChanged")]
	public bool _OnTexturePointBlockDataChanged;

	[Header("Name of array of matrixes for instance data")]
	const string		TexturePointBlocksUniform = "TexturePointBlocks";
	const string		TexturePointBlockCountUniform = "TexturePointBlockCount";


	[InspectorButton("MakeDumbMesh")]
	public bool			_MakeDumbMesh;
	public PointType	PointGeometry = PointType.Triangle;		

	[InspectorButton("UpdateMeshBoundsToCollider")]
	public bool		_UpdateMeshBounds;

	[Header("Add cullers etc here, or render everything")]
	public UnityEvent_TexturePointBlockFilter	OnRenderFilter;
	
	public bool			RenderWithInstances = false;

	public bool			DebugBounds
	{
		get	{ return DebugBoundsAlpha > 0; }
	}
	[Range(0,1)]
	public float	DebugBoundsAlpha = 0;

	[Range(1,2000)]
	public int			MaxKTriangles = 100;
	public int			MaxTriangles
	{
		get
		{
			return MaxKTriangles * 1000;
		}
	}


	

	public static void AddTriangleToMesh(ref List<Vector3> Positions,ref List<int> Indexes,ref List<Vector2> Uvs,Vector3 Position,int Index)
	{
		var pos0 = new Vector3( 0,-1,0 ) + Position;
		var pos1 = new Vector3( -1,0.5f,0 ) + Position;
		var pos2 = new Vector3( 1,0.5f,0 ) + Position;

		Positions.Add( pos0 );
		Uvs.Add( new Vector2(Index,0) );
		Indexes.Add( Positions.Count-1 );

		Positions.Add( pos1 );
		Uvs.Add( new Vector2(Index,1) );
		Indexes.Add( Positions.Count-1 );

		Positions.Add( pos2 );
		Uvs.Add( new Vector2(Index,2) );
		Indexes.Add( Positions.Count-1 );
	}

	static public Mesh MakeDumbTriangleMesh(int PointCount)
	{
		var Positions = new List<Vector3>();
		var Uvs = new List<Vector2>();
		var Indexes = new List<int>();

		{
			PointCount = Mathf.Min (PointCount, 65000/3);

			//	center triangle around 0,0,0
			for ( int i=0;	i<PointCount;	i++ )
			{
				AddTriangleToMesh (ref Positions, ref Indexes, ref Uvs, Vector3.zero, i);
			}
		}

		var mesh = new Mesh ();

		//	re-setup existing one
		mesh.bounds.SetMinMax( Vector3.zero, Vector3.one );
		mesh.SetVertices( Positions );
		mesh.SetUVs( 0, Uvs );
		mesh.SetIndices( Indexes.ToArray(), MeshTopology.Triangles, 0 );
		Debug.Log ("New dumb mesh; " + Indexes.Count + " indexes, " + PointCount+ " input positions, " + (Indexes.Count / 3) + " triangles");

		mesh.name = "DumbTriangleMesh x" + PointCount;

		return mesh;
	}

	public static void AddQuadToMesh(ref List<Vector3> Positions,ref List<int> Indexes,ref List<Vector2> Uvs,Vector3 Position,int Index)
	{
		var pos0 = new Vector3( -1,-1,0 ) + Position;
		var pos1 = new Vector3( 1,-1,0 ) + Position;
		var pos2 = new Vector3( -1,1,0 ) + Position;
		var pos3 = new Vector3( 1,1,0 ) + Position;

		Positions.Add( pos0 );
		Uvs.Add( new Vector2(Index,0) );
		var i0 = Positions.Count-1;

		Positions.Add( pos1 );
		Uvs.Add( new Vector2(Index,1) );
		var i1 = Positions.Count-1;

		Positions.Add( pos2 );
		Uvs.Add( new Vector2(Index,2) );
		var i2 = Positions.Count-1;

		Positions.Add( pos3 );
		Uvs.Add( new Vector2(Index,3) );
		var i3 = Positions.Count-1;

		Indexes.Add( i0 );
		Indexes.Add( i1 );
		Indexes.Add( i2 );

		Indexes.Add( i1 );
		Indexes.Add( i2 );
		Indexes.Add( i3 );
	}

	static public Mesh MakeDumbQuadMesh(int PointCount)
	{
		var Positions = new List<Vector3>();
		var Uvs = new List<Vector2>();
		var Indexes = new List<int>();

		{
			PointCount = Mathf.Min (PointCount, 65000/4);

			//	center triangle around 0,0,0
			for ( int i=0;	i<PointCount;	i++ )
			{
				AddQuadToMesh (ref Positions, ref Indexes, ref Uvs, Vector3.zero, i);
			}
		}

		var mesh = new Mesh ();

		//	re-setup existing one
		mesh.bounds.SetMinMax( Vector3.zero, Vector3.one );
		mesh.SetVertices( Positions );
		mesh.SetUVs( 0, Uvs );
		mesh.SetIndices( Indexes.ToArray(), MeshTopology.Triangles, 0 );
		Debug.Log ("New dumb mesh; " + Indexes.Count + " indexes, " + PointCount+ " input positions, " + (Indexes.Count / 3) + " triangles");

		mesh.name = "DumbQuadMesh x" + PointCount;

		return mesh;
	}

	public void OnTexturePointBlockDataChanged()
	{
		Debug.Log ("OnTexturePointBlockDataChanged");
		var TexturePointBlocks = GetComponent<TexturePointBlockCache> ();

		//	update textures, material etc
	
		var Mesh = MakeDumbMesh();

		//	mesh bounds needs to be in point-space
		//	size will encapsulate positioning from shader
		Mesh.bounds = TexturePointBlocks.GetTotalBounds();


		var mr = GetComponent<MeshRenderer> ();
		var Shader = mr.sharedMaterial;

		if ( Shader.GetTexture("PositionTexture" ) == null )
			Shader.SetTexture( "PositionTexture", TexturePointBlocks.BlockPositions );
		Shader.SetTexture( "ColourTexture", TexturePointBlocks.BlockColours );
	}



	void UpdateMeshBoundsToCollider()
	{
		var bc = GetComponent<BoxCollider> ();
		var mf = GetComponent<MeshFilter> ();
		mf.sharedMesh.bounds = bc.bounds;

	}
		
	
	public static void AddTriangleToMesh(ref List<Vector3> Positions,ref List<int> Indexes,ref List<Vector2> Uvs,ref List<Vector3> Normals,Vector3 Position,int Index,bool Trianglise)
	{
		var pos0 = new Vector3( 0,-1,0 );
		var pos1 = new Vector3( -1,0.5f,0 );
		var pos2 = new Vector3( 1,0.5f,0 );

		Positions.Add( Position + (Trianglise ? pos0 : Vector3.zero) );
		Normals.Add( pos0 );
		Uvs.Add( new Vector2(Index,0) );
		Indexes.Add( Positions.Count-1 );

		Positions.Add( Position + (Trianglise ? pos1 : Vector3.zero) );
		Normals.Add( pos1 );
		Uvs.Add( new Vector2(Index,1) );
		Indexes.Add( Positions.Count-1 );

		Positions.Add( Position + (Trianglise ? pos2 : Vector3.zero) );
		Normals.Add( pos2 );
		Uvs.Add( new Vector2(Index,2) );
		Indexes.Add( Positions.Count-1 );
	}
	

	Mesh MakeDumbMesh()
	{
		var NewMesh = new Mesh();

		if ( PointGeometry == PointType.Triangle )
		{
			NewMesh = MakeDumbTriangleMesh (MaxTriangles);
		}
		else if ( PointGeometry == PointType.Quad )
		{
			NewMesh = MakeDumbQuadMesh (MaxTriangles);
		}

		var mf = GetComponent<MeshFilter> ();
		mf.sharedMesh = NewMesh;
		UpdateMeshBoundsToCollider ();

		return mf.sharedMesh;
	}





	List<TTexturePointBlockAndScore> GetRenderInstances(bool AddCulledBlocks)
	{
		var TexturePointBlocks = GetComponent<TexturePointBlockCache> ();
		var AllBlocks = TexturePointBlocks.Blocks;

		var FilteredBlocks = new List<TTexturePointBlockAndScore>();

		//	sort, cull etc
		if (OnRenderFilter != null && OnRenderFilter.GetPersistentEventCount() > 0 )
		{
			OnRenderFilter.Invoke (AllBlocks, AddCulledBlocks, FilteredBlocks);
		}
		else
		{
			foreach (var Block in AllBlocks) {
				var ScoredBlock = new TTexturePointBlockAndScore();
				ScoredBlock.Block = Block;
				FilteredBlocks.Add( ScoredBlock );
			}
		}

		return FilteredBlocks;
	}


	void Start()
	{
		OnTexturePointBlockDataChanged ();
	}


	void AssignInstancesToMaterial(Material Shader,List<TTexturePointBlockAndScore> Instances)
	{
		var InstanceMtxs = new Matrix4x4[Instances.Count];
		for (int i = 0;	i < Instances.Count;	i++)
			InstanceMtxs [i] = Instances [i].Block.DataMatrix;
		AssignInstancesToMaterial (Shader, InstanceMtxs);
	}

	void AssignInstancesToMaterial(Material Shader,Matrix4x4[] Instances)
	{
		if ( Shader == null )
			return;
		Shader.SetMatrixArray ("TTexturePointBlocks", Instances);
		Shader.SetInt ("TTexturePointBlockCount", Instances.Length);
	}

	void RenderAsInstances(List<TTexturePointBlockAndScore> Instances)
	{
		var mf = GetComponent<MeshFilter> ();
		var mr = GetComponent<MeshRenderer> ();
		var TriangleMesh = mf.sharedMesh;
		var TriangleMaterial = mr.sharedMaterial;
		int PointSplit = TriangleMesh.triangles.Length / 3;

		List<Matrix4x4> InstanceCaches = null;
		int RunningPointCount = 0;

		var MtxIdentityList = new List<Matrix4x4> (){ Matrix4x4.identity };

		int InstancesDrawn = 0;
		int WastedPoints = 0;
		int BiggestInstanceCacheCount = 0;

		System.Action Flush = () => {
		
			if ( InstanceCaches != null && InstanceCaches.Count > 0 )
			{
				var InstanceUniforms = new MaterialPropertyBlock();

				InstanceUniforms.SetMatrixArray(TexturePointBlocksUniform, InstanceCaches );
				InstanceUniforms.SetFloat(TexturePointBlockCountUniform, InstanceCaches.Count );

				//	draw with instancing to draw in scene editor, but we don't wanna use it on mobile because of north american s6
				#if UNITY_EDITOR
				Graphics.DrawMeshInstanced( TriangleMesh, 0, TriangleMaterial, MtxIdentityList, InstanceUniforms );
				#else
				Graphics.DrawMesh( TriangleMesh, Matrix4x4.identity, TriangleMaterial, 0, Camera.main, 0, InstanceUniforms );
				#endif
				InstancesDrawn += MtxIdentityList.Count;
				BiggestInstanceCacheCount = Mathf.Max( BiggestInstanceCacheCount, InstanceCaches.Count );
			}

			InstanceCaches = new List<Matrix4x4>();
			RunningPointCount = 0;
		};

		//	init
		Flush();

		//	iterate and break up
		for (int i = 0;	i < Instances.Count;	i++) {
			var Block = Instances [i].Block;

			if ( InstanceCaches.Count >= TTEXTUREPOINTBLOCK_MAX )
			{
				WastedPoints += PointSplit - RunningPointCount;
				Flush ();
			}

			//	have we overflowed?
			if (Block.LodPointCount + RunningPointCount > PointSplit) {
				WastedPoints += PointSplit - RunningPointCount;
				Flush ();
			}

			RunningPointCount += Block.LodPointCount;
			InstanceCaches.Add (Block.DataMatrix);
		}

		Flush ();

		#if UNITY_EDITOR
		//Debug.Log ("Meshes drawn=" + InstancesDrawn + " wasted points=" + WastedPoints + " BiggestInstanceCacheCount="+BiggestInstanceCacheCount);
		#endif
	}


	void UpdateParticles()
	{
		var Instances = GetRenderInstances (false);
		var mr = GetComponent<MeshRenderer> ();

		if (RenderWithInstances) {
			RenderAsInstances (Instances);
			mr.enabled = false;
		} else {
			AssignInstancesToMaterial (mr.sharedMaterial, Instances);
			mr.enabled = true;
		}
	}

	void Update () 
	{
		UpdateParticles ();
	}


	void OnDrawGizmosSelected() 
	{
		if (!DebugBounds)
			return;

		var Instances = GetRenderInstances (true);
		foreach (var Instance in Instances)
		{
			var Colour = Instance.FrustumVisible&&Instance.DistanceVisible ? Color.green : Color.red;
			Colour.a = DebugBoundsAlpha;
			Gizmos.color = Colour;

			var Box = Instance.Block.BoundingBox;
			Gizmos.matrix = Matrix4x4.identity;
			Gizmos.DrawWireCube (Box.center, Box.size);
		}

	
	}
}
