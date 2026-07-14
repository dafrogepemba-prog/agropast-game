<?php
header('Content-Type: application/json');
$token = $_GET['t'] ?? '';
if ($token !== 'ping_' . date('Ymd')) { http_response_code(403); die('{"error":"forbidden"}'); }
ob_start();
try {
    require_once __DIR__ . '/config.php';
    $pdo = new PDO('mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    ob_end_clean();
    echo json_encode(['db'=>'OK','host_len'=>strlen(DB_HOST),'user_len'=>strlen(DB_USER),'pass_len'=>strlen(DB_PASS),'host_val'=>DB_HOST]);
} catch (Throwable $e) {
    $out = ob_get_clean();
    // Aussi lire server_config.php brut pour voir ce qui a ete deploye
    $sc = file_exists(__DIR__.'/server_config.php') ? file_get_contents(__DIR__.'/server_config.php') : 'NOT FOUND';
    // Masquer les valeurs sensibles — garder seulement les noms de variables
    $sc_safe = preg_replace('/putenv\("(\w+)=[^"]+"\)/', 'putenv("$1=***")', $sc);
    echo json_encode(['db'=>'FAIL','error'=>$e->getMessage(),'host_val'=>defined('DB_HOST')?DB_HOST:'UNDEF','server_config_content'=>$sc_safe]);
}
