<?php
// ============================================================
// ENDPOINT : POST /api/ad_view.php
// Track rewarded ad views and enforce daily cap of 8 per user
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// Connexion DB
try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'DB error']);
    exit;
}

function cleanInt(mixed $v): int { return max(0, (int)$v); }
function cleanStr(string $v, int $max=255): string {
    return substr(trim(htmlspecialchars($v, ENT_QUOTES, 'UTF-8')), 0, $max);
}

// Tables
$tTok   = DB_PREFIX . 'tokens';
$tLeads = DB_PREFIX . 'leads';
$tAdViews = DB_PREFIX . 'ad_views';

// Create ad_views table if it doesn't exist
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tAdViews}` (
        `id`              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`         INT UNSIGNED NOT NULL,
        `whatsapp`        VARCHAR(20)  NOT NULL,
        `ad_network`      VARCHAR(30)  DEFAULT 'unknown',
        `view_date`       DATE         NOT NULL,
        `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_user_date` (`user_id`, `view_date`),
        INDEX `idx_network_date` (`ad_network`, `view_date`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// ============================================================
// GET : Get today's ad count for user
// ============================================================
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $token = cleanStr($_GET['token'] ?? '', 70);

    if (strlen($token) < 10) {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Non authentifié']);
        exit;
    }

    // Verify token
    $authRow = $pdo->prepare("
        SELECT l.id, l.whatsapp, l.nom
        FROM `{$tTok}` t
        JOIN `{$tLeads}` l ON l.id = t.user_id
        WHERE t.token=? AND t.expires_at > NOW()
    ");
    $authRow->execute([$token]);
    $user = $authRow->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Session expirée']);
        exit;
    }

    // Get count for today (server time)
    $today = date('Y-m-d');
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count
        FROM `{$tAdViews}`
        WHERE user_id=? AND view_date=?
    ");
    $stmt->execute([$user['id'], $today]);
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

    echo json_encode([
        'success' => true,
        'ads_watched_today' => (int)$count,
        'daily_cap' => 8,
        'can_watch' => (int)$count < 8
    ]);
    exit;
}

// ============================================================
// POST : Record an ad view and give reward if under cap
// ============================================================
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw  = file_get_contents('php://input');
    $body = $raw ? (json_decode($raw, true) ?? []) : [];
    $body = array_merge($_POST, $body);

    $token      = cleanStr($body['token'] ?? '', 70);
    $ad_network = cleanStr($body['ad_network'] ?? 'unknown', 30);

    if (strlen($token) < 10) {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Non authentifié']);
        exit;
    }

    // Verify token
    $authRow = $pdo->prepare("
        SELECT l.id, l.whatsapp, l.nom
        FROM `{$tTok}` t
        JOIN `{$tLeads}` l ON l.id = t.user_id
        WHERE t.token=? AND t.expires_at > NOW()
    ");
    $authRow->execute([$token]);
    $user = $authRow->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['success'=>false,'error'=>'Session expirée']);
        exit;
    }

    // Check daily cap (server time)
    $today = date('Y-m-d');
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count
        FROM `{$tAdViews}`
        WHERE user_id=? AND view_date=?
    ");
    $stmt->execute([$user['id'], $today]);
    $count = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

    if ($count >= 8) {
        echo json_encode([
            'success' => false,
            'error' => 'Cap quotidien atteint',
            'ads_watched_today' => 8,
            'daily_cap' => 8
        ]);
        exit;
    }

    // Record the ad view
    $stmt = $pdo->prepare("
        INSERT INTO `{$tAdViews}`
            (user_id, whatsapp, ad_network, view_date)
        VALUES
            (:uid, :wa, :network, :date)
    ");
    $stmt->execute([
        ':uid' => $user['id'],
        ':wa' => $user['whatsapp'],
        ':network' => $ad_network,
        ':date' => $today
    ]);

    echo json_encode([
        'success' => true,
        'ads_watched_today' => $count + 1,
        'daily_cap' => 8,
        'ad_network' => $ad_network,
        'user' => $user['nom']
    ]);
    exit;
}

http_response_code(405);
echo json_encode(['success'=>false,'error'=>'Méthode non autorisée']);
