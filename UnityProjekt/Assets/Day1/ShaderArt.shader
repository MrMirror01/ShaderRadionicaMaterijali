Shader "Unlit/ShaderArt"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Frequency ("Frequency", float) = 5
        _Speed ("Speed", float) = 5
        _OscilationAmount ("Oscilation", Range(0, 1)) = 1
        _OscilationSpeed ("Oscilation speed", float) = 1
        _Iterations ("Iterations", float) = 5
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _Frequency;
            float _Speed;
            float _OscilationAmount;
            float _OscilationSpeed;
            float _Iterations;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv0 = i.uv - .5; // zapamtimo orginalne uv koordinate ali zamaknute tako da su u rasponu -0.5->0.5
                float2 uv = uv0;

                // postavimo boju na crnu
                float4 col = float4(0, 0, 0, 1);
                
                // iteriramo nekoliko puta, svaki put crtamo sve manje detalje
                for (float i = 1.; i < _Iterations; i++) {
                    // izracunamo udaljenost od ishodista uv koordinatnog sustava
                    // mnozimo sa (e ^ udaljenost od sredista slike) kako bi dodali 'nepravilnost' u gradijente
                    float gradient = length(uv) * exp(-length(uv0));

                    float3 faze = _Speed * _Time.y; // mijenjamo fazu sinusa u ovisnosti o zeljenoj brzini i vremenu
                    faze += _OscilationAmount * cos(_OscilationSpeed * _Time.yzw); // dodamo oscilacije u fazi ali sa razlicitim frekevencijama za razlicite boje

                    // izracunamo sinus u ovisnosti o gradientu i fazi
                    // povecamo frekvenciju za svaku iteraciju
                    float3 function = sin(i * _Frequency * gradient + faze);
                    // djelujemo funkcijom 0.1/x kako bi dobili vrlo svijetle vrijednosti sa brzim otpadanjem u nulu
                    function = .1 / (i * abs(function)); // funkciju mnozimo sa i kako bi kasnije iteracije bile tamnije

                    col.rgb += function; // dodamo rezultat u trenutnu boju

                    // prije slijedece iteracije skaliramo uv koordinate 
                    uv = frac(uv * 1.5) - .5;
                }

                // vratimo boju ali ju dignemo na neku potenciju kako bismo istancali tamnije boje
                return pow(col, 1.5);
            }
            ENDCG
        }
    }
}
