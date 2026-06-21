# CARACTERISTICAS QUE DEVEM TER NO SERVIDOR: OBWS-SERVER QUE SERÃO IMPLEMENTADAS NO: bws -> QUE SERÁ O AGENT REMOTO OU MELHOR (BINARIO REMOTO) QUE SERÁ CONTROLADO PELO C2
-------------------------
# BINARIO REMOTO: bws -> /usr/local/bin/bws -> ONDE DEVERÁ SER COLOCADO!
------ FUNCIONALIDADES DO OBWS-SERVER COMO C2:
# Reconhecimento do host
Identificação do sistema operacional
Usuário atual
Privilégios
Processos em execução
Serviços instalados
Interfaces de rede
Informações de domínio
# Navegação e coleta de informações
Listagem de diretórios
Leitura de arquivos
Busca de arquivos por nome ou conteúdo
Inventário de softwares instalados
Coleta de logs
# Gerenciamento de processos
Enumerar processos
Iniciar processos
Encerrar processos
Monitorar processos específicos
# Execução remota
Shell interativo (SEMPRE OCULTO E SEM LOGS)
Execução de comandos individuais
Execução de scripts (SEMPRE OCULTO E SEM LOGS)
Automação de tarefas administrativas
# Transferência de arquivos
Upload
Download
Sincronização de diretórios
Coleta de artefatos
# Movimentação na rede
Descoberta de hosts
Descoberta de serviços
Criação de túneis
Encaminhamento de portas (port forwarding)
Proxies internos
# Persistência
Registro de mecanismos de inicialização
Tarefas agendadas
Serviços de sistema
Outras técnicas de sobrevivência a reinicializações
# Escalação de privilégios
Verificação de permissões
Identificação de configurações inseguras
Tentativas controladas de elevação de privilégios
# Coleta de credenciais
Inventário de credenciais armazenadas
Tokens de autenticação
Sessões ativas
Integrações com mecanismos de autenticação corporativos
# Interação com Active Directory
Descoberta de controladores de domínio
Enumeração de usuários e grupos
Relações de confiança
Políticas e permissões
-- EM CASO DE O BWS SER ADICIONADO NO WINDOWS
# Operações de memória
Inspeção de memória de processos
Carregamento de módulos em memória
Execução sem gravação em disco
# Controle do agente
Alteração do intervalo de comunicação (beacon)
Mudança de servidor C2
Atualização do agente
Remoção do agente
Migração para outro processo
--------------------------------------
# ATIVIDADES EXTRAS:
# Gestão e Operação
Controle de múltiplos operadores
Controle de permissões (RBAC)
Auditoria completa de comandos
Histórico de sessões
Compartilhamento de agentes entre operadores
Tags e agrupamentos de hosts
Missões/campanhas
# Gestão de Agentes
Atualização automática
Migração entre processos
Migração entre hosts
Self-healing
Auto-reconexão
Configuração remota
# Inventário Avançado
- Além do básico:
Hypervisor detectado -> TODOS OS TIPOS
Cloud provider detectado
Containers ativos
Kubernetes
Docker
Proxmox
VMware
AWS
Azure
GCP
# Ocultação de Processo
- O agente tenta se misturar aos processos legítimos do sistema.
Uso de nomes semelhantes a processos do sistema.
Execução dentro de processos já existentes.
Redução de indicadores visíveis em listas de processos.
# Ocultação de Arquivos
- Busca dificultar a identificação dos artefatos no disco.
Técnicas observadas:

Diretórios pouco monitorados.
Nomes aparentemente legítimos.
Artefatos temporários e efêmeros.
Minimização de arquivos persistentes.
# Evasão de Monitoramento
