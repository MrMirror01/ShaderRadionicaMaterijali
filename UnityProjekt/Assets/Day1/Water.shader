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

                // zatrazimo podatke o normalama
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;

                // dodamo podatak o poziciji 
                float height : TEXCOORD1;
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

                // izracunamo visinu vala za trenutnu x koordinatu u ovisnosti o frekvenciji i vremenu
                o.height = sin(v.vertex.x * _Frequency + _Time.y);
                // promijenimo kordinate vrha u smjeru normale u ovisnosti o izracunatoj visini vala
                v.vertex.xyz += _Amplitude * v.normal.xyz * o.height;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float height01 = (i.height + 1) * 0.5; // prebacimo visinu s raspona [-1, 1] u [0, 1]
                return lerp(_ColorBottom, _ColorTop, height01); // napravimo linearni prijelaz iz jedne boje u drugu u ovisnosti o visini vala u toj tocki
            }
            ENDCG
        }
    }
}
