<?php
// DIAGNOSTIC TEMPORAIRE — supprimer après usage
$token = $_GET['t'] ?? '';
if ($token !== 'diag_' . date('Ymd')) {
    http_response_code(403);
    die(json_encode(['error' => 'forbidden']));
}

header('Content-Type: application/json');

$result = [
    'php_version'          => PHP_VERSION,
    'server_config_exists' => file_exists(__DIR__ . '/server_config.php'),
    'htaccess_exists'      => file_exists(__DIR__ . '/.htaccess'),
    'config_php_exists'    => file_exists(__DIR__ . '/config.php'),
];

// Etat brut des vars env
foreach (['APP_SECRET_KEY','DB_HOST','DB_NAME','DB_USER','DB_PASS'] as $var) {
    $val = getenv($var);
    $result['env_raw'][$var] = $val === false ? 'NOT_SET' : (strlen($val) > 0 ? 'SET(len=' . strlen($val) . ')' : 'EMPTY');
}

// Inclure server_config.php et re-checker
if (file_exists(__DIR__ . '/server_config.php')) {
    require_once __DIR__ . '/server_config.php';
    foreach (['APP_SECRET_KEY','DB_HOST','DB_NAME','DB_USER','DB_PASS'] as $var) {
        $val = getenv($var);
        $result['env_after_server_config'][$var] = $val === false ? 'NOT_SET' : (strlen($val) > 0 ? 'SET(len=' . strlen($val) . ')' : 'EMPTY');
    }
}

// Tester config.php lui-meme
if (file_exists(__DIR__ . '/config.php')) {
    try {
        require_once __DIR__ . '/config.php';
        $result['config_php_loaded'] = 'OK';
        $result['constants'] = [
            'DB_HOST' => defined('DB_HOST') ? 'SET(len=' . strlen(DB_HOST) . ')' : 'NOT_DEFINED',
            'DB_NAME' => defined('DB_NAME') ? 'SET(len=' . strlen(DB_NAME) . ')' : 'NOT_DEFINED',
            'DB_USER' => defined('DB_USER') ? 'SET(len=' . strlen(DB_USER) . ')' : 'NOT_DEFINED',
            'DB_PASS' => defined('DB_PASS') ? 'SET(len=' . strlen(DB_PASS) . ')' : 'NOT_DEFINED',
        ];
    } catch (Throwable $e) {
        $result['config_php_loaded'] = 'FAILED: ' . $e->getMessage();
    }
} else {
    $result['config_php_loaded'] = 'FILE_NOT_FOUND';
}

// Connexion PDO directe (sans config.php)
$host = getenv('DB_HOST');
$name = getenv('DB_NAME');
$user = getenv('DB_USER');
$pass = getenv('DB_PASS');
if ($host && $name && $user) {
    try {
        $pdo = new PDO("mysql:host=$host;dbname=$name;charset=utf8mb4", $user, $pass,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $result['db_direct'] = 'SUCCESS';
    } catch (PDOException $e) {
        $result['db_direct'] = 'FAILED: ' . $e->getMessage();
    }
} else {
    $result['db_direct'] = 'SKIPPED';
}

// Connexion PDO via constantes (comme leaderboard.php le fait)
if (defined('DB_HOST') && defined('DB_NAME') && defined('DB_USER') && defined('DB_PASS')) {
    try {
        $pdo2 = new PDO('mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER, DB_PASS, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $result['db_via_constants'] = 'SUCCESS';
    } catch (PDOException $e) {
        $result['db_via_constants'] = 'FAILED: ' . $e->getMessage();
    }
} else {
    $result['db_via_constants'] = 'SKIPPED: constants not defined';
}

echo json_encode($result, JSON_PRETTY_PRINT);
