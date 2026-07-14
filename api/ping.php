<?php
// ping.php — test minimal connexion DB, ne retourne que succès/échec
// Supprimer après usage
header('Content-Type: application/json');
$token = $_GET['t'] ?? '';
if ($token !== 'ping_' . date('Ymd')) { http_response_code(403); die('{"error":"forbidden"}'); }

ob_start();
try {
    require_once __DIR__ . '/config.php';
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    ob_end_clean();
    echo json_encode(['db' => 'OK', 'host_len' => strlen(DB_HOST), 'user_len' => strlen(DB_USER), 'pass_len' => strlen(DB_PASS)]);
} catch (Throwable $e) {
    $out = ob_get_clean();
    echo json_encode(['db' => 'FAIL', 'error' => $e->getMessage(), 'config_output' => $out]);
}
