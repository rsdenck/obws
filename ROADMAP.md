# OBWS Roadmap - Command & Control Server

## Visão Geral

Este roadmap detalha o desenvolvimento e as funcionalidades do OBWS (Obfuscated Binary Web Shell), um sistema de gerenciamento remoto de servidores com arquitetura C2 (Command & Control). O roadmap está organizado em fases, cada uma com objetivos claros e entregáveis.

## Fase 1: Core C2 (CONCLUÍDA)

### Objetivo
Implementar os componentes essenciais do C2: endpoints API, agente bws compatível, interface de usuário básica e templates de comandos fundamentais.

### Entregáveis Concluídos

#### Backend (Go)
- [x] Endpoints REST API:
  - `POST /api/command` - comando único
  - `POST /api/commands/bulk` - comando em massa
  - `POST /api/commands/cancel/{id}` - cancelar comando
  - `POST /api/commands/retry/{id}` - reenviar comando
  - `GET /api/stats` - estatísticas
  - `POST /api/profile` - gerenciar perfil

- [x] Handlers de polling e resultado:
  - `pollHandler` retorna `job_id` (não `id`)
  - `resultHandler` aceita tanto `command_id` quanto `job_id`
  - `formatParams()` converte params do admin para formato bws

- [x] Sistema de templates:
  - `applyTemplate()` resolve `__template__` para comandos pré-definidos
  - 40+ templates organizados por categoria (reconhecimento, processos, rede, arquivos, creds, admin)

- [x] Compatibilidade bws:
  - `write_file` action com JSON params (`{"path":"...","content":"..."}`)
  - `exec` action com JSON params (`{"command":"..."}`)
  - `collect` action com params vazios

#### Frontend (PHP/JS)
- [x] Interface Harbor-style com header e sidebar
- [x] Menu dropdown do usuário (Perfil, Preferências, Alterar Senha, Sobre, Sair)
- [x] Sidebar agrupado (Hosts, C2)
- [x] Páginas:
  - Dashboard (estatísticas)
  - Hosts / Endpoints (lista e grid)
  - Comandos (lista com filtros)
  - Broadcast (envio para múltiplos hosts)
  - Perfil, Preferências, Alterar Senha, Sobre

- [x] Página de agente com ações C2 organizadas em painéis:
  - Reconhecimento (whoami, id, uname, etc.)
  - Processos (ps, top, etc.)
  - Rede (ip, netstat, etc.)
  - Arquivos e Discos (df, ls, cat, write_file, etc.)
  - Credenciais e Acesso (passwd, shadow, sudoers, etc.)
  - Administração (collect, reboot, poweroff, exec)

#### Segurança e Persistência
- [x] Criptografia X25519 + NaCl box
- [x] Execução de comandos em sessões `setsid` isoladas
- [x] Sem registro de histórico (`set +o history`)
- [x] Sem escrita em logs (`2>/dev/null`)

#### Deploy
- [x] Serviço systemd (`/etc/systemd/system/obws.service`)
- [x] Configuração Nginx para proxy reverso
- [x] Configuração Nginx admin (`a.obws.fun`)

## Fase 2: Avançado C2

### Objetivo
Expandir as capacidades C2 com funcionalidades mais avançadas, incluindo web shell interativo, gerenciamento de arquivos completo e controle de processos.

### Entregáveis Planejados

#### Web Shell e Terminal
- [ ] Web shell interativo (TTY) via WebSocket
- [ ] Comandos interativos em tempo real
- [ ] Upload/download de arquivos via web shell

#### Gerenciamento de Arquivos
- [ ] Upload de arquivos via API
- [ ] Download de arquivos do host remoto
- [ ] Sincronização de diretórios
- [ ] Compressão e extração de arquivos

#### Controle de Processos
- [ ] Matar processos específicos
- [ ] Iniciar serviços do sistema
- [ ] Reiniciar serviços
- [ ] Monitorar processos em tempo real

#### Varredura e Enumeração
- [ ] Varredura de portas (nmap-like)
- [ ] Enumeração de usuários e grupos
- [ ] Detecção de vulnerabilidades
- [ ] Fingerprinting de serviços

#### Rede Avançada
- [ ] Proxy HTTP/HTTPS
- [ ] Tunneling SSH
- [ ] Injeção de pacotes
- [ ] Sniffing de rede

## Fase 3: Evasão e Persistência

### Objetivo
Implementar técnicas avançadas de evasão e persistência para manter acesso e evitar detecção.

### Entregáveis Planejados

#### Evasão
- [ ] Técnicas de ocultação de processo:
  - Injeção de código em processos legítimos
  - Uso de nomes similares a processos do sistema
  - Modificação de strings de linha de comando

- [ ] Técnicas de ocultação de arquivos:
  - Busca por artefatos em diretórios pouco monitorados
  - Uso de nomes aparentemente legítimos
  - Artefatos temporários e efêmeros
  - Sistemas de arquivos ocultos

- [ ] Evasão de monitoramento:
  - Anti-forense
  - Anti-debugging
  - Timestomping
  - Obfuscation de código

#### Persistência
- [ ] Vetores de persistência:
  - Registro de mecanismos de inicialização (Windows)
  - Tarefas agendadas (cron)
  - Serviços de sistema
  - Modificação de arquivos de configuração

- [ ] Sobrevivência a reinicializações:
  - Criação de serviços systemd
  - Uso de init scripts
  - Técnicas de bootkit

## Fase 4: Orquestração e Gestão

### Objetivo
Implementar recursos avançados de orquestração, gerenciamento de múltiplos operadores e auditoria completa.

### Entregáveis Planejados

#### Gestão de Operadores
- [ ] Múltiplos operadores com permissões
- [ ] RBAC (Role-Based Access Control)
- [ ] Auditoria completa de comandos
- [ ] Histórico de sessões

#### Compartilhamento e Colaboração
- [ ] Compartilhamento de agentes entre operadores
- [ ] Tags e agrupamentos de hosts
- [ ] Missões/campanhas
- [ ] Agendamento de tarefas

#### Monitoramento e Alertas
- [ ] Monitoramento em tempo real de agentes
- [ ] Alertas de falha de agente
- [ ] Alertas de comandos suspeitos
- [ ] Dashboards de análise

## Fase 5: Integração e Ecossistema

### Objetivo
Integrar OBWS com outros sistemas e ferramentas de segurança.

### Entregáveis Planejados

#### Integrações
- [ ] Integração com SIEM (Splunk, ELK, Graylog)
- [ ] Integração com SOAR (Cortex XSOAR, Splunk SOAR)
- [ ] Integração com ferramentas de pentest (Metasploit, Burp Suite)
- [ ] API para automação externa

#### Exportação de Dados
- [ ] Exportação de telemetria para análise
- [ ] Exportação de logs para correlação
- [ ] Exportação de comandos para análise forense

## Cronograma de Desenvolvimento

### Sprint 1 (Semanas 1-2)
- Core C2 endpoints e handlers
- Agente bws compatível
- Interface usuário básica

### Sprint 2 (Semanas 3-4)
- Templates de comandos
- Segurança e criptografia
- Deploy e configuração

### Sprint 3 (Semanas 5-6)
- Web shell interativo
- Gerenciamento de arquivos
- Controle de processos

### Sprint 4 (Semanas 7-8)
- Técnicas de evasão
- Persistência
- Anti-forense

### Sprint 5 (Semanas 9-10)
- Múltiplos operadores
- RBAC e auditoria
- Histórico de sessões

### Sprint 6 (Semanas 11-12)
- Integrações com SIEM/SOAR
- Exportação de dados
- Documentação e testes

## Métricas de Sucesso

### Qualidade de Código
- [ ] Testes unitários (cobertura > 80%)
- [ ] Testes de integração
- [ ] Linting e type checking
- [ ] Revisão de código

### Funcionalidade
- [ ] 90% dos requisitos especificados
- [ ] 99.9% de tempo de atividade
- [ ] < 1s de latência para comandos
- [ ] Suporte a 1000+ agentes

### Segurança
- [ ] Sem vazamentos de credenciais em logs
- [ ] Criptografia forte para dados em trânsito
- [ ] Execução isolada de comandos
- [ ] Sem artefatos persistentes detectáveis

## Considerações Especiais

### Compatibilidade
- [ ] Linux (Ubuntu, Debian, CentOS, RHEL)
- [ ] Windows (via WSL2)
- [ ] macOS (limitado)

### Escalabilidade
- [ ] Suporte a múltiplos servidores C2
- [ ] Balanceamento de carga
- [ ] Partição horizontal de agentes

### Privacidade
- [ ] Sem coleta de dados pessoais desnecessários
- [ ] Configuração de privacidade por agente
- [ ] Controle de retenção de dados

## Conclusão

O OBWS é um sistema C2 completo e seguro que evolui continuamente. O roadmap define uma visão clara para o desenvolvimento, garantindo entregas incrementais e valor contínuo para os usuários. O foco principal é manter a segurança, a usabilidade e a eficácia operacional enquanto expandimos as capacidades para atender às necessidades em constante mudança de operadores de segurança e infraestrutura.

## Agradecimentos

Desenvolvimento baseado em:
- Harbor (interface de usuário)
- Go (backend)
- PHP (frontend)
- Font Awesome (ícones)
- Google Fonts (Inter)
- X25519 e NaCl (criptografia)
- SHC (compilação do agente bws)
