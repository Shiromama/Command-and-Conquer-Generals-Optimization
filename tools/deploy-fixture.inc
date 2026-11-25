// T-120 development-only unattended fixture. Injected into an isolated source tree by
// prepare-deploy-fixture.py. Never part of the shipping source or a packaged build.
//
// Cases:
//   deploy_guard  - China Nuke Cannon in a real human slot, deploy/shot/move coverage,
//                   control-vs-ZH_DEPLOY_GUARD_HOLD verdict.
//   path_bench    - deterministic ground group-move workload for ZH_PF_FRAME / cache tests.
//
// The fixture starts a skirmish from ZH_FIXTURE_MAP, writes a heartbeat every 30 frames and
// one final result JSON. It is gated to local singleplayer and requires a real human slot.

#include "Common/NameKeyGenerator.h"
#include "Common/OptimizationPolicy.h"
#include "Common/PlayerTemplate.h"
#include "Common/ThingFactory.h"
#include "Common/ThingTemplate.h"
#include "GameClient/InGameUI.h"
#include "GameClient/View.h"
#include "GameLogic/AI.h"
#include "GameLogic/AIGuard.h"
#include "GameLogic/Pathfinder/PathfindCell.h"
#include "GameLogic/Module/BodyModule.h"
#include "GameLogic/Weapon.h"
#include "GameNetwork/GameInfo.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

extern unsigned g_zhPfCacheMismatches;

namespace {

enum DfStage
{
    DF_SETUP = 0,
    DF_WAIT_DEPLOY,
    DF_WAIT_SHOT,
    DF_GUARD_SETTLE,
    DF_OBSERVE_MOVE,
    DF_STOP,
    DF_OBSERVE_POSTSTOP,
    DF_PATH_SETUP,
    DF_PATH_WAVES,
    DF_FORMATION_WAIT,
    DF_VISION_WAIT,
    DF_AVOID_WAIT,
    DF_DONE
};

struct DfState
{
    bool startAttempted;
    bool inGameSeen;
    bool done;
    bool hold;
    bool pathBench;
    bool sawHuman;
    bool sawEnemy;
    bool templateFound;
    bool deployModule;
    bool targetVisible;
    bool deployed;
    bool fired;
    bool movedDuringGuard;
    bool unpackedDuringGuard;
    bool movedAfterStop;
    bool unpackedAfterStop;
    bool pathSpawned;
    bool postStopMoveIssued;
    int stage;
    unsigned stageFrame;
    unsigned guardFrame;
    unsigned firstShotFrame;
    unsigned moveFrame;
    unsigned postStopFrame;
    unsigned pathWave;
    unsigned pathWaves;
    unsigned pathInterval;
    float maxDisplacement;
    float maxPostStopDisplacement;
    Coord3D center;
    Coord3D farA;
    Coord3D farB;
    ObjectID unit;
    ObjectID target;
    ObjectID pathUnits[400];
    int pathUnitCount;
    int cacheQueries;
    int cacheHits;
    bool formation;
    bool relax;
    bool visionCase;
    bool avoidCase;
    bool longRange;
    bool avoidEnabled;
    float visionRange;
    float shroudRange;
    float shroudClearingRange;
    float guardRange;
    float weaponRange;
    int avoidWidth;
    int avoidFlags;
    int avoidCrushable;
    int avoidStatus;
    int avoidCellObject;
    unsigned avoidUnitId;
    unsigned avoidCellUnitId;
    bool leaderUsable;
    bool alternateUsable;
    bool formationMoved;
    bool groupIdle;
    int groupCount;
    int membersMoving;
    int membersWithPath;
    unsigned firstPathAge;
    int firstPathNodes;
    float firstPathX, firstPathY, firstUnitX, firstUnitY;
    int formationUnits;
    ObjectID formationFirst;
    Coord3D formationStart;
    char formationFailure[64];
    char blockerAt[16];
};

DfState s_df;
AIGroupPtr s_formationGroup;

const char* dfEnv(const char* name, const char* fallback)
{
    const char* value = std::getenv(name);
    return (value && *value) ? value : fallback;
}

bool dfFlag(const char* name)
{
    const char* value = std::getenv(name);
    return value && std::atoi(value) != 0;
}

int dfInt(const char* name, int fallback, int low, int high)
{
    const char* value = std::getenv(name);
    int result = value ? std::atoi(value) : fallback;
    if (result < low) result = low;
    if (result > high) result = high;
    return result;
}

const char* dfResultPath()
{
    const char* path = std::getenv("ZH_FIXTURE_RESULT");
    return (path && *path) ? path : nullptr;
}

void dfComplete(Object* object)
{
    for (BehaviorModule** module = object->getBehaviorModules(); *module; ++module)
    {
        CreateModuleInterface* create = (*module)->getCreate();
        if (create) create->onBuildComplete();
    }
    TheAI->pathfinder()->addObjectToPathfindMap(object);
}

void dfWriteHeartbeat(GameLogic* logic)
{
    const char* path = dfResultPath();
    if (!path) return;
    char heartbeat[512];
    _snprintf(heartbeat, sizeof(heartbeat) - 1, "%s.heartbeat", path);
    heartbeat[sizeof(heartbeat) - 1] = 0;
    FILE* file = std::fopen(heartbeat, "w");
    if (!file) return;
    Object* unit = logic->findObjectByID(s_df.unit);
    std::fprintf(file, "frame=%u\nstage=%d\nunit=%u\ndeployed=%d\nmoved=%d\nfired=%d\ncache_mismatches=%u\n",
        logic->getFrame(), s_df.stage, s_df.unit,
        unit && unit->testStatus(OBJECT_STATUS_DEPLOYED) ? 1 : 0,
        s_df.movedDuringGuard ? 1 : 0, s_df.fired ? 1 : 0, g_zhPfCacheMismatches);
    std::fclose(file);
}

void dfJsonEscape(const char* input, char* output, size_t outputSize)
{
    size_t j = 0;
    for (; input && *input && j + 2 < outputSize; ++input)
    {
        if (*input == '\\' || *input == '"')
        {
            output[j++] = '\\';
            output[j++] = *input;
        }
        else if (*input == '\n')
        {
            output[j++] = '\\';
            output[j++] = 'n';
        }
        else if (*input != '\r')
        {
            output[j++] = *input;
        }
    }
    output[j] = 0;
}

void dfWriteResult(const char* status, const char* failure)
{
    if (s_df.done) return;
    const char* path = dfResultPath();
    if (!path) return;
    FILE* file = std::fopen(path, "w");
    if (!file) return;
    Object* unit = TheGameLogic ? TheGameLogic->findObjectByID(s_df.unit) : nullptr;
    const char* unitTemplate = unit && unit->getTemplate() ? unit->getTemplate()->getName().str() : "";
    char mapEscaped[1024];
    char templateEscaped[256];
    char failureEscaped[512];
    char statusEscaped[64];
    char formationFailureEscaped[128];
    dfJsonEscape(dfEnv("ZH_FIXTURE_MAP", ""), mapEscaped, sizeof(mapEscaped));
    dfJsonEscape(unitTemplate, templateEscaped, sizeof(templateEscaped));
    dfJsonEscape(failure ? failure : "", failureEscaped, sizeof(failureEscaped));
    dfJsonEscape(status, statusEscaped, sizeof(statusEscaped));
    dfJsonEscape(s_df.formationFailure, formationFailureEscaped, sizeof(formationFailureEscaped));
    const char* caseName = s_df.pathBench ? "path_bench_v1"
        : s_df.formation ? "formation_start_v1"
        : s_df.visionCase ? "vision_probe_v1"
        : s_df.avoidCase ? "avoid_probe_v1" : "deploy_guard_v1";
    const char* modeName = s_df.formation ? (s_df.relax ? "relax" : "control")
        : s_df.visionCase ? (s_df.longRange ? "long-range" : "legacy")
        : s_df.avoidCase ? (s_df.avoidEnabled ? "avoid-on" : "avoid-off")
        : (s_df.hold ? "hold" : "control");
    std::fprintf(file,
        "{\n"
        "  \"schema\": 1,\n"
        "  \"case\": \"%s\",\n"
        "  \"status\": \"%s\",\n"
        "  \"mode\": \"%s\",\n"
        "  \"frame\": %u,\n"
        "  \"map\": \"%s\",\n"
        "  \"unit_template\": \"%s\",\n"
        "  \"cache_mismatches\": %u,\n"
        "  \"coverage\": {\"human_slot\": %s, \"enemy_ai\": %s, \"template_found\": %s, "
        "\"deploy_module\": %s, \"target_visible\": %s, \"deployed\": %s, \"fired\": %s, "
        "\"move_issued\": %s, \"post_stop_move_issued\": %s, \"path_units\": %d, "
        "\"formation_units\": %d},\n"
        "  \"observed\": {\"moved_during_guard\": %s, \"unpacked_during_guard\": %s, "
        "\"moved_after_stop\": %s, \"unpacked_after_stop\": %s, \"max_displacement\": %.3f, "
        "\"max_post_stop_displacement\": %.3f, \"first_shot_frame\": %u, \"cache_queries\": %d, "
        "\"cache_hits\": %d, \"path_waves\": %u, \"leader_usable\": %s, \"alternate_usable\": %s, "
        "\"last_failure\": \"%s\", \"formation_moved\": %s, \"group_idle\": %s, \"group_count\": %d, "
        "\"members_moving\": %d, \"members_with_path\": %d, \"first_path_age\": %u, "
        "\"first_path_nodes\": %d, \"first_path_x\": %.1f, \"first_path_y\": %.1f, \"first_unit_x\": %.1f, \"first_unit_y\": %.1f, \"vision_range\": %.3f, "
        "\"shroud_range\": %.3f, \"shroud_clearing\": %.3f, \"guard_range\": %.3f, "
        "\"weapon_range\": %.3f, \"avoid_width\": %d, \"avoid_flags\": %d, \"avoid_crushable\": %d, "
        "\"avoid_status\": %d, \"avoid_cell_object\": %d, \"avoid_unit_id\": %u, "
        "\"avoid_cell_unit_id\": %u},\n"
        "  \"first_failure\": \"%s\"\n"
        "}\n",
        caseName,
        statusEscaped,
        modeName,
        TheGameLogic ? TheGameLogic->getFrame() : 0,
        mapEscaped,
        templateEscaped,
        g_zhPfCacheMismatches,
        s_df.sawHuman ? "true" : "false",
        s_df.sawEnemy ? "true" : "false",
        s_df.templateFound ? "true" : "false",
        s_df.deployModule ? "true" : "false",
        s_df.targetVisible ? "true" : "false",
        s_df.deployed ? "true" : "false",
        s_df.fired ? "true" : "false",
        s_df.moveFrame ? "true" : "false",
        s_df.postStopMoveIssued ? "true" : "false",
        s_df.pathUnitCount,
        s_df.formationUnits,
        s_df.movedDuringGuard ? "true" : "false",
        s_df.unpackedDuringGuard ? "true" : "false",
        s_df.movedAfterStop ? "true" : "false",
        s_df.unpackedAfterStop ? "true" : "false",
        s_df.maxDisplacement,
        s_df.maxPostStopDisplacement,
        s_df.firstShotFrame,
        s_df.cacheQueries,
        s_df.cacheHits,
        s_df.pathWave,
        s_df.leaderUsable ? "true" : "false",
        s_df.alternateUsable ? "true" : "false",
        formationFailureEscaped,
        s_df.formationMoved ? "true" : "false",
        s_df.groupIdle ? "true" : "false",
        s_df.groupCount,
        s_df.membersMoving,
        s_df.membersWithPath,
        s_df.firstPathAge,
        s_df.firstPathNodes,
        s_df.firstPathX,
        s_df.firstPathY,
        s_df.firstUnitX,
        s_df.firstUnitY,
        s_df.visionRange,
        s_df.shroudRange,
        s_df.shroudClearingRange,
        s_df.guardRange,
        s_df.weaponRange,
        s_df.avoidWidth,
        s_df.avoidFlags,
        s_df.avoidCrushable,
        s_df.avoidStatus,
        s_df.avoidCellObject,
        s_df.avoidUnitId,
        s_df.avoidCellUnitId,
        failureEscaped);
    std::fclose(file);
    s_df.done = true;
}

float dfDistance2D(const Coord3D& a, const Coord3D& b)
{
    const float dx = a.x - b.x;
    const float dy = a.y - b.y;
    return std::sqrt(dx * dx + dy * dy);
}

void dfCenterOfMap(Coord3D* center)
{
    Region3D extent;
    TheTerrainLogic->getExtent(&extent);
    center->x = (extent.lo.x + extent.hi.x) * 0.5f;
    center->y = (extent.lo.y + extent.hi.y) * 0.5f;
    center->z = TheTerrainLogic->getGroundHeight(center->x, center->y);
}

// The map centre can be a mesa edge. Pick a point at the requested distance whose ground
// height is close to the subject's height, so a 3D attack-range check is not dominated by a
// cliff. Falls back to the closest-height candidate.
void dfFlatPoint(const Coord3D& center, float angle, float distance, Coord3D* out)
{
    float bestDelta = 1.0e9f;
    Coord3D best = center;
    for (int i = 0; i < 24; ++i)
    {
        const float a = angle + i * (2.0f * 3.14159265f / 24.0f);
        Coord3D p;
        p.x = center.x + std::cos(a) * distance;
        p.y = center.y + std::sin(a) * distance;
        p.z = TheTerrainLogic->getGroundHeight(p.x, p.y);
        const float delta = std::fabs(p.z - center.z);
        if (delta < bestDelta)
        {
            bestDelta = delta;
            best = p;
        }
        if (delta < 12.0f)
        {
            *out = p;
            return;
        }
    }
    *out = best;
}

void dfStartGame(GameLogic* logic)
{
    if (s_df.startAttempted) return;
    const char* map = std::getenv("ZH_FIXTURE_MAP");
    if (!map || !*map) return;
    s_df.startAttempted = true;
    s_df.hold = dfFlag("ZH_DEPLOY_GUARD_HOLD");
    const char* fixtureCase = dfEnv("ZH_FIXTURE_CASE", "deploy_guard");
    s_df.pathBench = std::strcmp(fixtureCase, "path_bench") == 0;
    s_df.formation = std::strcmp(fixtureCase, "formation_start") == 0;
    s_df.visionCase = std::strcmp(fixtureCase, "vision_probe") == 0;
    s_df.avoidCase = std::strcmp(fixtureCase, "avoid_probe") == 0;
    s_df.relax = dfFlag("ZH_GROUP_START_RELAX");
    s_df.longRange = dfFlag("ZH_LONG_RANGE_VISION");
    s_df.avoidEnabled = dfFlag("ZH_DEPLOYED_AVOID");

    TheWritableGlobalData->m_pendingFile.set(map);
    if (!TheSkirmishGameInfo) TheSkirmishGameInfo = NEW SkirmishGameInfo;
    TheSkirmishGameInfo->reset();
    TheSkirmishGameInfo->setInGame();
    TheSkirmishGameInfo->setLocalIP(0);
    TheSkirmishGameInfo->setMap(AsciiString(map));
    TheSkirmishGameInfo->setSeed(dfInt("ZH_FIXTURE_SEED", 1, 0, 2147483647));
    TheSkirmishGameInfo->setUseStats(0);

    const Int humanFaction = ThePlayerTemplateStore->getTemplateNumByName("FactionChina");
    const Int enemyFaction = ThePlayerTemplateStore->getTemplateNumByName("FactionAmerica");
    UnicodeString name;
    name.set(L"T-120 fixture");
    for (Int slot = 0; slot < MAX_SLOTS; ++slot)
    {
        GameSlot* info = TheSkirmishGameInfo->getSlot(slot);
        info->setState(slot == 0 ? SLOT_PLAYER : slot == 1 ? SLOT_EASY_AI : SLOT_CLOSED, name, 0);
        info->setPlayerTemplate(slot == 0 ? humanFaction : enemyFaction);
        info->setColor(slot);
        info->setStartPos(slot);
        info->setTeamNumber(-1);
    }
    TheGameInfo = TheSkirmishGameInfo;
    TheWritableGlobalData->m_mapName.set(map);
    TheWritableGlobalData->m_shroudOn = false;
    TheSkirmishGameInfo->startGame(0);

    GameMessage* startMsg = TheMessageStream->appendMessage(GameMessage::MSG_NEW_GAME);
    startMsg->appendIntegerArgument(GAME_SKIRMISH);
    startMsg->appendIntegerArgument(DIFFICULTY_NORMAL);
    startMsg->appendIntegerArgument(0);
    InitRandom(dfInt("ZH_FIXTURE_SEED", 1, 0, 2147483647));
    if (TheShell) TheShell->hideShell();
}

bool dfFindPlayers(GameLogic* logic)
{
    Player* neutral = ThePlayerList->getNeutralPlayer();
    Player* human = ThePlayerList->getLocalPlayer();
    Player* enemy = nullptr;
    for (Int p = 0; p < ThePlayerList->getPlayerCount(); ++p)
    {
        Player* candidate = ThePlayerList->getNthPlayer(p);
        if (candidate && candidate != human && candidate != neutral
            && candidate->getPlayerType() == PLAYER_COMPUTER)
        {
            enemy = candidate;
            break;
        }
    }
    s_df.sawHuman = human && human->getPlayerType() == PLAYER_HUMAN;
    s_df.sawEnemy = enemy != nullptr;
    if (!s_df.sawHuman || !s_df.sawEnemy)
    {
        dfWriteResult("invalid_fixture", "no real human slot or AI opponent");
        return false;
    }
    if (human->getRelationship(enemy->getDefaultTeam()) != ENEMIES)
        human->setPlayerRelationship(enemy, ENEMIES);
    if (enemy->getRelationship(human->getDefaultTeam()) != ENEMIES)
        enemy->setPlayerRelationship(human, ENEMIES);
    TheWritableGlobalData->m_shroudOn = false;
    return true;
}

Player* dfEnemyPlayer(Player* human)
{
    Player* neutral = ThePlayerList->getNeutralPlayer();
    for (Int p = 0; p < ThePlayerList->getPlayerCount(); ++p)
    {
        Player* candidate = ThePlayerList->getNthPlayer(p);
        if (candidate && candidate != human && candidate != neutral
            && candidate->getPlayerType() == PLAYER_COMPUTER)
            return candidate;
    }
    return nullptr;
}

Team* dfPlayerTeam(GameLogic* logic, Player* player)
{
    Team* team = nullptr;
    for (Object* obj = logic->getFirstObject(); obj; obj = obj->getNextObject())
    {
        if (obj->getControllingPlayer() == player)
        {
            team = obj->getTeam();
            break;
        }
    }
    if (!team && player) team = player->getDefaultTeam();
    return team;
}

void dfSetupVision(GameLogic* logic)
{
    if (!dfFindPlayers(logic)) return;
    Player* human = ThePlayerList->getLocalPlayer();
    Team* humanTeam = dfPlayerTeam(logic, human);
    const ThingTemplate* mobile = TheThingFactory->findTemplate(
        dfEnv("ZH_FIXTURE_TEMPLATE", "ChinaVehicleNukeLauncher"));
    if (!humanTeam || !mobile)
    {
        dfWriteResult("invalid_fixture", "vision unit or team missing");
        return;
    }
    Coord3D center;
    dfCenterOfMap(&center);
    Object* unit = TheThingFactory->newObject(mobile, humanTeam);
    if (!unit)
    {
        dfWriteResult("invalid_fixture", "vision unit creation failed");
        return;
    }
    unit->setPosition(&center);
    unit->setOrientation(0);
    dfComplete(unit);
    s_df.unit = unit->getID();
    s_df.visionRange = unit->getVisionRange();
    s_df.shroudRange = unit->getShroudRange();
    s_df.shroudClearingRange = unit->getShroudClearingRange();
    const Weapon* weapon = unit->getWeaponInWeaponSlot(PRIMARY_WEAPON);
    s_df.weaponRange = weapon ? weapon->getAttackRange(unit) : 0.0f;
    s_df.guardRange = AIGuardMachine::getStdGuardRange(unit);
    s_df.stage = DF_VISION_WAIT;
    s_df.stageFrame = logic->getFrame();
}

void dfSetupAvoid(GameLogic* logic)
{
    if (!dfFindPlayers(logic)) return;
    Player* human = ThePlayerList->getLocalPlayer();
    Team* humanTeam = dfPlayerTeam(logic, human);
    const ThingTemplate* mobile = TheThingFactory->findTemplate(
        dfEnv("ZH_FIXTURE_TEMPLATE", "ChinaVehicleNukeLauncher"));
    if (!humanTeam || !mobile)
    {
        dfWriteResult("invalid_fixture", "avoid unit or team missing");
        return;
    }
    Coord3D center;
    dfCenterOfMap(&center);
    Object* unit = TheThingFactory->newObject(mobile, humanTeam);
    if (!unit)
    {
        dfWriteResult("invalid_fixture", "avoid unit creation failed");
        return;
    }
    unit->setPosition(&center);
    unit->setOrientation(0);
    dfComplete(unit);
    unit->setStatus(MAKE_OBJECT_STATUS_MASK(OBJECT_STATUS_DEPLOYED));
    TheAI->pathfinder()->updateGoal(unit, unit->getPosition(), LAYER_GROUND);
    s_df.unit = unit->getID();
    s_df.deployed = true;
    s_df.avoidCrushable = unit->getCrushableLevel();
    ICoord2D cell{};
    TheAI->pathfinder()->worldToCell(unit->getPosition(), &cell);
    PathfindCell* pathCell = TheAI->pathfinder()->getCell(LAYER_GROUND, cell.x, cell.y);
    if (pathCell)
    {
        // Force a fixed goal occupancy. setPosUnit early-outs when the goal and
        // position IDs already match, so clear the position first.
        pathCell->setPosUnit(INVALID_ID, cell);
        pathCell->setGoalUnit(unit->getID(), cell);
        pathCell->setPosUnit(unit->getID(), cell);
        s_df.avoidFlags = int(pathCell->getFlags());
        s_df.avoidCellUnitId = pathCell->getPosUnit();
        s_df.avoidCellObject = pathCell->getPosObject() ? 1 : 0;
    }
    s_df.avoidStatus = unit->testStatus(OBJECT_STATUS_DEPLOYED) ? 1 : 0;
    s_df.avoidUnitId = unit->getID();
    s_df.avoidWidth = TheAI->pathfinder()->clearCellForDiameter(
        FALSE, cell.x, cell.y, LAYER_GROUND, 2);
    s_df.stage = DF_AVOID_WAIT;
    s_df.stageFrame = logic->getFrame();
}

void dfSetupDeploy(GameLogic* logic)
{
    if (!dfFindPlayers(logic)) return;
    Player* human = ThePlayerList->getLocalPlayer();
    Player* enemy = nullptr;
    Player* neutral = ThePlayerList->getNeutralPlayer();
    for (Int p = 0; p < ThePlayerList->getPlayerCount(); ++p)
    {
        Player* candidate = ThePlayerList->getNthPlayer(p);
        if (candidate && candidate != human && candidate != neutral
            && candidate->getPlayerType() == PLAYER_COMPUTER)
        {
            enemy = candidate;
            break;
        }
    }
    if (!enemy) { dfWriteResult("invalid_fixture", "enemy player missing"); return; }

    Team* enemyTeam = nullptr;
    for (Object* obj = logic->getFirstObject(); obj; obj = obj->getNextObject())
    {
        if (obj->getControllingPlayer() == enemy)
        {
            if (!enemyTeam && obj->getTeam()) enemyTeam = obj->getTeam();
            obj->setStatus(OBJECT_STATUS_NO_ATTACK_FROM_AI);
        }
    }
    if (!enemyTeam) enemyTeam = enemy->getDefaultTeam();
    if (!enemyTeam)
    {
        dfWriteResult("invalid_fixture", "enemy team missing");
        return;
    }

    dfCenterOfMap(&s_df.center);
    const char* templateName = dfEnv("ZH_FIXTURE_TEMPLATE", "ChinaVehicleNukeLauncher");
    const ThingTemplate* thing = TheThingFactory->findTemplate(templateName);
    s_df.templateFound = thing != nullptr;
    if (!thing)
    {
        dfWriteResult("invalid_fixture", "unit template not found");
        return;
    }
    Team* humanTeam = nullptr;
    for (Object* obj = logic->getFirstObject(); obj; obj = obj->getNextObject())
    {
        if (obj->getControllingPlayer() == human)
        {
            humanTeam = obj->getTeam();
            break;
        }
    }
    if (!humanTeam) humanTeam = human->getDefaultTeam();
    if (!humanTeam)
    {
        dfWriteResult("invalid_fixture", "human team missing");
        return;
    }
    Object* unit = TheThingFactory->newObject(thing, humanTeam);
    if (!unit)
    {
        dfWriteResult("invalid_fixture", "unit creation failed");
        return;
    }
    unit->setPosition(&s_df.center);
    unit->setOrientation(0);
    dfComplete(unit);
    s_df.unit = unit->getID();

    static NameKeyType deployKey = NAMEKEY("DeployStyleAIUpdate");
    s_df.deployModule = unit->findUpdateModule(deployKey) != nullptr;
    if (!s_df.deployModule)
    {
        dfWriteResult("invalid_fixture", "template lacks DeployStyleAIUpdate");
        return;
    }

    const ThingTemplate* targetThing = TheThingFactory->findTemplate(dfEnv("ZH_FIXTURE_TARGET", "AmericaPowerPlant"));
    if (!targetThing)
    {
        dfWriteResult("invalid_fixture", "target template not found");
        return;
    }
    Coord3D targetPos;
    dfFlatPoint(s_df.center, 0.0f, 335.75f, &targetPos);
    Object* target = TheThingFactory->newObject(targetThing, enemyTeam);
    if (!target)
    {
        dfWriteResult("invalid_fixture", "target creation failed");
        return;
    }
    target->setPosition(&targetPos);
    dfComplete(target);
    s_df.target = target->getID();
    if (unit->getRelationship(target) != ENEMIES)
    {
        Player* unitOwner = unit->getTeam() ? unit->getTeam()->getControllingPlayer() : human;
        Player* targetOwner = target->getTeam() ? target->getTeam()->getControllingPlayer() : enemy;
        if (unitOwner && targetOwner)
        {
            unitOwner->setPlayerRelationship(targetOwner, ENEMIES);
            targetOwner->setPlayerRelationship(unitOwner, ENEMIES);
        }
        human->setPlayerRelationship(enemy, ENEMIES);
        enemy->setPlayerRelationship(human, ENEMIES);
    }

    // Local vision source next to the target. The T-081 fixture used the same pattern;
    // the target itself is a building and does not provide vision.
    Coord3D spotterPos = targetPos;
    spotterPos.y += 80.0f;
    spotterPos.z = TheTerrainLogic->getGroundHeight(spotterPos.x, spotterPos.y);
    Object* spotter = TheThingFactory->newObject(
        TheThingFactory->findTemplate("AmericaVehicleDozer"), human->getDefaultTeam());
    if (spotter)
    {
        spotter->setPosition(&spotterPos);
        dfComplete(spotter);
    }
    s_df.targetVisible = target->getShroudedStatus(human->getPlayerIndex()) == OBJECTSHROUD_CLEAR;

    dfFlatPoint(s_df.center, 0.0f, 300.0f, &s_df.farA);
    dfFlatPoint(s_df.center, 3.14159265f, 300.0f, &s_df.farB);

    if (TheTacticalView)
    {
        Coord3D camera = s_df.center;
        camera.x += 150.0f;
        TheTacticalView->lookAt(&camera);
    }
    if (TheInGameUI && unit->getDrawable())
    {
        TheInGameUI->deselectAllDrawables();
        TheInGameUI->selectDrawable(unit->getDrawable());
    }

    // Guard-only sequence: the target is hostile, so the guard machine must acquire it,
    // deploy the unit and fire. The move filtering is the T-117 comparison.
    unit->getAI()->aiGuardPosition(&s_df.center, GUARDMODE_GUARD_WITHOUT_PURSUIT, CMD_FROM_PLAYER);
    s_df.guardFrame = logic->getFrame();
    s_df.stage = DF_WAIT_DEPLOY;
    s_df.stageFrame = logic->getFrame();
}

void dfSetupPathBench(GameLogic* logic)
{
    if (!dfFindPlayers(logic)) return;
    Player* human = ThePlayerList->getLocalPlayer();
    dfCenterOfMap(&s_df.center);
    const ThingTemplate* mobile = TheThingFactory->findTemplate(dfEnv("ZH_FIXTURE_TEMPLATE", "AmericaTankCrusader"));
    s_df.templateFound = mobile != nullptr;
    if (!mobile)
    {
        dfWriteResult("invalid_fixture", "path template not found");
        return;
    }
    // Stationary neutral units create fixed-occupancy cells. The moving group's width
    // scans must resolve those occupants, which is the T-118 cache path.
    Player* neutral = ThePlayerList->getNeutralPlayer();
    Team* neutralTeam = neutral ? neutral->getDefaultTeam() : nullptr;
    if (neutralTeam)
    {
        const ThingTemplate* blockerTemplate = TheThingFactory->findTemplate("AmericaTankCrusader");
        const int blockers = dfInt("ZH_FIXTURE_BLOCKERS", 100, 0, 200);
        for (int i = 0; i < blockers && blockerTemplate; ++i)
        {
            Coord3D p = s_df.center;
            p.x += (i % 10 - 5) * 30.0f;
            p.y += (i / 10 - 5) * 30.0f;
            p.z = TheTerrainLogic->getGroundHeight(p.x, p.y);
            Object* blocker = TheThingFactory->newObject(blockerTemplate, neutralTeam);
            if (!blocker) continue;
            blocker->setPosition(&p);
            dfComplete(blocker);
            PathfindCell* cell = TheAI->pathfinder()->getCell(LAYER_GROUND, blocker->getPosition());
            if (cell)
            {
                ++s_df.cacheQueries;
                if (cell->getPosObject() == blocker) ++s_df.cacheHits;
            }
        }
    }

    const int groups = dfInt("ZH_FIXTURE_GROUPS", 8, 1, 16);
    const int size = dfInt("ZH_FIXTURE_GROUP_SIZE", 25, 1, 25);
    s_df.pathWaves = dfInt("ZH_FIXTURE_WAVES", 4, 1, 12);
    s_df.pathInterval = dfInt("ZH_FIXTURE_INTERVAL", 90, 15, 900);
    s_df.pathUnitCount = 0;
    for (int g = 0; g < groups; ++g)
    {
        for (int j = 0; j < size; ++j)
        {
            Coord3D p = s_df.center;
            p.x += (g % 2 ? -1.0f : 1.0f) * (260.0f + (j % 5) * 20.0f);
            p.y += (g / 2 - (groups / 2 - 1) * 0.5f) * 120.0f + (j / 5 - 2) * 20.0f;
            p.z = TheTerrainLogic->getGroundHeight(p.x, p.y);
            Object* unit = TheThingFactory->newObject(mobile, human->getDefaultTeam());
            if (!unit) continue;
            unit->setPosition(&p);
            dfComplete(unit);
            if (s_df.pathUnitCount < (int)(sizeof(s_df.pathUnits) / sizeof(s_df.pathUnits[0])))
                s_df.pathUnits[s_df.pathUnitCount++] = unit->getID();
        }
    }
    s_df.pathSpawned = s_df.pathUnitCount > 0;
    if (!s_df.pathSpawned)
    {
        dfWriteResult("invalid_fixture", "path units not spawned");
        return;
    }
    s_df.stage = DF_PATH_WAVES;
    s_df.stageFrame = logic->getFrame();
}

void dfSetupFormation(GameLogic* logic)
{
    if (!dfFindPlayers(logic)) return;
    Player* human = ThePlayerList->getLocalPlayer();
    Player* neutral = ThePlayerList->getNeutralPlayer();
    Player* enemy = nullptr;
    for (Int p = 0; p < ThePlayerList->getPlayerCount(); ++p)
    {
        Player* candidate = ThePlayerList->getNthPlayer(p);
        if (candidate && candidate != human && candidate != neutral
            && candidate->getPlayerType() == PLAYER_COMPUTER)
        {
            enemy = candidate;
            break;
        }
    }
    if (!enemy) { dfWriteResult("invalid_fixture", "enemy player missing"); return; }

    Team* humanTeam = nullptr;
    for (Object* obj = logic->getFirstObject(); obj; obj = obj->getNextObject())
    {
        if (obj->getControllingPlayer() == human)
        {
            humanTeam = obj->getTeam();
            break;
        }
    }
    if (!humanTeam) humanTeam = human->getDefaultTeam();
    if (!humanTeam)
    {
        dfWriteResult("invalid_fixture", "human team missing");
        return;
    }

    const ThingTemplate* mobile = TheThingFactory->findTemplate(
        dfEnv("ZH_FIXTURE_TEMPLATE", "ChinaVehicleBattleMaster"));
    if (!mobile)
    {
        dfWriteResult("invalid_fixture", "formation template not found");
        return;
    }

    // Recorded T-116 live-baseline leader and one of its three goals.
    Coord3D leader;
    leader.x = 2775.0f;
    leader.y = 1168.0f;
    leader.z = TheTerrainLogic->getGroundHeight(leader.x, leader.y);
    Coord3D goal;
    goal.x = 1281.0f;
    goal.y = 890.0f;
    goal.z = TheTerrainLogic->getGroundHeight(goal.x, goal.y);

    const char* blockerName = std::getenv("ZH_FIXTURE_BLOCKER_BUILDING");
    const char* blockerAt = std::getenv("ZH_FIXTURE_BLOCKER_AT");
    std::strncpy(s_df.blockerAt, blockerAt ? blockerAt : "leader", sizeof(s_df.blockerAt) - 1);
    s_df.blockerAt[sizeof(s_df.blockerAt) - 1] = '\0';
    if (blockerName && *blockerName)
    {
        const ThingTemplate* blockerTemplate = TheThingFactory->findTemplate(blockerName);
        if (blockerTemplate)
        {
            Coord3D blockerPos = leader;
            if (blockerAt && std::strcmp(blockerAt, "mid") == 0)
            {
                blockerPos.x = (leader.x + goal.x) * 0.5f;
                blockerPos.y = (leader.y + goal.y) * 0.5f;
                blockerPos.z = TheTerrainLogic->getGroundHeight(blockerPos.x, blockerPos.y);
            }
            else if (blockerAt && std::strcmp(blockerAt, "goal") == 0)
            {
                blockerPos = goal;
            }

            float dx = goal.x - leader.x;
            float dy = goal.y - leader.y;
            const float length = std::sqrt(dx * dx + dy * dy);
            if (length > 1.0f) { dx /= length; dy /= length; }
            else { dx = 1.0f; dy = 0.0f; }
            const float perpX = -dy;
            const float perpY = dx;
            const int blockerCount = dfInt("ZH_FIXTURE_BLOCKER_COUNT", 1, 1, 16);
            const float spacing = 80.0f;
            for (int i = 0; i < blockerCount; ++i)
            {
                const float offset = (i - (blockerCount - 1) * 0.5f) * spacing;
                Coord3D position = blockerPos;
                position.x += perpX * offset;
                position.y += perpY * offset;
                position.z = TheTerrainLogic->getGroundHeight(position.x, position.y);
                Object* blocker = TheThingFactory->newObject(blockerTemplate, humanTeam);
                if (!blocker)
                    continue;
                blocker->setPosition(&position);
                dfComplete(blocker);
            }
        }
    }

    Coord3D clear = leader;
    bool haveClear = false;
    for (int i = 0; i < 16 && !haveClear; ++i)
    {
        const float angle = i * (2.0f * 3.14159265f / 16.0f);
        Coord3D candidate = leader;
        candidate.x += std::cos(angle) * 100.0f;
        candidate.y += std::sin(angle) * 100.0f;
        candidate.z = TheTerrainLogic->getGroundHeight(candidate.x, candidate.y);
        if (TheAI->pathfinder()->isGroupStartCellUsable(&candidate, &goal))
        {
            clear = candidate;
            haveClear = true;
        }
    }
    if (!haveClear)
    {
        if (std::strcmp(s_df.blockerAt, "goal") == 0)
        {
            // Diagnostic: the goal's zone is invalid, so no start is usable.
            // Keep the blocked goal and record the group failure instead of
            // aborting the fixture.
            clear = leader;
        }
        else
        {
            dfWriteResult("invalid_fixture", "no usable alternate start cell near the leader");
            return;
        }
    }

    s_formationGroup = TheAI->createGroup();
    int count = 0;
    for (int i = 0; i < 6; ++i)
    {
        Coord3D p = (i < 4) ? leader : clear;
        if (i < 4)
        {
            p.x += (i % 2) ? -20.0f : 20.0f;
            p.y += (i / 2) ? -20.0f : 20.0f;
        }
        else
        {
            p.y += (i - 4) * 25.0f;
        }
        p.z = TheTerrainLogic->getGroundHeight(p.x, p.y);
        Object* unit = TheThingFactory->newObject(mobile, humanTeam);
        if (!unit) continue;
        unit->setPosition(&p);
        unit->setOrientation(0);
        dfComplete(unit);
        s_formationGroup->add(unit);
        if (count == 0) s_df.formationFirst = unit->getID();
        ++count;
    }
    s_df.formationUnits = count;
    s_df.formationStart = leader;
    s_df.leaderUsable = TheAI->pathfinder()->isGroupStartCellUsable(&leader, &goal);
    s_df.alternateUsable = TheAI->pathfinder()->isGroupStartCellUsable(&clear, &goal);
    if (count < 2)
    {
        dfWriteResult("invalid_fixture", "formation units not spawned");
        return;
    }

    s_formationGroup->groupMoveToPosition(&goal, FALSE, CMD_FROM_SCRIPT);
    const char* failure = TheAI->pathfinder()->lastGroundPathFailure();
    std::strncpy(s_df.formationFailure, failure ? failure : "none",
        sizeof(s_df.formationFailure) - 1);
    s_df.formationFailure[sizeof(s_df.formationFailure) - 1] = 0;
    s_df.stage = DF_FORMATION_WAIT;
    s_df.stageFrame = logic->getFrame();
}

void dfIssuePathWave(GameLogic* logic)
{
    for (int i = 0; i < s_df.pathUnitCount; ++i)
    {
        Object* unit = logic->findObjectByID(s_df.pathUnits[i]);
        if (!unit || !unit->getAIUpdateInterface()) continue;
        Coord3D target = s_df.center;
        const unsigned phase = s_df.pathWave % 4;
        if (phase == 0) target.x += 320.0f;
        if (phase == 1) target.y += 320.0f;
        if (phase == 2) target.x -= 320.0f;
        if (phase == 3) target.y -= 320.0f;
        target.z = TheTerrainLogic->getGroundHeight(target.x, target.y);
        unit->getAIUpdateInterface()->aiMoveToPosition(&target, CMD_FROM_SCRIPT);
    }
    ++s_df.pathWave;
}

void dfUpdateDeploy(GameLogic* logic)
{
    Object* unit = logic->findObjectByID(s_df.unit);
    const unsigned now = logic->getFrame();
    const unsigned elapsed = now - s_df.stageFrame;

    if (!unit)
    {
        dfWriteResult("invalid_fixture", "subject unit disappeared");
        return;
    }
    Player* human = ThePlayerList ? ThePlayerList->getLocalPlayer() : nullptr;
    Object* target = logic->findObjectByID(s_df.target);
    if (human && target)
        s_df.targetVisible = target->getShroudedStatus(human->getPlayerIndex()) == OBJECTSHROUD_CLEAR;
    if (elapsed % 30 == 0 && target)
    {
        const char* resultPath = dfResultPath();
        char diagPath[512];
        _snprintf(diagPath, sizeof(diagPath) - 1, "%s.diag.csv", resultPath ? resultPath : "");
        diagPath[sizeof(diagPath) - 1] = 0;
        static FILE* diag = nullptr;
        if (!diag)
        {
            diag = std::fopen(diagPath, "w");
            if (diag)
                std::fprintf(diag, "frame,stage,aiState,deployed,visible,canAttack,withinRange,relationship,guardRange,weaponRange,targetHealth,mood,unitX,unitY,unitZ,targetX,targetY,targetZ,distance3d,unitPlayer,targetPlayer\n");
        }
        if (diag)
        {
            const Weapon* weapon = unit->getWeaponInWeaponSlot(PRIMARY_WEAPON);
            const Coord3D* up = unit->getPosition();
            const Coord3D* tp = target->getPosition();
            const float ddx = up->x - tp->x;
            const float ddy = up->y - tp->y;
            const float ddz = up->z - tp->z;
            const float d3 = std::sqrt(ddx * ddx + ddy * ddy + ddz * ddz);
            const int unitPlayer = unit->getControllingPlayer() ? unit->getControllingPlayer()->getPlayerIndex() : -1;
            const int targetPlayer = target->getControllingPlayer() ? target->getControllingPlayer()->getPlayerIndex() : -1;
            std::fprintf(diag, "%u,%d,%d,%d,%d,%d,%d,%d,%.3f,%.3f,%.3f,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.3f,%d,%d\n",
                now, s_df.stage,
                unit->getAI() ? int(unit->getAI()->getCurrentStateID()) : -1,
                unit->testStatus(OBJECT_STATUS_DEPLOYED) ? 1 : 0,
                s_df.targetVisible ? 1 : 0,
                int(unit->getAbleToAttackSpecificObject(ATTACK_NEW_TARGET, target, CMD_FROM_AI)),
                weapon && target && weapon->isWithinAttackRange(unit, target) ? 1 : 0,
                int(unit->getRelationship(target)),
                AIGuardMachine::getStdGuardRange(unit),
                weapon ? weapon->getAttackRange(unit) : -1.0f,
                target->getBodyModule() ? target->getBodyModule()->getHealth() : -1.0f,
                unit->getAI() ? unit->getAI()->getMoodMatrixValue() : 0,
                up->x, up->y, up->z, tp->x, tp->y, tp->z, d3, unitPlayer, targetPlayer);
            std::fflush(diag);
        }
    }
    if (elapsed % 30 == 0) dfWriteHeartbeat(logic);

    switch (s_df.stage)
    {
        case DF_WAIT_DEPLOY:
            if (unit->testStatus(OBJECT_STATUS_DEPLOYED))
            {
                s_df.deployed = true;
                s_df.stage = DF_WAIT_SHOT;
                s_df.stageFrame = now;
            }
            else if (elapsed > 300)
            {
                dfWriteResult("invalid_fixture", "unit never deployed");
            }
            break;

        case DF_WAIT_SHOT:
        {
            const Weapon* weapon = unit->getWeaponInWeaponSlot(PRIMARY_WEAPON);
            const unsigned shot = weapon ? weapon->getLastShotFrame() : 0;
            if (shot > 0)
            {
                s_df.fired = true;
                s_df.firstShotFrame = shot;
                unit->getAI()->aiGuardPosition(&s_df.center, GUARDMODE_GUARD_WITHOUT_PURSUIT, CMD_FROM_PLAYER);
                s_df.guardFrame = now;
                s_df.stage = DF_GUARD_SETTLE;
                s_df.stageFrame = now;
            }
            else if (elapsed > 900)
            {
                dfWriteResult("invalid_fixture", "unit never fired at the in-range target");
            }
            break;
        }

        case DF_GUARD_SETTLE:
            if (elapsed % 30 == 0)
                unit->getAI()->aiGuardPosition(&s_df.center, GUARDMODE_GUARD_WITHOUT_PURSUIT, CMD_FROM_PLAYER);
            if (elapsed >= 15 && unit->getAI()->getCurrentStateID() == AI_GUARD
                && unit->testStatus(OBJECT_STATUS_DEPLOYED))
            {
                s_df.moveFrame = now;
                s_df.stage = DF_OBSERVE_MOVE;
                s_df.stageFrame = now;
                unit->getAI()->aiMoveToPosition(&s_df.farA, CMD_FROM_PLAYER);
            }
            else if (elapsed > 300)
            {
                dfWriteResult("invalid_fixture", "unit did not enter the guard state deployed");
            }
            break;

        case DF_OBSERVE_MOVE:
        {
            const float displacement = dfDistance2D(*unit->getPosition(), s_df.center);
            if (displacement > s_df.maxDisplacement) s_df.maxDisplacement = displacement;
            if (displacement > 20.0f) s_df.movedDuringGuard = true;
            if (!unit->testStatus(OBJECT_STATUS_DEPLOYED)) s_df.unpackedDuringGuard = true;
            if (elapsed >= 240)
            {
                if (s_df.hold && (s_df.movedDuringGuard || s_df.unpackedDuringGuard))
                {
                    dfWriteResult("assertion_failed", "hold unit moved or unpacked during guard");
                }
                else if (!s_df.hold && !s_df.movedDuringGuard && !s_df.unpackedDuringGuard)
                {
                    dfWriteResult("invalid_fixture", "control did not respond to the move command");
                }
                else
                {
                    s_df.stage = DF_STOP;
                    s_df.stageFrame = now;
                    unit->getAI()->aiIdle(CMD_FROM_PLAYER);
                }
            }
            break;
        }

        case DF_STOP:
            if (elapsed >= 15)
            {
                s_df.postStopMoveIssued = true;
                s_df.stage = DF_OBSERVE_POSTSTOP;
                s_df.stageFrame = now;
                unit->getAI()->aiMoveToPosition(&s_df.farB, CMD_FROM_PLAYER);
            }
            break;

        case DF_OBSERVE_POSTSTOP:
        {
            const float displacement = dfDistance2D(*unit->getPosition(), s_df.center);
            if (displacement > s_df.maxPostStopDisplacement) s_df.maxPostStopDisplacement = displacement;
            if (displacement > 20.0f && s_df.postStopMoveIssued) s_df.movedAfterStop = true;
            if (!unit->testStatus(OBJECT_STATUS_DEPLOYED)) s_df.unpackedAfterStop = true;
            if (elapsed >= 240)
            {
                if (!s_df.movedAfterStop && !s_df.unpackedAfterStop)
                    dfWriteResult("assertion_failed", "unit did not move after Stop");
                else
                    dfWriteResult("pass", "");
            }
            break;
        }

        default:
            break;
    }
}

void dfUpdatePathBench(GameLogic* logic)
{
    const unsigned now = logic->getFrame();
    const unsigned elapsed = now - s_df.stageFrame;
    if (elapsed % 30 == 0) dfWriteHeartbeat(logic);
    if (s_df.pathWave < s_df.pathWaves)
    {
        if (elapsed >= s_df.pathWave * s_df.pathInterval)
            dfIssuePathWave(logic);
        return;
    }
    if (elapsed >= s_df.pathWaves * s_df.pathInterval + 240)
        dfWriteResult("pass", "");
}

} // namespace

void dfUpdateFormation(GameLogic* logic)
{
    const unsigned now = logic->getFrame();
    const unsigned elapsed = now - s_df.stageFrame;
    if (elapsed % 30 == 0) dfWriteHeartbeat(logic);
    if (elapsed < 240) return;

    Object* first = logic->findObjectByID(s_df.formationFirst);
    if (first)
    {
        const float dx = first->getPosition()->x - s_df.formationStart.x;
        const float dy = first->getPosition()->y - s_df.formationStart.y;
        s_df.formationMoved = std::sqrt(dx * dx + dy * dy) > 20.0f;
    }

    if (s_formationGroup)
    {
        s_df.groupIdle = s_formationGroup->isIdle();
        s_df.groupCount = s_formationGroup->getCount();
        const VecObjectID &ids = s_formationGroup->getAllIDs();
        bool first = true;
        for (ObjectID id : ids)
        {
            Object *obj = logic->findObjectByID(id);
            AIUpdateInterface *ai = obj ? obj->getAIUpdateInterface() : nullptr;
            if (!ai)
                continue;
            if (ai->isMoving())
                ++s_df.membersMoving;
            if (ai->getPath())
                ++s_df.membersWithPath;
            if (first)
            {
                s_df.firstPathAge = ai->getPathAge();
                Path *p = ai->getPath();
                if (p)
                {
                    for (PathNode *n = p->getFirstNode(); n; n = n->getNext())
                    {
                        if (s_df.firstPathNodes == 0)
                        {
                            s_df.firstPathX = n->getPosition()->x;
                            s_df.firstPathY = n->getPosition()->y;
                        }
                        ++s_df.firstPathNodes;
                    }
                }
                s_df.firstUnitX = obj->getPosition()->x;
                s_df.firstUnitY = obj->getPosition()->y;
                first = false;
            }
        }
    }
    else
    {
        s_df.groupIdle = true;
    }

    if (std::strcmp(s_df.blockerAt, "leader") != 0)
    {
        // Route-blocker diagnostic: the leader is intentionally clear, so the
        // bad-start assertions do not apply. The result and command CSV classify
        // whether the mid/goal blocker caused a detour or a failure.
        dfWriteResult("pass", "");
        return;
    }
    if (s_df.leaderUsable)
    {
        dfWriteResult("invalid_fixture", "leader cell is usable; bad start not reproduced");
        return;
    }
    if (!s_df.alternateUsable)
    {
        dfWriteResult("invalid_fixture", "no usable alternate in the fixture");
        return;
    }
    if (s_df.relax)
    {
        if (std::strcmp(s_df.formationFailure, "none") == 0 && s_df.formationMoved)
            dfWriteResult("pass", "");
        else
            dfWriteResult("assertion_failed", "relaxed group did not dispatch a moving route");
    }
    else
    {
        // The control predicate is the group path rejection reason. Some members
        // can still take fallback individual routes, so movement alone is not the
        // control assertion.
        if (std::strcmp(s_df.formationFailure, "zone_mismatch") == 0)
            dfWriteResult("pass", "");
        else
            dfWriteResult("assertion_failed", "control did not reproduce zone_mismatch");
    }
}

void dfUpdateVision(GameLogic* logic)
{
    const unsigned elapsed = logic->getFrame() - s_df.stageFrame;
    if (elapsed < 30) return;
    if (s_df.weaponRange <= 0.0f)
    {
        dfWriteResult("invalid_fixture", "vision unit has no weapon range");
        return;
    }
    const bool longEnough = s_df.visionRange >= s_df.weaponRange * 0.95f;
    const bool clearingLongEnough = s_df.shroudClearingRange >= s_df.weaponRange * 0.95f;
    if (s_df.longRange)
    {
        if (longEnough && clearingLongEnough)
            dfWriteResult("pass", "");
        else
            dfWriteResult("assertion_failed", "long-range vision did not reach weapon range");
    }
    else
    {
        if (!longEnough)
            dfWriteResult("pass", "");
        else
            dfWriteResult("invalid_fixture", "base vision already reaches weapon range");
    }
}

void dfUpdateAvoid(GameLogic* logic)
{
    const unsigned elapsed = logic->getFrame() - s_df.stageFrame;
    if (elapsed < 30) return;
    if (s_df.avoidEnabled)
    {
        // clearCellForDiameter(2) returns 2 when the two-wide footprint is clear
        // and 1 (or 0) when the deployed occupant rejects it.
        if (s_df.avoidWidth < 2)
            dfWriteResult("pass", "");
        else
            dfWriteResult("assertion_failed", "deployed unit did not narrow the width");
    }
    else
    {
        if (s_df.avoidWidth == 2)
            dfWriteResult("pass", "");
        else
            dfWriteResult("invalid_fixture", "control width already narrowed");
    }
}

static void zhDeployFixture(GameLogic* logic)
{
    if (!dfResultPath()) return;
    if (s_df.done) return;

    if (!logic->isInGame())
    {
        dfStartGame(logic);
        return;
    }
    if (logic->isInShellGame() || logic->isInMultiplayerGame() || logic->isInReplayGame())
        return;
    const unsigned readyFrame = s_df.formation
        ? (unsigned)dfInt("ZH_FIXTURE_READY_FRAME", 180, 60, 3000) : 60u;
    if (logic->getFrame() < readyFrame)
        return;

    if (!s_df.inGameSeen)
    {
        s_df.inGameSeen = true;
        s_df.stageFrame = logic->getFrame();
        if (s_df.pathBench)
            dfSetupPathBench(logic);
        else if (s_df.formation)
            dfSetupFormation(logic);
        else if (s_df.visionCase)
            dfSetupVision(logic);
        else if (s_df.avoidCase)
            dfSetupAvoid(logic);
        else
            dfSetupDeploy(logic);
        return;
    }

    if (s_df.pathBench)
        dfUpdatePathBench(logic);
    else if (s_df.formation)
        dfUpdateFormation(logic);
    else if (s_df.visionCase)
        dfUpdateVision(logic);
    else if (s_df.avoidCase)
        dfUpdateAvoid(logic);
    else
        dfUpdateDeploy(logic);
}
