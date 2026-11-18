"""Compile the actual guard resolver/decal resize methods against targeting and mode boundaries."""
import argparse,hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,default=root/'build/alpha-engine-source');parser.add_argument('--output',type=Path,default=root/'artifacts/2026-11-18-guard-range/compiled-tests');args=parser.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
def method(source,signature):
    start=source.index(signature);brace=source.index('{',start);depth=1;i=brace+1
    while depth:
        if source[i]=='{':depth+=1
        if source[i]=='}':depth-=1
        i+=1
    return source[start:i]
guard=(args.source/'GeneralsMD/Code/GameEngine/Source/GameLogic/AI/AIGuard.cpp').read_text(encoding='utf-8')
decal=(args.source/'Core/GameEngine/Source/GameClient/RadiusDecal.cpp').read_text(encoding='utf-8')
ui=(args.source/'GeneralsMD/Code/GameEngine/Source/GameClient/InGameUI.cpp').read_text(encoding='utf-8')
functions=[method(guard,'static Real getAutomaticGuardWeaponRange'),method(guard,'/*static*/ Real AIGuardMachine::getStdGuardRange'),method(decal,'void RadiusDecal::setRadius')]
assert 'm_curRadiusCursor.setRadius(AIGuardMachine::getStdGuardRange(selected))' in ui
assert 'radius = AIGuardMachine::getStdGuardRange(obj);' in ui
assert 'getClosestObject(&pos, visionRange, FROM_CENTER_2D, filters)' in guard
cpp=r'''
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
using Real=float;using Bool=bool;using Int=int;
enum WeaponSlotType{PRIMARY_WEAPON,SECONDARY_WEAPON,TERTIARY_WEAPON,WEAPONSLOT_COUNT};
enum{CMD_FROM_AI=2,MM_Controller_Player=4,AI_VISIONFACTOR_OWNERTYPE=1,AI_VISIONFACTOR_MOOD=2,AI_VISIONFACTOR_GUARDINNER=4};
enum WeaponStatus{READY_TO_FIRE,RELOADING_CLIP,OUT_OF_AMMO};
struct Object;
struct Weapon{Real range=300;bool damage=true;int anti=1;WeaponStatus status=READY_TO_FIRE;bool reload=false;
 bool isDamageWeapon()const{return damage;}int getAntiMask()const{return anti;}WeaponStatus getStatus()const{return status;}bool getAutoReloadsClip()const{return reload;}
 Real getAttackRange(const Object*)const;};
struct UnitAI{unsigned mood=MM_Controller_Player;unsigned getMoodMatrixValue()const{return mood;}};
struct Template{bool enter=false;bool isEnterGuard()const{return enter;}};
struct Object{UnitAI ai;Template tm;bool hasAI=true,locked=false;Weapon* current=nullptr;Weapon* slots[3]={};unsigned masks[3]={~0u,~0u,~0u};Real bonus=1,legacy=100;
 const UnitAI*getAI()const{return hasAI?&ai:nullptr;}const Template*getTemplate()const{return &tm;}bool isCurWeaponLocked()const{return locked;}
 const Weapon*getCurrentWeapon()const{return current;}Weapon*getWeaponInWeaponSlot(WeaponSlotType s)const{return slots[s];}unsigned getWeaponInWeaponSlotCommandSourceMask(WeaponSlotType s)const{return masks[s];}};
Real Weapon::getAttackRange(const Object* obj)const{return range*obj->bonus;}
struct AI{Real getAdjustedVisionRangeForObject(const Object*o,int){return o->legacy;}};
struct Logic{bool game=true,shell=false,multi=false,replay=false;bool isInGame()const{return game;}bool isInShellGame()const{return shell;}bool isInMultiplayerGame()const{return multi;}bool isInReplayGame()const{return replay;}};
AI ai;AI*TheAI=&ai;Logic logic;Logic*TheGameLogic=&logic;
struct AIGuardMachine{static Real getStdGuardRange(const Object*);};
struct Shadow{Real x=-1,y=-1;void setSize(Real a,Real b){x=a;y=b;}};
struct RadiusDecal{Shadow*m_decal=nullptr;void setRadius(Real);};
METHODS
int main(){unsigned cases=0;
 auto check=[&](const Object*o,Real expected){assert(std::fabs(AIGuardMachine::getStdGuardRange(o)-expected)<0.001f);++cases;};
 Object o;Weapon a,b; o.slots[0]=&a;
 check(nullptr,0);o.hasAI=false;check(&o,0);o.hasAI=true;TheAI=nullptr;check(&o,0);TheAI=&ai;
 TheGameLogic=nullptr;check(&o,100);TheGameLogic=&logic;
 logic.game=false;check(&o,100);logic.game=true;logic.shell=true;check(&o,100);logic.shell=false;
 logic.multi=true;check(&o,100);logic.multi=false;logic.replay=true;check(&o,100);logic.replay=false;
 o.ai.mood=0;check(&o,100);o.ai.mood=MM_Controller_Player;o.tm.enter=true;check(&o,100);o.tm.enter=false;
 o.slots[0]=nullptr;check(&o,100);o.slots[0]=&a;a.range=70;check(&o,100);a.range=300;check(&o,300);
 o.bonus=1.25f;check(&o,375);o.bonus=1;a.range=350;check(&o,350);
 o.masks[0]=1u;check(&o,100);o.masks[0]=~0u;a.damage=false;check(&o,100);a.damage=true;a.anti=0;check(&o,100);a.anti=1;
 a.status=OUT_OF_AMMO;check(&o,100);a.status=RELOADING_CLIP;check(&o,350);a.status=OUT_OF_AMMO;a.reload=true;check(&o,350);a.status=READY_TO_FIRE;a.reload=false;
 b.range=10000;o.slots[1]=&b;o.masks[1]=0;check(&o,350);o.masks[1]=~0u;b.damage=false;check(&o,350);b.damage=true;b.range=500;check(&o,500);
 o.locked=true;o.current=&a;check(&o,350);o.current=&b;check(&o,500);o.masks[1]=0;check(&o,500);o.current=nullptr;check(&o,100);o.locked=false;o.slots[1]=nullptr;
 for(Real invalid:{-5.0f,std::numeric_limits<Real>::quiet_NaN(),std::numeric_limits<Real>::infinity()}){a.range=invalid;check(&o,100);}
 for(Real legacy:{0.0f,100.0f,198.0f,324.0f,540.0f})for(Real range:{0.0f,80.0f,150.0f,350.0f,450.0f,600.0f}){o.legacy=legacy;a.range=range;check(&o,range>legacy?range:legacy);}
 Shadow shadow;RadiusDecal decal;decal.setRadius(350);++cases;decal.m_decal=&shadow;
 for(Real radius:{350.0f,420.0f,100.0f,0.0f,-1.0f}){decal.setRadius(radius);Real d=radius>0?radius*2:0;assert(shadow.x==d&&shadow.y==d);++cases;}
 std::printf("PASS: %u actual-source guard/mode/weapon/decal cases; shared UI/search resolver verified\n",cases);
}
'''.replace('METHODS','\n'.join(functions)).replace('#include <limits>','#include <limits>\n#include <initializer_list>')
(out/'guard.cpp').write_text(cpp,encoding='utf-8')
(out/'extracted-methods.json').write_text(json.dumps([dict(sha256=hashlib.sha256(f.encode()).hexdigest(),source=f) for f in functions],indent=2)+'\n',encoding='utf-8')
(out/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.20)\nproject(guard_checks LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 20)\nadd_executable(guard_checks guard.cpp)\n',encoding='utf-8')
for name,command in [('configure',['cmake','-S',str(out),'-B',str(out/'build'),'-G','Visual Studio 17 2022','-A','Win32']),('build',['cmake','--build',str(out/'build'),'--config','Release','--','/m:1','/nodeReuse:false']),('run',[str(out/'build/Release/guard_checks.exe')])]:
    result=subprocess.run(command,capture_output=True,text=True);(out/f'{name}.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode:raise RuntimeError(f'{name} failed: {out/name}.log')
    if name=='run':print(result.stdout,end='')
