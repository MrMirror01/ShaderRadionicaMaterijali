using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RayTracingDriver : MonoBehaviour
{
    private Material mat;

    // klasa koja sluzi samo za sucelje koje korisnik vidi
    [Serializable] // oznacava da hocemo editirati u inspektoru
    public class Sphere
    {
        public Transform transform;
        public Color color;
        public float emmission;
        public Color emmissionColor;
    }

    // strukture ekvivalentne onima iz shadera
    private struct RayTraceMaterial
    {
        public RayTraceMaterial(Color color, float emmission, Color emmissionColor)
        {
            this.color = color;
            this.emmission = emmission;
            this.emmissionColor = emmissionColor;
        }

        Color color;
        float emmission;
        Color emmissionColor;
    };

    private struct SphereStruct
    {
        public SphereStruct(Sphere s)
        {
            position = s.transform.position;
            radius = s.transform.lossyScale.x / 2;
            material = new RayTraceMaterial(s.color, s.emmission, s.emmissionColor);
        }

        Vector3 position;
        float radius;
        RayTraceMaterial material;
    };

    public int raysPerFrame; // koliko zraka bacamo svaki frame
    public int maxBounces; // koliko se maksimalno puta zraka moze odbiti

    public Color skyColor;

    public List<Sphere> sphereList; // lista kugli koja je vidljiva korisniku
    private SphereStruct[] spheres; // te kugle u obliku u kojem ih mozemo proslijediti shaderu

    // funkcija koja azurira listu kugli u shaderu ovisno o postavkama korisnika
    private void SetSpheres()
    {
        // kugle iz liste pretvorimo u SphereStruct oblik te zapisemo u spheres array
        spheres = new SphereStruct[sphereList.Count];
        for (int i = 0; i < spheres.Length; i++)
        {
            Sphere s = sphereList[i];
            spheres[i] = new SphereStruct(s);
        }

        mat.SetInt("_SphereCount", sphereList.Count);

        //konstruiramo buffer od tih podataka te ga proslijedimo shaderu
        ComputeBuffer sphereBuffer = new ComputeBuffer(sphereList.Count, 4 * (3+1+4+1+4));
        sphereBuffer.SetData(spheres);
        mat.SetBuffer("_Spheres", sphereBuffer);
    }

    private void SetCameraProperties()
    {
        mat.SetVector("_CameraPos", Camera.main.transform.position); // pozicija kamere

        // izracunamo dimenzije near clip plane-a
        float planeHeight = Camera.main.nearClipPlane * Mathf.Tan(Camera.main.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2f;
        float planeWidth = planeHeight * Camera.main.aspect;
        mat.SetVector("_NearPlane", new Vector3(planeWidth, planeHeight, Camera.main.nearClipPlane));

        // proslijedimo object to world space matricu kamere
        mat.SetMatrix("_CameraObjectToWorldMat", Camera.main.transform.localToWorldMatrix);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (mat == null)
        {
            mat = new Material(Shader.Find("Hidden/RayTracing"));
        }

        SetSpheres(); // postavimo parametre kugli

        SetCameraProperties(); // postavimo parametre kamere

        // postavimo ostale parametre shadera
        mat.SetInt("_RaysPerFrame", raysPerFrame);
        mat.SetInt("_MaxBounces", maxBounces);

        // postavimo boju neba
        mat.SetColor("_SkyColor", skyColor);

        // pokrenemo shader na slici
        Graphics.Blit(source, destination, mat);
    }
}
