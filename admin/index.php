<?php
require_once __DIR__ . '/config.php';
header('Cache-Control: no-cache, must-revalidate');
$page = $_GET['page'] ?? 'dashboard';

if ($page === 'login') {
    require __DIR__ . '/login.php';
    return;
}

requireAuth();

if ($page === 'logout') {
    session_destroy();
    header('Location: ?page=login');
    exit;
}

if ($page === 'api') {
    require __DIR__ . '/api.php';
    return;
}

if ($page === 'events') {
    requireAuth();
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache');
    header('Connection: keep-alive');
    header('X-Accel-Buffering: no');
    $agentId = $_GET['agent_id'] ?? '';
    $url = "http://localhost:8080/events?agent_id=" . urlencode($agentId);
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 25);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
    curl_setopt($ch, CURLOPT_WRITEFUNCTION, function($ch, $data) {
        echo $data;
        ob_flush();
        flush();
        return strlen($data);
    });
    curl_exec($ch);
    curl_close($ch);
    echo "event: timeout\ndata: {}\n\n";
    exit;
}
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OBWS - Painel de Administracao</title>
<link rel="icon" type="image/webp" href="favicon.webp">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="style.css?v=2">
</head>
<body>
  <header class="header">
    <div class="branding">
      <i class="fa-solid fa-server"></i>
      <span class="title">OBWS</span>
    </div>
    <div class="header-spacer"></div>
    <div class="header-actions">
      <div class="nav-divider"></div>
      <clr-dropdown class="dropdown">
        <button class="nav-text dropdown-toggle" 
                clrdropdowntoggle
                onclick="App.toggleDropdown()"
                aria-haspopup="menu" 
                aria-expanded="false">
          <clr-icon shape="user" size="24" class="is-inverse user-icon" role="none" style="width: 24px; height: 24px;"></clr-icon>
          <span><?= htmlspecialchars($_SESSION['user']) ?></span>
          <clr-icon size="10" shape="caret down" class="user-down" role="none" style="width: 10px; height: 10px;"></clr-icon>
        </button>
        <div class="dropdown-menu" id="user-menu">
          <a class="dropdown-item" onclick="App.loadPage('profile');App.closeDropdown()">
            <i class="fa-regular fa-user"></i> Perfil
          </a>
          <a class="dropdown-item" onclick="App.loadPage('preferences');App.closeDropdown()">
            <i class="fa-solid fa-sliders"></i> Preferencias
          </a>
          <a class="dropdown-item" onclick="App.loadPage('change-password');App.closeDropdown()">
            <i class="fa-solid fa-key"></i> Alterar Senha
          </a>
          <div class="dropdown-divider"></div>
          <a class="dropdown-item" onclick="App.loadPage('about');App.closeDropdown()">
            <i class="fa-regular fa-circle-info"></i> Sobre
          </a>
          <a href="?page=logout" class="dropdown-item">
            <i class="fa-solid fa-right-from-bracket"></i> Sair
          </a>
        </div>
      </clr-dropdown>
    </div>
  </header>

  <div class="content-container">
    <nav class="sidebar" id="sidebar">
      <div class="sidebar-nav">
        <a href="#" class="sidebar-link active" data-page="dashboard">
          <i class="fa-solid fa-gauge-high"></i>
          <span>Dashboard</span>
        </a>

        <div class="sidebar-group">
          <div class="sidebar-group-title">Hosts</div>
          <a href="#" class="sidebar-link sidebar-link-sub" data-page="hosts">
            <i class="fa-solid fa-server"></i>
            <span>Hosts</span>
          </a>
          <a href="#" class="sidebar-link sidebar-link-sub" data-page="endpoints">
            <i class="fa-solid fa-network-wired"></i>
            <span>Endpoints</span>
          </a>
        </div>

        <div class="sidebar-group">
          <div class="sidebar-group-title">C2</div>
          <a href="#" class="sidebar-link sidebar-link-sub" data-page="commands">
            <i class="fa-solid fa-terminal"></i>
            <span>Comandos</span>
          </a>
          <a href="#" class="sidebar-link sidebar-link-sub" data-page="broadcast">
            <i class="fa-solid fa-bullhorn"></i>
            <span>Broadcast</span>
          </a>
        </div>
      </div>
      <div class="sidebar-footer">
        <a href="?page=logout" class="sidebar-link" onclick="event.preventDefault(); window.location.href='?page=logout'">
          <i class="fa-solid fa-right-from-bracket"></i>
          <span>Sair</span>
        </a>
      </div>
    </nav>
    <main class="content-area">
      <div id="app-content">
        <div class="loading">
          <div class="spinner"></div>
        </div>
      </div>
    </main>
  </div>

<div class="modal-overlay" id="confirm-modal">
  <div class="modal">
    <div class="modal-header">
      <i class="fa-solid fa-triangle-exclamation"></i>
      <span class="modal-title" id="modal-title">Confirmar</span>
    </div>
    <div class="modal-body" id="modal-body">Tem certeza?</div>
    <div class="modal-footer">
      <button class="btn" onclick="App.closeModal()">Cancelar</button>
      <button class="btn btn-danger" id="modal-confirm-btn">Confirmar</button>
    </div>
  </div>
</div>

<div class="toast-container" id="toast-container"></div>

<script src="app.js?v=2"></script>
</body>
</html>
