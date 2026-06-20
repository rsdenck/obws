<?php
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    if (authUser($username, $password)) {
        $_SESSION['user'] = $username;
        header('Location: ?page=dashboard');
        exit;
    }
    $error = 'Usuário ou senha inválidos';
}
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OBWS - Login</title>
<link rel="icon" type="image/webp" href="favicon.webp">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="style.css?v=2">
</head>
<body class="login-body">
<div class="login-container">
  <div class="login-box">
    <div style="text-align:center;margin-bottom:16px"><img src="logo.webp" alt="OBWS" style="width:64px;height:64px;border-radius:6px"></div>
    <h1><i class="fa-solid fa-server"></i>OBWS</h1>
    <p class="login-subtitle">Administração de Agentes Remotos</p>
    <?php if ($error): ?>
      <div class="alert alert-error"><i class="fa-solid fa-circle-exclamation"></i> <?= htmlspecialchars($error) ?></div>
    <?php endif; ?>
    <form method="POST" class="login-form">
      <div class="form-group">
        <label for="username">Usuário</label>
        <input type="text" id="username" name="username" placeholder="admin" required autofocus>
      </div>
      <div class="form-group">
        <label for="password">Senha</label>
        <input type="password" id="password" name="password" placeholder="••••••••" required>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Entrar</button>
    </form>
  </div>
</div>
</body>
</html>
