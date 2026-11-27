#!/usr/bin/env python3
"""Static guard for the determinism hard rules (design doc §0, §7.3).

Checks every .gd file under sim/:
  * starts with the '# SIM: deterministic' header
  * never extends Node / uses scenes
  * no float types/literals, float math builtins, engine RNG, time/OS,
    physics, threads, signals or await
Exit code 1 on any violation. Run: python3 tools/lint_sim.py
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SIM = ROOT / "sim"
HEADER = "# SIM: deterministic"

BANNED = [
    (r"\bfloat\b", "float type"),
    (r"(?<![\w.])\d+\.\d*(?:e[+-]?\d+)?\b|(?<![\w.])\.\d+\b", "float literal"),
    (r"\b(randf|randi|randf_range|randi_range|randfn|randomize|seed)\s*\(", "engine RNG"),
    (r"\bRandomNumberGenerator\b", "engine RNG"),
    (r"\b(Time|OS|Engine|Performance)\.", "non-deterministic engine singleton"),
    (r"\b(sin|cos|tan|asin|acos|atan|atan2|sqrt|pow|exp|log|lerp|lerpf|deg_to_rad|rad_to_deg|snappedf|floorf|ceilf|roundf|fmod|fposmod)\s*\(", "float math builtin"),
    (r"\b(Vector[234]|Transform[23]D|Basis|Quaternion|Rect2|Plane|AABB|Color)\b(?!i)", "float engine type"),
    (r"\b(PI|TAU|INF|NAN)\b", "float constant"),
    (r"\bextends\s+(Node\w*|Resource)\b", "sim class must extend RefCounted"),
    (r"\b(get_tree|get_node|add_child|PackedScene|preload\s*\(\s*\"[^\"]*\.tscn)", "scene/node access"),
    (r"\b(PhysicsServer\w*|PhysicsDirect\w*|RigidBody\w*|CharacterBody\w*)\b", "physics engine"),
    (r"\b(Thread|Mutex|Semaphore|WorkerThreadPool)\b", "threads"),
    (r"^\s*signal\s", "signals"),
    (r"\bawait\b", "await"),
    (r"\bPackedFloat(32|64)Array\b", "float array"),
]

def strip(line: str) -> str:
    # drop string literals then comments
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    i = line.find("#")
    return line if i < 0 else line[:i]

def main() -> int:
    errors = []
    for path in sorted(SIM.rglob("*.gd")):
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if not text.startswith(HEADER):
            errors.append(f"{rel}:1: missing '{HEADER}' header")
        for n, raw in enumerate(text.splitlines(), 1):
            code = strip(raw)
            for pattern, why in BANNED:
                if re.search(pattern, code):
                    errors.append(f"{rel}:{n}: {why}: {raw.strip()}")
    for e in errors:
        print(e)
    print(f"lint_sim: {len(errors)} problem(s) in {SIM.relative_to(ROOT)}/")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
