#!/usr/bin/env python3
import os,secrets
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'.env.example').read_text()
for key,n in [('DB_PASSWORD',32),('SECRET_KEY_BASE',64),('ENCRYPTION_SECRET',32)]:
    s=s.replace(key+'=GENERAR',key+'='+secrets.token_hex(n))
fd=os.open(root/'.env',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
with os.fdopen(fd,'w') as f:f.write(s)
print('.env creado con secretos nuevos. No regenerar en una instalación existente.')
