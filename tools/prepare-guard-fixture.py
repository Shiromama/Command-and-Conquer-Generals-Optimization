"""Temporarily prepare control/fixed runtime fixtures in the isolated alpha tree; restore before packaging."""
import argparse,hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['control','fixed','restore']);args=parser.parse_args()
source=root/'build/alpha-engine-source';evidence=root/'artifacts/2026-11-18-guard-range/fixture-source';evidence.mkdir(parents=True,exist_ok=True)
logic_rel='GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp';guard_rel='GeneralsMD/Code/GameEngine/Source/GameLogic/AI/AIGuard.cpp'
for name,rel in [('shipping-logic.cpp',logic_rel),('shipping-guard.cpp',guard_rel)]:
    backup=evidence/name
    if not backup.exists():backup.write_bytes((source/rel).read_bytes())
if args.mode=='restore':
    for name,rel in [('shipping-logic.cpp',logic_rel),('shipping-guard.cpp',guard_rel)]:
        (source/rel).write_bytes((evidence/name).read_bytes())
    print('Restored shipping alpha source; rebuild required before packaging')
else:
    logic=(root/'vendor/GeneralsGameCode'/logic_rel).read_text(encoding='utf-8')
    fixture=(root/'tools/guard-range-fixture.inc').read_text(encoding='utf-8')
    fixture='#include "GameNetwork/GameInfo.h"\n#include "Common/PlayerTemplate.h"\n'+fixture
    logic=logic.replace('#include "PathfindHarness.inc"','#include "PathfindHarness.inc"\n'+fixture)
    logic=logic.replace('    zhPathfindHarness(this);','    zhPathfindHarness(this);\n    zhGuardFixture(this);')
    assert '    zhGuardFixture(this);' in logic
    setup=r'''
                // Development fixture starts an ordinary skirmish with a real human slot.
                if (!TheSkirmishGameInfo) TheSkirmishGameInfo = NEW SkirmishGameInfo;
                TheSkirmishGameInfo->reset();
                TheSkirmishGameInfo->setInGame();
                TheSkirmishGameInfo->setLocalIP(0);
                TheSkirmishGameInfo->setMap(AsciiString(autoMap));
                TheSkirmishGameInfo->setSeed(1);
                TheSkirmishGameInfo->setUseStats(0);
                const Int faction = ThePlayerTemplateStore->getTemplateNumByName("FactionAmerica");
                UnicodeString name; name.set(L"Guard range check");
                for (Int slot = 0; slot < MAX_SLOTS; ++slot)
                {
                    GameSlot* info = TheSkirmishGameInfo->getSlot(slot);
                    info->setState(slot == 0 ? SLOT_PLAYER : slot == 1 ? SLOT_EASY_AI : SLOT_CLOSED, name, 0);
                    info->setPlayerTemplate(faction);
                    info->setColor(slot);
                    info->setStartPos(slot);
                    info->setTeamNumber(-1);
                }
                TheGameInfo = TheSkirmishGameInfo;
                TheWritableGlobalData->m_mapName.set(autoMap);
                TheSkirmishGameInfo->startGame(0);
'''
    anchor='TheWritableGlobalData->m_pendingFile.set(autoMap);'
    assert logic.count(anchor)==1
    logic=logic.replace(anchor,anchor+setup).replace('startMsg->appendIntegerArgument(GAME_SINGLE_PLAYER);','startMsg->appendIntegerArgument(GAME_SKIRMISH);')
    (source/logic_rel).write_text(logic,encoding='utf-8')
    if args.mode=='control':
        (source/guard_rel).write_bytes((root/'vendor/GeneralsGameCode'/guard_rel).read_bytes())
    else:(source/guard_rel).write_bytes((evidence/'shipping-guard.cpp').read_bytes())
    print(f'Prepared {args.mode} development fixture; not a shipping build')
(evidence/'current.json').write_text(json.dumps(dict(mode=args.mode,logic_sha256=hashlib.sha256((source/logic_rel).read_bytes()).hexdigest(),guard_sha256=hashlib.sha256((source/guard_rel).read_bytes()).hexdigest()),indent=2)+'\n',encoding='utf-8')
