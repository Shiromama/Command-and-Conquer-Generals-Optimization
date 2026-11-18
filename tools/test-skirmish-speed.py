"""Compile the engine's match-start and simulation scheduling paths against a controlled clock."""
import argparse
import re
import subprocess
from pathlib import Path


def method(text, signature):
    start = text.index(signature)
    brace = text.index('{', start)
    depth = 0
    for i in range(brace, len(text)):
        depth += (text[i] == '{') - (text[i] == '}')
        if depth == 0:
            return text[start:i + 1]
    raise ValueError(signature)


parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
md = args.source / 'GeneralsMD/Code/GameEngine/Source'
core = args.source / 'Core/GameEngine/Source'
dispatch = (core / 'GameLogic/System/GameLogicDispatch.cpp').read_text(encoding='utf-8')
engine = (md / 'Common/GameEngine.cpp').read_text(encoding='utf-8')
menu = (md / 'GameClient/GUI/GUICallbacks/Menus/SkirmishGameOptionsMenu.cpp').read_text(encoding='utf-8')
startup = (md / 'Common/GlobalData.cpp').read_text(encoding='utf-8')
assert re.search(r'm_windowed\s*=\s*TRUE;', startup)
assert menu.count('appendIntegerArgument(ticksPerSecond)') == 2

prefix = r'''
#undef NDEBUG
#include <cassert>
#include <algorithm>
#include <cstdio>
#define RETAIL_COMPATIBLE_CRC 1
#define MAYBE_UNUSED
using Int = int;
using Real = float;
using Bool = bool;
using UnsignedInt = unsigned int;
using std::min;
constexpr bool FALSE = false;
template<class T> T clamp(T low, T value, T high) { return std::clamp(value, low, high); }
enum GameMode { GAME_SINGLE_PLAYER, GAME_SKIRMISH, GAME_REPLAY, GAME_LAN, GAME_SHELL };
enum GameDifficulty { DIFFICULTY_NORMAL };
struct Argument { Int integer = 0; };
struct GameMessage {
    Argument values[4];
    Int count = 4;
    Int getArgumentCount() const { return count; }
    const Argument* getArgument(Int i) const { return &values[i]; }
};
struct GameLogic {
    GameMode mode = GAME_SHELL;
    bool onNewGame(GameMessage*);
    void prepareNewGame(GameMode next, GameDifficulty, Int) { mode = next; }
    void startNewGame(Bool) {}
    bool isInReplayGame() const { return mode == GAME_REPLAY; }
};
struct GameEngine {
    Real m_logicTimeAccumulator = 0;
    Bool canUpdateRegularGameLogic(UnsignedInt flags);
};
struct Pacer {
    Int logic = 30;
    Int render = 120;
    bool logicLimited = false;
    bool renderLimited = true;
    Real elapsed = 1.0f / 120;
    void setLogicTimeScaleFps(Int ticks) { logic = ticks; }
    void enableLogicTimeScale(Bool enable) { logicLimited = enable; }
    Int getActualLogicTimeScaleFps(UnsignedInt) const { return logicLimited ? logic : 1000; }
    Int getActualFramesPerSecondLimit() const { return renderLimited ? render : 1000; }
    Real getUpdateTime() const { return elapsed; }
};
GameLogic game;
GameLogic* TheGameLogic = &game;
Pacer pacer;
Pacer* TheFramePacer = &pacer;
struct Globals { bool m_TiVOFastMode = false; } globals;
Globals* TheGlobalData = &globals;
'''
cases = r'''
int main() {
    int tests = 0;
    for (bool capped : {false, true}) {
        for (int slider : {15, 30, 60, 61, 1000}) {
            for (auto mode : {GAME_SKIRMISH, GAME_SINGLE_PLAYER}) {
                GameMessage message;
                message.values[0].integer = mode;
                message.values[3].integer = slider;
                pacer.renderLimited = capped;
                pacer.elapsed = 1.0f / (capped ? 120 : 240);
                assert(game.onNewGame(&message));
                assert(game.mode == mode);
                auto wanted = clamp(15, slider, 60);
                assert(pacer.getActualLogicTimeScaleFps(0) == wanted);
                assert(pacer.getActualFramesPerSecondLimit() == (capped ? 120 : 1000));
                GameEngine clock;
                int ticks = 0;
                for (int frame = 0; frame < (capped ? 120 : 240); ++frame)
                    ticks += clock.canUpdateRegularGameLogic(0);
                assert(ticks == wanted || ticks == wanted - 1);
                ++tests;
            }
        }
    }
    for (auto mode : {GAME_SHELL, GAME_REPLAY, GAME_LAN}) {
        GameMessage message;
        message.values[0].integer = mode;
        message.values[3].integer = 15;
        assert(game.onNewGame(&message));
        assert(!pacer.logicLimited && pacer.renderLimited && pacer.render == 120);
        ++tests;
    }
    GameMessage campaign;
    campaign.values[0].integer = GAME_SINGLE_PLAYER;
    campaign.count = 3;
    pacer.logicLimited = true;
    assert(game.onNewGame(&campaign) && !pacer.logicLimited);
    std::printf("PASS: %d skirmish speed, render-limit and game-mode cases\n", tests + 1);
}
'''
(out / 'test.cpp').write_text(
    prefix + '\n' + method(dispatch, 'bool GameLogic::onNewGame(') + '\n'
    + method(engine, 'Bool GameEngine::canUpdateRegularGameLogic(') + cases,
    encoding='utf-8',
)
(out / 'CMakeLists.txt').write_text(
    'cmake_minimum_required(VERSION 3.20)\nproject(speed LANGUAGES CXX)\n'
    'add_executable(speed test.cpp)\ntarget_compile_features(speed PRIVATE cxx_std_17)\n',
    encoding='utf-8',
)
for name, command in (
    ('configure', ['cmake', '-S', str(out), '-B', str(out / 'build'), '-G', 'Visual Studio 17 2022', '-A', 'Win32']),
    ('build', ['cmake', '--build', str(out / 'build'), '--config', 'Release', '--', '/m:1', '/nodeReuse:false']),
    ('run', [str(out / 'build/Release/speed.exe')]),
):
    result = subprocess.run(command, capture_output=True, text=True)
    (out / f'{name}.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(f'{name} failed. See {out / (name + ".log")}')
    if name == 'run':
        print(result.stdout, end='')
