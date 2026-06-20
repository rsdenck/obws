<?php
$agents = goApi('GET', '/api/agents') ?? [];
$commands = goApi('GET', '/api/commands?status=pending') ?? [];
$pendingCount = count($commands);
$totalTelemetry = 0;
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OBWS - Dashboard</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<nav class="navbar">
  <div class="nav-brand">OBWS</div>
  <div class="nav-links">
    <span class="nav-user"><?= htmlspecialchars($_SESSION['user']) ?></span>
    <a href="?page=logout" class="btn btn-sm">Sair</a>
  </div>
</nav>
<div class="container">
  <div class="page-header">
    <h2 class="page-title">Agentes Remotos</h2>
  </div>

  <div class="stats-grid">
    <div class="stat-card">
      <span class="stat-number"><?= count($agents) ?></span>
      <span class="stat-label">Agentes Registrados</span>
    </div>
    <div class="stat-card">
      <span class="stat-number"><?= $pendingCount ?></span>
      <span class="stat-label">Comandos Pendentes</span>
    </div>
  </div>

  <?php if (empty($agents)): ?>
    <div class="empty-state">
      <div class="empty-state-icon">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="#30363d"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/></svg>
      </div>
      <p class="empty-state-title">Nenhum agente registrado</p>
      <p class="empty-state-desc">Aguardando o primeiro push de telemetria de um agente bws remoto.</p>
    </div>
  <?php else: ?>
    <div class="agent-list">
      <?php foreach ($agents as $a): ?>
      <a href="?page=agent&id=<?= urlencode($a['agent_id']) ?>" class="agent-card">
        <div class="agent-card-main">
          <div class="agent-card-header">
            <span class="agent-hostname"><?= htmlspecialchars($a['hostname']) ?></span>
            <span class="agent-id-text"><code><?= htmlspecialchars($a['agent_id']) ?></code></span>
          </div>
          <div class="agent-card-specs">
            <span class="spec"><?= htmlspecialchars($a['os']) ?></span>
            <span class="spec-sep">|</span>
            <span class="spec"><?= (int)($a['cpu_cores'] ?? 0) ?> cores</span>
            <span class="spec-sep">|</span>
            <span class="spec"><?= number_format((int)($a['mem_mb'] ?? 0)) ?> MB</span>
          </div>
          <div class="agent-card-meta">
            <span class="meta-item">IP: <?= htmlspecialchars($a['last_ip'] ?? '-') ?></span>
            <span class="meta-item">Ultimo contato: <?= htmlspecialchars($a['last_seen'] ?? '-') ?></span>
          </div>
        </div>
        <div class="agent-card-action">
          <span class="btn btn-primary btn-sm">Gerenciar</span>
        </div>
      </a>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>
</div>
</body>
</html>
