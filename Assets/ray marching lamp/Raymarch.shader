Shader "Unlit/Raymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Smoothness ("Smooth Union", Range(0,1)) = 0.5
        _GlobalSphereSize ("Sphere Size", Float) = 1
        _MoveScale ("Move scale", Vector) = (0.2, 4, 0.2,0)
        _PositionOffset ("Position Offset", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Cull Back
        //ZTest Off
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
                float4 worldPos : TEXCOORD2;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Smoothness;
            float _GlobalSphereSize;
            float3 _MoveScale;
            float3 _PositionOffset;

            //https://iquilezles.org/articles/distfunctions/
            float opSmoothUnion( float d1, float d2, float k )
            {
                float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
                return lerp( d2, d1, h ) - k*h*(1.0-h);
            }
            
            float sdSphere(float3 p, float3 spherePos, float r)
            {
                return length(p - spherePos) - r;
            }
            
            float getDist(float3 p)
            {

                float t = _Time.y;
                float3 sphere1Pos = float3(sin(t * 0.33), abs(sin(t * 0.43)), sin(t * -0.98)) ;
                float3 sphere2Pos = float3(sin(t * -0.21), abs(sin(t * -0.72)), sin(t * 0.56));
                float3 sphere3Pos = float3(sin(t * -0.67), abs(sin(t * 0.27)), sin(t * 0.77)) ;

                float sphereSize = 0.8 * _GlobalSphereSize;
                
                float distToSphere1 = sdSphere(p, sphere1Pos * _MoveScale +_PositionOffset,  sphereSize);
                float distToSphere2 = sdSphere(p, sphere2Pos * _MoveScale +_PositionOffset, sphereSize*0.75);
                float distToSphere3 = sdSphere(p, sphere3Pos * _MoveScale +_PositionOffset, sphereSize*0.4);
                float distToSphere4 = sdSphere(p, _PositionOffset , 1.4 * _GlobalSphereSize );
                
                return opSmoothUnion(opSmoothUnion(opSmoothUnion(distToSphere1,distToSphere2,_Smoothness),
                    distToSphere3,_Smoothness),
                    distToSphere4,_Smoothness);
            }
            
            float rayMarch(float3 rayOrigin, float3 rayDir)
            {
                const int MaxSteps = 100;
                const float SurfDist = 0.01;
                const float MaxDist = 100;


                float distanceFromOrigin = 0;
                for (int i = 0; i < MaxSteps; i++)
                {
                    float3 p = rayOrigin + distanceFromOrigin * rayDir;
                    float newDist = getDist(p);
                    distanceFromOrigin += newDist;
                    if (distanceFromOrigin >= MaxDist) clip(-1);
                    if (newDist <= SurfDist) break;
                }

                return distanceFromOrigin;
            }

            float3 getNormal(float3 p)
            {
                float d = getDist(p);
                float2 e = float2(0.01, 0);

                float3 n = d - float3(
                    getDist(p - e.xyy),
                    getDist(p - e.yxy),
                    getDist(p - e.yyx)
                    );
                
                return normalize(n);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //fixed4 col = tex2D(_MainTex, i.uv);

                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDir = normalize(i.worldPos - rayOrigin);

                
                float dist = rayMarch(rayOrigin, rayDir);
                float3 p = rayOrigin + rayDir * dist;
                float height = p.y;
                height = 1 - (height - 2) * 0.5;
                float3 col = lerp(float3(1, 0.05, 0), float3(1, 0.2, 0), height) * 3;

                float3 viewDir = normalize(i.worldPos - p);
                float rim = pow(dot(viewDir, getNormal(p)), 0.65);
                return float4(col * rim,1) ;
            }
            ENDCG
        }
    }
}
