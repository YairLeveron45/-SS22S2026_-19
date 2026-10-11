"""Auditar archivos candidatos de Git sin imprimir valores de credenciales.

Es una ayuda local antes de publicar; no detecta todas las clases de secretos.
"""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
repo = root.parent
env = root / '.env'
values = []
if env.exists():
    values = [line.split('=', 1)[1].strip().encode() for line in env.read_text().splitlines()
              if '=' in line and line.split('=', 1)[1].strip()]
names = subprocess.check_output(
    # Incluye archivos versionados y nuevos no ignorados de PROYECTO1.
    ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--', 'PROYECTO1'],
    cwd=repo, text=True).splitlines()
patterns = [rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
            rb'gh[pousr]_[A-Za-z0-9]{30,}', rb'github_pat_[A-Za-z0-9_]{50,}',
            rb'AKIA[A-Z0-9]{16}']
leaks = []
# Se buscan los valores actuales de .env y algunos patrones conocidos.
# Solo se muestran nombres de archivos sospechosos, nunca su contenido.
for name in names:
    path = repo / name
    if not path.is_file():
        continue
    data = path.read_bytes()
    if any(value in data for value in values) or any(re.search(p, data) for p in patterns):
        leaks.append(name)
print(f'Archivos candidatos revisados: {len(names)}')
if leaks:
    print('Revisar archivos con posibles secretos:', ', '.join(leaks))
    raise SystemExit(1)
print('No se encontraron credenciales locales ni los patrones de secretos revisados.')
if env.exists():
    # Estar ignorado no basta: un archivo agregado antes podría seguir versionado.
    ignored = subprocess.run(['git', 'check-ignore', '-q', str(env)], cwd=repo).returncode == 0
    tracked = subprocess.check_output(['git', 'ls-files', '--', 'PROYECTO1/.env'], cwd=repo, text=True).strip()
    if not ignored or tracked:
        raise SystemExit('El archivo .env no está protegido por Git.')
    print('.env está ignorado y no está versionado.')
