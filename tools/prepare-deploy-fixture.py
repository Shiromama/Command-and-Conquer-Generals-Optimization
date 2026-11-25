"""Inject/restore the T-120 development fixture in the isolated source tree.

The source tree under build/ is a mutable, ignored working tree. The shipping copy of GameLogic.cpp
is kept in the artifact directory and restored by `restore`. Markers are not needed because the
shipping copy is always restored first and the fixture is appended once.

The T-118 cache switch/oracle now lives in the shipping `PathfindCell.cpp`; this script no longer
touches the pathfinder.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "build/last-stand-profile-source"
DEFAULT_ARTIFACT = ROOT / "artifacts/2026-11-22-t120-deploy-fixture/fixture-source"

LOGIC_REL = Path("GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp")

ANCHOR_HELPER = "static void zhPfLogCrc(GameLogic*) {}\n"
ANCHOR_CALL = "    zhPathfindHarness(this);\n"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_if_changed(path: Path, data: bytes) -> None:
    if path.exists() and path.read_bytes() == data:
        return
    path.write_bytes(data)


def restore(source: Path, artifact: Path) -> None:
    target = artifact / LOGIC_REL.name
    write_if_changed(source / LOGIC_REL, target.read_bytes())


def prepare(source: Path, artifact: Path) -> None:
    fixture = (ROOT / "tools/deploy-fixture.inc").read_text(encoding="utf-8")
    logic_path = source / LOGIC_REL
    logic = logic_path.read_text(encoding="utf-8")
    if ANCHOR_HELPER not in logic:
        raise SystemExit("GameLogic anchor not found")
    block = (
        "\n// >>> T-120 DEPLOY FIXTURE (development only)\n"
        + fixture
        + "\n// <<< T-120 DEPLOY FIXTURE\n"
    )
    logic = logic.replace(ANCHOR_HELPER, ANCHOR_HELPER + block, 1)
    if ANCHOR_CALL not in logic:
        raise SystemExit("zhPathfindHarness call anchor not found")
    logic = logic.replace(ANCHOR_CALL, ANCHOR_CALL + "    zhDeployFixture(this);\n", 1)
    write_if_changed(logic_path, logic.encode("utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "restore"])
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--artifact", type=Path, default=DEFAULT_ARTIFACT)
    args = parser.parse_args()
    source = args.source.resolve()
    artifact = args.artifact.resolve()
    artifact.mkdir(parents=True, exist_ok=True)
    target = artifact / LOGIC_REL.name
    if not target.exists():
        target.write_bytes((source / LOGIC_REL).read_bytes())
    restore(source, artifact)
    if args.mode == "prepare":
        prepare(source, artifact)
    state = {
        "mode": args.mode,
        "source": str(source),
        "fixture": str(ROOT / "tools/deploy-fixture.inc"),
        "files": {
            str(LOGIC_REL): {
                "shipping_sha256": sha256(target),
                "current_sha256": sha256(source / LOGIC_REL),
            }
        },
    }
    (artifact / "current.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(state, indent=2))


if __name__ == "__main__":
    main()
