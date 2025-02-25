using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FogDriver : MonoBehaviour
{
    private Material mat;

    [Range(0f, 1f)]
    public float density = 0.1f;
    public Color color;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (mat == null)
        {
            mat = new Material(Shader.Find("Hidden/Fog"));
        }

        mat.SetFloat("_Density", density);
        mat.SetColor("_FogColor", color);

        Graphics.Blit(source, destination, mat);
    }
}
