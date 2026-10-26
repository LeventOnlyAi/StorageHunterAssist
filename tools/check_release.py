"""Optional developer checks. Requires Python 3 and lupa; never starts the game."""
import os
from pathlib import Path
from lupa import LuaRuntime
from package_release import build

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
scripts = ROOT / 'mod' / 'StorageHunterAssist' / 'Scripts'
files = sorted(scripts.rglob('*.lua'))
for path in files:
    lua.execute('assert(load(...))', path.read_text(encoding='utf-8-sig'))
lua.execute((ROOT / 'tests' / 'verify_remote.lua').read_text(encoding='utf-8-sig'))
print(f'Lua syntax: {len(files)} files passed')
build()
