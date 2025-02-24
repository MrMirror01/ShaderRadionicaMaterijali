using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BlurDriver : MonoBehaviour
{
    private Material mat;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Shader shader = Shader.Find("Hidden/Blur");
        if (mat == null)
        {
            mat = new Material(shader);
        }

        Graphics.Blit(source, destination, mat, 1);
    }
}
