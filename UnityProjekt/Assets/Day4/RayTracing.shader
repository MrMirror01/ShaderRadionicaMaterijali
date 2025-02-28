Shader "Hidden/RayTracing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // materijal od kojeg se sastoji pojedini objekt
            struct Material {
                float4 color;
                float emmission;
                float4 emmissionColor;
            };

            // kugla
            struct Sphere {
                float3 position;
                float radius;
                Material material;
            };

            struct Triangle
            {
                float3 posA;
                float3 posB;
                float3 posC;
                float3 normalA;
                float3 normalB;
                float3 normalC;
            };
            
            struct Mesh
            {
                int firstTriangleIdx;
                int numTriangles;
                Material material;
            };

            // zraka
            struct Ray {
                float3 position;
                float3 direction;
                float4 color;
            };

            // podatci o tocki koju je zraka pogodila
            struct HitInfo {
                bool didHit;
                float3 position;
                float distance;
                float3 normal;
                Material material;
            };

            sampler2D _MainTex;

            // broj framea
            uint _Frame;

            // parametri ray tracinga
            int _RaysPerFrame;
            int _MaxBounces;

            // boja neba
            float4 _SkyColor;

            // podatci o kameri
            float3 _CameraPos;
            float3 _NearPlane;
            float4x4 _CameraObjectToWorldMat;

            // buffer sa kuglama
            int _SphereCount;
            StructuredBuffer<Sphere> _Spheres;

            // bufferi za trokute i mesheve
            int _TriangleCount;
            StructuredBuffer<Triangle> _Triangles;
            int _MeshCount;
            StructuredBuffer<Mesh> _Meshes;

            // funkcija koja generira pseudonasumican broj od 0 do 0xffffffff (2^32-1) za pojedini state
            // inout oznacava da ce promijena na state biti odrazena i u pozivajucoj funkciji (kao da koristimo pointer)
            uint nextRand(inout uint state)
			{
				state = state * 747796405 + 2891336453;
				uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
				result = (result >> 22) ^ result;
				return result;
			}

            // podijeli nasumicni broj sa maksimalnim mogucim da bi se generirao broj u rasponu [0,1]
            float random01(inout uint state) {
                return nextRand(state) / float(0xffffffff);
            }

            // generira nasumicni smjer (tocka na sferi radijusa 1)
            float3 randomDirection(inout uint state) {
                // generira nasumicne tocke u kocki tako dugo dok se ta tocka ne nalazi u kugli radijusa 1
                for (int limit = 0; limit < 100; limit++) {
                    float x = random01(state) * 2 - 1;
                    float y = random01(state) * 2 - 1;
                    float z = random01(state) * 2 - 1;

                    float3 pointInCube = float3(x, y, z);

                    if (length(pointInCube) <= 1) {
                        // tu tocku normalizira kako bi se dobila tocka na sferi
                        return normalize(pointInCube);
                    }
                }

                float x = random01(state) * 2 - 1;
                float y = random01(state) * 2 - 1;
                float z = random01(state) * 2 - 1;
                return normalize(float3(x, y, z));
            }

            // generira tocku na polusferi na nacin da tocku s sfere preokrene ako je na krivoj polovici
            float3 randomInsideHemisphere(float3 normal, inout uint state) {
                float3 ranDir = randomDirection(state);
                return ranDir * sign(dot(ranDir, normal));
            }

            HitInfo rayTriangleIntersection(Ray ray, Triangle tri, Material mat)
            {
                float3 edgeAB = tri.posB - tri.posA;
                float3 edgeAC = tri.posC - tri.posA;
                float3 normalVector = cross(edgeAB, edgeAC);
                float3 ao = ray.position - tri.posA;
                float3 dao = cross(ao, ray.direction);
            
                float determinant = -dot(ray.direction, normalVector);
                float invDet = 1 / determinant;
            				
            	// Calculate dst to triangle & barycentric coordinates of intersection point
                float dst = dot(ao, normalVector) * invDet;
                float u = dot(edgeAC, dao) * invDet;
                float v = -dot(edgeAB, dao) * invDet;
                float w = 1 - u - v;
                
            	// Initialize hit info
                HitInfo hit;
                // for backface culling use: (determinant >= 1E-6)
                // for no backface culling use: ((abs(determinant) >= 1E-6) -> careful ka zbog float precision ti zavrsi ray nutra v objektu i onda je stuck
                hit.didHit = ((determinant >= 1E-6) && (dst >= 0) && (u >= 0) && (v >= 0) && (w >= 0));
                hit.position = ray.position + ray.direction * dst;
                hit.distance = dst;
                hit.material = mat;

                float3 normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
                hit.normal = normal;

                return hit;
            }

            HitInfo raySphereIntersection(Ray ray, Sphere s)
            {
                HitInfo hit;
                
                float3 L = s.position - ray.position; // vektor od izvora zrake do centra kugle
                float Tca = dot(L, ray.direction); // udaljenost od izvora zrake do tocke na zraki koji je pod pravim kutom od centra
                
                // gleda na komplet drugu stranu ray
                if (Tca < 0.0)
                {
                    hit.didHit = false;
                    return hit;
                }
                
                float d = sqrt(length(L) * length(L) - Tca * Tca);
                if (d > s.radius)
                {
                    hit.didHit = false;
                    return hit;
                }
                
                float Thc = sqrt(s.radius * s.radius - d * d); // udaljenost od intersectiona do tocke na zraki koja je pod pravim kutom od centra
                float3 intersection = ray.position + ray.direction * (Tca - Thc);
                
                hit.didHit = true;
                hit.position = intersection;
                hit.distance = length(ray.position - intersection);
                hit.normal = normalize(intersection - s.position);
                hit.material = s.material;
                return hit;
            }

            // pronalazi najblizu tocku koju je zraka pogodila
            HitInfo castRay(Ray ray) {

                HitInfo bestHit;
                bestHit.distance = 1.#INF;
                for (int s = 0; s < _SphereCount; s++) {
                    Sphere sphere = _Spheres[s];

                    HitInfo hit = raySphereIntersection(ray, sphere);

                    if (hit.didHit) {
                        if (hit.distance < bestHit.distance){
                            bestHit = hit;
                        }
                    }
                }

                for (int m = 0; m < _MeshCount; m++) {
                    int start = _Meshes[m].firstTriangleIdx;
                    int end = start + _Meshes[m].numTriangles;
                    for (int t = start; t < end; t++) {
                        Triangle tri = _Triangles[t];

                        HitInfo hit = rayTriangleIntersection(ray, tri, _Meshes[m].material);

                        if (hit.didHit) {
                            if (hit.distance < bestHit.distance){
                                bestHit = hit;
                            }
                        }
                    }
                }

                return bestHit;
            }

            // prati odbijanje zrake po sceni te izracuna boju piksela
            float3 trace(Ray ray, inout uint randomState) {
                float3 incomingLight = 0;

                // bacamo zraku MaxBounces puta ili dok ne promasi sve objekte
                for (int i = 0; i < _MaxBounces; i++) {
                    // izracunamo najblizu tocku koju je zraka pogodila
                    HitInfo hit = castRay(ray);

                    // ako je zraka pogodila nesto
                    if (hit.didHit) {
                        // izracunamo boju i jacinu svjetla koje dolazi iz objekta
                        float3 emmitedLight = hit.material.emmission * hit.material.emmissionColor;

                        // dodamo svjetlo (pobojano u boju "zrake") u varijablu koja pamti ukupnu kolicinu svjetlosti koju je zraka vidjela
                        incomingLight += emmitedLight * ray.color;

                        ray.position = hit.position; // azuriramo poziciju zrake na mjesto gdje je pogodila objekt   
                        ray.direction = randomInsideHemisphere(hit.normal, randomState); // odbijemo zraku u nasumicnom smjeru
                        float ligthStrength = dot(hit.normal, ray.direction);
                        ray.color *= hit.material.color * ligthStrength; // pobojamo boju zrake ovisno o boji objekta od kojeg se odbila
                    }
                    else {
                        incomingLight += _SkyColor * ray.color;
                        break;
                    }
                }

                return incomingLight; // vratimo pronadenu svjetlost
            }

            

            fixed4 frag (v2f i) : SV_Target
            {
                // izracunamo poziciju koja odgovara trenutnom pikselu na near ravnini
                float3 rayPoint = float3(i.uv - 0.5, 1) * _NearPlane;
                rayPoint = mul(_CameraObjectToWorldMat, float4(rayPoint, 1));

                // izracunamo jedinstven broj koji pridodjelimo svakom pikselu
                float2 pixelPos = i.uv * _ScreenParams.xy;
                uint pixelIndex = pixelPos.x * _ScreenParams.x + pixelPos.y;

                // taj broj koristimo kao seed za generiranje nasumicnih brojeva
                uint randomState = pixelIndex + _Frame * 757283;

                // zraka krece iz kamere u smjeru piksela te je na pocetku bijela
                Ray ray;
                ray.position = _CameraPos;
                ray.direction = normalize(rayPoint - _CameraPos);
                ray.color = 1;

                // pratimo put veceg broja zraka te uzmemo njihov prosijek
                float3 col = 0;
                for (int _ = 0; _ < _RaysPerFrame; _++) {
                    col += trace(ray, randomState);
                }
                col /= _RaysPerFrame;

                return float4(col, 1); // vratimo izracunatu boju
            }
            ENDCG
        }
    }
}
