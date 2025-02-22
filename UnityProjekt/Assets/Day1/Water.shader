Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ColorTop ("Color Top", Color) = (.5, .5, 1, 0)
        _ColorBottom ("Color Bottom", Color) = (0, 0, 1, 0)
        _Amplitude ("Amplitude", Range(0, 1)) = .1
        _Frequency ("Frequency", float) = 10
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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 objectVert : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _ColorTop;
            float4 _ColorBottom;
            float _Frequency;
            float _Amplitude;

            v2f vert (appdata v)
            {
                v2f o;

                o.objectVert = v.vertex;
                o.objectVert.xyz += _Amplitude * v.normal.xyz * sin(v.vertex.x * _Frequency + _Time.y);


                o.vertex = UnityObjectToClipPos(o.objectVert);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return lerp(_ColorBottom, _ColorTop, (i.objectVert.z / _Amplitude + 1) / 2);
            }
            ENDCG
        }
    }
}
