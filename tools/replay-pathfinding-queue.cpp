// T-022 offline queue evaluation. Replays real engine operations; never changes the game.
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>
#include "../vendor/GeneralsGameCode/Core/GameEngine/Include/Common/PathfindHeap.h"
struct Event { uint32_t op,node,cost; };
static_assert(sizeof(Event)==12);
constexpr uint32_t nil=std::numeric_limits<uint32_t>::max();
struct Node { uint32_t cost=0,prev=nil,next=nil,position=0,epoch=0; uint64_t sequence=0; bool present=false; };
struct List {
    std::vector<Node> nodes;
    uint32_t head=nil,epoch=0;
    explicit List(size_t n):nodes(n){}
    void reset(){head=nil;++epoch;}
    bool has(uint32_t id)const{return nodes[id].epoch==epoch&&nodes[id].present;}
    void insert(uint32_t id,uint32_t cost){
        if(has(id))throw std::runtime_error("duplicate list insert");
        Node &n=nodes[id]; n.cost=cost;n.epoch=epoch;n.present=true;
        uint32_t current=head,previous=nil,count=0;
        // Exact original retail forward insertion rule, including its 5,000-cell cap.
        while(current!=nil&&count<5000&&nodes[current].cost<=cost){++count;previous=current;current=nodes[current].next;}
        n.prev=previous;n.next=current;
        if(previous!=nil)nodes[previous].next=id;else head=id;
        if(current!=nil)nodes[current].prev=id;
    }
    void remove(uint32_t id){
        if(!has(id))throw std::runtime_error("list remove missing node");
        Node &n=nodes[id];if(n.prev!=nil)nodes[n.prev].next=n.next;else head=n.next;
        if(n.next!=nil)nodes[n.next].prev=n.prev;n.present=false;
    }
    uint32_t top()const{return head;}
};
struct Heap {
    std::vector<Node> nodes;
    std::vector<uint32_t> heap;
    uint32_t epoch=0;uint64_t sequence=0;
    explicit Heap(size_t n):nodes(n){heap.reserve(n);}
    bool has(uint32_t id)const{return nodes[id].epoch==epoch&&nodes[id].present;}
    bool less(uint32_t a,uint32_t b)const{return nodes[a].cost<nodes[b].cost||(nodes[a].cost==nodes[b].cost&&nodes[a].sequence<nodes[b].sequence);}
    void swapAt(size_t a,size_t b){std::swap(heap[a],heap[b]);nodes[heap[a]].position=static_cast<uint32_t>(a);nodes[heap[b]].position=static_cast<uint32_t>(b);}
    void up(size_t p){while(p){size_t parent=(p-1)/2;if(!less(heap[p],heap[parent]))break;swapAt(p,parent);p=parent;}}
    void down(size_t p){for(;;){size_t left=2*p+1;if(left>=heap.size())return;size_t child=left;
        if(left+1<heap.size()&&less(heap[left+1],heap[left]))child=left+1;
        if(!less(heap[child],heap[p]))return;swapAt(child,p);p=child;}}
    void reset(){heap.clear();++epoch;sequence=0;}
    void insert(uint32_t id,uint32_t cost){if(has(id))throw std::runtime_error("duplicate heap insert");
        Node &n=nodes[id];n.cost=cost;n.sequence=sequence++;n.epoch=epoch;n.present=true;
        n.position=static_cast<uint32_t>(heap.size());heap.push_back(id);up(heap.size()-1);}
    void remove(uint32_t id){if(!has(id))throw std::runtime_error("heap remove missing node");
        size_t p=nodes[id].position;nodes[id].present=false;
        if(p==heap.size()-1){heap.pop_back();return;}
        heap[p]=heap.back();heap.pop_back();nodes[heap[p]].position=static_cast<uint32_t>(p);
        if(p&&less(heap[p],heap[(p-1)/2]))up(p);else down(p);}
    uint32_t top()const{return heap.empty()?nil:heap[0];}
};
// Verify the actual request-heap header, including sorted cleanup, not only the offline candidate.
static void verifyProduction(const std::vector<Event>&events,unsigned nodeCount){
    struct Cell {uint32_t padding[4];};std::vector<Cell> cells(nodeCount);
    List reference(nodeCount);zhpf::HeapContext production;
    for(const Event &event:events){
        void *cell=&cells[event.node];
        switch(event.op){
            case 0:reference.reset();production.begin();break;
            case 1:reference.insert(event.node,event.cost);production.insert(cell,event.cost);break;
            case 2:reference.remove(event.node);production.remove(cell);break;
            case 3:if(production.top()!=&cells[reference.top()])throw std::runtime_error("production heap head mismatch");break;
            case 4:{production.sortForCleanup();unsigned next=reference.top();
                for(void *value:production.ordered){if(next==nil||value!=&cells[next])throw std::runtime_error("production cleanup order mismatch");next=reference.nodes[next].next;}
                if(next!=nil)throw std::runtime_error("production cleanup lost a cell");break;}
        }
    }
}
template<class Queue> uint64_t replay(Queue &queue,const std::vector<Event>&events,bool verify){
    uint64_t hash=14695981039346656037ull;uint32_t request=0;
    for(size_t i=0;i<events.size();++i){const Event &e=events[i];
        switch(e.op){
            case 0:queue.reset();++request;break;
            case 1:queue.insert(e.node,e.cost);break;
            case 2:queue.remove(e.node);break;
            case 3:{uint32_t actual=queue.top();if(verify&&actual!=e.node){
                std::cerr<<"first divergence request="<<request<<" event="<<i<<" expected="<<e.node<<" actual="<<actual<<"\n";
                throw std::runtime_error("head parity failure");}
                hash^=actual;hash*=1099511628211ull;break;}
            case 4:break;
            default:throw std::runtime_error("bad operation");
        }
    }return hash;
}
template<class Queue> double timedReplay(Queue &queue,const std::vector<Event>&events,uint64_t expected){
    auto begin=std::chrono::steady_clock::now();uint64_t hash=replay(queue,events,false);
    auto end=std::chrono::steady_clock::now();if(hash!=expected)throw std::runtime_error("benchmark checksum changed");
    return std::chrono::duration<double,std::milli>(end-begin).count();
}
int main(int argc,char**argv){try{
    if(argc!=2)throw std::runtime_error("usage: replay-pathfinding-queue trace.bin");
    std::ifstream in(argv[1],std::ios::binary);char magic[4];uint32_t header[3];in.read(magic,4);in.read(reinterpret_cast<char*>(header),12);
    if(!in||std::string(magic,4)!="PFQ1")throw std::runtime_error("bad header");
    std::vector<Event> events(header[1]);in.read(reinterpret_cast<char*>(events.data()),static_cast<std::streamsize>(events.size()*sizeof(Event)));
    if(!in)throw std::runtime_error("truncated trace");
    verifyProduction(events,header[0]);
    List list(header[0]);Heap heap(header[0]);uint64_t reference=replay(list,events,true),candidate=replay(heap,events,true);
    if(reference!=candidate)throw std::runtime_error("aggregate parity failure");
    std::vector<double> a,b;
    for(int pair=0;pair<9;++pair){
        if(pair%2){b.push_back(timedReplay(heap,events,reference));a.push_back(timedReplay(list,events,reference));}
        else {a.push_back(timedReplay(list,events,reference));b.push_back(timedReplay(heap,events,reference));}
    }
    auto median=[](std::vector<double> v){std::sort(v.begin(),v.end());return v[v.size()/2];};
    std::cout<<"{\"requests\":"<<header[2]<<",\"events\":"<<header[1]<<",\"nodes\":"<<header[0]
        <<",\"heads_equal\":true,\"production_heads_cleanup_equal\":true,\"checksum\":"<<reference<<",\"list_median_ms\":"<<median(a)<<",\"heap_median_ms\":"<<median(b)
        <<",\"heap_over_list\":"<<median(b)/median(a)<<",\"list_samples_ms\":[";
    for(size_t i=0;i<a.size();++i)std::cout<<(i?",":"")<<a[i];std::cout<<"],\"heap_samples_ms\":[";
    for(size_t i=0;i<b.size();++i)std::cout<<(i?",":"")<<b[i];std::cout<<"]}\n";
    return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
