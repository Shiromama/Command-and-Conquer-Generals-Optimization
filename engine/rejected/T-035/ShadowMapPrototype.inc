// T-035 experimental real shadow-map path. Default off; stencil fallback on capability failure.
#include "WW3D2/matpass.h"
#include "WW3D2/dx8renderer.h"
#include <string>
#include "WW3D2/rinfo.h"
#include "WW3D2/vertmaterial.h"
#include "WW3D2/texture.h"
#include "d3dx8.h"
#include "Common/OptimizationPolicy.h"
#include <vector>
#include <unordered_map>
#include <cstdio>
#include <cmath>
namespace zhsm {
static IDirect3DTexture8 *texture=nullptr;
static IDirect3DSurface8 *surface=nullptr, *depth=nullptr;
static DWORD writeShader=0, compareShader=0, deltaShader=0,batchVertexShader=0;
static void clearGeometryCache();
static bool failed=false, dumped=false,depthIsIntz=false;
static DWORD floatBits(float value){DWORD bits;memcpy(&bits,&value,sizeof(bits));return bits;}
static unsigned resolution=1024, renderedFrames=0,depthMeshes=0,receiverMeshes=0;
static FILE *diagnostics=nullptr;
static LARGE_INTEGER frequency;
static void report(const char *event, HRESULT hr) {
    if(!diagnostics) {
        const char *path=getenv("ZH_SHADOWMAP_LOG");
        if(path&&*path) { diagnostics=fopen(path,"w"); if(diagnostics) fprintf(diagnostics,"event,hresult,casters,tiles,usec,gather_usec,depth_usec,terrain_usec,receiver_usec,batches,triangles\n"); }
    }
    if(diagnostics) { fprintf(diagnostics,"%s,%08lx,0,0,0,0,0,0,0,0,0\n",event,static_cast<unsigned long>(hr)); fflush(diagnostics); }
}
template<class T> static void release(T *&p) { if(p) { p->Release(); p=nullptr; } }
static void freeResources() {
    IDirect3DDevice8 *device=DX8Wrapper::_Get_D3D_Device8();
    if(device) { if(writeShader) device->DeletePixelShader(writeShader); if(compareShader) device->DeletePixelShader(compareShader); if(deltaShader) device->DeletePixelShader(deltaShader); }
    if(device&&batchVertexShader)device->DeleteVertexShader(batchVertexShader);
    batchVertexShader=0;clearGeometryCache();
    writeShader=compareShader=deltaShader=0;
    release(surface); release(depth); release(texture);
    failed=false; dumped=false; depthIsIntz=false; renderedFrames=0;
}
static HRESULT assemble(IDirect3DDevice8 *device,const char *source,DWORD &shader,bool vertex=false,const DWORD *customDeclaration=nullptr) {
    ID3DXBuffer *code=nullptr,*errors=nullptr;
    HRESULT hr=D3DXAssembleShader(source,static_cast<UINT>(strlen(source)),0,nullptr,&code,&errors);
    if(FAILED(hr) && errors) {
        const char *p=getenv("ZH_SHADOWMAP_LOG");
        if(p) { std::string name=std::string(p)+".shader-errors.txt"; FILE *f=fopen(name.c_str(),"a");
            if(f) { fwrite(errors->GetBufferPointer(),1,errors->GetBufferSize(),f); fclose(f); } }
    }
    if(SUCCEEDED(hr)) {
        if(vertex){const DWORD declaration[]={D3DVSD_STREAM(0),D3DVSD_REG(0,D3DVSDT_FLOAT3),D3DVSD_END()};
            hr=device->CreateVertexShader(customDeclaration?customDeclaration:declaration,static_cast<DWORD*>(code->GetBufferPointer()),&shader,0);
        }else hr=device->CreatePixelShader(static_cast<DWORD*>(code->GetBufferPointer()),&shader);
    }
    release(code); release(errors); return hr;
}
static bool acquire(IDirect3DDevice8 *device) {
    if(texture) return true;
    if(failed) return false;
    D3DCAPS8 caps{};
    HRESULT hr=device->GetDeviceCaps(&caps);
    if(FAILED(hr) || caps.PixelShaderVersion<D3DPS_VERSION(1,4)) { report("pixel_shader_1_4_unavailable",hr); failed=true; return false; }
    const char *size=getenv("ZH_SHADOWMAP_SIZE");
    resolution=size?static_cast<unsigned>(atoi(size)):1024;
    if(resolution<256 || resolution>4096 || (resolution&(resolution-1))) resolution=1024;
    depthIsIntz=zh::parseBoolean(getenv("ZH_SHADOWMAP_INTZ"),false);
    if(depthIsIntz){
        const DWORD format='I'|('N'<<8)|('T'<<16)|('Z'<<24);
        hr=device->CreateTexture(resolution,resolution,1,D3DUSAGE_DEPTHSTENCIL,static_cast<D3DFORMAT>(format),D3DPOOL_DEFAULT,&texture);
        if(SUCCEEDED(hr))hr=texture->GetSurfaceLevel(0,&depth);
        if(SUCCEEDED(hr))hr=device->CreateRenderTarget(resolution,resolution,D3DFMT_A8R8G8B8,D3DMULTISAMPLE_NONE,FALSE,&surface);
        if(SUCCEEDED(hr)){
            // D3D9 states forwarded by the pinned wrapper. Probe and restore before any draw.
            DWORD oldSlope=0,oldBias=0;
            hr=device->GetRenderState(static_cast<D3DRENDERSTATETYPE>(175),&oldSlope);
            if(SUCCEEDED(hr))hr=device->GetRenderState(static_cast<D3DRENDERSTATETYPE>(195),&oldBias);
            if(SUCCEEDED(hr)){
                hr=device->SetRenderState(static_cast<D3DRENDERSTATETYPE>(175),floatBits(1));
                if(SUCCEEDED(hr))hr=device->SetRenderState(static_cast<D3DRENDERSTATETYPE>(195),floatBits(0.00001f));
                device->SetRenderState(static_cast<D3DRENDERSTATETYPE>(175),oldSlope);
                device->SetRenderState(static_cast<D3DRENDERSTATETYPE>(195),oldBias);
            }
        }
        if(FAILED(hr)){report("intz_shadow_unavailable",hr);freeResources();failed=true;return false;}
    }else{
        // D3DFMT_R32F (114) is a D3D9-era format: probe, never assume native D3D8 support.
        hr=device->CreateTexture(resolution,resolution,1,D3DUSAGE_RENDERTARGET,static_cast<D3DFORMAT>(114),D3DPOOL_DEFAULT,&texture);
        if(FAILED(hr)){report("r32f_target_unavailable",hr);failed=true;return false;}
        hr=texture->GetSurfaceLevel(0,&surface);
        if(SUCCEEDED(hr))hr=device->CreateDepthStencilSurface(resolution,resolution,D3DFMT_D16,D3DMULTISAMPLE_NONE,&depth);
    }
    if(SUCCEEDED(hr)) hr=assemble(device,"ps.1.4\ntexcrd r0.rgb, t0\nmov r0, r0.zzzz\n",writeShader);
    if(SUCCEEDED(hr)) hr=assemble(device,"ps.1.4\ntexld r0, t0\ntexcrd r1.rgb, t1\nsub r0.r, r0.r, r1.z\nadd r0.r, r0.r, c0.x\ncmp r0.rgb, r0.r, c1, c2\nmov r0.a, c1.a\n",compareShader);
    if(SUCCEEDED(hr)) hr=assemble(device,"ps.1.4\ntexld r0, t0\ntexcrd r1.rgb, t1\nsub r0.r, r0.r, r1.z\nmul_x4 r0.rgb, r0.r, c3.x\nmul_x4 r0.rgb, r0, c3.x\nmad_x4 r0.rgb, r0, c3.x, c3.y\nmov r0.a, c1.a\n",deltaShader);
    if(SUCCEEDED(hr)) hr=assemble(device,"vs.1.1\nm4x4 oPos, v0, c0\nm4x4 r0, v0, c4\nmov oT0, r0\nmov oT1, r0\n",batchVertexShader,true);
    if(FAILED(hr)) { report("resource_or_shader_failure",hr); freeResources(); failed=true; return false; }
    QueryPerformanceFrequency(&frequency); report(depthIsIntz?"ready_intz":"ready",S_OK); return true;
}
class Pass : public MaterialPassClass {
public:
    bool writing;
    bool explicitCoordinates;
    D3DXMATRIX coordinates;
    mutable bool matrixInstalled=false;
    Pass(bool write,const D3DXMATRIX &matrix,bool explicitUV=false):writing(write),explicitCoordinates(explicitUV),coordinates(matrix) {
        VertexMaterialClass *material=VertexMaterialClass::Get_Preset(VertexMaterialClass::PRELIT_DIFFUSE);
        Set_Material(material); material->Release_Ref();
        ShaderClass shader=ShaderClass::_PresetOpaqueShader;
        shader.Set_Depth_Mask(write?ShaderClass::DEPTH_WRITE_ENABLE:ShaderClass::DEPTH_WRITE_DISABLE);
        if(!write) {
            shader.Set_Src_Blend_Func(ShaderClass::SRCBLEND_ZERO);
            shader.Set_Dst_Blend_Func(ShaderClass::DSTBLEND_SRC_COLOR);
        }
        shader.Set_Fog_Func(ShaderClass::FOG_DISABLE); Set_Shader(shader);
        Enable_On_Translucent_Meshes(true); // Vehicle materials can be marked translucent by the engine.
    }
    void Install_Materials() const override {
        if(writing) ++depthMeshes; else ++receiverMeshes;
        MaterialPassClass::Install_Materials();
        DX8Wrapper::Apply_Render_State_Changes();
        IDirect3DDevice8 *d=DX8Wrapper::_Get_D3D_Device8();
        DX8Wrapper::Set_Pixel_Shader(writing?writeShader:(getenv("ZH_SHADOWMAP_DELTA")?deltaShader:compareShader));
        for(unsigned i=0;i<2;++i) {
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXCOORDINDEX,explicitCoordinates?i:D3DTSS_TCI_CAMERASPACEPOSITION);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXTURETRANSFORMFLAGS,explicitCoordinates?D3DTTFF_DISABLE:D3DTTFF_COUNT3);
            if(!matrixInstalled && !explicitCoordinates) d->SetTransform(static_cast<D3DTRANSFORMSTATETYPE>(D3DTS_TEXTURE0+i),&coordinates);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_ADDRESSU,D3DTADDRESS_BORDER);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_ADDRESSV,D3DTADDRESS_BORDER);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_BORDERCOLOR,0xffffffff);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MINFILTER,D3DTEXF_POINT);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MAGFILTER,D3DTEXF_POINT);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MIPFILTER,D3DTEXF_NONE);
        }
        d->SetTexture(0,writing?nullptr:texture);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_COLORWRITEENABLE,writing&&depthIsIntz?0:0xf);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZENABLE,TRUE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZFUNC,D3DCMP_LESSEQUAL);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZWRITEENABLE,writing?TRUE:FALSE);
        const char *rasterBiasValue=getenv("ZH_SHADOWMAP_RECEIVER_BIAS");
        const unsigned rasterBias=rasterBiasValue?static_cast<unsigned>(atoi(rasterBiasValue)):1;
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZBIAS,writing?0:__min(rasterBias,16u));
        if(depthIsIntz){
            const char *slopeValue=getenv("ZH_SHADOWMAP_SLOPE");float slope=slopeValue?static_cast<float>(atof(slopeValue)):1;
            if(!(slope>=0&&slope<=4))slope=1;
            d->SetRenderState(static_cast<D3DRENDERSTATETYPE>(175),floatBits(writing?slope:0));
            if(writing)d->SetRenderState(static_cast<D3DRENDERSTATETYPE>(195),floatBits(0.00001f));
        }
        DX8Wrapper::Set_DX8_Render_State(D3DRS_FOGENABLE,FALSE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ALPHATESTENABLE,FALSE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_STENCILENABLE,FALSE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ALPHABLENDENABLE,(writing || getenv("ZH_SHADOWMAP_DELTA") || zh::parseBoolean(getenv("ZH_SHADOWMAP_MASK"),false))?FALSE:TRUE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_SRCBLEND,D3DBLEND_ZERO);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_DESTBLEND,D3DBLEND_SRCCOLOR);
        const float shade=zh::parseBoolean(getenv("ZH_SHADOWMAP_MASK"),false)?0.0f:0.65f;
        const char *biasValue=getenv("ZH_SHADOWMAP_BIAS");
        float bias=biasValue?static_cast<float>(atof(biasValue)):0.001f;
        if(!(bias>=0.0f&&bias<=0.02f))bias=0.001f;
        const float c[4][4]={{bias,0,0,0},{1,1,1,1},{shade,shade,shade,1},{1,0.125f,0,0}};
        // The outer device state block restores constants behind the wrapper cache.
        // Upload once per pass directly so the cache remains consistent with its pre-pass state.
        if(!matrixInstalled) d->SetPixelShaderConstant(0,c,4);
        matrixInstalled=true;
    }
    // The controlled additional-pass flush contains only this pass. Keep its state installed
    // across meshes; Finish explicitly restores it once at the end of that flush.
    void UnInstall_Materials() const override { }
    void Finish() const {
        IDirect3DDevice8 *d=DX8Wrapper::_Get_D3D_Device8();
        DX8Wrapper::Set_Pixel_Shader(0);
        for(unsigned i=0;i<2;++i) {
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXCOORDINDEX,i);
            DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXTURETRANSFORMFLAGS,D3DTTFF_DISABLE);
        }
        d->SetTexture(0,nullptr);
        matrixInstalled=false;
    }
};
struct SavedState {
    IDirect3DDevice8 *d;
    IDirect3DSurface8 *target=nullptr,*z=nullptr;
    DWORD block=0, pixelShader=0, vertexShader=0,legacyZBias=0,translatedBias=0,slopeBias=0;
    bool translatedBiasValid=false;
    D3DVIEWPORT8 viewport{};
    RenderStateStruct wrapper;
    CameraClass *meshCamera=nullptr;
    bool staticSorting=true;
    bool valid=false;
    SavedState(IDirect3DDevice8 *device):d(device) {
        meshCamera=TheDX8MeshRenderer.Peek_Camera();
        staticSorting=WW3D::Are_Static_Sort_Lists_Enabled();
        DX8Wrapper::Get_Render_State(wrapper);
        d->GetPixelShader(&pixelShader); d->GetVertexShader(&vertexShader);
        d->GetRenderState(D3DRS_ZBIAS,&legacyZBias);
        if(depthIsIntz)translatedBiasValid=SUCCEEDED(d->GetRenderState(static_cast<D3DRENDERSTATETYPE>(175),&slopeBias))&&
            SUCCEEDED(d->GetRenderState(static_cast<D3DRENDERSTATETYPE>(195),&translatedBias));
        const HRESULT depthResult=d->GetDepthStencilSurface(&z);
        // A color-only target legitimately has no depth surface while sampling INTZ.
        valid=SUCCEEDED(d->GetRenderTarget(&target)) && (SUCCEEDED(depthResult)||depthResult==D3DERR_NOTFOUND)
            && SUCCEEDED(d->GetViewport(&viewport)) && SUCCEEDED(d->CreateStateBlock(D3DSBT_ALL,&block));
    }
    void restoreTarget() { d->SetRenderTarget(target,z); d->SetViewport(&viewport); }
    ~SavedState() {
        TheDX8MeshRenderer.Set_Camera(meshCamera);
        WW3D::Enable_Static_Sort_Lists(staticSorting);
        if(valid) { restoreTarget(); d->ApplyStateBlock(block);
            d->SetRenderState(D3DRS_ZBIAS,legacyZBias);
            if(translatedBiasValid){d->SetRenderState(static_cast<D3DRENDERSTATETYPE>(175),slopeBias);
                d->SetRenderState(static_cast<D3DRENDERSTATETYPE>(195),translatedBias);}
        }
        if(block) d->DeleteStateBlock(block);
        release(target); release(z);
        DX8Wrapper::Invalidate_Cached_Render_States();
        DX8Wrapper::Set_Render_State(wrapper);
        DX8Wrapper::Set_Vertex_Shader(vertexShader);
        DX8Wrapper::Set_Pixel_Shader(pixelShader);
    }
};
// D3DX8 does not understand numerical R32F. Sample it into a native A8R8G8B8
// render target before raw BMP export, while preserving the current depth-pass state.
static HRESULT dumpDepthBitmap(IDirect3DDevice8 *d,const char *path) {
    SavedState saved(d); if(!saved.valid) return E_FAIL;
    IDirect3DTexture8 *preview=nullptr;
    IDirect3DSurface8 *previewSurface=nullptr,*readback=nullptr;
    DWORD shader=0;
    HRESULT hr=d->CreateTexture(resolution,resolution,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,&preview);
    if(FAILED(hr)) report("depth_preview_create",hr);
    if(SUCCEEDED(hr)) { hr=preview->GetSurfaceLevel(0,&previewSurface); if(FAILED(hr)) report("depth_preview_surface",hr); }
    if(SUCCEEDED(hr)) { hr=assemble(d,"ps.1.4\ntexld r0, t0\nmov r0, r0.rrrr\n",shader); if(FAILED(hr)) report("depth_preview_shader",hr); }
    if(SUCCEEDED(hr)) { hr=d->SetRenderTarget(previewSurface,nullptr); if(FAILED(hr)) report("depth_preview_target",hr); }
    if(SUCCEEDED(hr)) {
        D3DVIEWPORT8 viewport={0,0,resolution,resolution,0,1};
        d->SetViewport(&viewport);
        d->SetPixelShader(shader); d->SetVertexShader(D3DFVF_XYZRHW|D3DFVF_TEX1);
        d->SetRenderState(D3DRS_ZENABLE,FALSE); d->SetRenderState(D3DRS_ZWRITEENABLE,FALSE);
        d->SetRenderState(D3DRS_STENCILENABLE,FALSE); d->SetRenderState(D3DRS_ALPHABLENDENABLE,FALSE);
        d->SetRenderState(D3DRS_ALPHATESTENABLE,FALSE); d->SetRenderState(D3DRS_CULLMODE,D3DCULL_NONE);
        d->SetRenderState(D3DRS_FOGENABLE,FALSE); d->SetRenderState(D3DRS_COLORWRITEENABLE,0xf);
        for(unsigned stage=0;stage<8;++stage) {
            d->SetTextureStageState(stage,D3DTSS_TEXCOORDINDEX,stage);
            d->SetTextureStageState(stage,D3DTSS_TEXTURETRANSFORMFLAGS,D3DTTFF_DISABLE);
            d->SetTexture(stage,nullptr);
        }
        d->SetTextureStageState(0,D3DTSS_TEXCOORDINDEX,0);
        d->SetTextureStageState(0,D3DTSS_TEXTURETRANSFORMFLAGS,D3DTTFF_DISABLE);
        d->SetTextureStageState(0,D3DTSS_MINFILTER,D3DTEXF_POINT);
        d->SetTextureStageState(0,D3DTSS_MAGFILTER,D3DTEXF_POINT);
        d->SetTextureStageState(0,D3DTSS_MIPFILTER,D3DTEXF_NONE);
        d->SetTextureStageState(0,D3DTSS_ADDRESSU,D3DTADDRESS_CLAMP);
        d->SetTextureStageState(0,D3DTSS_ADDRESSV,D3DTADDRESS_CLAMP);
        d->SetTexture(0,texture);
        struct Vertex { float x,y,z,rhw,u,v; };
        const float edge=static_cast<float>(resolution)-0.5f;
        const Vertex vertices[]={{-0.5f,-0.5f,0.5f,1,0,0},{edge,-0.5f,0.5f,1,1,0},
                                 {-0.5f,edge,0.5f,1,0,1},{edge,edge,0.5f,1,1,1}};
        hr=d->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,2,vertices,sizeof(Vertex));
        d->SetTexture(0,nullptr); d->SetPixelShader(0);
        if(FAILED(hr)) report("depth_preview_draw",hr);
        if(SUCCEEDED(hr)) { hr=d->CreateImageSurface(resolution,resolution,D3DFMT_A8R8G8B8,&readback); if(FAILED(hr)) report("depth_preview_readback_create",hr); }
        if(SUCCEEDED(hr)) { hr=d->CopyRects(previewSurface,nullptr,0,readback,nullptr); if(FAILED(hr)) report("depth_preview_copy",hr); }
        if(SUCCEEDED(hr)) {
            D3DLOCKED_RECT locked{};
            hr=readback->LockRect(&locked,nullptr,D3DLOCK_READONLY);
            if(SUCCEEDED(hr)) {
                FILE *file=fopen(path,"wb");
                if(!file) hr=E_FAIL;
                else {
                    BITMAPFILEHEADER fileHeader{}; BITMAPINFOHEADER info{};
                    const DWORD rowBytes=resolution*4;
                    fileHeader.bfType=0x4d42; fileHeader.bfOffBits=sizeof(fileHeader)+sizeof(info);
                    fileHeader.bfSize=fileHeader.bfOffBits+rowBytes*resolution;
                    info.biSize=sizeof(info); info.biWidth=resolution; info.biHeight=-static_cast<LONG>(resolution);
                    info.biPlanes=1;info.biBitCount=32;info.biCompression=BI_RGB;info.biSizeImage=rowBytes*resolution;
                    bool ok=fwrite(&fileHeader,1,sizeof(fileHeader),file)==sizeof(fileHeader)
                        && fwrite(&info,1,sizeof(info),file)==sizeof(info);
                    unsigned minimum=255,maximum=0,nonwhite=0;
                    for(unsigned row=0;row<resolution;++row) {
                        const unsigned char *bytes=static_cast<unsigned char*>(locked.pBits)+row*locked.Pitch;
                        ok=ok&&fwrite(bytes,1,rowBytes,file)==rowBytes;
                        for(unsigned col=0;col<resolution;++col) {
                            const unsigned value=bytes[col*4+2];
                            minimum=__min(minimum,value);maximum=__max(maximum,value);nonwhite+=value<255;
                        }
                    }
                    fclose(file); if(!ok) hr=E_FAIL;
                    const std::string metadata=std::string(path)+".json";
                    FILE *meta=fopen(metadata.c_str(),"w");
                    if(meta) { fprintf(meta,"{\"pixels\":%u,\"minimum\":%u,\"maximum\":%u,\"nonwhite\":%u}\n",resolution*resolution,minimum,maximum,nonwhite);fclose(meta); }
                }
                readback->UnlockRect();
            }
            if(FAILED(hr)) report("depth_preview_bitmap",hr);
        }
    }
    if(shader) d->DeletePixelShader(shader);
    release(readback); release(previewSurface); release(preview);
    return hr;
}
static D3DXMATRIX installGeometryProjection(IDirect3DDevice8 *d,const D3DXMATRIX &worldToLight) {
    D3DXMATRIX view,projection,constants[2];
    d->GetTransform(D3DTS_VIEW,&view);d->GetTransform(D3DTS_PROJECTION,&projection);
    const D3DXMATRIX viewProjection=view*projection;
    D3DXMatrixTranspose(&constants[0],&viewProjection);D3DXMatrixTranspose(&constants[1],&worldToLight);
    d->SetVertexShaderConstant(0,constants,8);DX8Wrapper::Set_Vertex_Shader(batchVertexShader);
    return viewProjection;
}
static unsigned terrain(Pass &pass,const AABoxClass &box,const D3DXMATRIX &worldToLight) {
    struct Vertex { float x,y,z; };
    Region3D bounds; TheTerrainLogic->getExtent(&bounds);
    const float step=MAP_XY_FACTOR;
    const int loX=static_cast<int>(floor(__max(bounds.lo.x,box.Center.X-box.Extent.X)/step));
    const int loY=static_cast<int>(floor(__max(bounds.lo.y,box.Center.Y-box.Extent.Y)/step));
    const int hiX=static_cast<int>(ceil(__min(bounds.hi.x,box.Center.X+box.Extent.X)/step));
    const int hiY=static_cast<int>(ceil(__min(bounds.hi.y,box.Center.Y+box.Extent.Y)/step));
    unsigned tiles=0;
    IDirect3DDevice8 *d=DX8Wrapper::_Get_D3D_Device8();
    D3DXMATRIX identity; D3DXMatrixIdentity(&identity);
    for(int y=loY;y<hiY;y+=32) for(int x=loX;x<hiX;x+=32) {
        const int nx=__min(32,hiX-x),ny=__min(32,hiY-y);
        std::vector<Vertex> vertices; std::vector<unsigned short> indices;
        vertices.reserve((nx+1)*(ny+1)); indices.reserve(nx*ny*6);
        for(int j=0;j<=ny;++j) for(int i=0;i<=nx;++i) {
            const float wx=(x+i)*step,wy=(y+j)*step;
            vertices.push_back({wx,wy,TheTerrainLogic->getGroundHeight(wx,wy)+0.03f});
        }
        for(int j=0;j<ny;++j) for(int i=0;i<nx;++i) {
            const unsigned short a=static_cast<unsigned short>(j*(nx+1)+i),b=a+1,c=a+nx+1,e=c+1;
            indices.insert(indices.end(),{a,b,c,b,e,c});
        }
        pass.Install_Materials();
        d->SetTransform(D3DTS_WORLD,&identity);installGeometryProjection(d,worldToLight);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_CULLMODE,D3DCULL_NONE);
        const HRESULT hr=d->DrawIndexedPrimitiveUP(D3DPT_TRIANGLELIST,0,static_cast<UINT>(vertices.size()),
            static_cast<UINT>(indices.size()/3),indices.data(),D3DFMT_INDEX16,vertices.data(),sizeof(Vertex));
        pass.UnInstall_Materials();
        if(FAILED(hr)) { report("terrain_draw_failed",hr); return 0; }
        ++tiles;
    }
    return tiles;
}
// Explicit world/light coordinates avoid FFP texgen dependencies and allow bounded draws.
struct BatchVertex { float x,y,z; };
struct ModelSnapshot {
    std::vector<Vector3> vertices;std::vector<TriIndex> triangles;
    unsigned frame=0;unsigned long long revision=0;
};
static std::unordered_map<MeshModelClass*,ModelSnapshot> modelSnapshots;
static unsigned geometryFrame=0;
static unsigned long long modelRevision(MeshModelClass *model,const Vector3 *vertices,unsigned count,const TriIndex *triangles,unsigned polygons){
    ModelSnapshot &snapshot=modelSnapshots[model];
    if(snapshot.frame!=geometryFrame){
        snapshot.frame=geometryFrame;
        if(snapshot.vertices.size()!=count || snapshot.triangles.size()!=polygons ||
            memcmp(snapshot.vertices.data(),vertices,count*sizeof(Vector3)) || memcmp(snapshot.triangles.data(),triangles,polygons*sizeof(TriIndex))){
            snapshot.vertices.assign(vertices,vertices+count);snapshot.triangles.assign(triangles,triangles+polygons);++snapshot.revision;
        }
    }
    return snapshot.revision;
}
struct MeshRegion {
    MeshClass *mesh=nullptr; MeshModelClass *model=nullptr;
    const Vector3 *source=nullptr;const TriIndex *triangles=nullptr;
    Matrix3D transform;
    unsigned count=0,polygons=0,base=0,indexBase=0;unsigned long long revision=0;
};
struct GeometryBatch {
    std::vector<BatchVertex> vertices;std::vector<unsigned short> indices;
    std::vector<MeshRegion> regions;
    unsigned vertexCursor=0,indexCursor=0,regionCursor=0;
};
static std::vector<GeometryBatch> batches;
static unsigned usedBatches=0,batchMeshes=0,batchTriangles=0,cacheHits=0;
static void clearGeometryCache(){batches.clear();modelSnapshots.clear();usedBatches=0;}
static void beginGeometryBatches(){usedBatches=batchMeshes=batchTriangles=cacheHits=0;
    if(++geometryFrame==0){clearGeometryCache();geometryFrame=1;}
}
static void finishGeometryBatches(){for(unsigned i=0;i<usedBatches;++i){GeometryBatch &batch=batches[i];
    batch.vertices.resize(batch.vertexCursor);batch.indices.resize(batch.indexCursor);batch.regions.resize(batch.regionCursor);
}}
static bool appendGeometry(RenderObjClass *object,const D3DXMATRIX &worldToLight,unsigned level=0) {
    if(!object || !object->Is_Not_Hidden_At_All()) return true;
    if(level>16)return false;
    if(object->Class_ID()==RenderObjClass::CLASSID_MESH) {
        MeshClass *mesh=static_cast<MeshClass*>(object); MeshModelClass *model=mesh->Peek_Model();
        // Match the existing volume-caster material exclusions. Never silhouette opaque FX cards.
        if((mesh->Is_Alpha() || mesh->Is_Translucent()) && !model->Get_Flag(MeshGeometryClass::CAST_SHADOW)) return true;
        if(model->Get_Flag(MeshGeometryClass::SKIN)) return true; // Existing skin/decal path remains separate.
        const unsigned count=model->Get_Vertex_Count(),polygons=model->Get_Polygon_Count();
        if(!count || !polygons) return true;
        if(count>60000) return false;
        if(!usedBatches || batches[usedBatches-1].vertexCursor+count>60000) {
            if(batches.size()<=usedBatches) batches.emplace_back();
            ++usedBatches; GeometryBatch &fresh=batches[usedBatches-1];fresh.vertexCursor=fresh.indexCursor=fresh.regionCursor=0;
        }
        GeometryBatch &batch=batches[usedBatches-1];const unsigned base=batch.vertexCursor,indexBase=batch.indexCursor;
        const Vector3 *vertices=model->Get_Vertex_Array();const TriIndex *triangles=model->Get_Polygon_Array();
        const Matrix3D &transform=mesh->Get_Transform();
        const unsigned long long revision=modelRevision(model,vertices,count,triangles,polygons);
        if(batch.regions.size()<=batch.regionCursor)batch.regions.emplace_back();
        MeshRegion &region=batch.regions[batch.regionCursor++];
        const bool same=region.mesh==mesh && region.model==model && region.source==vertices && region.triangles==triangles &&
            region.count==count && region.polygons==polygons && region.base==base && region.indexBase==indexBase && region.revision==revision;
        if(batch.vertices.size()<base+count)batch.vertices.resize(base+count);
        if(!same || memcmp(&region.transform,&transform,sizeof(transform))!=0){
            for(unsigned i=0;i<count;++i){Vector3 world;Matrix3D::Transform_Vector(transform,vertices[i],&world);
                batch.vertices[base+i]={world.X,world.Y,world.Z};}
        }else ++cacheHits;
        if(batch.indices.size()<indexBase+polygons*3)batch.indices.resize(indexBase+polygons*3);
        if(!same)for(unsigned i=0;i<polygons;++i){
            if(triangles[i].I>=count || triangles[i].J>=count || triangles[i].K>=count)return false;
            batch.indices[indexBase+i*3]=static_cast<unsigned short>(base+triangles[i].I);
            batch.indices[indexBase+i*3+1]=static_cast<unsigned short>(base+triangles[i].J);
            batch.indices[indexBase+i*3+2]=static_cast<unsigned short>(base+triangles[i].K);
        }
        region.mesh=mesh;region.model=model;region.source=vertices;region.triangles=triangles;region.transform=transform;
        region.count=count;region.polygons=polygons;region.base=base;region.indexBase=indexBase;region.revision=revision;
        batch.vertexCursor+=count;batch.indexCursor+=polygons*3;
        ++batchMeshes;batchTriangles+=polygons;return true;
    }
    if(object->Class_ID()==RenderObjClass::CLASSID_HLOD) {
        HLodClass *hlod=static_cast<HLodClass*>(object); const int lod=hlod->Get_LOD_Level();
        for(int i=0;i<hlod->Get_Lod_Model_Count(lod);++i)
            if(!appendGeometry(hlod->Peek_Lod_Model(lod,i),worldToLight,level+1))return false;
        // Generic sub-object enumeration contains every LOD; include only additional attachments.
        int allLodModels=0;for(int i=0;i<hlod->Get_LOD_Count();++i)allLodModels+=hlod->Get_Lod_Model_Count(i);
        for(int i=allLodModels;i<object->Get_Num_Sub_Objects();++i){
            RenderObjClass *child=object->Get_Sub_Object(i);const bool ok=appendGeometry(child,worldToLight,level+1);
            if(child)child->Release_Ref();if(!ok)return false;
        }
        return true;
    }
    for(int i=0;i<object->Get_Num_Sub_Objects();++i) {
        RenderObjClass *child=object->Get_Sub_Object(i); const bool ok=appendGeometry(child,worldToLight,level+1);
        if(child)child->Release_Ref(); if(!ok)return false;
    }
    return true;
}
static bool drawGeometry(Pass &pass,const D3DXMATRIX &worldToLight,bool calibrationDepth=false) {
    IDirect3DDevice8 *d=DX8Wrapper::_Get_D3D_Device8();D3DXMATRIX identity;D3DXMatrixIdentity(&identity);
    pass.Install_Materials();d->SetTransform(D3DTS_WORLD,&identity);
    if(calibrationDepth){
        // Isolated calibration starts with an empty depth buffer, not a coplanar overlay.
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZWRITEENABLE,TRUE);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ZBIAS,0);
        DX8Wrapper::Set_DX8_Render_State(D3DRS_ALPHABLENDENABLE,FALSE);
        const float black[4]={0,0,0,1};d->SetPixelShaderConstant(2,black,1);
    }
    const D3DXMATRIX viewProjection=installGeometryProjection(d,worldToLight);
    if(calibrationDepth){const char *path=getenv("ZH_SHADOWMAP_DUMP");if(path){
        const std::string name=std::string(path)+".gpu.json";FILE *f=fopen(name.c_str(),"w");
        if(f){float pixel[16];d->GetPixelShaderConstant(0,pixel,4);
            fprintf(f,"{\"pixel_constants\":[");for(unsigned i=0;i<16;++i)fprintf(f,"%s%.9g",i?",":"",pixel[i]);
            fprintf(f,"],\"view_projection\":[");for(unsigned i=0;i<16;++i)fprintf(f,"%s%.9g",i?",":"",reinterpret_cast<const float*>(&viewProjection)[i]);
            fprintf(f,"]}\n");fclose(f);}
    }}
    DX8Wrapper::Set_DX8_Render_State(D3DRS_CULLMODE,D3DCULL_NONE);
    bool ok=true;
    for(unsigned i=0;i<usedBatches;++i){const GeometryBatch &batch=batches[i];
        const HRESULT hr=d->DrawIndexedPrimitiveUP(D3DPT_TRIANGLELIST,0,static_cast<UINT>(batch.vertices.size()),
            static_cast<UINT>(batch.indices.size()/3),batch.indices.data(),D3DFMT_INDEX16,batch.vertices.data(),sizeof(BatchVertex));
        if(FAILED(hr)){report("batch_draw_failed",hr);ok=false;break;}
    }
    pass.Finish();return ok;
}
static HRESULT createScreenShaders(IDirect3DDevice8 *d,DWORD &vertex,DWORD &pixel,unsigned debug=0){
    std::string source="ps.1.4\ntexld r0, t0\ntexcrd r1.rgb, t1\nmov r5.r, r0.r\nmad r2.rgb, r0.r, c4, r1\nmov r4.g, r2.b\nmad r2.b, r0.r, c6.r, c6.g\nmov r4.r, r2.b\nphase\ntexld r3, r2_dz\nmul r4.b, r3.r, r4.r\nmad r4.b, c0.x, r4.r, r4.b\nsub r4.b, r4.b, r4.g\ncmp r0.rgb, r4.b, c1, c2\nsub r5.r, c1.r, r5.r\ncmp r0.rgb, -r5.r, c1, r0\nmov r0.a, c1.a\n";
    if(debug){const char *operations[]={"","mov r0.rgb, c2\n",
        "sub r0.rgb, c1.r, r5.r\nmul_x4 r0.rgb, r0, c7.x\nmul_x4 r0.rgb, r0, c7.x\nmul_x4 r0.rgb, r0, c7.x\n",
        "mov r0.rgb, r3.r\n","mul_x4 r0.rgb, r4.r, c7.x\nmul_x4 r0.rgb, r0, c7.x\nmul_x4 r0.rgb, r0, c7.x\n"};
        source.resize(source.find("mul r4.b"));source+=operations[debug];source+="mov r0.a, c1.a\n";}
    HRESULT hr=assemble(d,source.c_str(),pixel);
    if(SUCCEEDED(hr)&&!debug){const char *path=getenv("ZH_SHADOWMAP_DUMP");if(path){
        DWORD size=0;d->GetPixelShaderFunction(pixel,nullptr,&size);std::vector<DWORD> code((size+3)/4);
        if(size&&SUCCEEDED(d->GetPixelShaderFunction(pixel,code.data(),&size))){ID3DXBuffer *assembly=nullptr;
            const std::string binary=std::string(path)+".screen-ps.bin";FILE *raw=fopen(binary.c_str(),"wb");
            if(raw){fwrite(code.data(),1,size,raw);fclose(raw);}
            typedef HRESULT (WINAPI *DisassembleFunction)(const DWORD*,BOOL,LPCSTR,ID3DXBuffer**);
            DisassembleFunction disassemble=nullptr;
            const char *modules[]={"d3dx9_43.dll","d3dx9_42.dll","d3dx9_41.dll"};
            for(const char *name:modules)if(HMODULE module=GetModuleHandleA(name)){
                disassemble=reinterpret_cast<DisassembleFunction>(GetProcAddress(module,"D3DXDisassembleShader"));if(disassemble)break;
            }
            if(disassemble&&SUCCEEDED(disassemble(code.data(),FALSE,nullptr,&assembly))){
                const std::string name=std::string(path)+".screen-ps.asm";FILE *file=fopen(name.c_str(),"w");
                if(file){fwrite(assembly->GetBufferPointer(),1,assembly->GetBufferSize(),file);fclose(file);}release(assembly);}
        }
    }}
    const DWORD declaration[]={D3DVSD_STREAM(0),D3DVSD_REG(0,D3DVSDT_FLOAT4),D3DVSD_REG(1,D3DVSDT_FLOAT2),D3DVSD_END()};
    if(SUCCEEDED(hr))hr=assemble(d,"vs.1.1\nmov oPos, v0\nmov oT0.xy, v1\nm4x4 r0, v0, c0\nmov oT1, r0\n",vertex,true,declaration);
    if(FAILED(hr)){if(vertex)d->DeleteVertexShader(vertex);if(pixel)d->DeletePixelShader(pixel);vertex=pixel=0;}
    return hr;
}
static bool drawScreenShadow(IDirect3DDevice8 *d,DWORD vertex,DWORD pixel,IDirect3DTexture8 *mainDepth,
    const D3DXMATRIX &mainViewProjection,const D3DXMATRIX &worldToLight,unsigned width,unsigned height,bool mask){
    D3DXMATRIX inverse,projection,constants;
    if(!D3DXMatrixInverse(&inverse,nullptr,&mainViewProjection)){report("screen_inverse_failed",E_FAIL);return false;}
    projection=inverse*worldToLight;
    // PS1.x constants clamp to [-1,+1]. Homogeneous scaling preserves UV/Z division
    // and comparison signs while keeping both vertex bases and pixel coefficients legal.
    float maximum=0;for(unsigned i=0;i<16;++i)maximum=__max(maximum,std::fabs(reinterpret_cast<float*>(&projection)[i]));
    const float normalization=maximum>0.5f?0.5f/maximum:1;
    for(unsigned i=0;i<16;++i)reinterpret_cast<float*>(&projection)[i]*=normalization;
    D3DXMatrixTranspose(&constants,&projection);
    DX8Wrapper::Apply_Render_State_Changes();
    d->SetVertexShaderConstant(0,&constants,4);
    const char *value=getenv("ZH_SHADOWMAP_BIAS");float bias=value?static_cast<float>(atof(value)):0.001f;
    if(!(bias>=0&&bias<=0.02f))bias=0.001f;
    const float c[8][4]={{bias,0,0,0},{1,1,1,1},{mask?0.0f:0.65f,mask?0.0f:0.65f,mask?0.0f:0.65f,1},{0,0,0,0},
        {projection._31,projection._32,projection._33,0},{0,0,0,0},{projection._34,projection._44,0,0},{1,0.5f,0,0}};
    d->SetPixelShaderConstant(0,c,8);
    if(const char *path=getenv("ZH_SHADOWMAP_DUMP")){const std::string name=std::string(path)+".screen-projection.json";
        FILE *file=fopen(name.c_str(),"w");if(file){fprintf(file,"{\"normalization\":%.9g,\"pixel_constants\":[",normalization);
            for(unsigned i=0;i<32;++i)fprintf(file,"%s%.9g",i?",":"",reinterpret_cast<const float*>(c)[i]);fprintf(file,"]}\n");fclose(file);}}

    DX8Wrapper::Set_Vertex_Shader(vertex);DX8Wrapper::Set_Pixel_Shader(pixel);
    for(unsigned i=0;i<4;++i){
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXCOORDINDEX,i);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_TEXTURETRANSFORMFLAGS,D3DTTFF_DISABLE);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MINFILTER,D3DTEXF_POINT);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MAGFILTER,D3DTEXF_POINT);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_MIPFILTER,D3DTEXF_NONE);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_ADDRESSU,D3DTADDRESS_BORDER);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_ADDRESSV,D3DTADDRESS_BORDER);
        DX8Wrapper::Set_DX8_Texture_Stage_State(i,D3DTSS_BORDERCOLOR,0xffffffff);
    }
    d->SetTexture(0,mainDepth);d->SetTexture(3,texture);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_ZENABLE,FALSE);DX8Wrapper::Set_DX8_Render_State(D3DRS_ZWRITEENABLE,FALSE);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_STENCILENABLE,FALSE);DX8Wrapper::Set_DX8_Render_State(D3DRS_ALPHATESTENABLE,FALSE);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_FOGENABLE,FALSE);DX8Wrapper::Set_DX8_Render_State(D3DRS_CULLMODE,D3DCULL_NONE);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_COLORWRITEENABLE,0xf);DX8Wrapper::Set_DX8_Render_State(D3DRS_CLIPPLANEENABLE,0);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_ALPHABLENDENABLE,mask?FALSE:TRUE);
    DX8Wrapper::Set_DX8_Render_State(D3DRS_SRCBLEND,D3DBLEND_ZERO);DX8Wrapper::Set_DX8_Render_State(D3DRS_DESTBLEND,D3DBLEND_SRCCOLOR);
    struct ScreenVertex{float x,y,z,w,u,v;};const float dx=1.0f/width,dy=1.0f/height;
    const ScreenVertex quad[]={{-1-dx,1+dy,0,1,0,0},{1-dx,1+dy,0,1,1,0},{-1-dx,-1+dy,0,1,0,1},{1-dx,-1+dy,0,1,1,1}};
    const HRESULT hr=d->DrawPrimitiveUP(D3DPT_TRIANGLESTRIP,2,quad,sizeof(ScreenVertex));
    d->SetTexture(0,nullptr);d->SetTexture(3,nullptr);DX8Wrapper::Set_Pixel_Shader(0);DX8Wrapper::Set_Vertex_Shader(D3DFVF_XYZ);
    if(FAILED(hr))report("screen_draw_failed",hr);return SUCCEEDED(hr);
}
// Isolated GPU fixture: a 40x40x40 box on a 200x200 plane, viewed from above.
// It exercises exactly the production write/compare shaders and GPU projection.
static void calibrationGeometry(bool plane) {
    beginGeometryBatches();if(batches.empty())batches.emplace_back();usedBatches=1;
    GeometryBatch &b=batches[0];b.vertices={
        {-20,-20,0},{20,-20,0},{20,20,0},{-20,20,0},
        {-20,-20,40},{20,-20,40},{20,20,40},{-20,20,40}};
    b.indices={0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,
        1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7};
    if(plane){b.vertices.insert(b.vertices.end(),{{-100,-100,0},{100,-100,0},{100,100,0},{-100,100,0}});
        b.indices.insert(b.indices.end(),{8,9,10,8,10,11});}
}
static bool calibrate(IDirect3DDevice8 *d) {
    if(dumped)return true;
    const char *path=getenv("ZH_SHADOWMAP_DUMP");
    if(!path||!*path){report("calibration_dump_required",E_FAIL);return false;}
    SavedState saved(d);if(!saved.valid)return false;
    DX8Wrapper::Apply_Render_State_Changes();
    const int variant=getenv("ZH_SHADOWMAP_CALIBRATION_LIGHT")?atoi(getenv("ZH_SHADOWMAP_CALIBRATION_LIGHT")):1;
    D3DXVECTOR3 direction(1,0,1);if(variant==2)direction=D3DXVECTOR3(1,1,2);else if(variant==3)direction=D3DXVECTOR3(0,0,1);
    else if(variant==4){const Vector3 current=TheW3DShadowManager->getLightPosWorld(0);direction=D3DXVECTOR3(current.X,current.Y,current.Z);}
    D3DXVec3Normalize(&direction,&direction);
    const D3DXVECTOR3 eye(direction.x*300,direction.y*300,direction.z*300),center(0,0,0),up(0,1,0);
    D3DXMATRIX view,projection,clipToTexture;
    D3DXMatrixLookAtRH(&view,&eye,&center,&up);D3DXMatrixOrthoRH(&projection,200,200,1,601);
    D3DXMatrixIdentity(&clipToTexture);clipToTexture._11=0.5f;clipToTexture._22=-0.5f;
    clipToTexture._41=clipToTexture._42=0.5f+0.5f/resolution;
    const D3DXMATRIX worldToLight=view*projection*clipToTexture;
    D3DVIEWPORT8 viewport={0,0,resolution,resolution,0,1};
    HRESULT hr=d->SetRenderTarget(surface,depth);if(FAILED(hr))return false;
    d->SetViewport(&viewport);d->SetTransform(D3DTS_VIEW,&view);d->SetTransform(D3DTS_PROJECTION,&projection);
    d->Clear(0,nullptr,D3DCLEAR_TARGET|D3DCLEAR_ZBUFFER,0xffffffff,1,0);
    calibrationGeometry(false);
    Pass *writer=NEW_REF(Pass,(true,worldToLight,true));const bool writeOkay=drawGeometry(*writer,worldToLight);
    writer->Release_Ref();if(!writeOkay)return false;
    const HRESULT depthDump=dumpDepthBitmap(d,path);
    const int cameraMode=getenv("ZH_SHADOWMAP_CALIBRATION_CAMERA")?atoi(getenv("ZH_SHADOWMAP_CALIBRATION_CAMERA")):0;
    D3DXVECTOR3 cameraEye(0,0,300);if(cameraMode==2)cameraEye=D3DXVECTOR3(120,-160,300);
    IDirect3DTexture8 *mask=nullptr;IDirect3DSurface8 *maskSurface=nullptr,*receiverDepth=nullptr;
    hr=d->CreateTexture(resolution,resolution,1,D3DUSAGE_RENDERTARGET,D3DFMT_A8R8G8B8,D3DPOOL_DEFAULT,&mask);
    if(SUCCEEDED(hr))hr=mask->GetSurfaceLevel(0,&maskSurface);
    if(SUCCEEDED(hr))hr=d->CreateDepthStencilSurface(resolution,resolution,D3DFMT_D24S8,D3DMULTISAMPLE_NONE,&receiverDepth);
    if(SUCCEEDED(hr))hr=d->SetRenderTarget(maskSurface,receiverDepth);
    if(SUCCEEDED(hr)){
        d->SetViewport(&viewport);d->Clear(0,nullptr,D3DCLEAR_TARGET|D3DCLEAR_ZBUFFER,0xffffffff,1,0);
        D3DXMatrixLookAtRH(&view,&cameraEye,&center,&up);
        if(cameraMode)D3DXMatrixPerspectiveFovRH(&projection,D3DX_PI/3.0f,1,1,601);
        // Nested readback restores wrapper matrices with VIEW_CHANGED pending.
        DX8Wrapper::Apply_Render_State_Changes();
        d->SetTransform(D3DTS_VIEW,&view);d->SetTransform(D3DTS_PROJECTION,&projection);
        calibrationGeometry(true);
        Pass *receiver=NEW_REF(Pass,(false,worldToLight,true));
        const bool compareOkay=drawGeometry(*receiver,worldToLight,true);receiver->Release_Ref();
        if(!compareOkay)hr=E_FAIL;
        if(SUCCEEDED(hr)){
            // Reuse the tested grayscale readback on the A8 mask, preserving the real R32F target.
            IDirect3DTexture8 *original=texture;texture=mask;
            const std::string maskPath=std::string(path)+".mask.bmp";
            hr=dumpDepthBitmap(d,maskPath.c_str());texture=original;
        }
    }
    // Capability evidence for complete screen-space receivers, not a default rendering change.
    DWORD screenShader=0,screenVertex=0;
    const HRESULT screenShaderHr=createScreenShaders(d,screenVertex,screenShader);
    report("screen_compare_shader",screenShaderHr);
    IDirect3DTexture8 *sampledDepth=nullptr;IDirect3DSurface8 *sampledDepthSurface=nullptr;
    const DWORD intz='I'|('N'<<8)|('T'<<16)|('Z'<<24);
    HRESULT intzHr=d->CreateTexture(resolution,resolution,1,D3DUSAGE_DEPTHSTENCIL,static_cast<D3DFORMAT>(intz),D3DPOOL_DEFAULT,&sampledDepth);
    report("intz_create",intzHr);
    if(SUCCEEDED(intzHr))intzHr=sampledDepth->GetSurfaceLevel(0,&sampledDepthSurface);
    if(SUCCEEDED(intzHr))intzHr=d->SetRenderTarget(maskSurface,sampledDepthSurface);
    if(SUCCEEDED(intzHr)){
        DX8Wrapper::Apply_Render_State_Changes();d->SetViewport(&viewport);
        d->SetTransform(D3DTS_VIEW,&view);d->SetTransform(D3DTS_PROJECTION,&projection);
        intzHr=d->Clear(0,nullptr,D3DCLEAR_TARGET|D3DCLEAR_ZBUFFER,0xffffffff,1,0);
        Pass *depthProbe=NEW_REF(Pass,(false,worldToLight,true));
        if(!drawGeometry(*depthProbe,worldToLight,true))intzHr=E_FAIL;depthProbe->Release_Ref();
        if(SUCCEEDED(intzHr)){
            IDirect3DTexture8 *original=texture;texture=sampledDepth;
            const std::string name=std::string(path)+".screen-depth.bmp";
            intzHr=dumpDepthBitmap(d,name.c_str());texture=original;
        }
    }
    report("intz_sample",intzHr);
    HRESULT screenMaskHr=E_FAIL;
    if(SUCCEEDED(intzHr)&&SUCCEEDED(screenShaderHr)){
        d->SetRenderTarget(maskSurface,nullptr);d->SetViewport(&viewport);
        d->Clear(0,nullptr,D3DCLEAR_TARGET,0xffffffff,1,0);
        const D3DXMATRIX mainViewProjection=view*projection;
        if(drawScreenShadow(d,screenVertex,screenShader,sampledDepth,mainViewProjection,worldToLight,resolution,resolution,true)){
            IDirect3DTexture8 *original=texture;texture=mask;
            const std::string name=std::string(path)+".screen-mask.bmp";
            IDirect3DSurface8 *probeDepth=nullptr;report("screen_readback_depth_state",d->GetDepthStencilSurface(&probeDepth));release(probeDepth);
            screenMaskHr=dumpDepthBitmap(d,name.c_str());texture=original;
        }
    }
    report("screen_mask",screenMaskHr);
    if(SUCCEEDED(intzHr)&&SUCCEEDED(screenShaderHr))for(unsigned debug=1;debug<=4;++debug){
        DWORD debugVertex=0,debugPixel=0;
        if(SUCCEEDED(createScreenShaders(d,debugVertex,debugPixel,debug))){
            d->SetRenderTarget(maskSurface,nullptr);d->SetViewport(&viewport);d->Clear(0,nullptr,D3DCLEAR_TARGET,0xffffffff,1,0);
            const D3DXMATRIX mainViewProjection=view*projection;
            if(drawScreenShadow(d,debugVertex,debugPixel,sampledDepth,mainViewProjection,worldToLight,resolution,resolution,true)){
                IDirect3DTexture8 *original=texture;texture=mask;char suffix[80];sprintf(suffix,".screen-debug%u.bmp",debug);
                const std::string name=std::string(path)+suffix;dumpDepthBitmap(d,name.c_str());texture=original;
            }
            d->DeleteVertexShader(debugVertex);d->DeletePixelShader(debugPixel);
        }
    }
    if(screenVertex)d->DeleteVertexShader(screenVertex);if(screenShader)d->DeletePixelShader(screenShader);
    release(sampledDepthSurface);release(sampledDepth);
    const std::string metadata=std::string(path)+".calibration.json";
    FILE *file=fopen(metadata.c_str(),"w");
    if(file){fprintf(file,"{\"resolution\":%u,\"main_width\":%u,\"main_height\":%u,\"light\":[%.9g,%.9g,%.9g],\"box_min\":[-20,-20,0],\"box_max\":[20,20,40],\"plane_extent\":100,\"intz_shadow\":%s,\"camera_eye\":[%.9g,%.9g,%.9g],\"perspective\":%s,\"tan_half_fov\":0.577350269,\"depth_dump_hr\":%ld,\"mask_dump_hr\":%ld,\"intz_hr\":%ld,\"screen_shader_hr\":%ld,\"screen_mask_hr\":%ld}\n",resolution,saved.viewport.Width,saved.viewport.Height,direction.x,direction.y,direction.z,depthIsIntz?"true":"false",cameraEye.x,cameraEye.y,cameraEye.z,cameraMode?"true":"false",static_cast<long>(depthDump),static_cast<long>(hr),static_cast<long>(intzHr),static_cast<long>(screenShaderHr),static_cast<long>(screenMaskHr));fclose(file);}
    release(receiverDepth);release(maskSurface);release(mask);dumped=SUCCEEDED(hr)&&SUCCEEDED(depthDump);
    report("calibration",hr);return dumped;
}
static void describeObject(FILE *file,RenderObjClass *object,unsigned level=0) {
    if(!object||level>2)return;
    const Vector3 pos=object->Get_Position(); const AABoxClass bounds=object->Get_Bounding_Box();
    fprintf(file,"object level=%u name=%s class=%d visible=%d hidden=%d pos=%.9g,%.9g,%.9g box=%.9g,%.9g,%.9g extent=%.9g,%.9g,%.9g children=%d\n",
        level,object->Get_Name()?object->Get_Name():"null",object->Class_ID(),object->Is_Really_Visible(),!object->Is_Not_Hidden_At_All(),
        pos.X,pos.Y,pos.Z,bounds.Center.X,bounds.Center.Y,bounds.Center.Z,bounds.Extent.X,bounds.Extent.Y,bounds.Extent.Z,object->Get_Num_Sub_Objects());
    if(object->Class_ID()==RenderObjClass::CLASSID_MESH) {
        MeshModelClass *model=static_cast<MeshClass*>(object)->Peek_Model();
        fprintf(file,"mesh sort_level=%d polygons=%d srcblend=%d alpha_test=%d\n",model->Get_Sort_Level(),model->Get_Polygon_Count(),model->Get_Single_Shader().Get_Src_Blend_Func(),model->Get_Single_Shader().Get_Alpha_Test());
    }
    for(int i=0;i<__min(16,object->Get_Num_Sub_Objects());++i) {
        RenderObjClass *child=object->Get_Sub_Object(i);
        describeObject(file,child,level+1); if(child)child->Release_Ref();
    }
}
} // namespace zhsm
static void zhShadowMapRelease() { zhsm::freeResources(); }
Bool W3DVolumetricShadowManager::renderShadowMap(RenderInfoClass &rinfo) {
    if(!zh::parseBoolean(getenv("ZH_SHADOWMAP"),false)) return FALSE;
    using namespace zhsm;
    IDirect3DDevice8 *d=DX8Wrapper::_Get_D3D_Device8();
    if(!d || !TheTerrainRenderObject || !acquire(d)) return FALSE;
    if(zh::parseBoolean(getenv("ZH_SHADOWMAP_CALIBRATE"),false))return calibrate(d)?TRUE:FALSE;
    if(!TheGlobalData->m_useShadowVolumes || !m_shadowList) return FALSE;
    TheDX8MeshRenderer.Flush();
    SavedState saved(d); if(!saved.valid) { report("state_capture_failed",E_FAIL); return FALSE; }
    WW3D::Enable_Static_Sort_Lists(false); // Render now, with this pass/camera, not on the later main-scene sort list.
    depthMeshes=receiverMeshes=0;
    LARGE_INTEGER begin,end,gatherBegin,gatherEnd,depthEnd,terrainBegin,terrainEnd; QueryPerformanceCounter(&begin);
    AABoxClass box;
    TheTerrainRenderObject->getMaximumVisibleBox(rinfo.Camera.Get_Frustum(),&box,TRUE);
    const float extent=__max(300.0f,__max(box.Extent.X,box.Extent.Y)+200.0f);
    Vector3 direction=TheW3DShadowManager->getLightPosWorld(0); direction.Normalize();
    const Vector3 eye=box.Center+direction*(extent*3.0f);
    CameraClass light;
    Matrix3D transform(true); transform.Look_At(eye,box.Center,0.0f);
    light.Set_Transform(transform); light.Set_Projection_Type(CameraClass::ORTHO);
    light.Set_View_Plane(Vector2(-extent,-extent),Vector2(extent,extent));
    light.Set_Clip_Planes(1.0f,extent*6.0f);
    HRESULT hr=d->SetRenderTarget(surface,depth);
    if(FAILED(hr)) { report("set_target_failed",hr); failed=true; return FALSE; }
    TheDX8MeshRenderer.Set_Camera(&light);
    light.Apply(); DX8Wrapper::Apply_Render_State_Changes();
    D3DVIEWPORT8 viewport={0,0,resolution,resolution,0,1}; d->SetViewport(&viewport);
    hr=d->Clear(0,nullptr,D3DCLEAR_TARGET|D3DCLEAR_ZBUFFER,0xffffffff,1.0f,0);
    if(FAILED(hr)) { report("clear_failed",hr); failed=true; return FALSE; }
    D3DXMATRIX lightView,lightProjection,clipToTexture;
    hr=d->GetTransform(D3DTS_VIEW,&lightView);
    if(SUCCEEDED(hr)) hr=d->GetTransform(D3DTS_PROJECTION,&lightProjection);
    if(FAILED(hr)) { report("light_transform_read",hr);return FALSE; }
    D3DXMatrixIdentity(&clipToTexture);
    clipToTexture._11=0.5f; clipToTexture._22=-0.5f;
    clipToTexture._41=0.5f+0.5f/resolution; clipToTexture._42=0.5f+0.5f/resolution;
    D3DXMATRIX writeCoordinates=lightProjection*clipToTexture;
    const bool batching=zh::parseBoolean(getenv("ZH_SHADOWMAP_BATCH"),true);
    beginGeometryBatches();
    const D3DXMATRIX worldToLight=lightView*writeCoordinates;
    QueryPerformanceCounter(&gatherBegin);
    if(batching) for(W3DVolumetricShadow *s=m_shadowList;s;s=s->m_next) {
        if(s->m_isEnabled && !s->m_isInvisibleEnabled && s->m_robj && !light.Cull_Box(s->m_robj->Get_Bounding_Box()))
            if(!appendGeometry(s->m_robj,worldToLight)){report("unsupported_batch_geometry",E_FAIL);return FALSE;}
    }
    finishGeometryBatches();
    QueryPerformanceCounter(&gatherEnd);
    Pass *writer=NEW_REF(Pass,(true,writeCoordinates,batching));
    RenderInfoClass lightInfo(light);
    lightInfo.Push_Material_Pass(writer);
    lightInfo.Push_Override_Flags(RenderInfoClass::RINFO_OVERRIDE_ADDITIONAL_PASSES_ONLY);
    unsigned casters=0;
    for(W3DVolumetricShadow *s=m_shadowList;s;s=s->m_next) {
        if(s->m_isEnabled && !s->m_isInvisibleEnabled && s->m_robj && s->m_robj->Is_Not_Hidden_At_All()
            && !light.Cull_Box(s->m_robj->Get_Bounding_Box())) { if(!batching) s->m_robj->Render(lightInfo); ++casters; }
    }
    const bool depthOkay=!batching || drawGeometry(*writer,worldToLight);
    if(!batching)TheDX8MeshRenderer.Flush();
    writer->Finish();
    lightInfo.Pop_Override_Flags(); lightInfo.Pop_Material_Pass(); writer->Release_Ref();
    if(!depthOkay)return FALSE;
    QueryPerformanceCounter(&depthEnd);
    const char *dump=getenv("ZH_SHADOWMAP_DUMP");
    if(dump && *dump && !dumped && ++renderedFrames>=30) {
        report("depth_bitmap",dumpDepthBitmap(d,dump));
        const std::string name=std::string(dump)+".scene.txt"; FILE *file=fopen(name.c_str(),"w");
        if(file) {
            fprintf(file,"queued_roots=%u depth_pass_installs=%u main_viewport=%u,%u batches=%u meshes=%u triangles=%u cache_hits=%u box=%.9g,%.9g,%.9g extent=%.9g,%.9g,%.9g light_extent=%.9g\n",casters,depthMeshes,saved.viewport.Width,saved.viewport.Height,usedBatches,batchMeshes,batchTriangles,cacheHits,box.Center.X,box.Center.Y,box.Center.Z,box.Extent.X,box.Extent.Y,box.Extent.Z,extent);
            for(unsigned row=0;row<4;++row) fprintf(file,"view[%u]=%.9g,%.9g,%.9g,%.9g projection[%u]=%.9g,%.9g,%.9g,%.9g\n",row,lightView.m[row][0],lightView.m[row][1],lightView.m[row][2],lightView.m[row][3],row,lightProjection.m[row][0],lightProjection.m[row][1],lightProjection.m[row][2],lightProjection.m[row][3]);
            unsigned count=0;
            for(W3DVolumetricShadow *shadow=m_shadowList;shadow&&count<3;shadow=shadow->m_next) if(shadow->m_robj) {describeObject(file,shadow->m_robj);++count;}
            fclose(file);
        }
        dumped=true;
    }
    saved.restoreTarget(); TheDX8MeshRenderer.Set_Camera(&rinfo.Camera); rinfo.Camera.Apply(); DX8Wrapper::Apply_Render_State_Changes();
    D3DXMATRIX mainView,inverseView;
    hr=d->GetTransform(D3DTS_VIEW,&mainView); if(FAILED(hr)) { report("main_transform_read",hr);return FALSE; }
    D3DXMatrixInverse(&inverseView,nullptr,&mainView);
    D3DXMATRIX receiverCoordinates=inverseView*lightView*lightProjection*clipToTexture;
    Pass *receiver=NEW_REF(Pass,(false,receiverCoordinates));
    QueryPerformanceCounter(&terrainBegin);
    Pass *terrainReceiver=NEW_REF(Pass,(false,receiverCoordinates,true));
    const unsigned tiles=terrain(*terrainReceiver,box,worldToLight);
    terrainReceiver->Finish();terrainReceiver->Release_Ref();
    QueryPerformanceCounter(&terrainEnd);
    receiver->Finish();
    DX8Wrapper::Invalidate_Cached_Render_States();
    rinfo.Camera.Apply();
    rinfo.Push_Material_Pass(receiver); rinfo.Push_Override_Flags(RenderInfoClass::RINFO_OVERRIDE_ADDITIONAL_PASSES_ONLY);
    if(batching){
        Pass *batchReceiver=NEW_REF(Pass,(false,receiverCoordinates,true));
        drawGeometry(*batchReceiver,worldToLight);batchReceiver->Release_Ref();
    }else for(W3DVolumetricShadow *s=m_shadowList;s;s=s->m_next) {
        if(s->m_isEnabled && !s->m_isInvisibleEnabled && s->m_robj && s->m_robj->Is_Really_Visible()) s->m_robj->Render(rinfo);
    }
    TheDX8MeshRenderer.Flush(); receiver->Finish(); rinfo.Pop_Override_Flags(); rinfo.Pop_Material_Pass(); receiver->Release_Ref();
    QueryPerformanceCounter(&end);
    if(diagnostics) { fprintf(diagnostics,"frame,00000000,%u,%u,%.3f,%.3f,%.3f,%.3f,%.3f,%u,%u\n",casters,tiles,(end.QuadPart-begin.QuadPart)*1000000.0/frequency.QuadPart,(gatherEnd.QuadPart-gatherBegin.QuadPart)*1000000.0/frequency.QuadPart,(depthEnd.QuadPart-gatherEnd.QuadPart)*1000000.0/frequency.QuadPart,(terrainEnd.QuadPart-terrainBegin.QuadPart)*1000000.0/frequency.QuadPart,(end.QuadPart-terrainEnd.QuadPart)*1000000.0/frequency.QuadPart,usedBatches,batchTriangles); fflush(diagnostics); }
    return TRUE;
}
