#!/bin/bash
# ================================================
# PS3 HFW 4.93 Proxy - VIDEOGAMES SCZ
# Script de instalación automática
# Uso: bash install.sh
# ================================================

echo "================================================"
echo "  PS3 HFW 4.93 Proxy - VIDEOGAMES SCZ"
echo "  Instalando..."
echo "================================================"

# 1. Parar nginx si está corriendo
echo "[1/5] Parando nginx..."
systemctl stop nginx 2>/dev/null
systemctl disable nginx 2>/dev/null

# 2. Escribir server.py
echo "[2/5] Creando servidor..."
cat > /root/server.py << 'PYEOF'
import http.server, urllib.request, os, socketserver
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 443
PUP = Path("/root/PS3UPDAT.PUP")
DESTS = [131,132,133,134,135,136,137,138,139,140,141]

def ul(host):
    out = "# PS3 HFW 4.93 - VIDEOGAMES SCZ\n"
    for d in DESTS:
        out += f"Dest={d};CompatibleSystemSoftwareVersion=1.0000-;\n"
        out += f"Dest={d};ImageVersion=00ffffff;SystemSoftwareVersion=9.9999;CDN=http://{host}/PS3UPDAT.PUP;CDN_Timeout=60;\n"
    return out.encode()

class H(BaseHTTPRequestHandler):
    def log_message(self, f, *a): print(f"[{self.address_string()}] {f%a}")
    def do_CONNECT(self): self.send_response(200,"OK"); self.end_headers()
    def do_HEAD(self): self.send_response(200 if PUP.exists() else 503); self.end_headers()
    def do_GET(self):
        p = self.path.lower()
        if "updatelist" in p: self._ul()
        elif "ps3updat.pup" in p: self._pup()
        else: self._st()
    def _ul(self):
        host = self.headers.get("Host","videogamesscz.online")
        b = ul(host)
        self.send_response(200)
        self.send_header("Content-Type","text/plain")
        self.send_header("Content-Length",str(len(b)))
        self.send_header("Connection","close")
        self.end_headers()
        self.wfile.write(b)
        print(f"[OK] updatelist -> {self.address_string()}")
    def _pup(self):
        if not PUP.exists():
            self.send_error(503,"Sube PS3UPDAT.PUP a /root/")
            return
        sz = PUP.stat().st_size
        self.send_response(200)
        self.send_header("Content-Type","application/octet-stream")
        self.send_header("Content-Length",str(sz))
        self.send_header("Connection","close")
        self.end_headers()
        with open(PUP,"rb") as f:
            while True:
                c = f.read(65536)
                if not c: break
                self.wfile.write(c)
        print(f"[OK] PUP enviado -> {self.address_string()}")
    def _st(self):
        ok = PUP.exists()
        sz = f"{PUP.stat().st_size//1024//1024} MB" if ok else "NO encontrado"
        b = f"""<!DOCTYPE html>
<html><head><meta charset=UTF-8><title>PS3 HFW Proxy</title>
<style>
body{{background:#001a0a;color:#00ff88;font-family:monospace;padding:40px}}
h1{{text-shadow:0 0 10px #00ff88}}
.box{{background:#003318;padding:20px;margin-top:20px;line-height:2}}
.ok{{color:#00ff88}} .err{{color:#ff4444}}
</style></head>
<body>
<h1>PS3 HFW 4.93 Proxy</h1>
<h2>VIDEOGAMES SCZ</h2>
<p>PUP: <span class="{'ok' if ok else 'err'}">{'✅ OK - '+sz if ok else '❌ '+sz}</span></p>
<p>Servidor: videogamesscz.online | Puerto: {PORT}</p>
<div class="box">
<b>Configurar en PS3:</b><br>
1. Ajustes → Configuración de red → Editar conexión<br>
2. Proxy: <b>videogamesscz.online</b> &nbsp; Puerto: <b>{PORT}</b><br>
3. Ajustes → Actualización del sistema → Por Internet<br>
4. ⚠️ Desactiva el proxy tras instalar la HFW
</div>
</body></html>""".encode()
        self.send_response(200)
        self.send_header("Content-Type","text/html;charset=utf-8")
        self.send_header("Content-Length",str(len(b)))
        self.send_header("Connection","close")
        self.end_headers()
        self.wfile.write(b)

socketserver.TCPServer.allow_reuse_address = True
server = HTTPServer(("0.0.0.0", PORT), H)
print(f"[PROXY] Puerto {PORT} | PUP: {'OK' if PUP.exists() else 'NO ENCONTRADO - ejecuta: wget -L -O /root/PS3UPDAT.PUP https://github.com/Videogamesscz/PlayStation-3/releases/download/HFW493/PS3UPDAT.PUP'}")
server.serve_forever()
PYEOF

# 3. Descargar el PUP desde GitHub
echo "[3/5] Descargando PUP de HFW 4.93 desde GitHub..."
wget -L --progress=bar:force -O /root/PS3UPDAT.PUP \
  "https://github.com/Videogamesscz/PlayStation-3/releases/download/HFW493/PS3UPDAT.PUP"

if [ $? -eq 0 ]; then
    echo "[OK] PUP descargado: $(du -h /root/PS3UPDAT.PUP | cut -f1)"
else
    echo "[!] Error descargando PUP - puedes descargarlo luego con:"
    echo "    wget -L -O /root/PS3UPDAT.PUP https://github.com/Videogamesscz/PlayStation-3/releases/download/HFW493/PS3UPDAT.PUP"
fi

# 4. Crear servicio systemd
echo "[4/5] Creando servicio ps3proxy..."
cat > /etc/systemd/system/ps3proxy.service << 'EOF'
[Unit]
Description=PS3 HFW 4.93 Proxy - VIDEOGAMES SCZ
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 5. Arrancar servicio
echo "[5/5] Arrancando servicio..."
systemctl daemon-reload
systemctl enable ps3proxy
systemctl start ps3proxy
sleep 2

# Verificar
if systemctl is-active --quiet ps3proxy; then
    echo ""
    echo "================================================"
    echo "  ✅ PROXY INSTALADO Y FUNCIONANDO"
    echo "================================================"
    echo "  URL:    http://videogamesscz.online:443"
    echo "  PS3:    Proxy: videogamesscz.online  Puerto: 443"
    echo "================================================"
    curl -s http://127.0.0.1:443/status | grep -o "PUP:.*<" | head -1
else
    echo "  ❌ Error arrancando el servicio"
    journalctl -u ps3proxy -n 20
fi
