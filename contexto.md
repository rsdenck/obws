# OBWS - Contexto do Servidor de Telemetria

## Arquitetura Geral

```
obws.fun (HTTPS)
     │
     ▼  (SSL terminado na edge Cloudflare)
Cloudflare Edge
     │
     ▼  (túnel criptografado)
cloudflared tunnel (obws-tunnel.service)
     │
     ▼  (localhost:80)
nginx → proxy reverso → 127.0.0.1:8080
     │
     ▼  (localhost:8080)
obws-server (Go) → descriptografa X25519 → SQLite
```

## Componentes

### 1. Cloudflare Tunnel
- **Tunnel ID:** `65a1a449-2159-429c-97c7-acfc4046fd6b`
- **Config:** `/etc/cloudflared/obws.yml`
- **Service:** `obws-tunnel.service`
- **Domínios:** `obws.fun`, `www.obws.fun` → CNAME → `65a1a449-...cfargotunnel.com`
- **Ingress:** `obws.fun` → `http://localhost:80`

### 2. Nginx (Proxy Reverso)
- **Config:** `/etc/nginx/conf.d/obws.conf`
- **Porta:** `:80`
- **Server:** `obws.fun` / `www.obws.fun`
- **Ação:** Proxy reverso para `127.0.0.1:8080`
- **Headers:** Repassa Host, Real-IP, Forwarded-For, Forwarded-Proto

### 3. Go Backend (obws-server)
- **Binário:** `/opt/bws/obws-server`
- **Service:** `obws.service` (WorkingDirectory: `/opt/bws`)
- **Porta local:** `:8080`
- **Código:** `/opt/bws/main.go`
- **Chave privada:** `/opt/bws/ws/server_x25519.key`

---

## Endpoints HTTP

### `GET /`
Retorna status do servidor:
```json
{
  "servico": "OBWS - Telemetria",
  "status": "operacional",
  "uso": "POST / com body base64 (ou JSON: {\"data\":\"<base64>\"})"
}
```

### `GET /health`
Retorna status + últimos registros:
```json
{
  "status": "ok",
  "message": "backend obws rodando",
  "ultimos_dados": [
    {
      "id": 1,
      "remote_addr": "177.xxx.xxx.xxx:12345",
      "payload": "dados descriptografados",
      "received_at": "2026-06-19T01:20:00Z"
    }
  ]
}
```

### `POST /`
Endpoint principal para receber telemetria.

---

## Formato do Push Remoto (criptografado)

O binário remoto envia um **POST** para `https://obws.fun/` com o body contendo **apenas o base64** do blob criptografado (sem JSON, apenas texto puro).

### Estrutura do blob decodificado (bytes)

| Offset | Tamanho | Campo | Descrição |
|--------|---------|-------|-----------|
| 0 | 32 | `ephemeralPub` | Chave pública efêmera do remoto (Curve25519) |
| 32 | 24 | `nonce` | Nonce único (NaCl secretbox) |
| 56 | resto | `ciphertext` | Dados criptografados (NaCl box) |

### Processo de descriptografia

1. Server recebe o body → string base64
2. Decodifica base64 → blob binário
3. Extrai: ephemeralPub (32 bytes) + nonce (24 bytes) + ciphertext (resto)
4. Server faz ECDH: `sharedSecret = privateKey * ephemeralPub` (Curve25519)
5. Decripta: `box.OpenAfterPrecomputation(ciphertext, nonce, sharedSecret)`
6. Resultado: texto plano (JSON ou string)

### Exemplo de body HTTP (POST)

Body cru (Content-Type: text/plain ou application/octet-stream):
```
5PdC3j9Fm0...base64 longo...Zw==
```

Ou alternativamente como JSON:
```json
{"data": "5PdC3j9Fm0...base64 longo...Zw=="}
```

### Exemplo de código do cliente (remoto) - envio

```python
import requests, base64
from nacl.bindings import crypto_box_keypair, crypto_box

# Gerar par de chaves efêmero
pk, sk = crypto_box_keypair()

# Chave pública do servidor (derivada da server_x25519.key)
server_pub = b"..."  # 32 bytes

# Nonce aleatório
nonce = os.urandom(24)

# Dados a enviar
dados = json.dumps({"metric": "cpu", "value": 42}).encode()

# Criptografar
ciphertext = crypto_box(dados, nonce, server_pub, sk)

# Montar blob: ephemeralPub + nonce + ciphertext
blob = pk + nonce + ciphertext
body = base64.b64encode(blob).decode()

# Enviar
requests.post("https://obws.fun/", data=body)
```

---

## Chave do Servidor

### Localização
`/opt/bws/ws/server_x25519.key`

### Formato
```
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VuBCIEILCNHIDBnbnrhrxWAdUeVAxuTWiDS0KJpkzHr07cYnVI
-----END PRIVATE KEY-----
```
- PKCS#8, algoritmo X25519 (OID 1.3.101.110)
- 32 bytes de chave privada

### Chave pública correspondente (derivada da privada)
Para uso nos clientes remotos, a chave pública pode ser extraída com:
```bash
openssl pkey -in /opt/bws/ws/server_x25519.key -pubout | base64
```

---

## Armazenamento (SQLite)

- **Banco:** `/var/lib/obws/obws.db`
- **Tabela:** `telemetry`
  - `id` INTEGER PRIMARY KEY AUTOINCREMENT
  - `remote_addr` TEXT (IP:porta do remoto)
  - `payload` TEXT (dados descriptografados)
  - `received_at` DATETIME (UTC)

## Logs

- **Arquivo:** `/var/log/obws/obws-server.log`
- **Formato:** `2006/01/02 15:04:05 main.go:XXX: mensagem`
- **Conteúdo:** Inicialização, telemetrias recebidas (IP, id, payload), erros

---

## Serviços Systemd

| Serviço | Descrição | Comando |
|---------|-----------|---------|
| `obws.service` | Backend Go (porta 8080) | `systemctl restart obws.service` |
| `obws-tunnel.service` | Túnel Cloudflare | `systemctl restart obws-tunnel.service` |
| `nginx` | Proxy reverso | `systemctl restart nginx` |

## Fluxo Completo de uma Requisição

```
Remoto (qualquer país)
    │ POST https://obws.fun/ (base64 criptografado)
    ▼
Cloudflare Edge (SSL, CDN)
    │ túnel criptografado QUIC
    ▼
cloudflared tunnel (servidor local)
    │ http://localhost:80 (Host: obws.fun)
    ▼
nginx (porta 80)
    │ proxy_pass http://127.0.0.1:8080
    ▼
obws-server (porta 8080)
    │ 1. Decodifica base64
    │ 2. Extrai ephemeralPub (32) + nonce (24) + ciphertext
    │ 3. ECDH: sharedSecret = privateKey * ephemeralPub
    │ 4. NaCl box.Open: plaintext = decript(ciphertext, nonce, sharedSecret)
    │ 5. Salva no SQLite
    │ 6. Loga no arquivo
    │ 7. Responde: {"status":"ok","message":"dados recebidos (id=N)"}
    ▼
Resposta volta pelo túnel → Cloudflare → Remoto
```
