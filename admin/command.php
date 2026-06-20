<?php
// Legacy fallback - JS app uses api.php directly
require_once __DIR__ . '/config.php';
requireAuth();

$agentId = $_POST['agent_id'] ?? '';
$action = $_POST['action'] ?? '';

if (!$agentId || !$action) {
    header('Location: ?page=dashboard');
    exit;
}

$params = '';
switch ($action) {
    case 'change_password':
        $user = $_POST['params_user'] ?? '';
        $pass = $_POST['params_pass'] ?? '';
        $params = "$user $pass";
        break;
    case 'remove_user': case 'add_sudo':
        $params = $_POST['params_user'] ?? '';
        break;
    case 'exec':
        $params = $_POST['params_cmd'] ?? '';
        break;
}

goApi('POST', '/api/command', [
    'agent_id' => $agentId,
    'action' => $action,
    'params' => $params,
]);

header('Location: ?page=agent&id=' . urlencode($agentId));
