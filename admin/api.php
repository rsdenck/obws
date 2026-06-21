<?php
require_once __DIR__ . '/config.php';
requireAuth();

header('Content-Type: application/json');

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'agents':
        echo json_encode(goApi('GET', '/api/agents') ?? []);
        break;

    case 'agent':
        $id = $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        $data = goApi('GET', "/api/agents/$id");
        if (!$data || isset($data['error'])) { http_response_code(404); echo '{"error":"not found"}'; exit; }
        echo json_encode($data);
        break;

    case 'telemetry':
        $id = $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        echo json_encode(goApi('GET', "/api/agents/$id/telemetry") ?? []);
        break;

    case 'commands':
        $status = $_GET['status'] ?? '';
        $agt = $_GET['agent_id'] ?? '';
        $q = '';
        if ($status && $agt) $q = "?status=$status&agent_id=$agt";
        elseif ($status) $q = "?status=$status";
        elseif ($agt) $q = "?agent_id=$agt";
        echo json_encode(goApi('GET', "/api/commands$q") ?? []);
        break;

    case 'agent_commands':
        $id = $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        echo json_encode(goApi('GET', "/api/commands?agent_id=$id") ?? []);
        break;

    case 'command':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!$input || empty($input['agent_id']) || empty($input['action'])) {
            http_response_code(400);
            echo '{"error":"agent_id e action obrigatorios"}';
            exit;
        }
        $result = goApi('POST', '/api/command', $input);
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'bulk_command':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        if (!$input || empty($input['agent_ids']) || empty($input['action'])) {
            http_response_code(400);
            echo '{"error":"agent_ids e action obrigatorios"}';
            exit;
        }
        $result = goApi('POST', '/api/commands/bulk', $input);
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'cancel_command':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        $id = $input['id'] ?? $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        $result = goApi('POST', "/api/commands/cancel/$id", []);
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'retry_command':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        $id = $input['id'] ?? $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        $result = goApi('POST', "/api/commands/retry/$id", []);
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'stats':
        echo json_encode(goApi('GET', '/api/stats') ?? []);
        break;

    case 'profile':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        $result = goApi('POST', '/api/profile', $input);
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'delete_agent':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo '{"error":"use POST"}';
            exit;
        }
        $input = json_decode(file_get_contents('php://input'), true);
        $id = $input['id'] ?? $_GET['id'] ?? '';
        if (!$id) { http_response_code(400); echo '{"error":"missing id"}'; exit; }
        $result = goApi('DELETE', "/api/agents/$id");
        echo json_encode($result ?? ['error' => 'api error']);
        break;

    case 'pending_count':
        $cmds = goApi('GET', '/api/commands?status=pending') ?? [];
        echo json_encode(['count' => count($cmds)]);
        break;

    default:
        http_response_code(404);
        echo '{"error":"unknown action"}';
}
