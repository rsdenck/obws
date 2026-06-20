# OBWS - Command & Control Server

OBWS (Obfuscated Binary Web Shell) é um sistema de gerenciamento remoto de servidores com arquitetura C2 (Command & Control). Utiliza criptografia X25519 + NaCl box para comunicação segura com agentes remotos.

## Visão Geral

OBWS permite o controle completo de hosts remotos através de uma interface web intuitiva, semelhante ao Harbor. O sistema inclui:

- **Painel de controle web** com interface de usuário moderna e responsiva
- **Agentes remotos** (bws) que se conectam periodicamente para receber comandos
- **Endpoints C2 completos** para execução de comandos, gerenciamento de agentes e monitoramento
- **Templates de comandos** para operações comuns de reconhecimento e administração
- **Funcionalidades avançadas** de persistência, evasão e escalação de privilégios

## Arquitetura

### Componentes Principais

1. **OBWS Server** (`/opt/bws-server/obws-server`)
   - Backend Go com endpoints REST API
   - Gerencia agentes, telemetria e execução de comandos
   - Compatível com o agente bws (shell script compilado)

2. **bws Agent** (`/tmp/bws/bws.sh`)
   - Binário remoto compilado com SHC
   - Poll para comandos via `/poll/{agent_id}` a cada 3600s
   - Executa comandos em sessões isoladas (`setsid`)
   - Reporta resultados via `/result/{agent_id}`

3. **Frontend Admin** (`/opt/bws/admin/`)
   - Painel PHP com JavaScript SPA
   - Interface similar ao Harbor com menu dropdown e sidebar agrupado
   - Páginas: Dashboard, Hosts, Endpoints, Comandos, Broadcast, Perfil, Preferências, Alterar Senha, Sobre

### Fluxo de Comunicação

1. Agente bws se conecta e envia telemetria (push)
2. Servidor armazena telemetria e lista de agentes
3. Admin pode enviar comandos via API para agentes específicos ou múltiplos (broadcast)
4. Agente bws poll para novos comandos
5. Comandos são executados em sessões isoladas
6. Resultados são reportados de volta ao servidor

## Funcionalidades

### Endpoints C2

- **Comando único**: `POST /api/command` - envia comando para agente específico
- **Comando em massa**: `POST /api/commands/bulk` - envia comando para múltiplos agentes
- **Cancelar comando**: `POST /api/commands/cancel/{id}` - cancela comando pendente
- **Reenviar comando**: `POST /api/commands/retry/{id}` - recria comando falhado/cancelado
- **Stats**: `GET /api/stats` - estatísticas do sistema
- **Perfil**: `POST /api/profile` - gerenciar perfil do administrador

### Templates de Comandos

O sistema inclui mais de 40 templates de comandos organizados por categoria:

#### Reconhecimento
- `whoami`, `id`, `uname`, `uptime`, `hostname`, `date`, `last`, `os_release`, `env`, `users`

#### Processos
- `ps`, `ps_tree`, `top`, `proc_roots`

#### Rede
- `ip`, `netstat`, `routes`, `arp`, `connections`, `dns`, `iptables`, `firewall`

#### Arquivos e Discos
- `df`, `mount`, `ls_root`, `ls_tmp`, `ls_etc`, `ls_var_log`, `ls_home`, `find_suid`, `disk_usage`, `cat_file`, `grep_search`, `write_file`

#### Credenciais e Acesso
- `passwd`, `shadow`, `sudoers`, `ssh_keys`, `lastlog`, `packages`, `services`, `crontab`, `docker_ps`

#### Administração
- `collect` (forçar telemetria), `reboot`, `poweroff`, `exec` (comando personalizado)

### Interface do Usuário

#### Header
- Logo OBWS com ícone de servidor
- Menu dropdown do usuário (Perfil, Preferências, Alterar Senha, Sobre, Sair)
- Menu responsivo para dispositivos móveis

#### Sidebar
- **Dashboard** - Visão geral com estatísticas
- **Hosts** (grupo) - Lista de agentes registrados
- **Endpoints** (subpágina do Hosts) - Visualização em grid de hosts
- **C2** (grupo) - Comandos e broadcast
- **Comandos** (subpágina do C2) - Lista de todos os comandos executados
- **Broadcast** (subpágina do C2) - Enviar comando para múltiplos hosts

#### Páginas Detalhadas

**Página de Agente**
- Informações do agente (SO, kernel, CPU, RAM, disco, IP)
- Ações organizadas em painéis colapsáveis:
  - Reconhecimento
  - Processos
  - Rede
  - Arquivos e Discos
  - Credenciais e Acesso
  - Administração
- Histórico de comandos e telemetrias

**Página de Comandos**
- Lista filtrável de todos os comandos
- Filtros por status e busca por ação/agente
- Ações: cancelar (pendentes), reenviar (falhados/cancelados)

**Página de Broadcast**
- Checklist de seleção de múltiplos hosts
- Templates rápidos para comandos comuns
- Campo de ação e parâmetros customizáveis

**Outras Páginas**
- **Perfil** - Informações do administrador
- **Preferências** - Configurações do sistema (tema escuro, atualizações)
- **Alterar Senha** - Alterar senha do administrador
- **Sobre** - Informações do sistema e estatísticas

## Segurança

### Criptografia
- Chaves X25519 para handshake inicial
- NaCl box para criptografia de dados
- Nonce aleatório por conexão

### Execução
- Todos os comandos são executados em sessões `setsid` isoladas
- Sem registro de histórico (`set +o history`)
- Sem escrita em arquivos de log (`2>/dev/null`)

### Persistência
- Agente bws pode ser instalado como serviço systemd
- Técnicas de ocultação de processo e arquivos
- Uso de nomes semelhantes a processos do sistema

### Evasão
- Busca por artefatos em diretórios pouco monitorados
- Uso de nomes aparentemente legítimos
- Artefatos temporários e efêmeros

## Configuração

### Requisitos
- **Servidor**: Linux (qualquer distribuição)
- **Go**: 1.21+
- **PHP-FPM**: 7.4+
- **Nginx**: 1.18+
- **MySQL/MariaDB**: 10.2+

### Arquivos de Configuração

1. **Serviço systemd** (`/etc/systemd/system/obws.service`)
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

2. **Configuração Nginx** (`/etc/nginx/conf.d/obws.conf`)
   ```nginx
   server {
       listen 80;
       server_name obws.fun www.obws.fun;

       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

3. **Configuração Nginx Admin** (`/etc/nginx/conf.d/a.obws.fun.conf`)
   ```nginx
   server {
       listen 80;
       server_name a.obws.fun;

       root /opt/bws/admin;
       index index.php;

       location / {
           try_files $uri $uri/ /index.php?$query_string;
       }

       location ~ \.php$ {
           fastcgi_pass unix:/run/php-fpm/www.sock;
           fastcgi_index index.php;
           fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
           include fastcgi_params;
       }
   }
   ```

### Banco de Dados

Tabelas:
- `agents` - informações dos agentes
- `commands` - histórico de comandos
- `telemetry` - dados de telemetria

## Uso

### 1. Instalação

```bash
# Clonar repositório
git clone https://github.com/rsdenck/obws.git /opt/bws-server

# Compilar servidor Go
cd /opt/bws-server
go build -o obws-server

# Copiar para local de instalação
sudo cp obws-server /opt/bws-server/obws-server
sudo chmod +x /opt/bws-server/obws-server

# Instalar serviço systemd
sudo cp /opt/bws-server/obws.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable obws-server
sudo systemctl start obws-server

# Configurar Nginx para proxy reverso
# ... editar /etc/nginx/conf.d/obws.conf ...

# Reiniciar Nginx
sudo systemctl restart nginx
```

### 2. Primeira Inicialização

1. Acessar o painel admin em `https://a.obws.fun`
2. Fazer login com usuário/senha padrão (admin/admin)
3. Aguardar primeiros agentes se conectarem (telemetria push)
4. Começar a gerenciar hosts remotos

### 3. Operações Comuns

#### Gerenciar Agentes
- Acessar **Hosts** para ver lista de agentes
- Clicar em um host para acessar página detalhada
- Usar ações na página de agente (reconhecimento, processos, rede, arquivos, administração)

#### Executar Comandos
- **Comando único**: Na página do agente, usar formulário de execução
- **Broadcast**: Acessar **Broadcast**, selecionar múltiplos hosts, escolher template
- **Templates**: Usar templates rápidos para comandos comuns

#### Monitoramento
- **Dashboard**: Visão geral com estatísticas em tempo real
- **Comandos**: Histórico filtrável de todos os comandos
- **Telemetrias**: Dados brutos dos agentes

## Desenvolvimento

### Compilar

```bash
cd /opt/bws-server
go build -o obws-server
```

### Frontend

O frontend está em `/opt/bws/admin/` e usa:
- Fontes: Google Fonts (Inter)
- Ícones: Font Awesome 6.5.1
- Estilo: CSS customizado (style.css)
- JavaScript: SPA (app.js)

### Testar

```bashn# Testar endpoints Go
curl http://localhost:8080/health

# Testar proxy PHP
curl http://localhost/?page=dashboard
```

## Manutenção

### Backups

```bashn# Backup do banco de dados
sudo mysqldump -u root -p obws_db > backup_$(date +%Y%m%d).sql

# Backup de arquivos
sudo tar -czf obws_backup_$(date +%Y%m%d).tar.gz /opt/bws-server /opt/bws
```

### Atualizações

```bashn# Parar serviço
sudo systemctl stop obws-server

# Atualizar código
cd /opt/bws-server
git pull origin main

# Recompilar e reiniciar
go build -o obws-server
sudo cp obws-server /opt/bws-server/obws-server
sudo systemctl restart obws-server
```

## Roadmap Futuro

### Fase 1: Core C2 (CONCLUÍDA)
- [x] Endpoints C2 básicos
- [x] Compatibilidade bws agent
- [x] Templates de comandos
- [x] Interface Harbor-style

### Fase 2: Avançado C2
- [ ] WebShell interativo (TTY)
- [ ] Upload/download de arquivos
- [ ] VNC/SSH reverse proxy
- [ ] Controle de processo (kill, start, restart)
- [ ] Gerenciamento de serviços
- [ ] Varredura de vulnerabilidades

### Fase 3: Evasão e Persistência
- [ ] Técnicas avançadas de ocultação
- [ ] Persistência em múltiplos vetores
- [ ] Anti-forense
- [ ] Living off the land

### Fase 4: Orquestração
- [ ] Múltiplos operadores
- [ ] RBAC (Role-Based Access Control)
- [ ] Auditoria completa
- [ ] Histórico de sessões
- [ ] Compartilhamento de agentes entre operadores
- [ ] Tags e agrupamentos de hosts
- [ ] Missões/campanhas

## Contribuição

### Guia de Contribuição

1. Fork o repositório
2. Criar branch para funcionalidade (`git checkout -b feature/nova-funcionalidade`)
3. Commitar (`git commit -am 'adicionar funcionalidade'`)
4. Push (`git push origin feature/nova-funcionalidade`)
5. Abrir Pull Request

### Convenções de Código

- Go: Sugestões do Go formatter (gofmt)
- PHP: PSR-2
- JavaScript: ESLint (se disponível)

## Suporte

Para problemas, bugs ou perguntas:
1. Abrir issue no GitHub
2. Incluir logs relevantes
3. Descrever ambiente e passos para reproduzir

## Licença

MIT
