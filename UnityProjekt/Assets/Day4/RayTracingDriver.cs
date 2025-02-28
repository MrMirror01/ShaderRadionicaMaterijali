using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class RayTracingDriver : MonoBehaviour
{

    // klasa koja sluzi samo za sucelje koje korisnik vidi
    [Serializable] // oznacava da hocemo editirati u inspektoru
    public class Sphere
    {
        public Transform transform;
        public Color color;
        public float emmission;
        public Color emmissionColor;
    }

    [Serializable]
    public class RayTracingMesh
    {
        public MeshFilter meshInfo;
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

    private struct MeshStruct
    {
        public MeshStruct(RayTracingMesh mesh, int firstTriangleIdx, int numTriangles)
        {
            this.firstTriangleIdx = firstTriangleIdx;
            this.numTriangles = numTriangles;
            this.material = new RayTraceMaterial(mesh.color, mesh.emmission, mesh.emmissionColor);
        }
        
        int firstTriangleIdx;
        int numTriangles;
        RayTraceMaterial material;
    }

    private struct TriangleStruct
    {
        public TriangleStruct(Vector3 posA, Vector3 posB, Vector3 posC, Vector3 normalA, Vector3 normalB, Vector3 normalC)
        {
            this.posA = posA;
            this.posB = posB;
            this.posC = posC;
            this.normalA = normalA;
            this.normalB = normalB;
            this.normalC = normalC;
        }

        Vector3 posA;
        Vector3 posB;
        Vector3 posC;
        Vector3 normalA;
        Vector3 normalB;
        Vector3 normalC;
    }

    private Material rayTraceMat;
    private Material averageMat;
    private RenderTexture frameTex;
    private RenderTexture averageTex;

    private int frame = 1;

    public int raysPerFrame; // koliko zraka bacamo svaki frame
    public int maxBounces; // koliko se maksimalno puta zraka moze odbiti

    public Color skyColor;

    public List<Sphere> sphereList; // lista kugli koja je vidljiva korisniku
    private SphereStruct[] spheres; // te kugle u obliku u kojem ih mozemo proslijediti shaderu
    private ComputeBuffer sphereBuffer;

    public List<RayTracingMesh> meshList;
    private List<MeshStruct> meshes;
    private List<TriangleStruct> triangles;
    private ComputeBuffer meshBuffer;
    private ComputeBuffer triangleBuffer;

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

        rayTraceMat.SetInt("_SphereCount", sphereList.Count);

        //konstruiramo buffer od tih podataka te ga proslijedimo shaderu
        if (sphereBuffer != null) sphereBuffer.Release();
        sphereBuffer = new ComputeBuffer(sphereList.Count, 4 * (3+1+4+1+4));
        sphereBuffer.SetData(spheres);
        rayTraceMat.SetBuffer("_Spheres", sphereBuffer);
    }

    private void SetCameraProperties()
    {
        rayTraceMat.SetVector("_CameraPos", Camera.main.transform.position); // pozicija kamere

        // izracunamo dimenzije near clip plane-a
        float planeHeight = Camera.main.nearClipPlane * Mathf.Tan(Camera.main.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2f;
        float planeWidth = planeHeight * Camera.main.aspect;
        rayTraceMat.SetVector("_NearPlane", new Vector3(planeWidth, planeHeight, Camera.main.nearClipPlane));

        // proslijedimo object to world space matricu kamere
        rayTraceMat.SetMatrix("_CameraObjectToWorldMat", Camera.main.transform.localToWorldMatrix);
    }

    private void SetMeshes()
    {
        int firstTriIdx = 0;
        meshes = new List<MeshStruct> ();
        triangles = new List<TriangleStruct> ();

        for (int i = 0; i < meshList.Count; i++)
        {
            Mesh mesh = meshList[i].meshInfo.mesh;

            int numTris = mesh.triangles.Length / 3;
            meshes.Add(new MeshStruct(meshList[i], firstTriIdx, numTris));
            firstTriIdx += numTris;

            List<Vector3> verteces = new List<Vector3>();
            foreach (Vector3 v in mesh.vertices)
            {
                Vector4 vert4 = new Vector4(v.x, v.y, v.z, 1);
                vert4 = meshList[i].meshInfo.transform.localToWorldMatrix * vert4;
                verteces.Add(new Vector3(vert4.x, vert4.y, vert4.z));
            }

            List<Vector3> normals = new List<Vector3>();
            foreach (Vector3 n in mesh.normals)
            {
                Vector4 norm4 = new Vector4(n.x, n.y, n.z, 0);
                norm4 = meshList[i].meshInfo.transform.localToWorldMatrix * norm4;
                normals.Add(new Vector3(norm4.x, norm4.y, norm4.z));
            }

            for (int t = 0; t < mesh.triangles.Length; t += 3)
            {
                triangles.Add(new TriangleStruct(
                    verteces[mesh.triangles[t]],
                    verteces[mesh.triangles[t + 1]],
                    verteces[mesh.triangles[t + 2]],
                    normals[mesh.triangles[t]],
                    normals[mesh.triangles[t + 1]],
                    normals[mesh.triangles[t + 2]]
                ));
            }
        }

        if (meshBuffer != null) meshBuffer.Release();
        
        
        if (triangleBuffer != null) triangleBuffer.Release();

        meshBuffer = new ComputeBuffer(meshes.Count, 4 * (1 + 1 + 4 + 1 + 4));
        meshBuffer.SetData(meshes);
        triangleBuffer = new ComputeBuffer(triangles.Count, 4 * (3 * 6));
        triangleBuffer.SetData(triangles);

        rayTraceMat.SetBuffer("_Meshes", meshBuffer);
        rayTraceMat.SetBuffer("_Triangles", triangleBuffer);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (rayTraceMat == null)
        {
            rayTraceMat = new Material(Shader.Find("Hidden/RayTracing"));
            averageMat = new Material(Shader.Find("Hidden/Average"));

            averageTex = new RenderTexture(source.descriptor);
            averageTex.graphicsFormat = GraphicsFormat.R32G32B32A32_SFloat;
            averageTex.Create();
            frameTex = new RenderTexture(source.descriptor);
            frameTex.graphicsFormat = GraphicsFormat.R32G32B32A32_SFloat;
            frameTex.Create();

            SetSpheres(); // postavimo parametre kugli
            SetMeshes();
        }


        SetCameraProperties(); // postavimo parametre kamere

        // postavimo ostale parametre shadera
        rayTraceMat.SetInt("_RaysPerFrame", raysPerFrame);
        rayTraceMat.SetInt("_MaxBounces", maxBounces);

        // postavimo boju neba
        rayTraceMat.SetColor("_SkyColor", skyColor);

        // postavimo trenutni frame
        rayTraceMat.SetInt("_Frame", frame);
        rayTraceMat.SetInt("_RandomSeed", UnityEngine.Random.Range(0, int.MaxValue));

        // pokrenemo shader na slici
        Graphics.Blit(source, frameTex, rayTraceMat);

        averageMat.SetTexture("_AverageTex", averageTex);
        averageMat.SetInt("_Frame", frame);
        Graphics.Blit(frameTex, averageTex, averageMat);
        frame++;

        Graphics.Blit(averageTex, destination);
    }

    // na kraju moramo izbrisati teksture jer ce inace njihova memorija ostati zauzeta (memory leak)
    private void OnDestroy()
    {
        sphereBuffer.Release();
        meshBuffer.Release();
        triangleBuffer.Release();

        averageTex.Release();
        frameTex.Release();
    }
}
