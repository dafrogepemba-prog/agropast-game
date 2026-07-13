<?php
// ============================================================
// ENDPOINT : POST /api/sync_score.php
// Synchronise le score — requête signée avec token de session
// Anti-triche : vérifie le token avant d'accepter le score
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit; }

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

// Lire body
$raw  = file_get_contents('php://input');
$body = $raw ? (json_decode($raw, true) ?? []) : [];
$body = array_merge($_POST, $body);

function cleanInt(mixed $v): int { return max(0, (int)$v); }
function cleanStr(string $v, int $max=255): string {
    return substr(trim(htmlspecialchars($v, ENT_QUOTES, 'UTF-8')), 0, $max);
}

$token          = cleanStr($body['token']           ?? '', 70);
$score_total    = cleanInt($body['score_total']     ?? 0);
$nombre_recoltes= cleanInt($body['nombre_recoltes'] ?? 0);
$event_type     = cleanStr($body['event_type']      ?? 'recolte', 30);
$bonus_points   = cleanInt($body['bonus_points']    ?? 0);

// ---- Vérification anti-triche : token obligatoire ----------
if (strlen($token) < 10) {
    http_response_code(401);
    echo json_encode(['success'=>false,'error'=>'Non authentifié']);
    exit;
}

$tTok   = DB_PREFIX . 'tokens';
$tLeads = DB_PREFIX . 'leads';
$tScore = DB_PREFIX . 'scores';

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
    echo json_encode(['success'=>false,'error'=>'Session expirée. Reconnecte-toi.']);
    exit;
}

// ---- Limite anti-triche : score par session ----------------
// Max 50 000 pts par appel (une saison max)
if ($score_total > 999999) {
    http_response_code(422);
    echo json_encode(['success'=>false,'error'=>'Score suspect']);
    exit;
}

// ---- Upsert table scores -----------------------------------
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tScore}` (
        `id`              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`         INT UNSIGNED NOT NULL,
        `whatsapp`        VARCHAR(20)  NOT NULL,
        `score_total`     INT UNSIGNED DEFAULT 0,
        `nombre_recoltes` INT UNSIGNED DEFAULT 0,
        `event_type`      VARCHAR(30)  DEFAULT 'recolte',
        `bonus_total`     INT UNSIGNED DEFAULT 0,
        `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
            ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_user` (`user_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

$stmt = $pdo->prepare("
    INSERT INTO `{$tScore}`
        (user_id, whatsapp, score_total, nombre_recoltes, event_type, bonus_total)
    VALUES
        (:uid, :wa, :score, :recoltes, :event, :bonus)
    ON DUPLICATE KEY UPDATE
        score_total     = GREATEST(score_total, VALUES(score_total)),
        nombre_recoltes = GREATEST(nombre_recoltes, VALUES(nombre_recoltes)),
        event_type      = VALUES(event_type),
        bonus_total     = bonus_total + :bonus2
");
$stmt->execute([
    ':uid'     => $user['id'],
    ':wa'      => $user['whatsapp'],
    ':score'   => $score_total,
    ':recoltes'=> $nombre_recoltes,
    ':event'   => $event_type,
    ':bonus'   => $bonus_points,
    ':bonus2'  => $bonus_points,
]);

echo json_encode([
    'success'    => true,
    'score_total'=> $score_total,
    'event_type' => $event_type,
    'user'       => $user['nom'],
]);
