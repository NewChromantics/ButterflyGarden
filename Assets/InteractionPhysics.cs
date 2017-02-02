using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InteractionPhysics : MonoBehaviour {

	public Transform	LeftHand;
	public Transform	RightHand;
	public Material		ForcesShader;

	void Update () {
		
		var LeftPos = LeftHand ? LeftHand.position : Vector3.zero;
		var RightPos = RightHand ? RightHand.position : Vector3.zero;

		ForcesShader.SetVector("Avoid0", LeftPos);
		ForcesShader.SetVector("Avoid1", RightPos);
	}
}
