Shader "Unlit/BlinPhong"
{
    Properties
    {
        _LightDir ("Light direction", Vector) = (-1, -1, 0, 0)

        _AmbientColor ("Ambient light color", Color) = (0.1, 0.1, 0.1, 1)
        _LightColor ("Light color", Color) = (1, 1, 1, 1)
        _LightIntensity ("Light intensity", float) = 1.0
        _DiffuseColor ("Diffuse color", Color) = (1, 1, 1, 1)
        _SpecularColor ("Specular color", Color) = (1, 1, 1, 1)
        _SpecularIntensity ("Shinyness", float) = 1
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
                float3 normal : NORMAL; // -- najavimo da hocemo normale
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;

                float3 normal : TEXCOORD1; // -- normale prenosimo iz vertex u fragment shader
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float3 _LightDir;

            float3 _ViewDir;

            float3 _AmbientColor;
            float3 _LightColor;
            float _LightIntensity;
            float3 _DiffuseColor;
            float3 _SpecularColor;
            float _SpecularIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = mul(unity_ObjectToWorld, v.normal); // -- proslijedimo normale, ali u World Space-u u fragment shader
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // izracunamo difuznu svijetlost kao skalarni umnozak
                // normale i vektora koji pokazuje prema izvoru svijetlosti
                float diffuse = dot(i.normal, -_LightDir);
                // ogranicimo izmedu vrijednost 0 i 1
                diffuse = saturate(diffuse);

                // izracunamo smjer na pola puta izmedu vektora smjera prema svjetlosti i vektora smjera prema kameri
                // taj smjer diktira na kojim povrsinama se mora nalaziti specular highlight
                float3 specDir = normalize(-_ViewDir + -_LightDir);

                // izracunamo specular svijetlost kao skalarni umnozak
                // normale i vektora koji se nalazi izmedu svjetlosti i kamere
                float specular = dot(i.normal, specDir);
                specular = saturate(specular);
                // eksponencijalno skaliramo specular ovisno o _SpecularIntensity
                specular = pow(specular, _SpecularIntensity);

                // izracunamo boju kao kombinaciju ambientnog, difuznog i spekularnog osvjetljenja
                float3 col = _AmbientColor +
                            _DiffuseColor * diffuse * _LightColor * _LightIntensity +
                            _SpecularColor * specular * _LightColor * _LightIntensity;

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);

                return float4(col, 1.);
            }
            ENDCG
        }
    }
}
