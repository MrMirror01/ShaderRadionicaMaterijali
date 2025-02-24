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

        static const float gaussianKernel1D[7] = { 0.0027, 0.0451, 0.2415, 0.4215, 0.2415, 0.0451, 0.0027 };

        sampler2D _MainTex;
        //Unity automatski postavlja vrijednost na {1 / sirina teksture, 1 / visina teksture, sirina teksture, visina teksture}
        //gdje je 1 / sirina teksture = sirina pikesla u UV koordinatama
        float4 _MainTex_TexelSize;
        ENDCG

        Pass
        {
            Name "Box Blur"

            CGPROGRAM
            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0;

                // iteriramo po okolnim pikselima (7x7)
                for (int x = -3; x <= 3; x++) {
                    for (int y = -3; y <= 3; y++) {
                        // uzorkujemo teksturu za svaki piksel i dodamo boju
                        col += tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy);
                    }
                }
                col /= 49; // podijelimo sa brojem uzorkovanih piksela kako bi dobili prosjek

                return col;
            }
            ENDCG
        }

        Pass
        {
            Name "Gaussian Blur"

            CGPROGRAM
            // 2D kernel matrica za gaussian blur
            static const float gaussianKernel2D[49] = {
                0.0000, 0.0001, 0.0006, 0.0011, 0.0006, 0.0001, 0.0000,
                0.0001, 0.0020, 0.0109, 0.0190, 0.0109, 0.0020, 0.0001,
                0.0006, 0.0109, 0.0583, 0.1018, 0.0583, 0.0109, 0.0006,
                0.0011, 0.0190, 0.1018, 0.1777, 0.1018, 0.0190, 0.0011,
                0.0006, 0.0109, 0.0583, 0.1018, 0.0583, 0.0109, 0.0006,
                0.0001, 0.0020, 0.0109, 0.0190, 0.0109, 0.0020, 0.0001,
                0.0000, 0.0001, 0.0006, 0.0011, 0.0006, 0.0001, 0.0000
            };

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0;
                float sum = 0;

                for (int x = -3; x <= 3; x++) {
                    for (int y = -3; y <= 3; y++) {
                        float4 sample = tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy);

                        int xIdx = x + 3;
                        int yIdx = y + 3;
                        float weight = gaussianKernel2D[xIdx * 7 + yIdx];

                        col += sample * weight;
                    }
                }

                return col;
            }
            ENDCG
        }
    }
}
