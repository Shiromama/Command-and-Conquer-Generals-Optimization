"""Compile the actual rigid shadow-batch collector against cache/layout boundary cases."""
from pathlib import Path
import subprocess,hashlib,json,argparse
from datetime import datetime
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=root/'engine/rejected/T-035/ShadowMapPrototype.inc')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
source=args.source.resolve()
text=source.read_text(encoding='utf-8')
body=text[text.index('struct BatchVertex'):text.index('static bool drawGeometry')]
output=(args.output or root/'artifacts'/datetime.now().strftime('%Y-%m-%d-shadow-batches-%H%M%S')).resolve()
output.mkdir(parents=True,exist_ok=False)
stubs=r"""
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <cstring>
#include <cstdio>
#include <vector>
#include <algorithm>
#include <unordered_map>
struct Vector3 {float X=0,Y=0,Z=0;};
struct Matrix3D {float m[12]={1,0,0,0,0,1,0,0,0,0,1,0};
 static void Transform_Vector(const Matrix3D &a,const Vector3 &v,Vector3 *out){
  *out={a.m[0]*v.X+a.m[1]*v.Y+a.m[2]*v.Z+a.m[3],a.m[4]*v.X+a.m[5]*v.Y+a.m[6]*v.Z+a.m[7],a.m[8]*v.X+a.m[9]*v.Y+a.m[10]*v.Z+a.m[11]};}
};
struct D3DXMATRIX {};
struct TriIndex {unsigned short I,J,K;};
struct MeshGeometryClass {enum{CAST_SHADOW=1,SKIN=2};};
struct MeshModelClass {
 std::vector<Vector3> vertices{{0,0,0},{1,0,0},{0,1,0}};
 std::vector<TriIndex> triangles{{0,1,2}};
 int flags=0;
 bool Get_Flag(int bit)const{return (flags&bit)!=0;}
 unsigned Get_Vertex_Count()const{return static_cast<unsigned>(vertices.size());}
 unsigned Get_Polygon_Count()const{return static_cast<unsigned>(triangles.size());}
 const Vector3 *Get_Vertex_Array()const{return vertices.data();}
 const TriIndex *Get_Polygon_Array()const{return triangles.data();}
};
struct RenderObjClass {
 enum{CLASSID_MESH=0,CLASSID_HLOD=25};
 bool hidden=false;
 std::vector<RenderObjClass*> children;
 virtual ~RenderObjClass()=default;
 virtual int Class_ID()const{return 99;}
 bool Is_Not_Hidden_At_All()const{return !hidden;}
 virtual int Get_Num_Sub_Objects()const{return static_cast<int>(children.size());}
 virtual RenderObjClass *Get_Sub_Object(int i){return children.at(i);}
 void Release_Ref(){}
};
struct MeshClass:RenderObjClass {
 MeshModelClass *model;Matrix3D transform;bool alpha=false,translucent=false;
 explicit MeshClass(MeshModelClass *m):model(m){}
 int Class_ID()const override{return CLASSID_MESH;}
 MeshModelClass *Peek_Model(){return model;}
 bool Is_Alpha()const{return alpha;}
 bool Is_Translucent()const{return translucent;}
 const Matrix3D &Get_Transform()const{return transform;}
};
struct HLodClass:RenderObjClass {
 std::vector<std::vector<RenderObjClass*>> lods;int selected=0;
 int Class_ID()const override{return CLASSID_HLOD;}
 int Get_LOD_Level()const{return selected;}
 int Get_LOD_Count()const{return static_cast<int>(lods.size());}
 int Get_Lod_Model_Count(int i)const{return static_cast<int>(lods.at(i).size());}
 RenderObjClass *Peek_Lod_Model(int i,int j){return lods.at(i).at(j);}
 int Get_Num_Sub_Objects()const override{int n=static_cast<int>(children.size());for(auto &l:lods)n+=static_cast<int>(l.size());return n;}
 RenderObjClass *Get_Sub_Object(int i)override{for(auto &l:lods){if(i<static_cast<int>(l.size()))return l.at(i);i-=static_cast<int>(l.size());}return children.at(i);}
};
"""
tests=r"""
static bool frame(std::vector<RenderObjClass*> roots){
 beginGeometryBatches();D3DXMATRIX matrix;
 for(auto *root:roots)if(!appendGeometry(root,matrix))return false;
 finishGeometryBatches();return true;
}
static void vertex(unsigned batch,unsigned index,float x){assert(batches.at(batch).vertices.at(index).x==x);}
int main(){
 unsigned cases=0;MeshModelClass model,other;MeshClass a(&model),b(&model),c(&other);
 b.transform.m[3]=10;c.transform.m[3]=20;
 assert(frame({&a,&b}));assert(batchMeshes==2&&usedBatches==1&&cacheHits==0);vertex(0,3,10);++cases;
 assert(frame({&a,&b}));assert(cacheHits==2);++cases;
 a.transform.m[3]=5;assert(frame({&a,&b}));assert(cacheHits==1);vertex(0,0,5);++cases;
 assert(frame({&b,&a}));assert(cacheHits==0);vertex(0,0,10);vertex(0,3,5);++cases;
 b.hidden=true;assert(frame({&b,&a}));assert(batchMeshes==1&&batches[0].vertices.size()==3);vertex(0,0,5);++cases;
 b.hidden=false;assert(frame({&a,&b,&c}));assert(batches[0].vertices.size()==9);vertex(0,6,20);++cases;
 a.model=&other;assert(frame({&a,&b,&c}));assert(cacheHits==2);++cases;
 other.vertices.reserve(100);other.vertices[0].X=3;assert(frame({&a,&b,&c}));vertex(0,0,8);vertex(0,6,23);++cases;
 other.vertices.push_back({2,2,2});other.triangles.push_back({1,2,3});assert(frame({&a,&b,&c}));assert(batchTriangles==5);++cases;
 other.vertices[0].X=7;other.triangles[0]={2,1,0};assert(frame({&a,&b,&c}));vertex(0,0,12);vertex(0,7,27);assert(batches[0].indices[0]==2);++cases;
 HLodClass tree;tree.lods={{&a},{&b}};tree.children={&c};assert(frame({&tree}));assert(batchMeshes==2);vertex(0,0,12);tree.selected=1;assert(frame({&tree}));vertex(0,0,10);++cases;
 b.alpha=true;assert(frame({&b}));assert(batchMeshes==0);model.flags=MeshGeometryClass::CAST_SHADOW;assert(frame({&b}));assert(batchMeshes==1);model.flags|=MeshGeometryClass::SKIN;assert(frame({&b}));assert(batchMeshes==0);model.flags=0;b.alpha=false;++cases;
 MeshModelClass large;large.vertices.resize(40000);MeshClass d(&large),e(&large);assert(frame({&d,&e}));assert(usedBatches==2);for(unsigned i=0;i<usedBatches;++i){assert(batches[i].vertices.size()<=60000);for(auto n:batches[i].indices)assert(n<batches[i].vertices.size());}++cases;
 large.vertices.resize(60001);assert(!frame({&d}));++cases;
 large.vertices.resize(3);large.triangles={{0,1,3}};assert(!frame({&d}));++cases;
 std::vector<RenderObjClass> deep(19);for(unsigned i=0;i+1<deep.size();++i)deep[i].children={&deep[i+1]};assert(!frame({&deep[0]}));++cases;
 clearGeometryCache();assert(batches.empty()&&usedBatches==0);assert(frame({&a}));assert(cacheHits==0);++cases;
 std::printf("PASS: %u actual-source shadow batch/cache cases\n",cases);
}
"""
(output/'collector.cpp').write_text(stubs+body+tests,encoding='utf-8')
(output/'source.json').write_text(json.dumps({'source':str(source.relative_to(root)),'extracted_sha256':hashlib.sha256(body.encode()).hexdigest()},indent=2)+'\n',encoding='utf-8')
(output/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.20)\nproject(shadow_batches LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 20)\nadd_executable(shadow_batches collector.cpp)\n',encoding='utf-8')
for label,command in [('configure',['cmake','-S',str(output),'-B',str(output/'build'),'-G','Visual Studio 17 2022','-A','Win32']),('build',['cmake','--build',str(output/'build'),'--config','Release','--','/m:1','/nodeReuse:false']),('run',[str(output/'build/Release/shadow_batches.exe')])]:
 result=subprocess.run(command,capture_output=True,text=True)
 (output/(label+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
 if result.returncode:raise RuntimeError(f'{label} failed: see {output}/{label}.log')
 if label=='run':print(result.stdout,end='')
