Shader "Hidden/Vignette"
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

            sampler2D _MainTex;
            float _Intensity;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                // centriramo uv koordinate
                float2 centeredUv = i.uv - 0.5;

                // odredimo intenyitet vinjete u ovisnosti o udaljenosti od sredista slike
                float vignette = saturate(length(centeredUv) + _Intensity);
                vignette = smoothstep(1, 0, vignette);

                // pomnozimo boju vrijednosti vinjete kako bi zatamnili rubove
                col.rgb *= vignette;

                return col;
            }
            ENDCG
        }
    }
}
