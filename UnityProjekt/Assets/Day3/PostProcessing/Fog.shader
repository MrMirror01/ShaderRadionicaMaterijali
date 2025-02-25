Shader "Hidden/Fog"
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
            sampler2D _CameraDepthTexture; //depth buffer camere -> sadrzi udaljenosti svakog piksela od kamere

            float4 _FogColor;
            float _Density;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                //_ProjectionParams = {1.0, near, far, 1/far}
                float near = _ProjectionParams.y;
                float far = _ProjectionParams.z;
                float depth = 1.0 - tex2D(_CameraDepthTexture, i.uv);
                
                //lineariziramo depth
                depth = (1 - far / near) * depth + (far / near);
                depth = 1.0 / depth;

                depth *= far; //udaljenost od kamere u world space-u

                // izracunamo jacinu magle po formuli
                float fogFactor = pow(2, -pow(depth * _Density, 2));

                // interpoliramo izmedu boje magle i boje scene u ovisnosti o jacini magle
                return lerp(_FogColor, col, fogFactor);
            }
            ENDCG
        }
    }
}
