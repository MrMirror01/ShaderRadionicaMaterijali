using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class BlinPhongDriver : MonoBehaviour
{
    public Material mat;
    public Transform lightTransform;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        mat.SetVector("_ViewDir", Camera.main.transform.forward);
        mat.SetVector("_LightDir", lightTransform.forward);
    }
}
