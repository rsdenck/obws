# OBWS - Summary of Changes

## Visão Geral

Este documento resume as implementações e correções realizadas no sistema OBWS (Obfuscated Binary Web Shell) para compatibilizar o agente remoto bws com o servidor obws-server.

## Problemas Corrigidos

### 1. Compatibilidade bws-agent e obws-server

**Problema:** Comandos ficavam permanentemente "pendentes" porque o servidor e o agente usavam formatos JSON diferentes.

**Raiz:**
- `pollHandler` retornava `id`, mas bws espera `job_id`
- `resultHandler` só aceitava `command_id`, mas bws envia `job_id`
- Params estavam no formato errado (ex: `"user pass"` em vez de `{"user":"...","password":"..."}`)

**Solução:**
- `pollHandler` agora retorna `job_id`, `action`, `params`
- `resultHandler` aceita ambos `command_id` e `job_id`
- `formatParams()` converte params do admin para formato bws esperado:
  - `change_password "user pass"` → `{"user":"user","password":"pass"}`
  - `remove_user "user"` / `add_sudo "user"` → `{"user":"user"}`
  - `exec "cmd"` → `{"command":"cmd"}`
  - `write_file "path content"` → `{"path":"path","content":"content"}`

### 2. Templates de Comandos C2

**Implementação:** Mais de 40 templates de comandos organizados por categoria:

#### Reconhecimento (13 comandos)
- `whoami`, `id`, `uname`, `uptime`, `hostname`, `date`, `last`, `os_release`, `env`, `users`, `ip`, `hostname`, `date`

#### Processos (4 comandos)
- `ps`, `ps_tree`, `top`, `proc_roots`

#### Rede (7 comandos)
- `ip`, `netstat`, `routes`, `arp`, `connections`, `dns`, `iptables`

#### Arquivos e Discos (12 comandos)
- `df`, `mount`, `ls_root`, `ls_tmp`, `ls_etc`, `ls_var_log`, `ls_home`, `find_suid`, `disk_usage`, `cat_file`, `grep_search`, `write_file`

#### Credenciais e Acesso (8 comandos)
- `passwd`, `shadow`, `sudoers`, `ssh_keys`, `lastlog`, `packages`, `services`, `crontab`, `docker_ps`

#### Administração (4 comandos)
- `collect`, `reboot`, `poweroff`, `exec`

### 3. Interface do Usuário

**Frontend Admin** (`/opt/bws/admin/`):
- Interface Harbor-style com header e sidebar
- Menu dropdown do usuário (Perfil, Preferências, Alterar Senha, Sobre, Sair)
- Sidebar agrupado (Hosts, C2)

**Páginas:**
- **Dashboard** - Estatísticas em tempo real
- **Hosts / Endpoints** - Lista e grid de agentes
- **Comandos** - Histórico filtrável
- **Broadcast** - Envio para múltiplos hosts
- **Perfil, Preferências, Alterar Senha, Sobre** - Gerenciamento do administrador

**Página de Agente:**
- Informações do agente (SO, kernel, CPU, RAM, disco, IP)
- Ações organizadas em painéis colapsáveis:
  - Reconhecimento
  - Processos
  - Rede
  - Arquivos e Discos
  - Credenciais e Acesso
  - Administração

### 4. Segurança e Criptografia

- **X25519** para handshake inicial
- **NaCl box** para criptografia de dados
- **Nonce aleatório** por conexão
- **Execução isolada** (`setsid`, sem history, sem logs)

### 5. Deploy e Configuração

**Serviço systemd:** (`/etc/systemd/system/obws.service`)
```ini
[Unit]
Description=OBWS Command & Control Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/bws-server/obws-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Configuração Nginx:**
- `obws.fun` - proxy reverso para Go backend (telemetria)
- `a.obws.fun` - painel PHP admin

## Arquivos Principais

### Backend (`/opt/bws-server/main.go`)
- Endpoints C2: `/api/command`, `/api/commands/bulk`, `/api/commands/cancel/{id}`, `/api/commands/retry/{id}`, `/api/stats`, `/api/profile`
- Handlers: `pollHandler`, `resultHandler`, `createCommand`
- Funções auxiliares: `applyTemplate()`, `formatParams()`

### Frontend (`/opt/bws/admin/`)
- `app.js` - SPA JavaScript com lógica de UI
- `style.css` - CSS customizado
- `index.php` - página principal com sidebar e header
- `api.php` - proxy para endpoints Go
- `login.php` - página de login com logo.webp

### Agente (`/tmp/bws/bws.sh`)
- Shell script compilado com SHC
- Poll de comandos via `GET /poll/{agent_id}` a cada 3600s
- Executa comandos em sessões isoladas
- Reporta resultados via `POST /result/{agent_id}`

## Testes Realizados

### 1. Compatibilidade bws
```bash
# Comando collect com template
curl -X POST http://localhost:8080/api/command \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"b2efb7fdcfc8dd6a","action":"collect","params":"__template__"}'

# Comando whoami com template
curl -X POST http://localhost:8080/api/command \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"b2efb7fdcfc8dd6a","action":"whoami","params":"__template__"}'

# Comando write_file
curl -X POST http://localhost:8080/api/command \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"b2efb7fdcfc8dd6a","action":"write_file","params":"/tmp/test.txt hello world"}'
```

### 2. Verificação de Poll
```bash
curl http://localhost:8080/poll/b2efb7fdcfc8dd6a | python3 -m json.tool
```

Resultado esperado (novos comandos com params formatados):
```json
[
  {
    "job_id": 20,
    "action": "collect",
    "params": ""
  },
  {
    "job_id": 21,
    "action": "whoami",
    "params": "whoami"
  },
  {
    "job_id": 22,
    "action": "write_file",
    "params": "{\"path\":\"/tmp/test.txt\",\"content\":\"hello world\"}"
  }
]
```

## Versionamento Git

### Repositório
- **URL**: https://github.com/rsdenck/obws.git
- **Branch**: main
- **Commit inicial**: 682d3f5

### Estrutura
```
/opt/bws-server/
├── README.md              # Documentação principal
├── ROADMAP.md             # Roteiro de desenvolvimento
├── SUMMARY.md             # Resumo das alterações
├── .gitignore             # Arquivos ignorados
├── main.go                # Backend Go
├── go.mod, go.sum         # Módulo Go
├── admin/                 # Frontend PHP/JS
│   ├── app.js
│   ├── style.css
│   ├── index.php
│   ├── api.php
│   ├── login.php
│   ├── ...
├── bws/                   # Agente remoto bws
│   ├── bws.sh
│   ├── bws.bin
│   ├── bws_crypt.bin
│   ├── ...
└── ...
```

## Status Atual

✅ **Completo:**
- Compatibilidade bws-agent corrigida
- Templates de comandos implementados
- Interface Harbor-style implementada
- Segurança e criptografia implementadas
- Deploy e configuração prontos

📋 **Planejado:**
- [ ] Web shell interativo (Fase 2)
- [ ] Upload/download de arquivos (Fase 2)
- [ ] Controle de processos (Fase 2)
- [ ] Técnicas avançadas de evasão (Fase 3)
- [ ] Persistência (Fase 3)
- [ ] Múltiplos operadores (Fase 4)
- [ ] RBAC e auditoria (Fase 4)
- [ ] Integrações SIEM/SOAR (Fase 5)

## Notas Finais

1. **bws agent** é o único componente nos hosts remotos - sem serviços, sem logs, apenas o binário
2. **bws usa X25519 keypair** (mesmas chaves que obws-server)
3. **Todos os comandos executam** em sessões isoladas (`setsid`), sem history
4. **Novo binário** em `/opt/bws-server/obws-server`
5. **Serviço systemd** atualizado para usar novo binário

## Referências

- [bws.sh](https://github.com/rsdenck/obws/blob/main/bws/bws.sh) - Agente remoto
- [OBWS Architecture](https://github.com/rsdenck/obws/blob/main/bws/contexto_bin.md) - Documentação de arquitetura
- [C2 Endpoints](https://github.com/rsdenck/obws/blob/main/main.go) - Endpoints API
