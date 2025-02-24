using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VignetteDriver : MonoBehaviour
{
    [Range(0.0f, 1.0f)]
    public float intensity;

    private Material mat;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Shader shader = Shader.Find("Hidden/Vignette");
        if (mat == null )
        {
            mat = new Material(shader);
        }

        mat.SetFloat("_Intensity", intensity);

        Graphics.Blit(source, destination, mat);
    }
}
