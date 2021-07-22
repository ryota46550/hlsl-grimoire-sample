///////////////////////////////////////////
// 構造体
///////////////////////////////////////////
// 頂点シェーダーへの入力
struct SVSIn
{
    float4 pos      : POSITION;
    float2 uv       : TEXCOORD0;
    float3 normal   : NORMAL;
};

// ピクセルシェーダーへの入力
struct SPSIn
{
    float4 pos          : SV_POSITION;
    float3 normal       : NORMAL;
    float2 uv           : TEXCOORD0;
    float4 posInProj    : TEXCOORD1;
};

///////////////////////////////////////////
// 定数バッファー
///////////////////////////////////////////
// モデル用の定数バッファー
cbuffer ModelCb : register(b0)
{
    float4x4 mWorld;
    float4x4 mView;
    float4x4 mProj;
};

///////////////////////////////////////////
// シェーダーリソース
///////////////////////////////////////////
// モデルテクスチャ
Texture2D<float4> g_texture : register(t0);

// 深度テクスチャにアクセスするための変数を追加
Texture2D<float4> g_depthTexture : register(t10);

///////////////////////////////////////////
// サンプラーステート
///////////////////////////////////////////
sampler g_sampler : register(s0);

///////////////////////////////////////////
// 関数
///////////////////////////////////////////

/// <summary>
/// 輪郭線を描画する必要があるかどうか判定。
/// </summary>
int IsDrawEdge(SPSIn psIn)
{
    // 近傍8テクセルの深度値を計算して、エッジを抽出する
    // 正規化スクリーン座標系からUV座標系に変換する
    psIn.posInProj.xy /= psIn.posInProj.w;
    float2 uv = psIn.posInProj.xy * float2( 0.5f, -0.5f) + 0.5f;

    // 近傍8テクセルへのUVオフセット
    float2 uvOffset[8] = {
        float2(           0.0f,  1.0f / 720.0f), //上
        float2(           0.0f, -1.0f / 720.0f), //下
        float2( 1.0f / 1280.0f,           0.0f), //右
        float2(-1.0f / 1280.0f,           0.0f), //左
        float2( 1.0f / 1280.0f,  1.0f / 720.0f), //右上
        float2(-1.0f / 1280.0f,  1.0f / 720.0f), //左上
        float2( 1.0f / 1280.0f, -1.0f / 720.0f), //右下
        float2(-1.0f / 1280.0f, -1.0f / 720.0f)  //左下
    };

    // このピクセルの深度値を取得
    float depth = g_depthTexture.Sample(g_sampler, uv).x;

    // 近傍8テクセルの深度値の平均値を計算する
    float depth2 = 0.0f;
    for( int i = 0; i < 8; i++)
    {
        depth2 += g_depthTexture.Sample(g_sampler, uv + uvOffset[i]).x;
    }
    depth2 /= 8.0f;

    // 自身の深度値と近傍8テクセルの深度値の差を調べる
    if(abs(depth - depth2) > 0.00005f)
    {
        return 1;
    }
    return 0;
}

/// <summary>
/// モデル用の頂点シェーダーのエントリーポイント
/// </summary>
SPSIn VSMain(SVSIn vsIn, uniform bool hasSkin)
{
    SPSIn psIn;

    psIn.pos = mul(mWorld, vsIn.pos);   // モデルの頂点をワールド座標系に変換
    psIn.pos = mul(mView, psIn.pos);    // ワールド座標系からカメラ座標系に変換
    psIn.pos = mul(mProj, psIn.pos);    // カメラ座標系からスクリーン座標系に変換
    psIn.uv = vsIn.uv;
    psIn.normal = mul( mWorld, vsIn.normal );

    //頂点の正規化スクリーン座標系の座標をピクセルシェーダーに渡す
    psIn.posInProj = psIn.pos;

    return psIn;
}

/// <summary>
/// モデル用のピクセルシェーダーのエントリーポイント
/// </summary>
float4 PSMain(SPSIn psIn) : SV_Target0
{
    // 輪郭線を描く必要があるか判定する。
    if( IsDrawEdge( psIn ) )
    {
        // 輪郭線を描画する必要があるので、輪郭線のカラーを出力する。
        return float4( 0.0f, 0.0f, 0.0f, 1.0f);
    }

    // テクスチャカラーをサンプリング
    float4 finalColor = g_texture.Sample(g_sampler, psIn.uv);
    
    // step-1 斜め下方向のライトと法線の内積の結果を利用して光の強さを切り替える。
    // ライトの方向を定義する。
    float3 ligDir = normalize( float3( 1.0f, -1.0f, -1.0f) );
    // 法線とライトの方向とで内積を計算する。
    float t = dot( psIn.normal, -ligDir ) ;
    // 内積の結果が0.1以下なら、最終カラーの色味を若干落とす。
    if( t < 0.1f){
        finalColor.xyz *= 0.8f;
    }
    
    return finalColor;
}
