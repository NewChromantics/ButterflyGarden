using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MakeButterflyMeshes : MonoBehaviour {


	
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

	public void MakeButterflyMesh(int MaxCount,Mesh mesh)
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
	

}
