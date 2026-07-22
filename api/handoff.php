<?php
// ============================================================
// ENDPOINT : POST /api/handoff.php
// Récupère les infos d'inscription (PIN, tel) via un jeton
// à usage unique, généré par leads.php, jamais exposé en URL.
// ============================================================
require_once __DIR__ . '/config.php';
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    { http_response_code(405); exit; }

try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'Erreur serveur']);
    exit;
}

$table = DB_PREFIX . 'registration_handoff';
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$table}` (
        `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `token`      VARCHAR(64)  NOT NULL,
        `whatsapp`   VARCHAR(20)  DEFAULT '',
        `nom`        VARCHAR(60)  DEFAULT '',
        `pin`        VARCHAR(6)   DEFAULT '',
        `ref_id`     VARCHAR(12)  DEFAULT '',
        `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `expires_at` DATETIME     NOT NULL,
        `used`       TINYINT(1)   NOT NULL DEFAULT 0,
        UNIQUE KEY `uq_token` (`token`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

$body = json_decode(file_get_contents('php://input'), true) ?? [];
$token = substr(trim($body['token'] ?? ''), 0, 64);

if (strlen($token) < 16) {
    echo json_encode(['success'=>false,'error'=>'Jeton invalide']);
    exit;
}

$row = $pdo->prepare("
    SELECT whatsapp, nom, pin, ref_id FROM `{$table}`
    WHERE token = ? AND used = 0 AND expires_at > NOW()
");
$row->execute([$token]);
$data = $row->fetch();

if (!$data) {
    echo json_encode(['success'=>false,'error'=>'Jeton expiré ou déjà utilisé']);
    exit;
}

// Usage unique : on marque immédiatement comme utilisé
$pdo->prepare("UPDATE `{$table}` SET used = 1 WHERE token = ?")->execute([$token]);

echo json_encode([
    'success'  => true,
    'whatsapp' => $data['whatsapp'],
    'nom'      => $data['nom'],
    'pin'      => $data['pin'],
    'ref_id'   => $data['ref_id'],
]);
