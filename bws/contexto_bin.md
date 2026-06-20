# bws - Contexto do Binario Remoto

## Visao Geral

O **bws** (Background Telemetry & Remote Administration Agent) e um
binario unico que executa em servidores remotos (clientes). Ele coleta
telemetria do sistema, criptografa com a chave publica do servidor
central, e envia para `https://obws.fun/`.

**Um unico binario para todos os servidores remotos.** Todos usam a
mesma chave publica X25519 embutida, enviando para o mesmo servidor.

---

## Arquivos Fonte

```
/root/src/bws/bws.sh          # Script fonte (assinado)
/root/src/bws/bws.sig         # Assinatura RSA-2048 SHA256
/root/src/bws/bws_crypt.c     # Helper C (NaCl encryption)
/root/src/bws/server_x25519.key    # Chave PRIVADA do servidor (NUNCA no binario)
/root/src/bws/server_x25519.pub    # Chave PUBLICA do servidor (para referencia)
```

---

## Ativacao (osbin)

O binario so executa se a variavel de ambiente `osbin` for fornecida
com o valor correto. O script calcula SHA256 do valor informado e
compara com o hash embutido.

Valor da variavel (permanente em todo servidor remoto):
```
osbin=96bd105f30e65f491a9efe240a0b5c71b78a7f17
```

Hash SHA256 deste valor (embutido no binario para verificacao):
```
c2bc31baa3e1037c3480ebcf0523a613c8d36e61d3918a7379345017c5918706
```

### Definicao permanente

Para que o bws funcione apos reboot (via systemd), a variavel `osbin`
deve ser definida de forma permanente no servidor remoto.

**Metodo 1 — /etc/environment (recomendado):**
```bash
echo 'osbin=96bd105f30e65f491a9efe240a0b5c71b78a7f17' >> /etc/environment
```

**Metodo 2 — /etc/systemd/system/bws.service.d/override.conf:**
```ini
[Service]
Environment=osbin=96bd105f30e65f491a9efe240a0b5c71b78a7f17
```

**Metodo 3 — export no profile do usuario:**
```bash
echo 'export osbin=96bd105f30e65f491a9efe240a0b5c71b78a7f17' >> ~/.bashrc
```

O servico systemd criado pelo `--install` ja inclui `Environment=osbin=...`
no arquivo de unidade, usando o valor da variavel no momento da instalacao.

---

## Chave Publica X25519 (embutida no binario)

A chave publica do servidor (32 bytes) e armazenada em 4 partes hex
para evitar extracao trivial por strings/grep:

```c
_pk_a = "ea0f9ee5de0f9af9"
_pk_b = "e56fd67568cc28c5"
_pk_c = "4e627ab07ebda382"
_pk_d = "a6571792bd1e797d"
```

Concatenadas formam os 32 bytes da chave publica:
```
ea0f9ee5de0f9af9e56fd67568cc28c54e627ab07ebda382a6571792bd1e797d
```

---

## Helper de Criptografia (embutido)

O binario bws carrega um helper ELF x86-64 em seu interior, codificado
como base64 na variavel `BWS_CRYPT_B64`. Na primeira execucao, extrai
para `/etc/bws/bws_crypt` e o utiliza para criptografar os dados.

O helper C usa **libsodium** e faz:
1. `crypto_box_keypair()` — gera par efemero (ephemeralSk, ephemeralPk)
2. `crypto_scalarmult(shared, ephemeralSk, serverPk)` — ECDH X25519
3. `crypto_secretbox_easy(cipher, plain, len, nonce, shared)` — XSalsa20-Poly1305

Dependencia: `libsodium.so.23` (presente na maioria das distros Linux).

---

## Formato do Blob Criptografado

O blob binario (antes do base64) tem esta estrutura:

| Offset | Tamanho | Campo | Descricao |
|--------|---------|-------|-----------|
| 0 | 32 | `ephemeralPub` | Chave publica efemera (Curve25519) |
| 32 | 24 | `nonce` | Nonce aleatorio (XSalsa20-Poly1305) |
| 56 | variavel | `ciphertext` | Dados criptografados + MAC (16 bytes) |

O cliente envia `base64(blob)` como body HTTP puro (Content-Type: text/plain).

---

## Fluxo de Envio

```
bws no servidor remoto
    │
    │ 1. Coleta telemetria (JSON)
    │ 2. Gera chave efemera X25519
    │ 3. ECDH: shared = ephemeralSk * serverPk
    │ 4. secretbox(plaintext, nonce, shared)
    │ 5. Monta blob: ephemeralPk(32) + nonce(24) + cipher
    │ 6. base64(blob)
    │
    ▼  POST https://obws.fun/ (Content-Type: text/plain)
    │
Cloudflare Edge → Tunnel → Nginx :80 → obws-server :8080
    │
    │ 1. Decodifica base64
    │ 2. Extrai ephemeralPk + nonce + cipher
    │ 3. ECDH: shared = serverSk * ephemeralPk
    │ 4. secretbox_open(cipher, nonce, shared)
    │ 5. Salva JSON no SQLite
    │
    ▼
Resposta: {"status":"ok","message":"dados recebidos (id=N)"}
```

---

## URLs do Servidor

| Metodo | URL | Funcao |
|--------|-----|--------|
| POST | `https://obws.fun/` | Envio de telemetria (base64) |
| GET | `https://obws.fun/poll/{agent_id}` | Polling de comandos |
| POST | `https://obws.fun/result/{agent_id}` | Resultado de comandos |

---

## Persistencia (systemd)

Na primeira execucao com `--install` ou `--serve`, o bws:

1. Cria diretorio `/etc/bws/`
2. Gera `agent.id` (hash do machine-id)
3. Cria servico systemd `/etc/systemd/system/bws.service`
4. Ativa e inicia o servico (restart automatico)

O servico executa `bws --serve` com a variavel `osbin` definida.

---

## Comandos

| Opcao | Descricao |
|-------|-----------|
| `--serve` | Inicia daemon (loop: push semanal + poll comandos) |
| `--once` | Push unico de telemetria |
| `--collect` | Exibe JSON da telemetria no stdout |
| `--install` | Instala servico systemd |
| `-h` / `--help` | Ajuda |
| `-V` / `--version` | Versao |

Comandos remotos recebidos via poll (executados com setsid, sem historico):
- `reboot`, `poweroff`
- `change_password <user> <pass>`
- `remove_user <user>`
- `add_sudo <user>`
- `exec <comando>`
- `collect` / `telemetry`

---

## Dados de Telemetria

```json
{
  "agent_id": "8dc8522ea18841a7",
  "ts": "2026-06-19T01:46:34Z",
  "hostname": "servidor-exemplo",
  "user": "root",
  "uptime": 47045,
  "os": "Zorin OS 17.3",
  "kernel": "6.8.0-111-generic",
  "cpu_cores": 8,
  "mem_mb": 15736,
  "swap_mb": 2047,
  "disk": "684G 175G 475G 27%",
  "ip": "2804:30c:b33:fb00:9ec0:3fb6:7ae4:6270"
}
```

---

## Seguranca

- A **chave privada** X25519 esta **APENAS** no servidor (`/opt/bws/ws/server_x25519.key`).
- O binario remoto contem **apenas a chave publica** (obfuscada em 4 partes).
- A criptografia usa X25519 ECDH + XSalsa20-Poly1305 (NaCl secretbox).
- Cada push gera um par de chaves efemero novo (forward secrecy).
- O binario e compilado com SHC (criptografia do script fonte).
- O script fonte e assinado com RSA-2048 (SHA256).
- A ativacao exige a variavel `osbin` (hash SHA256 verificado).

---

## Compilacao

```bash
# 1. Compilar helper C
gcc -O2 -s -o /usr/local/bin/bws_crypt bws_crypt.c -lsodium

# 2. Injetar base64 do helper no script
BWS_CRYPT_B64="$(base64 -w0 /usr/local/bin/bws_crypt)"

# 3. Assinar script
openssl dgst -sha256 -sign denck_private.pem -out bws.sig bws.sh

# 4. Compilar com SHC
shc -f bws.sh -o /usr/local/bin/bws
```

---

## Notas

- O binario compilado (`/usr/local/bin/bws`) tem ~57KB.
- O helper extraido (`/etc/bws/bws_crypt`) tem ~15KB.
- O intervalo padrao de push e 7 dias; polling de comandos a cada 3600s.
- O servidor descriptografa com `crypto_secretbox_open` usando o shared secret
  derivado de `crypto_scalarmult(serverSk, ephemeralPk)` — sem `crypto_box_beforenm`.
