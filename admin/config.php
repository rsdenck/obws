<?php
session_start();
$dbPath = '/var/lib/obws/obws.db';
$apiBase = 'http://localhost:8080';

// LDAP Configuration (set to empty strings to disable LDAP)
$ldapConfig = [
    'enabled'  => false,
    'host'     => 'ldap://ldap.example.com',
    'port'     => 389,
    'base_dn'  => 'dc=example,dc=com',
    'filter'   => '(&(objectClass=posixAccount)(uid=%s))',
    'bind_dn'  => 'cn=admin,dc=example,dc=com',
    'bind_pw'  => '',
];

function goApi($method, $path, $data = null) {
    global $apiBase;
    $ch = curl_init($apiBase . $path);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
    if ($data !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    $res = curl_exec($ch);
    $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return json_decode($res, true);
}

function authLDAP($username, $password) {
    global $ldapConfig;
    if (!$ldapConfig['enabled'] || !extension_loaded('ldap')) {
        return false;
    }
    if (empty($username) || empty($password)) {
        return false;
    }
    $conn = @ldap_connect($ldapConfig['host'], $ldapConfig['port']);
    if (!$conn) {
        error_log("authLDAP: falha ao conectar em {$ldapConfig['host']}:{$ldapConfig['port']}");
        return false;
    }
    ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
    ldap_set_option($conn, LDAP_OPT_REFERRALS, 0);

    if (!empty($ldapConfig['bind_dn']) && !empty($ldapConfig['bind_pw'])) {
        if (!@ldap_bind($conn, $ldapConfig['bind_dn'], $ldapConfig['bind_pw'])) {
            error_log("authLDAP: falha no bind inicial: " . ldap_error($conn));
            ldap_close($conn);
            return false;
        }
    }

    $filter = sprintf($ldapConfig['filter'], ldap_escape($username, '', LDAP_ESCAPE_FILTER));
    $search = @ldap_search($conn, $ldapConfig['base_dn'], $filter, ['dn'], 0, 1);
    if (!$search) {
        ldap_close($conn);
        return false;
    }
    $entries = ldap_get_entries($conn, $search);
    if ($entries['count'] === 0) {
        ldap_close($conn);
        return false;
    }
    $userDn = $entries[0]['dn'];
    if (!@ldap_bind($conn, $userDn, $password)) {
        error_log("authLDAP: falha ao autenticar $username: " . ldap_error($conn));
        ldap_close($conn);
        return false;
    }
    ldap_close($conn);
    error_log("authLDAP: $username autenticado com sucesso via LDAP");
    return true;
}

function authUser($username, $password) {
    if (authLDAP($username, $password)) {
        return true;
    }

    global $dbPath;
    try {
        $db = new PDO("sqlite:$dbPath");
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $stmt = $db->prepare("SELECT password_hash FROM users WHERE username = ?");
        $stmt->execute([$username]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) {
            error_log("authUser: usuario nao encontrado: $username");
            return false;
        }
        $ret = password_verify($password, $row['password_hash']);
        error_log("authUser: username=$username result=" . ($ret ? 'OK' : 'FAIL'));
        return $ret;
    } catch (Exception $e) {
        error_log("authUser error: " . $e->getMessage());
        return false;
    }
}

function requireAuth() {
    if (!isset($_SESSION['user'])) {
        header('Location: ?page=login');
        exit;
    }
}
