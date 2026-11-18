"""Compile actual pathfinding list/heap integration methods against boundary cases; no game launch."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

root=Path(__file__).resolve().parents[1]
vendor=root/'vendor/GeneralsGameCode'
output=root/'artifacts/2026-11-17-queue-replay/integration-tests'
output.mkdir(parents=True,exist_ok=True)
cell=(vendor/'Core/GameEngine/Source/GameLogic/AI/Pathfinder/PathfindCell.cpp').read_text(encoding='utf-8')
listing=(vendor/'Core/GameEngine/Source/GameLogic/AI/Pathfinder/PathfindCellList.cpp').read_text(encoding='utf-8')
telemetry=(vendor/'Core/GameEngine/Source/GameLogic/AI/PathfindTelemetry.inc').read_text(encoding='utf-8')

def method(source,signature):
    start=source.index(signature)
    brace=source.index('{',start)
    end=re.search(r'^}',source[brace+1:],re.M).start()+brace+2
    return source[start:end]

signatures=['void PathfindCell::prepareHeapList','void PathfindCell::putOnSortedOpenList',
            'void PathfindCell::removeFromOpenList','void PathfindCell::forwardInsertionSortRetailCompatible',
            'void PathfindCell::forwardInsertionSort(', 'void PathfindCell::reverseInsertionSort(',
            'UnsignedInt PathfindCell::getTotalCostDifference']
functions=[method(cell,s) for s in signatures]
functions.append(method(listing,'Bool PathfindCellList::canReverseSort'))
guards=method(telemetry,'inline bool allowed()')+'\n'+method(telemetry,'inline bool heapAllowed()')
cpp=r'''
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>
#include "HEAP"
#include "TELEMETRY"
#include "POLICY"
#define RETAIL_COMPATIBLE_PATHFINDING 1
#define DEBUG_ASSERTCRASH(condition,message) assert(condition)
using Bool=bool;using Int=int;using UnsignedInt=unsigned;constexpr bool FALSE=false,TRUE=true;
constexpr unsigned PATHFIND_CELLS_PER_FRAME=5000;
static bool s_useFixedPathfinding=false;
class PathfindCell;
struct PathfindCellInfo {PathfindCellInfo *m_nextOpen=nullptr,*m_prevOpen=nullptr;PathfindCell *m_cell=nullptr;
    uint16_t m_totalCost=0;bool m_open=false,m_closed=false;};
class PathfindCellList {friend class PathfindCell;public:PathfindCell *m_head=nullptr,*m_tail=nullptr;
    void reset(PathfindCell *head=nullptr){m_head=head;m_tail=nullptr;}Bool canReverseSort(PathfindCell&)const;};
class PathfindCell {public:PathfindCellInfo *m_info=nullptr;
    unsigned getTotalCost()const{return m_info->m_totalCost;}
    Bool hasInfo()const{return m_info!=nullptr;}
    PathfindCell *getNextOpen(){return m_info->m_nextOpen?m_info->m_nextOpen->m_cell:nullptr;}
    PathfindCell *getPrevOpen(){return m_info->m_prevOpen?m_info->m_prevOpen->m_cell:nullptr;}
    UnsignedInt getTotalCostDifference(PathfindCell&other)const;
    void forwardInsertionSortRetailCompatible(PathfindCellList&);void forwardInsertionSort(PathfindCellList&);
    void reverseInsertionSort(PathfindCellList&);void putOnSortedOpenList(PathfindCellList&);void removeFromOpenList(PathfindCellList&);
    static void prepareHeapList(PathfindCellList&);
};
FUNCTIONS
struct Logic {bool multiplayer=false,replay=false,ingame=true,shell=false;
 bool isInGame(){return ingame;}bool isInShellGame(){return shell;}bool isInMultiplayerGame(){return multiplayer;}bool isInReplayGame(){return replay;}};
Logic logic,*TheGameLogic=&logic;
namespace zhpf {GUARDS}
struct Event {char op;unsigned node,cost;};
static std::vector<unsigned> run(const std::vector<Event>&events,bool heap){
    std::vector<PathfindCellInfo> info(6500);std::vector<PathfindCell> cells(6500);
    for(unsigned i=0;i<cells.size();++i){cells[i].m_info=&info[i];info[i].m_cell=&cells[i];}
    PathfindCellList list;zhpf::HeapScope scope(heap);std::vector<unsigned> result;
    for(auto event:events){auto &cell=cells[event.node];
        if(event.op=='I'){cell.m_info->m_totalCost=static_cast<uint16_t>(event.cost);cell.putOnSortedOpenList(list);}
        if(event.op=='R'){cell.m_info->m_totalCost=static_cast<uint16_t>(event.cost);cell.removeFromOpenList(list);}
        if(event.op=='S'){cell.m_info->m_totalCost=static_cast<uint16_t>(event.cost);cell.m_info->m_open=true;list.reset(&cell);zhpf::seedHeap(&cell,cell.getTotalCost(),&list);}
        if(event.op=='H')result.push_back(list.m_head?static_cast<unsigned>(list.m_head-cells.data()):99999);
    }
    PathfindCell::prepareHeapList(list);
    unsigned visited=0;for(auto *next=list.m_head;next;next=next->getNextOpen()){
        assert(++visited<=cells.size());result.push_back(static_cast<unsigned>(next-cells.data()));
    }return result;
}
int main(){
    std::vector<std::vector<Event>> cases;
    cases.push_back({{'S',0,10},{'I',1,10},{'I',2,5},{'H',0,0},{'R',2,30},{'H',0,0},{'R',0,1},{'I',0,10},{'H',0,0}});
    for(bool ties:{false,true}){std::vector<Event> events;
        for(unsigned i=0;i<6003;++i){events.push_back({'I',i,ties?7:i});if(i%113==0)events.push_back({'H',0,0});}
        cases.push_back(events);
    }
    for(unsigned population:{32u,512u}){std::mt19937 random(761);std::vector<bool> present(population);std::vector<Event> events;
        for(unsigned i=0;i<30000;++i){unsigned node=random()%population;events.push_back({present[node]?'R':'I',node,random()%32});present[node]=!present[node];events.push_back({'H',0,0});}
        cases.push_back(events);
    }
    unsigned checked=0;
    for(bool fixed:{false,true}){s_useFixedPathfinding=fixed;for(auto &events:cases){assert(run(events,false)==run(events,true));++checked;}}
    unsigned modes=0;
    // Default (variable unset) is Heap in singleplayer; MP/replay always fall back to List.
    for(bool multiplayer:{false,true})for(bool replay:{false,true}){
        _putenv_s("ZH_PF_HEAP","");
        logic={};logic.ingame=true;logic.multiplayer=multiplayer;logic.replay=replay;
        assert(zhpf::heapAllowed()==(!multiplayer&&!replay));++modes;
    }
    for(bool multiplayer:{false,true})for(bool replay:{false,true}){
        _putenv_s("ZH_PF_HEAP","0");
        logic={};logic.ingame=true;logic.multiplayer=multiplayer;logic.replay=replay;
        assert(!zhpf::heapAllowed());++modes;
    }
    _putenv_s("ZH_PF_HEAP","1");
    logic={};logic.ingame=true;assert(zhpf::heapAllowed());++modes;
    logic={};logic.ingame=false;assert(!zhpf::heapAllowed());++modes;
    logic={};logic.shell=true;assert(!zhpf::heapAllowed());++modes;
    logic={};for(const char *token:{"invalid"}){_putenv_s("ZH_PF_HEAP",token);assert(!zhpf::heapAllowed());++modes;}
    std::printf("PASS: %u actual-method queue cases (retail/fixed, 5000-cell cap, ties, reinsertion, cleanup), %u mode guards\n",checked,modes);
}
'''
for marker,relative in [('HEAP','Core/GameEngine/Include/Common/PathfindHeap.h'),('TELEMETRY','Core/GameEngine/Include/Common/PathfindTelemetry.h'),('POLICY','Core/GameEngine/Include/Common/OptimizationPolicy.h')]:
    cpp=cpp.replace(chr(34)+marker+chr(34),chr(34)+(vendor/relative).as_posix()+chr(34))
cpp=cpp.replace('FUNCTIONS','\n'.join(functions)).replace('GUARDS',guards)
(output/'integration.cpp').write_text(cpp,encoding='utf-8')
(output/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.20)\nproject(heap_integration LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 20)\nadd_executable(heap_integration integration.cpp)\ntarget_compile_options(heap_integration PRIVATE /UNDEBUG)\n',encoding='utf-8')
(output/'extracted-methods.json').write_text(json.dumps({s:hashlib.sha256(f.encode()).hexdigest() for s,f in zip(signatures,functions)},indent=2)+'\n',encoding='utf-8')
for name,command in [('configure',['cmake','-S',str(output),'-B',str(output/'build'),'-G','Visual Studio 17 2022','-A','Win32']),('build',['cmake','--build',str(output/'build'),'--config','Release','--','/m:1','/nodeReuse:false']),('run',[str(output/'build/Release/heap_integration.exe')])]:
    result=subprocess.run(command,capture_output=True,text=True)
    (output/(name+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode:raise RuntimeError(f'{name} failed; see {output/name}.log')
    if name=='run':print(result.stdout,end='')
