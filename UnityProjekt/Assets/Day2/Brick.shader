Shader "Unlit/Brick"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Scale ("Scale", float) = 1
        _LengthRatio ("Length ratio", float) = 1
        _MortarPercent ("Mortar percent", Range(0, 1)) = .1
        _BevelPercent ("Bevel percent", Range(0, 1)) = .1
        _MortarColor ("Mortar color", Color) = (.2, .2, .2, 1)
        _BrickColor ("Brick color", Color) = (1, .2, .2, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                // zatrazimo normale i tangente
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                // najavimo da cemo proslijediti normale i tangente u fragment shader
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float3 _LightDir;
            float3 _ViewDir;

            float _Scale;
            float _LengthRatio;
            float _MortarPercent;
            float _BevelPercent;

            float4 _MortarColor;
            float4 _BrickColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // pretvorimo normalu i tangentu u World Space te ih proslijedimo fragment shaderu
                o.normal = mul(unity_ObjectToWorld, v.normal);
                float3 worldTan = mul(unity_ObjectToWorld, v.tangent.xyz);
                o.tangent = float4(worldTan.x, worldTan.y, worldTan.z, v.tangent.w);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // skaliramo uv koordinate sa raspona 0->1 do raspona 0->Scale na obje koordinate
                float2 scaledUv = i.uv * _Scale;
                scaledUv.x /= _LengthRatio; // x koordinatu podjelimo sa omjerom duljine stranica cigle kako bi ju produzili (sada raste sporije pa ce cigle ispasti duze)
                
                // svaki drugi red zamaknemo za pola cigle po x koordinati
                scaledUv.x = lerp(scaledUv.x, scaledUv.x + 0.5, floor(scaledUv.y) % 2);
                /* efektivno isto kao
                    if (floor(scaledUv.y) % 2)
                        scaledUv.x += 0.5;
                ali malo brze */

                // razdijelimo raspon 0->Scale na cigle tako da od koordinate ostavimo samo decimalni dio (npr. 2.34 -> 0.34)
                scaledUv = frac(scaledUv);
                // sada koordinatni sustav svake cigle skaliramo s raspona 0->1 na -1->1 tako da je ishodiste u sredini cigle
                scaledUv = 2 * scaledUv - 1;

                // izracunamo duljinu morta i nagiba na ciglama u lokalnim koordinatama cigle
                // pritom uzimamo u obzir da skaliramo x koordinatu u ovisnosti o omjeru duljina stranica kako bi sirina bila jednaka visini
                float2 mortarLen = _MortarPercent;
                mortarLen.x /= _LengthRatio;
                float2 bevelLen = _BevelPercent;
                bevelLen.x /= _LengthRatio;

                // izracunamo koordinate poctka i kraja nagiba
                float2 bevelEnd = saturate(1 - mortarLen);
                float2 bevelStart = saturate(bevelEnd - bevelLen);

                // "udaljenost" o sredista cigle po svakoj koordinati
                float2 distance = abs(scaledUv);

                // izracunamo je li trenutni piksel na cigli, i je li na kosini
                bool isBrick = (distance.x < bevelEnd.x) && (distance.y < bevelEnd.y);
                bool isBevel = isBrick && ((distance.x > bevelStart.x) || (distance.y > bevelStart.y));

                // zadamo boju ovisno o tome je li piksel nac cigli ili na mortu
                float4 col = lerp(_MortarColor, _BrickColor, float(isBrick));
                /* 
                isto kao
                    if ((distance.x < bevelEnd.x) && (distance.y < bevelEnd.y))
                        col = _MortarColor
                    else
                        col = _BrickColor
                ali malo brze jer je grananje u shaderima sporo
                */

                /*
                Sada zelimo izracunati normalu (okomit vektor) na nagib kako bi mogli izracunati osvjetljenje.
                Nagib pravca koji prolazi kroz dvije tocke se izracunava po formuli:
                k = (y2-y1) / (x2-x1)
                Dakle u nasem slucaju (pod pretpostavkom da je visina odnosno y kordinata cigle 1, a morta 0)
                k = (0 - 1) / (bevelEnd - bevelStart) = -1 / (bevelEnd - bevelStart)
                Nagib okomitog pravca je
                k2 = -1 / k = bevelEnd - bevelStart
                To iskoristimo da izracunamo vektor na tom pravcu posebno po x i y osi (vazno je da vektor bude duljine 1 pa ga normaliziramo)
                */
                float3 bevelNormalX = normalize(float3(1, 0, bevelEnd.x - bevelStart.x));
                float3 bevelNormalY = normalize(float3(0, 1, bevelEnd.y - bevelStart.y));

                // izracunamo bitangentu koristeci vektorski umnozak normale i tangente kako bi dobili vektor koji je okomit na oboje
                // nije bitno da razumijete mnozenje s i.tangent.w
                // (ako vas zanima, i.tangent.w je 1 ako se koristi desni koordinatni sustav, a -1 ako se korsti lijevi, pitajte chatGpt za vise informacija :P)
                float3 bitangent = cross(i.normal, i.tangent.xyz) * i.tangent.w;

                /*
                Konstruiramo matricu za pretvorbu iz koordinatnog sustava relativno na povrsinu na kojoj se nalazi trenutni piksel u World space
                Mnozenje vektora 'v' ovom matricom je isto kao da napisemo:
                float v = float3(
                    v.x * i.tangent.xyz,
                    v.y * bitangent,
                    v.z * i.normal
                );
                Za vise informacija: 3b1b Esence of Linear Algebra :)
                */
                float3x3 tangentToWorldSpace = transpose(float3x3(i.tangent.xyz, bitangent, i.normal));

                float3 calculatedNormal = float3(0, 0, 1); // ako se piksel ne nalazi na kosini, normala je okomita na povrsinu
                // ako je piksel na kosini
                if (isBevel){
                    // udaljenost od kraja cigle do trenutne pozicije
                    float2 distFromEndOfBrick = bevelEnd - distance;
                    distFromEndOfBrick.x *= _LengthRatio; // u ovom slucaju ne zelimo da se x i y os gledaju u omjeru 1:1 pa ponistimo skaliranje

                    // ovisno po kojoj osi je piksel blize rubu cigle, tu normalu izaberemo, pazeci na orijentaciju
                    if (distFromEndOfBrick.x < distFromEndOfBrick.y) 
                        calculatedNormal = bevelNormalX * float3(lerp(-1, 1, scaledUv.x > 0), 1, 1);
                    else 
                        calculatedNormal = bevelNormalY * float3(1, lerp(-1, 1, scaledUv.y > 0), 1);
                }
                // pretvorimo normalu u world space
                calculatedNormal = mul(tangentToWorldSpace, calculatedNormal);

                // izracunamo diffuse vrijednost kao u BlinPhong shaderu
                // za potrebe ovog materijala ne trebamo specular jer cigle nisu sjajne
                float diffuse = dot(calculatedNormal, -_LightDir);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                // vratimo boju ovisno o cigli
                return col * diffuse;
            }
            ENDCG
        }
    }
}
