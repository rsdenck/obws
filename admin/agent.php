<?php
$agentId = $_GET['id'] ?? '';
if (!$agentId) {
    header('Location: ?page=dashboard');
    exit;
}

$agent = goApi('GET', "/api/agents/$agentId");
if (!$agent || isset($agent['error'])) {
    echo '<div class="alert alert-error">Agente nao encontrado</div>';
    echo '<a href="?page=dashboard" class="btn">Voltar</a>';
    exit;
}

$telemetry = goApi('GET', "/api/agents/$agentId/telemetry") ?? [];
$agentCmds = goApi('GET', '/api/commands') ?? [];
$agentCmds = array_filter($agentCmds, fn($c) => $c['agent_id'] === $agentId);
$pendingCount = count(array_filter($agentCmds, fn($c) => $c['status'] === 'pending'));
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OBWS - <?= htmlspecialchars($agent['hostname']) ?></title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<nav class="navbar">
  <div class="nav-brand">OBWS</div>
  <div class="nav-links">
    <a href="?page=dashboard" class="btn btn-sm">Dashboard</a>
    <span class="nav-user"><?= htmlspecialchars($_SESSION['user']) ?></span>
    <a href="?page=logout" class="btn btn-sm">Sair</a>
  </div>
</nav>
<div class="container">
  <div class="page-header">
    <div>
      <h2 class="page-title"><?= htmlspecialchars($agent['hostname']) ?></h2>
      <span class="agent-id-badge">ID: <code><?= htmlspecialchars($agent['agent_id']) ?></code></span>
      <?php if ($pendingCount > 0): ?>
        <span class="badge badge-pending"><?= $pendingCount ?> comando(s) pendente(s)</span>
      <?php endif; ?>
    </div>
  </div>

  <div class="info-grid">
    <div class="info-card">
      <span class="info-label">Sistema Operacional</span>
      <span class="info-value"><?= htmlspecialchars($agent['os']) ?></span>
    </div>
    <div class="info-card">
      <span class="info-label">Kernel</span>
      <span class="info-value"><?= htmlspecialchars($agent['kernel']) ?></span>
    </div>
    <div class="info-card">
      <span class="info-label">CPU</span>
      <span class="info-value"><?= (int)($agent['cpu_cores'] ?? 0) ?> cores</span>
    </div>
    <div class="info-card">
      <span class="info-label">Memoria RAM</span>
      <span class="info-value"><?= number_format((int)($agent['mem_mb'] ?? 0)) ?> MB</span>
    </div>
    <div class="info-card">
      <span class="info-label">Disco</span>
      <span class="info-value"><?= htmlspecialchars($agent['disk'] ?? '-') ?></span>
    </div>
    <div class="info-card">
      <span class="info-label">Ultimo IP</span>
      <span class="info-value"><?= htmlspecialchars($agent['last_ip'] ?? '-') ?></span>
    </div>
    <div class="info-card">
      <span class="info-label">Ultimo Contato</span>
      <span class="info-value"><?= htmlspecialchars($agent['last_seen'] ?? '-') ?></span>
    </div>
  </div>

  <div class="section">
    <h3 class="section-title">Acoes Remotas</h3>
    <div class="actions-grid">
      <form method="POST" action="?page=command" class="action-form">
        <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
        <input type="hidden" name="action" value="reboot">
        <button type="submit" class="action-btn action-btn-danger" onclick="return confirm('Reiniciar <?= htmlspecialchars($agent['hostname']) ?>?')">
          <svg class="action-icon" width="22" height="22"><use href="icons.svg#ic-reboot"/></svg>
          <span class="action-label">Reboot</span>
          <span class="action-desc">Reiniciar o sistema</span>
        </button>
      </form>

      <form method="POST" action="?page=command" class="action-form">
        <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
        <input type="hidden" name="action" value="poweroff">
        <button type="submit" class="action-btn action-btn-danger" onclick="return confirm('Desligar <?= htmlspecialchars($agent['hostname']) ?>?')">
          <svg class="action-icon" width="22" height="22"><use href="icons.svg#ic-poweroff"/></svg>
          <span class="action-label">Poweroff</span>
          <span class="action-desc">Desligar o sistema</span>
        </button>
      </form>

      <form method="POST" action="?page=command" class="action-form">
        <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
        <input type="hidden" name="action" value="collect">
        <button type="submit" class="action-btn action-btn-primary">
          <svg class="action-icon" width="22" height="22"><use href="icons.svg#ic-collect"/></svg>
          <span class="action-label">Coletar Telemetria</span>
          <span class="action-desc">Solicitar dados do agente</span>
        </button>
      </form>

      <div class="action-card">
        <div class="action-card-header" onclick="this.parentElement.classList.toggle('expanded')">
          <svg class="action-icon" width="22" height="22"><use href="icons.svg#ic-users"/></svg>
          <span class="action-label">Gerenciar Usuarios</span>
          <svg class="expand-icon" width="20" height="20"><use href="icons.svg#ic-chevron-down"/></svg>
        </div>
        <div class="action-card-body">
          <form method="POST" action="?page=command" class="action-inline-form">
            <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
            <input type="hidden" name="action" value="change_password">
            <div class="form-row">
              <input type="text" name="params_user" placeholder="Usuario" required>
              <input type="password" name="params_pass" placeholder="Nova senha" required>
              <button type="submit" class="btn btn-warning">Alterar Senha</button>
            </div>
          </form>
          <form method="POST" action="?page=command" class="action-inline-form">
            <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
            <input type="hidden" name="action" value="remove_user">
            <div class="form-row">
              <input type="text" name="params_user" placeholder="Usuario" required>
              <button type="submit" class="btn btn-danger">Remover Usuario</button>
            </div>
          </form>
          <form method="POST" action="?page=command" class="action-inline-form">
            <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
            <input type="hidden" name="action" value="add_sudo">
            <div class="form-row">
              <input type="text" name="params_user" placeholder="Usuario" required>
              <button type="submit" class="btn btn-success">Adicionar Sudo</button>
            </div>
          </form>
        </div>
      </div>

      <div class="action-card expanded">
        <div class="action-card-header" onclick="this.parentElement.classList.toggle('expanded')">
          <svg class="action-icon" width="22" height="22"><use href="icons.svg#ic-exec"/></svg>
          <span class="action-label">Executar Comando</span>
          <svg class="expand-icon" width="20" height="20"><use href="icons.svg#ic-chevron-down"/></svg>
        </div>
        <div class="action-card-body">
          <form method="POST" action="?page=command" class="action-inline-form">
            <input type="hidden" name="agent_id" value="<?= htmlspecialchars($agentId) ?>">
            <input type="hidden" name="action" value="exec">
            <div class="form-row">
              <input type="text" name="params_cmd" placeholder="comando a executar" required class="input-wide">
              <button type="submit" class="btn btn-primary">Executar</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>

  <div class="section">
    <h3 class="section-title">Comandos Enviados</h3>
    <?php if (empty($agentCmds)): ?>
      <div class="empty-state">Nenhum comando enviado para este agente.</div>
    <?php else: ?>
      <div class="table-responsive">
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Acao</th>
              <th>Parametros</th>
              <th>Status</th>
              <th>Resultado</th>
              <th>Criado</th>
              <th>Concluido</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($agentCmds as $c): ?>
            <tr>
              <td class="cell-id">#<?= $c['id'] ?></td>
              <td><span class="cmd-label"><?= htmlspecialchars($c['action']) ?></span></td>
              <td class="cell-params"><?= htmlspecialchars($c['params'] ?: '-') ?></td>
              <td>
                <?php if ($c['status'] === 'pending'): ?>
                  <span class="badge badge-pending">Pendente</span>
                <?php elseif ($c['status'] === 'sent'): ?>
                  <span class="badge badge-sent">Enviado</span>
                <?php elseif ($c['status'] === 'completed'): ?>
                  <span class="badge badge-success">Concluido</span>
                <?php elseif ($c['status'] === 'failed'): ?>
                  <span class="badge badge-error">Falhou</span>
                <?php else: ?>
                  <span class="badge"><?= htmlspecialchars($c['status']) ?></span>
                <?php endif; ?>
              </td>
              <td class="cell-result"><?= htmlspecialchars(mb_substr($c['result'] ?: '-', 0, 80)) ?></td>
              <td class="cell-date"><?= htmlspecialchars($c['created_at']) ?></td>
              <td class="cell-date"><?= htmlspecialchars($c['completed_at'] ?: '-') ?></td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    <?php endif; ?>
  </div>

  <div class="section">
    <h3 class="section-title">Ultimas Telemetrias</h3>
    <?php if (empty($telemetry)): ?>
      <div class="empty-state">Nenhuma telemetria recebida ainda.</div>
    <?php else: ?>
      <div class="table-responsive">
        <table class="table table-compact">
          <thead>
            <tr>
              <th>ID</th>
              <th>Timestamp</th>
              <th>Payload</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($telemetry as $t): ?>
            <tr>
              <td class="cell-id">#<?= $t['id'] ?></td>
              <td class="cell-date"><?= htmlspecialchars($t['received_at']) ?></td>
              <td class="cell-payload"><pre><?= htmlspecialchars(json_encode(json_decode($t['payload']), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) ?></pre></td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    <?php endif; ?>
  </div>
</div>
</body>
</html>
