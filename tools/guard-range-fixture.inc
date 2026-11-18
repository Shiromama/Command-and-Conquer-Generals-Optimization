// T-081 development-only runtime fixture. Injected into isolated source by prepare-guard-fixture.py.
// Never part of the shipping source/build. No feature toggle: control/fixed are separate builds.
#include "GameLogic/AIGuard.h"
#include "GameLogic/Weapon.h"
#include <cstdio>
static void zhGuardFixtureComplete(Object* object)
{
    for (BehaviorModule** module = object->getBehaviorModules(); *module; ++module)
    {
        CreateModuleInterface* create = (*module)->getCreate();
        if (create) create->onBuildComplete();
    }
    TheAI->pathfinder()->addObjectToPathfindMap(object);
}
static void zhGuardFixture(GameLogic* logic)
{
    const char* path = getenv("ZH_GUARD_FIXTURE_CSV");
    if (!path || !*path || !logic->isInGame() || logic->isInShellGame()
        || logic->isInMultiplayerGame() || logic->isInReplayGame() || logic->getFrame() < 60)
        return;
    static const char* names[] = {"AmericaTankCrusader", "AmericaVehicleTomahawk", "GLAVehicleScudLauncher", "ChinaVehicleNukeLauncher"};
    static FILE* log = nullptr;
    static int index = -1;
    static UnsignedInt started = 0;
    static ObjectID unitID = INVALID_ID, targetID = INVALID_ID, spotterID = INVALID_ID;
    static Coord3D center;
    static Real distance = 0.0f;
    static Bool sawShot = FALSE;
    static Bool finished = FALSE;
    static Player* human = nullptr;
    static Player* enemyPlayer = nullptr;
    if (finished) return;
    if (!log)
    {
        log = fopen(path, "w");
        if (!log) return;
        fprintf(log, "event,frame,unit,guard_radius,legacy_radius,primary_range,distance,can_attack,within_weapon_range,last_shot,target_health,shroud,mood,saw_shot,relationship\n");
        Region3D extent; TheTerrainLogic->getExtent(&extent);
        center.x = (extent.lo.x + extent.hi.x) * 0.5f;
        center.y = (extent.lo.y + extent.hi.y) * 0.5f;
        center.z = TheTerrainLogic->getGroundHeight(center.x, center.y);
        Player* neutral = ThePlayerList->getNeutralPlayer();
        human = ThePlayerList->getLocalPlayer();
        Player* enemy = nullptr;
        for (Int p = 0; p < ThePlayerList->getPlayerCount(); ++p)
        {
            Player* candidate = ThePlayerList->getNthPlayer(p);
            if (candidate && candidate != human && candidate != neutral
                && candidate->getPlayerType() == PLAYER_COMPUTER)
            { enemy = candidate; break; }
        }
        if (!human || human->getPlayerType() != PLAYER_HUMAN || !enemy)
        { fprintf(log, "setup_error,%u,no_real_human_or_ai_player\n", logic->getFrame()); fflush(log); finished = TRUE; return; }
        enemyPlayer = enemy;
        // Keep map props out of target selection. Only our subsequently created probe is attackable.
        for (Object* obj = logic->getFirstObject(); obj; obj = obj->getNextObject())
            if (obj->getControllingPlayer() == enemy) obj->setStatus(OBJECT_STATUS_NO_ATTACK_FROM_AI);
        if (human->getRelationship(enemy->getDefaultTeam()) != ENEMIES)
            human->setPlayerRelationship(enemy, ENEMIES);
        if (enemy->getRelationship(human->getDefaultTeam()) != ENEMIES)
            enemy->setPlayerRelationship(human, ENEMIES);
        fprintf(log, "setup,%u,human=%d/%d,enemy=%d/%d,relationship=%d\n",
            logic->getFrame(), human->getPlayerIndex(), human->getPlayerType(),
            enemy->getPlayerIndex(), enemy->getPlayerType(),
            human->getRelationship(enemy->getDefaultTeam()));
        TheWritableGlobalData->m_shroudOn = false;
    }
    if (index >= 0)
    {
        Object* unit = logic->findObjectByID(unitID);
        Object* target = logic->findObjectByID(targetID);
        const Weapon* weapon = unit ? unit->getWeaponInWeaponSlot(PRIMARY_WEAPON) : nullptr;
        const UnsignedInt shot = weapon ? weapon->getLastShotFrame() : 0;
        if (shot > started) sawShot = TRUE;
        const UnsignedInt elapsed = logic->getFrame() - started;
        if (elapsed % 30 == 0 || elapsed >= 360)
        {
            const Real legacy = unit ? TheAI->getAdjustedVisionRangeForObject(unit, AI_VISIONFACTOR_OWNERTYPE | AI_VISIONFACTOR_MOOD | AI_VISIONFACTOR_GUARDINNER) : -1;
            const int canAttack = unit && target ? unit->getAbleToAttackSpecificObject(ATTACK_NEW_TARGET, target, CMD_FROM_AI) : -1;
            fprintf(log, "%s,%u,%s,%.9g,%.9g,%.9g,%.9g,%d,%d,%u,%.9g,%d,%u,%d,%d\n",
                elapsed >= 360 ? "result" : "sample", logic->getFrame(), names[index],
                unit ? AIGuardMachine::getStdGuardRange(unit) : -1, legacy,
                weapon && unit ? weapon->getAttackRange(unit) : -1, distance, canAttack,
                weapon && unit && target ? weapon->isWithinAttackRange(unit, target) : 0,
                shot, target && target->getBodyModule() ? target->getBodyModule()->getHealth() : -1,
                target ? target->getShroudedStatus(ThePlayerList->getLocalPlayer()->getPlayerIndex()) : -1,
                unit && unit->getAI() ? unit->getAI()->getMoodMatrixValue() : 0, sawShot,
                unit && target ? unit->getRelationship(target) : -1);
            fflush(log);
        }
        if (elapsed < 360) return;
        if (index == 3) { finished = TRUE; fclose(log); return; } // Retain final subject for visual inspection.
        if (unit) logic->destroyObject(unit);
        if (target) logic->destroyObject(target);
        Object* spotter = logic->findObjectByID(spotterID);
        if (spotter) logic->destroyObject(spotter);
    }
    ++index;
    Player* local = human;
    Player* enemy = enemyPlayer;
    if (!local || !enemy) { finished = TRUE; fclose(log); return; }
    Object* unit = TheThingFactory->newObject(TheThingFactory->findTemplate(names[index]), local->getDefaultTeam());
    unit->setPosition(&center); unit->setOrientation(0); zhGuardFixtureComplete(unit);
    const Real legacy = TheAI->getAdjustedVisionRangeForObject(unit, AI_VISIONFACTOR_OWNERTYPE | AI_VISIONFACTOR_MOOD | AI_VISIONFACTOR_GUARDINNER);
    const Weapon* weapon = unit->getWeaponInWeaponSlot(PRIMARY_WEAPON);
    distance = index == 0 ? 100.0f : (legacy + weapon->getAttackRange(unit)) * 0.5f;
    Coord3D targetPosition = center; targetPosition.x += distance;
    targetPosition.z = TheTerrainLogic->getGroundHeight(targetPosition.x, targetPosition.y);
    Object* target = TheThingFactory->newObject(TheThingFactory->findTemplate("AmericaPowerPlant"), enemy->getDefaultTeam());
    target->setPosition(&targetPosition); zhGuardFixtureComplete(target);
    Coord3D spotterPosition = targetPosition; spotterPosition.y += 80;
    spotterPosition.z = TheTerrainLogic->getGroundHeight(spotterPosition.x, spotterPosition.y);
    Object* spotter = TheThingFactory->newObject(TheThingFactory->findTemplate("AmericaVehicleDozer"), local->getDefaultTeam());
    spotter->setPosition(&spotterPosition); zhGuardFixtureComplete(spotter);
    unitID = unit->getID(); targetID = target->getID(); spotterID = spotter->getID();
    started = logic->getFrame(); sawShot = FALSE;
    unit->getAI()->aiGuardPosition(&center, GUARDMODE_GUARD_WITHOUT_PURSUIT, CMD_FROM_PLAYER);
    Coord3D camera = center; camera.x += 150;
    TheTacticalView->lookAt(&camera);
    TheInGameUI->deselectAllDrawables(); TheInGameUI->selectDrawable(unit->getDrawable());
}
