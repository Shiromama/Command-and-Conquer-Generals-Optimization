"""Compile focused tests against actual T-079 policy and extracted engine code.
Requires cl.exe/INCLUDE/LIB from VS vcvars32.bat. No game assets or engine execution.
"""
from pathlib import Path
import json, subprocess, hashlib
root=Path(__file__).resolve().parents[1]
v=root/'vendor/GeneralsGameCode'
out=root/'artifacts/2026-11-17-t079-remediation';out.mkdir(parents=True,exist_ok=True)
def read(rel): return (v/rel).read_text(encoding='utf-8')
def method(source, signature):
 start=source.index(signature); brace=source.index('{',start);depth=1;i=brace+1
 while depth:
  depth += (source[i]=='{')-(source[i]=='}');i+=1
 return source[start:i]
logic=read('GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp')
a=logic.index('\t\t// T-079: collect');b=logic.index('\n\n\t\tcurrentObject->removeFromList',a)
removal=logic[a:b]
erase=method(logic,'void GameLogic::eraseSleepyUpdate(Int i)')
pacer=method(read('Core/GameEngine/Source/Common/FramePacer.cpp'),'Bool FramePacer::isActualFramesPerSecondLimitEnabled() const')
option=method(read('Core/GameEngine/Source/Common/OptionPreferences.cpp'),'Bool OptionPreferences::getDebrisBroadphaseEnabled()')
assert 'g_zhDisabledObjects' not in logic
assert 'g_zhDisabledObjects' not in read('GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Object.cpp')
header=(v/'Core/GameEngine/Include/Common/OptimizationPolicy.h').as_posix()
cpp=r'''
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <map>
#include <memory>
#include <random>
#include <string>
#include <vector>
#include "HEADER"
using Bool=bool;using Int=int;
constexpr bool FALSE=false;
#define DEBUG_ASSERTCRASH(test,msg) assert(test)
#define USE_PERF_TIMER(x)
struct UpdateModuleInterface { virtual ~UpdateModuleInterface(){} };
struct UpdateModule:UpdateModuleInterface { int index=-1; int friend_getIndexInLogic()const{return index;} void friend_setIndexInLogic(int i){index=i;} };
using UpdateModulePtr=UpdateModule*;
struct BehaviorModule { UpdateModule *u;UpdateModuleInterface* getUpdate(){return u;} };
struct Object { std::vector<BehaviorModule*> modules;BehaviorModule** getBehaviorModules(){return modules.data();} };
struct GameLogic {
 std::vector<UpdateModulePtr> m_sleepyUpdates;
 void rebalanceSleepyUpdate(int) {
  // Force scheduler relocation after every erase; collected pointers must use live indices.
  std::reverse(m_sleepyUpdates.begin(),m_sleepyUpdates.end());
  for(int i=0;i<(int)m_sleepyUpdates.size();++i)m_sleepyUpdates[i]->friend_setIndexInLogic(i);
 }
 void eraseSleepyUpdate(Int);
 void remove(Object* currentObject) {
  std::vector<UpdateModulePtr> sleepyUpdatesForThisObject;
REMOVAL
 }
};
ERASE
struct Global {bool m_useFpsLimit=true;bool m_TiVOFastMode=false;} global;
Global *TheGlobalData=&global;
struct View {int getTimeMultiplier(){return 1;}};View *TheTacticalView=nullptr;
struct Script {bool isTimeFast(){return false;}};Script *TheScriptEngine=nullptr;
struct Logic {bool isGamePaused(){return false;}bool isInReplayGame(){return false;}};Logic *TheGameLogic=nullptr;
struct FramePacer {bool enabled=true;bool isFramesPerSecondLimitEnabled()const{return enabled;}Bool isActualFramesPerSecondLimitEnabled()const;};
PACER
struct Text {std::string value;const char*str()const{return value.c_str();}};
struct OptionPreferences:std::map<std::string,Text>{Bool getDebrisBroadphaseEnabled();};
OPTION
int main(){
 OptionPreferences pref; assert(!pref.getDebrisBroadphaseEnabled());
 for(const char *s:{"yes","YES","true","TrUe","1"}){pref["DebrisBroadphase"]={s};assert(pref.getDebrisBroadphaseEnabled());}
 for(const char *s:{"no","NO","false","0","garbage","2",""}){pref["DebrisBroadphase"]={s};assert(!pref.getDebrisBroadphaseEnabled());}
 assert(!zh::parseBoolean(nullptr,false));assert(zh::parseBoolean(nullptr,true));
 for(int requested=0;requested<2;++requested)for(int net=0;net<2;++net)for(int replay=0;replay<2;++replay)
  assert(zh::experimentalSimulationAllowed(requested,net,replay)==(requested&&!net&&!replay));
 FramePacer fps;
 for(bool preference:{false,true})for(const char *env:{(const char*)nullptr,"0","1"})for(bool cmd:{false,true}){
  global.m_useFpsLimit=zh::startupFpsLimit(preference,env,cmd);
  assert(fps.isActualFramesPerSecondLimitEnabled()==global.m_useFpsLimit);
  global.m_useFpsLimit=true;assert(fps.isActualFramesPerSecondLimitEnabled());
  global.m_useFpsLimit=false;assert(!fps.isActualFramesPerSecondLimitEnabled());
 }
 std::mt19937 rng(79);
 for(int n:{0,1,2,255,256,257,1024})for(int trial=0;trial<20;++trial){
  GameLogic logic;Object object;
  std::vector<std::unique_ptr<UpdateModule>> modules;
  std::vector<std::unique_ptr<BehaviorModule>> behaviors;
  for(int i=0;i<n+37;++i){
   modules.emplace_back(new UpdateModule);
   logic.m_sleepyUpdates.push_back(modules.back().get());
   if(i<n){behaviors.emplace_back(new BehaviorModule{modules.back().get()});object.modules.push_back(behaviors.back().get());}
  }
  // Include a behavior without an update and one unregistered update.
  UpdateModule unregistered;BehaviorModule nullBehavior{nullptr},unregisteredBehavior{&unregistered};
  object.modules.push_back(&nullBehavior);object.modules.push_back(&unregisteredBehavior);object.modules.push_back(nullptr);
  std::shuffle(logic.m_sleepyUpdates.begin(),logic.m_sleepyUpdates.end(),rng);
  for(int i=0;i<(int)logic.m_sleepyUpdates.size();++i)logic.m_sleepyUpdates[i]->index=i;
  logic.remove(&object);assert(logic.m_sleepyUpdates.size()==37);
  for(int i=0;i<n;++i)assert(modules[i]->index==-1);
  for(int i=n;i<n+37;++i)assert(modules[i]->index>=0&&logic.m_sleepyUpdates[modules[i]->index]==modules[i].get());
 }
 puts("PASS: actual boolean getter, 8 simulation policy combinations, FPS startup/live state transitions, 140 randomized scheduler cases through 1024 modules; disabled counter removed");
}
'''
cpp=cpp.replace('HEADER',header).replace('REMOVAL',removal).replace('ERASE',erase).replace('PACER',pacer).replace('OPTION',option)
p=out/'engine-regressions.cpp';p.write_text(cpp,encoding='utf-8')
command=['cl.exe','/nologo','/std:c++20','/EHsc','/W3','/Od',str(p),'/Fe'+str(out/'engine-regressions.exe'),'/Fo'+str(out/'engine-regressions.obj')]
c=subprocess.run(command,capture_output=True,text=True);(out/'unit-build.log').write_text(c.stdout+c.stderr);assert c.returncode==0,c.stdout+c.stderr
c=subprocess.run([str(out/'engine-regressions.exe')],capture_output=True,text=True);print(c.stdout);assert c.returncode==0,c.stderr
(out/'engine-tests.json').write_text(json.dumps({'exit_code':c.returncode,'output':c.stdout,'generated_test_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'method':'actual shared header and extracted engine methods, stubbed surrounding services; not a full game integration test'},indent=2)+'\n')
