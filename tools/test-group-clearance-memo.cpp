#include "GameLogic/Pathfinder/GroupClearanceMemo.h"

#include <cassert>
#include <cstdio>

int main()
{
    GroupClearanceMemo memo;
    int calls = 0;
    int width = 6;
    const auto clearance = [&] { ++calls; return width; };

    assert(memo.get(1, 2, 1, 6, false, clearance) == 6 && calls == 1);
    {
        GroupClearanceMemo::Scope search(memo, true);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 6 && calls == 2);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 6 && calls == 2);
        assert(memo.get(8193, 2, 1, 6, false, clearance) == 6 && calls == 3);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 6 && calls == 4);
        assert(memo.get(1, 3, 1, 6, false, clearance) == 6 && calls == 5);
        assert(memo.get(1, 2, 2, 6, false, clearance) == 6 && calls == 6);
        assert(memo.get(1, 2, 1, 4, false, clearance) == 6 && calls == 7);
        assert(memo.get(1, 2, 1, 6, true, clearance) == 6 && calls == 8);
    }

    width = 2;
    {
        GroupClearanceMemo::Scope search(memo, true);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 2 && calls == 9);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 2 && calls == 9);
        memo.invalidate();
        width = 0;
        assert(memo.get(1, 2, 1, 6, false, clearance) == 0 && calls == 10);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 0 && calls == 11);
    }

    {
        GroupClearanceMemo::Scope outer(memo, true);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 0 && calls == 12);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 0 && calls == 12);
        {
            GroupClearanceMemo::Scope nested(memo, true);
            width = 4;
            assert(memo.get(1, 2, 1, 6, false, clearance) == 4 && calls == 13);
        }
        assert(memo.get(1, 2, 1, 6, false, clearance) == 4 && calls == 14);
    }

    {
        GroupClearanceMemo::Scope disabled(memo, false);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 4 && calls == 15);
        assert(memo.get(1, 2, 1, 6, false, clearance) == 4 && calls == 16);
    }
    std::puts("PASS: clearance hits, full keys, collisions, fresh occupancy, recovery, recursion and disabled scope");
}
