using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BlurDriver : MonoBehaviour
{
    public enum BlurType
    {
        BoxBlur,
        GaussianBlur,
        OptimisedGaussianBlur
    };

    private Material mat;
    public BlurType blurType;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Shader shader = Shader.Find("Hidden/Blur");
        if (mat == null)
        {
            mat = new Material(shader);
        }

        if (blurType == BlurType.BoxBlur)
        {
            Graphics.Blit(source, destination, mat, 0);
        }
        else if (blurType == BlurType.GaussianBlur)
        {
            Graphics.Blit(source, destination, mat, 1);
        }
        else {
            RenderTexture tempTex = RenderTexture.GetTemporary(source.descriptor);
            Graphics.Blit(source, tempTex, mat, 2);
            Graphics.Blit(tempTex, destination, mat, 3);
            RenderTexture.ReleaseTemporary(tempTex);
        }
    }
}
