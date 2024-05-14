// Edited By frou01 from Unlit-Alpha.shader(Unlit/Transparent). 
// Copyright (c) 2024 frou01. MIT license(https://opensource.org/licenses/mit-license.php)


// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// Unlit alpha-blended shader.
// - no lighting
// - no lightmap support
// - no per-material color

Shader "DisplayFixedUnlit/Transparent" {
Properties {
    _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    _OffsetX("Position Offset X", Float) = 0
    _OffsetY("Position Offset Y", Float) = 0
    _OffsetZ("Position Offset Z", Float) = -1
    _ScaleX("Scale X", Float) = 1
    _ScaleY("Scale Y", Float) = 1
    _ScaleZ("Scale Z", Float) = 1
    
    _ZWriteMode("ZWrite Mode", Float) = 0
    _ZTestMode("ZTest Mode", Float) = 0
    _CullMode("Culling Mode", Float) = 0
}

SubShader {
    Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
    LOD 100

    ZWrite [_ZWriteMode]
    ZTest [_ZTestMode]

    Cull [_CullMode]

    Pass {
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            uniform float _VRChatCameraMode;
            uniform float _VRChatMirrorMode;

            float _OffsetX;
            float _OffsetY;
            float _OffsetZ;
            float _ScaleX;
            float _ScaleY;
            float _ScaleZ;

            //copy from https://qiita.com/RamType0/items/baf2b9d5ce0f9fc458be
            
            float3 PositionOf(in float4x4 mat){
                return mat._m03_m13_m23;
            }
            float4x4 BuildMatrix(in float3x3 mat,in float3 offset)
            {
                    return float4x4(
                        float4(mat[0],offset.x),
                        float4(mat[1],offset.y),
                        float4(mat[2],offset.z),
                        float4(0,0,0,1)
                        );
            }
            float3x3 RMatrixAverage(in float3x3 a,in float3x3 b){
                //OpenGLは列優先メモリレイアウトなのでこのままでOK
                #if SHADER_TARGET_GLSL

                float3 iy = (a._m01_m11_m21 + b._m01_m11_m21)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = (a._m02_m12_m22 + b._m02_m12_m22)*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);//直交する正規化ベクトル同士のクロス積も正規化されている
                return Columns(ix,iy,iz);
                #else
                //DirectXは行優先のメモリレイアウトなので、できれば行ベースで計算したい・・・
                //ところで回転行列って直交行列ですね？
                //回転行列の0,1,2列=この行列で回転をした後のX,Y,Z軸ベクトル
                //回転行列の0,1,2行=回転行列の転置行列の0,1,2列
                //                =回転行列の逆行列の0,1,2列
                //                =逆回転の回転行列の0,1,2列
                //                =この行列の逆回転の行列で回転をしたあとのX,Y,Z軸ベクトル
                //ということで、この関数の中では終始逆回転、かつ転置した状態として取り扱ってるのでこの計算の結果は正しいです。
                float3 iy = (a[1] + b[1])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 iz = (a[2] + b[2])*0.5;//回転行列の軸ベクトルは当然正規化済み 
                float3 ix = normalize(cross(iy,iz));//クロス積のベクトルの向きに絶対値は関係ない
                iz = normalize(iz);
                iy = cross(iz,ix);  //直交する正規化ベクトル同士のクロス積も正規化されている
                return float3x3(ix,iy,iz);
                #endif

            }
            float4x4 TRMatrixAverage(in float4x4 a,in float4x4 b){
                return BuildMatrix(RMatrixAverage((float3x3)a,(float3x3)b),(PositionOf(a)+PositionOf(b))*0.5);
            }

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                float3 worldPosition = transpose(UNITY_MATRIX_M)[3].xyz;
                float3 cameraPos = _WorldSpaceCameraPos;
                float4x4 CamToWorld = unity_CameraToWorld;
                #if defined(USING_STEREO_MATRICES)
                    cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * .5;
                    CamToWorld = TRMatrixAverage(unity_StereoCameraToWorld[0],unity_StereoCameraToWorld[1]);
                #endif
                
                float3 OrgnToCam = cameraPos - worldPosition;
                float DistToCam = dot(OrgnToCam,OrgnToCam);
                
                o.vertex = v.vertex;
                o.vertex.x += _OffsetX;
                o.vertex.y += _OffsetY;
                o.vertex.z += _OffsetZ;
                o.vertex.x *= _ScaleX;
                o.vertex.y *= _ScaleY;
                o.vertex.z *= _ScaleZ;
                o.vertex = mul(CamToWorld,o.vertex);
                o.vertex = mul(UNITY_MATRIX_V,float4(o.vertex.x,o.vertex.y,o.vertex.z,1));
                o.vertex = mul(UNITY_MATRIX_P,o.vertex);

                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                clip(1 - _VRChatCameraMode);
                clip(1 - _VRChatMirrorMode);
                fixed4 col = tex2D(_MainTex, i.texcoord);
                return col;
            }
        ENDCG
    }
}

}
