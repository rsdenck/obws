# OBWS - Admin Panel

## URL
https://a.obws.fun/

## Credenciais de Login (default)
| Campo    | Valor |
|----------|-------|
| Usuário  | admin |
| Senha    | admin |

## Observações
- O painel permite gerenciar os agentes bws remotos
- Ações disponíveis: reboot, poweroff, change_password, remove_user, add_sudo, exec, collect
- Os comandos são enviados para a fila do agente e executados via polling
- A autenticação usa bcrypt (SQLite) - futuramente LDAP
