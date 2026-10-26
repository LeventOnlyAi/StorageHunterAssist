"""Build the installation ZIP from an explicit public-file allowlist."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'mod' / 'StorageHunterAssist'
VERSION = '0.2.0'
ALLOW = {
    'KULLANIM.txt', 'LICENSE',
    'Scripts/main.lua', 'Scripts/sh_assist_config.lua',
    'Scripts/sh_assist_core.lua', 'Scripts/sh_assist_panel.lua',
    'Scripts/sh_assist_remote.lua', 'Scripts/ModMenu/ModMenu.lua',
    'Scripts/ModMenu/LICENSE.txt',
}


def build():
    actual = {p.relative_to(MOD).as_posix() for p in MOD.rglob('*') if p.is_file()}
    if actual != ALLOW:
        raise SystemExit(f'Unexpected mod file set: missing={ALLOW-actual}, extra={actual-ALLOW}')
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    target = dist / f'StorageHunterAssist_{VERSION}.zip'
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for rel in sorted(ALLOW):
            archive.write(MOD / rel, f'StorageHunterAssist/{rel}')
        readme = (ROOT / 'README.md').read_text(encoding='utf-8')
        base = 'https://github.com/LeventOnlyAi/StorageHunterAssist/blob/main/'
        for rel in ('docs/README.en.md', 'docs/TESTING.md', 'docs/images/panel.png', 'LICENSE', 'THIRD_PARTY_NOTICES.md'):
            readme = readme.replace(f']({rel})', f']({base}{rel})')
        archive.writestr('KURULUM_STEAM.md', readme)
        archive.write(ROOT / 'THIRD_PARTY_NOTICES.md', 'THIRD_PARTY_NOTICES.md')
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (dist / 'SHA256SUMS.txt').write_text(f'{digest}  {target.name}\n', encoding='utf-8')
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
    print(f'{target.name}: {digest}')
    return target


if __name__ == '__main__':
    build()
