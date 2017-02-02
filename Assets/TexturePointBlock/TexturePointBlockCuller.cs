using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class TexturePointBlockCuller : MonoBehaviour {

	public bool			EnableDebug = true;

	[Range(1,4000)]
	public int			MaxInstances = 100;

	[Range(1,2000)]
	public int			MaxKTriangles = 100;
	public int			MaxTriangles
	{
		get
		{
			return MaxKTriangles * 1000;
		}
	}

	public bool			CullByDistance = true;
	[Range(0,100)]
	public float		CullDistanceFar = 30;
	[Range(0,100)]
	public float		CullDistanceNear = 0;

	public bool			CullByFrustum = true;
	public Camera		CullCamera;

	[Header("Group center-of-vision sorting to allow better distance filtering")]
	[Range(0,1000)]
	public int			FrustumDotRanges = 100;

	[Header("FOV of 0 uses original. Gearvr is 90")]
	[Range(0,90)]
	public float		OverrideFov = 90;



	[Header("-1 disables")]
	[Range(-1,100)]
	public int			RenderSpecificInstance = -1;

	public bool			LodToDistance = false;
	public bool			LodToDistanceSquared = false;
	public bool			LodToMaxTriangles = false;

	[Range(0,100)]
	public float		LodDistanceMin = 0;


	[Range(0,1)]
	public float		Lod = 0;


	//	have an update to allow editor disabling
	void Update()
	{
	}

	public void CullBlocks(List<TTexturePointBlock> AllBlocks,bool AddCulledBlocks,List<TTexturePointBlockAndScore> FilteredBlocks)
	{
		//	render everything if disabled
		if (!enabled) {
		
			foreach (var Block in AllBlocks) {
				var BlockScored = new TTexturePointBlockAndScore ();
				BlockScored.Block = Block;
				FilteredBlocks.Add (BlockScored);
			}
			return;
		}
		
		var Cam = CullCamera;
		var CameraPos = Cam.transform.position;
		var CameraForward = Cam.transform.localToWorldMatrix.MultiplyVector (Vector3.forward);
		float RestoreFov = Cam.fieldOfView;
		if (OverrideFov > 0)
			Cam.fieldOfView = OverrideFov;
		var FrustumPlanes = GeometryUtility.CalculateFrustumPlanes(Cam);
		Cam.fieldOfView = RestoreFov;

		var CullDistanceNearSq = CullDistanceNear * CullDistanceNear;
		var CullDistanceFarSq = CullDistanceFar * CullDistanceFar;


		if ( RenderSpecificInstance != -1 )
		{
			if (RenderSpecificInstance < AllBlocks.Count) {
				var InstanceScored = new TTexturePointBlockAndScore ();
				InstanceScored.Block = AllBlocks [RenderSpecificInstance];

				InstanceScored.FrustumVisible = GeometryUtility.TestPlanesAABB (FrustumPlanes, InstanceScored.Block.BoundingBox);

				FilteredBlocks.Add (InstanceScored);
			}
			return;
		}



		foreach ( var Block in AllBlocks )
		{
			var InstanceScored = new TTexturePointBlockAndScore();
			InstanceScored.Block = Block;
			Block.Lod = Lod;

			var Box = Block.BoundingBox;


			//var InstancePos = Box.center;
			var InstancePos = Box.ClosestPoint (CameraPos);
			InstanceScored.DistanceSq = PopMath.Vector3_DistanceSquared (InstancePos, CameraPos);

			if (LodToDistance) 
			{
				var Distance = Mathf.Sqrt (InstanceScored.DistanceSq);
				var CullDistanceFar = Mathf.Sqrt (CullDistanceFarSq);
				Block.Lod = 1 - (Distance / CullDistanceFar);
				if (Distance <= LodDistanceMin)
					Block.Lod = 1;
				Block.Lod *= Lod;
			}
			else if (LodToDistanceSquared) 
			{
				var Distance = InstanceScored.DistanceSq;
				var CullDistanceFar = CullDistanceFarSq;
				Block.Lod = 1 - (Distance / CullDistanceFar);
				if (Distance <= (LodDistanceMin*LodDistanceMin))
					Block.Lod = 1;
				Block.Lod *= Lod;
			}

			InstanceScored.DistanceVisible = true;
			if (InstanceScored.DistanceSq > CullDistanceFarSq)
				InstanceScored.DistanceVisible = false;
			if (InstanceScored.DistanceSq < CullDistanceNearSq)
				InstanceScored.DistanceVisible = false;
			
			if (CullByDistance && !AddCulledBlocks && !InstanceScored.DistanceVisible) {
				continue;
			}

			var InstanceForward = InstancePos - CameraPos;
			InstanceForward.Normalize ();
			InstanceScored.DotToCamera = Vector3.Dot (InstanceForward, CameraForward);

			InstanceScored.FrustumVisible = GeometryUtility.TestPlanesAABB (FrustumPlanes, Box);
			if (CullByFrustum && !AddCulledBlocks && !InstanceScored.FrustumVisible )
				continue;

			FilteredBlocks.Add (InstanceScored);
		}

		FilteredBlocks.Sort ((a, b) => {

			if ( FrustumDotRanges > 0 )
			{
				var Dota = (int)(a.DotToCamera * FrustumDotRanges);
				var Dotb = (int)(b.DotToCamera * FrustumDotRanges);

				if ( Dota > Dotb )
					return -1;
				if ( Dota > Dotb )
					return 1;
			}
			else
			{
				if ( a.DotToCamera > b.DotToCamera )
					return -1;
				if ( a.DotToCamera < b.DotToCamera )
					return 1;
			}

			if ( a.DistanceSq < b.DistanceSq )
				return -1;
			if ( a.DistanceSq > b.DistanceSq )
				return 1;

			return 0;
		}
		);

		if ( !AddCulledBlocks )
		{
			//	now clip
			if ( FilteredBlocks.Count > MaxInstances )
				FilteredBlocks.RemoveRange (MaxInstances, FilteredBlocks.Count - MaxInstances);

			int TotalTriangles = 0;
			for ( int i=0;	i<FilteredBlocks.Count;	i++ )
			{
				var InstanceTriangleCount = FilteredBlocks [i].Block.LodPointCount;

				if (LodToMaxTriangles) {
				} else {
					//	clip
					if (TotalTriangles + InstanceTriangleCount > MaxTriangles) {
						FilteredBlocks.RemoveRange (i, FilteredBlocks.Count - i);
						break;
					}
				}

				TotalTriangles += InstanceTriangleCount;
			}			

			int LodToMaxTriangles_TriangleCount = 0;

			if (TotalTriangles > MaxTriangles && LodToMaxTriangles) {
				//	scale down all the LOD's to fit max triangles
				float LodScale = MaxTriangles / (float)TotalTriangles;
				#if UNITY_EDITOR
				if ( EnableDebug )
					Debug.Log ("LodScale=" + LodScale);
				#endif

				foreach (var Block in FilteredBlocks) {

					var OldTriangleCount = Block.Block.LodPointCount;
					Block.Block.Lod *= LodScale;
					var NewTriangleCount = Block.Block.LodPointCount;
					LodToMaxTriangles_TriangleCount += NewTriangleCount;
				}
			}

			#if UNITY_EDITOR
			if ( EnableDebug )
				Debug.Log ("Total triangles=" + TotalTriangles + " (lod'd to " + LodToMaxTriangles_TriangleCount + ") total blocks=" + FilteredBlocks.Count );
			#endif
		}
	}


	void OnDrawGizmosSelected()
	{
		if (CullByFrustum) {
			Gizmos.color = Color.white;
			var camera = CullCamera;
			Matrix4x4 temp = Gizmos.matrix;
			Gizmos.matrix = Matrix4x4.TRS (camera.transform.position, camera.transform.rotation, Vector3.one);
			if (camera.orthographic) {
				float spread = camera.farClipPlane - camera.nearClipPlane;
				float center = (camera.farClipPlane + camera.nearClipPlane) * 0.5f;
				Gizmos.DrawWireCube (new Vector3 (0, 0, center), new Vector3 (camera.orthographicSize * 2 * camera.aspect, camera.orthographicSize * 2, spread));
			} else {
				if (OverrideFov > 0) {
					Gizmos.color = Color.white;
					Gizmos.DrawFrustum (Vector3.zero, OverrideFov, camera.farClipPlane, camera.nearClipPlane, camera.aspect);
				}
				Gizmos.color = Color.grey;
				Gizmos.DrawFrustum (Vector3.zero, camera.fieldOfView, camera.farClipPlane, camera.nearClipPlane, camera.aspect);
			}
			Gizmos.matrix = temp;
		}

	}
}
