Shader "Hidden/Blur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        CGINCLUDE // zajednicko svim passovima shadera

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

        sampler2D _MainTex;
        //Unity automatski postavlja vrijednost na {1 / sirina teksture, 1 / visina teksture, sirina teksture, visina teksture}
        //gdje je 1 / sirina teksture = sirina pikesla u UV koordinatama
        float4 _MainTex_TexelSize;

        static const int KERNEL_SIZE = 19;
        static const int HALF_KERNEL_SIZE = KERNEL_SIZE / 2;
        ENDCG

        Pass
        {
            Name "Box Blur"

            CGPROGRAM
            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0;

                // iteriramo po okolnim pikselima
                for (int x = -HALF_KERNEL_SIZE; x <= HALF_KERNEL_SIZE; x++) {
                    for (int y = -HALF_KERNEL_SIZE; y <= HALF_KERNEL_SIZE; y++) {
                        // uzorkujemo teksturu za svaki piksel i dodamo boju
                        col += tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy);
                    }
                }
                col /= KERNEL_SIZE * KERNEL_SIZE; // podijelimo sa brojem uzorkovanih piksela kako bi dobili prosjek

                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Gaussian Blur"

            CGPROGRAM
            // 2D kernel matrica za gaussian blur
            static const float gaussianKernel2D[KERNEL_SIZE * KERNEL_SIZE] = {
                0.0009,	0.0011,	0.0013,	0.0014,	0.0016,	0.0018,	0.0019,	0.0020,	0.0021,	0.0021,	0.0021,	0.0020,	0.0019,	0.0018,	0.0016,	0.0014,	0.0013,	0.0011,	0.0009,
                0.0011,	0.0013,	0.0015,	0.0017,	0.0019,	0.0021,	0.0023,	0.0024,	0.0025,	0.0025,	0.0025,	0.0024,	0.0023,	0.0021,	0.0019,	0.0017,	0.0015,	0.0013,	0.0011,
                0.0013,	0.0015,	0.0018,	0.0020,	0.0022,	0.0025,	0.0026,	0.0028,	0.0029,	0.0029,	0.0029,	0.0028,	0.0026,	0.0025,	0.0022,	0.0020,	0.0018,	0.0015,	0.0013,
                0.0014,	0.0017,	0.0020,	0.0023,	0.0026,	0.0028,	0.0030,	0.0032,	0.0033,	0.0033,	0.0033,	0.0032,	0.0030,	0.0028,	0.0026,	0.0023,	0.0020,	0.0017,	0.0014,
                0.0016,	0.0019,	0.0022,	0.0026,	0.0029,	0.0031,	0.0034,	0.0035,	0.0037,	0.0037,	0.0037,	0.0035,	0.0034,	0.0031,	0.0029,	0.0026,	0.0022,	0.0019,	0.0016,
                0.0018,	0.0021,	0.0025,	0.0028,	0.0031,	0.0034,	0.0037,	0.0039,	0.0040,	0.0040,	0.0040,	0.0039,	0.0037,	0.0034,	0.0031,	0.0028,	0.0025,	0.0021,	0.0018,
                0.0019,	0.0023,	0.0026,	0.0030,	0.0034,	0.0037,	0.0040,	0.0042,	0.0043,	0.0043,	0.0043,	0.0042,	0.0040,	0.0037,	0.0034,	0.0030,	0.0026,	0.0023,	0.0019,
                0.0020,	0.0024,	0.0028,	0.0032,	0.0035,	0.0039,	0.0042,	0.0044,	0.0045,	0.0046,	0.0045,	0.0044,	0.0042,	0.0039,	0.0035,	0.0032,	0.0028,	0.0024,	0.0020,
                0.0021,	0.0025,	0.0029,	0.0033,	0.0037,	0.0040,	0.0043,	0.0045,	0.0047,	0.0047,	0.0047,	0.0045,	0.0043,	0.0040,	0.0037,	0.0033,	0.0029,	0.0025,	0.0021,
                0.0021,	0.0025,	0.0029,	0.0033,	0.0037,	0.0040,	0.0043,	0.0046,	0.0047,	0.0048,	0.0047,	0.0046,	0.0043,	0.0040,	0.0037,	0.0033,	0.0029,	0.0025,	0.0021,
                0.0021,	0.0025,	0.0029,	0.0033,	0.0037,	0.0040,	0.0043,	0.0045,	0.0047,	0.0047,	0.0047,	0.0045,	0.0043,	0.0040,	0.0037,	0.0033,	0.0029,	0.0025,	0.0021,
                0.0020,	0.0024,	0.0028,	0.0032,	0.0035,	0.0039,	0.0042,	0.0044,	0.0045,	0.0046,	0.0045,	0.0044,	0.0042,	0.0039,	0.0035,	0.0032,	0.0028,	0.0024,	0.0020,
                0.0019,	0.0023,	0.0026,	0.0030,	0.0034,	0.0037,	0.0040,	0.0042,	0.0043,	0.0043,	0.0043,	0.0042,	0.0040,	0.0037,	0.0034,	0.0030,	0.0026,	0.0023,	0.0019,
                0.0018,	0.0021,	0.0025,	0.0028,	0.0031,	0.0034,	0.0037,	0.0039,	0.0040,	0.0040,	0.0040,	0.0039,	0.0037,	0.0034,	0.0031,	0.0028,	0.0025,	0.0021,	0.0018,
                0.0016,	0.0019,	0.0022,	0.0026,	0.0029,	0.0031,	0.0034,	0.0035,	0.0037,	0.0037,	0.0037,	0.0035,	0.0034,	0.0031,	0.0029,	0.0026,	0.0022,	0.0019,	0.0016,
                0.0014,	0.0017,	0.0020,	0.0023,	0.0026,	0.0028,	0.0030,	0.0032,	0.0033,	0.0033,	0.0033,	0.0032,	0.0030,	0.0028,	0.0026,	0.0023,	0.0020,	0.0017,	0.0014,
                0.0013,	0.0015,	0.0018,	0.0020,	0.0022,	0.0025,	0.0026,	0.0028,	0.0029,	0.0029,	0.0029,	0.0028,	0.0026,	0.0025,	0.0022,	0.0020,	0.0018,	0.0015,	0.0013,
                0.0011,	0.0013,	0.0015,	0.0017,	0.0019,	0.0021,	0.0023,	0.0024,	0.0025,	0.0025,	0.0025,	0.0024,	0.0023,	0.0021,	0.0019,	0.0017,	0.0015,	0.0013,	0.0011,
                0.0009,	0.0011,	0.0013,	0.0014,	0.0016,	0.0018,	0.0019,	0.0020,	0.0021,	0.0021,	0.0021,	0.0020,	0.0019,	0.0018,	0.0016,	0.0014,	0.0013,	0.0011,	0.0009
            };

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0; // postavimo boju na crnu

                for (int x = -HALF_KERNEL_SIZE; x <= HALF_KERNEL_SIZE; x++) {
                    for (int y = -HALF_KERNEL_SIZE; y <= HALF_KERNEL_SIZE; y++) {
                        // uzorkujemo teksturu na zamaknutoj poziciji
                        float4 sample = tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy);

                        // izracunamo odgovarajuci index u kernel matrici 
                        int xIdx = x + HALF_KERNEL_SIZE;
                        int yIdx = y + HALF_KERNEL_SIZE;
                        // procitamo tezinu u kernelu
                        float weight = gaussianKernel2D[xIdx * KERNEL_SIZE + yIdx];

                        // boji dodamo ocitanu boju u ovisnosti o tezini
                        col += sample * weight;
                    }
                }

                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Gaussian Blur Horizontal"

            CGPROGRAM
            // 2D kernel matrica za gaussian blur
            static const float gaussianKernel1D[KERNEL_SIZE] = {0.0302,	0.0360,	0.0419,	0.0478,	0.0535,	0.0586,	0.0630,	0.0662,	0.0683,	0.0690,	0.0683,	0.0662,	0.0630,	0.0586,	0.0535,	0.0478,	0.0419,	0.0360,	0.0302};

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0; // postavimo boju na crnu

                for (int x = -HALF_KERNEL_SIZE; x <= HALF_KERNEL_SIZE; x++) {
                    // uzorkujemo teksturu na zamaknutoj poziciji
                    float4 sample = tex2D(_MainTex, i.uv + float2(x, 0) * _MainTex_TexelSize.xy);

                    // izracunamo odgovarajuci index u kernel matrici
                    int xIdx = x + HALF_KERNEL_SIZE;
                    // procitamo tezinu u kernelu
                    float weight = gaussianKernel1D[xIdx];

                    // boji dodamo ocitanu boju u ovisnosti o tezini
                    col += sample * weight;
                }

                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Gaussian Blur Vertical"

            CGPROGRAM
            // 2D kernel matrica za gaussian blur
            static const float gaussianKernel1D[KERNEL_SIZE] = {0.0302,	0.0360,	0.0419,	0.0478,	0.0535,	0.0586,	0.0630,	0.0662,	0.0683,	0.0690,	0.0683,	0.0662,	0.0630,	0.0586,	0.0535,	0.0478,	0.0419,	0.0360,	0.0302};

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0; // postavimo boju na crnu

                for (int y = -HALF_KERNEL_SIZE; y <= HALF_KERNEL_SIZE; y++) {
                    // uzorkujemo teksturu na zamaknutoj poziciji
                    float4 sample = tex2D(_MainTex, i.uv + float2(0, y) * _MainTex_TexelSize.xy);

                    // izracunamo odgovarajuci index u kernel matrici
                    int yIdx = y + HALF_KERNEL_SIZE;
                    // procitamo tezinu u kernelu
                    float weight = gaussianKernel1D[yIdx];

                    // boji dodamo ocitanu boju u ovisnosti o tezini
                    col += sample * weight;
                }

                return col;
            }
            ENDCG
        }
    }
}
