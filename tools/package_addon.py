"""Publish only the latest installable addon ZIP at a permanent download path."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / 'MoteveSpells'
downloads = root / 'downloads'
toc = (addon / 'MoteveSpells.toc').read_text(encoding='utf-8')
version = re.search(r'^## Version:\s*(\S+)', toc, re.MULTILINE).group(1)
for line in toc.splitlines():
    if line.strip() and not line.startswith('#'):
        assert (addon / line.strip()).is_file(), f'Missing TOC entry: {line}'

downloads.mkdir(exist_ok=True)
target = downloads / 'MoteveSpells.zip'
pending = downloads / 'MoteveSpells.zip.tmp'
files = sorted(p for p in addon.rglob('*') if p.is_file())
with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.relative_to(root).as_posix())
with zipfile.ZipFile(pending) as archive:
    assert archive.testzip() is None
    assert archive.namelist() == [p.relative_to(root).as_posix() for p in files]
    for path in files:
        assert archive.read(path.relative_to(root).as_posix()) == path.read_bytes()
pending.replace(target)

# Only old, versioned addon downloads in this exact directory are removed.
for path in downloads.glob('MoteveSpells-*.zip'):
    assert path.resolve().parent == downloads.resolve()
    if path.is_file():
        path.unlink()

readme = root / 'README.md'
text = readme.read_text(encoding='utf-8')
text = re.sub(r'\*\*Aktuális verzió: [^*]+\*\*', f'**Aktuális verzió: {version}**', text)
text = re.sub(r'downloads/MoteveSpells(?:-[0-9.]+)?\.zip\?raw=true', 'downloads/MoteveSpells.zip?raw=true', text)
readme.write_text(text, encoding='utf-8')
print(f'PASS: {version}; {len(files)} verified addon files; downloads/MoteveSpells.zip is the only current addon download.')
