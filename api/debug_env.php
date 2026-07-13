<?php
// DIAGNOSTIC TEMPORAIRE — supprimer après usage
// Accessible uniquement avec le bon token
$token = $_GET['t'] ?? '';
if ($token !== 'diag_' . date('Ymd')) {
    http_response_code(403);
    die(json_encode(['error' => 'forbidden']));
}

header('Content-Type: application/json');

// Inclure config pour voir ce qui se passe
$result = [
    'php_version'    => PHP_VERSION,
    'server_config_exists' => file_exists(__DIR__ . '/server_config.php'),
    'htaccess_exists'      => file_exists(__DIR__ . '/.htaccess'),
];

// Lire les vars sans inclure config.php (pour voir l'état brut)
foreach (['APP_SECRET_KEY','DB_HOST','DB_NAME','DB_USER','DB_PASS'] as $var) {
    $val = getenv($var);
    $result['env'][$var] = $val === false ? 'NOT_SET' : (strlen($val) > 0 ? 'SET(len=' . strlen($val) . ')' : 'EMPTY');
}

// Essayer d'inclure server_config.php et re-checker
if (file_exists(__DIR__ . '/server_config.php')) {
    require_once __DIR__ . '/server_config.php';
    foreach (['APP_SECRET_KEY','DB_HOST','DB_NAME','DB_USER','DB_PASS'] as $var) {
        $val = getenv($var);
        $result['after_server_config'][$var] = $val === false ? 'NOT_SET' : (strlen($val) > 0 ? 'SET(len=' . strlen($val) . ')' : 'EMPTY');
    }
}

// Tenter connexion DB avec ce qu'on a
$host = getenv('DB_HOST');
$name = getenv('DB_NAME');
$user = getenv('DB_USER');
$pass = getenv('DB_PASS');
if ($host && $name && $user) {
    try {
        $pdo = new PDO("mysql:host=$host;dbname=$name;charset=utf8mb4", $user, $pass,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $result['db_connect'] = 'SUCCESS';
    } catch (PDOException $e) {
        $result['db_connect'] = 'FAILED: ' . $e->getMessage();
    }
} else {
    $result['db_connect'] = 'SKIPPED: missing vars';
}

echo json_encode($result, JSON_PRETTY_PRINT);
