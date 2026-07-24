<?php
// ============================================================
// ENDPOINT : POST /api/sync_score.php
// Synchronise le score — le SERVEUR calcule les points.
//
// Changement de sécurité majeur (2026) :
// Avant, le client envoyait `score_total` et le serveur ne
// faisait que le stocker (avec GREATEST → toujours croissant).
// Ça permettait à quiconque connaissant un token de poser
// n'importe quel score directement via l'API, sans jouer.
//
// Désormais : le client indique seulement QUEL événement a eu
// lieu (event_type). Le serveur applique lui-même le barème de
// points, journalise chaque événement (table d'audit) et
// applique un anti-spam. `score_total` envoyé par le client
// n'est plus utilisé pour le calcul — conservé uniquement à
// titre de log forensique en cas d'écart suspect.
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit; }

// ---- Barème serveur (source de vérité unique) ---------------
// Doit rester synchronisé avec la logique de jeu (parcelle.dart),
// mais c'est désormais CETTE valeur qui compte, pas celle du client.
const SERVER_POINTS_RECOLTE   = 800;   // cf. Parcelle._calculerScore()
const SERVER_POINTS_PER_AD    = 100;   // plafond bonus pub / vue (ajuster si le barème pub change)
const MAX_RECOLTES_PAR_HEURE  = 40;    // largement au-dessus d'un usage normal
const COOLDOWN_RECOLTE_SEC    = 2;     // délai mini entre deux récoltes

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

$token               = cleanStr($body['token']           ?? '', 70);
$event_type          = cleanStr($body['event_type']      ?? 'recolte', 30);
// Conservés uniquement pour comparaison/forensique, jamais utilisés pour le calcul :
$client_score_report = cleanInt($body['score_total']     ?? 0);

$allowedEvents = ['recolte', 'ad_reward', 'admob_reward', 'saison'];
if (!in_array($event_type, $allowedEvents, true)) {
    http_response_code(422);
    echo json_encode(['success'=>false,'error'=>'Type d\'événement inconnu']);
    exit;
}

// ---- Vérification anti-triche : token obligatoire ----------
if (strlen($token) < 10) {
    http_response_code(401);
    echo json_encode(['success'=>false,'error'=>'Non authentifié']);
    exit;
}

$tTok      = DB_PREFIX . 'tokens';
$tLeads    = DB_PREFIX . 'leads';
$tScore    = DB_PREFIX . 'scores';
$tEvents   = DB_PREFIX . 'score_events';
$tAdViews  = DB_PREFIX . 'ad_views';

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
$userId = (int)$user['id'];

// ---- Tables ---------------------------------------------------
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

// Table d'audit append-only : jamais mise à jour, seulement insérée.
// Permet de reconstituer/auditer l'historique complet d'un compte.
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tEvents}` (
        `id`                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`             INT UNSIGNED NOT NULL,
        `event_type`          VARCHAR(30)  NOT NULL,
        `points_awarded`      INT NOT NULL,
        `client_score_report` INT UNSIGNED DEFAULT 0,
        `ip`                  VARCHAR(45)  DEFAULT '',
        `created_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_user_time` (`user_id`, `created_at`),
        INDEX `idx_user_type_time` (`user_id`, `event_type`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

$ip = cleanStr($_SERVER['REMOTE_ADDR'] ?? '', 45);
$pointsToAward = 0;

// ============================================================
// Calcul des points — barème serveur uniquement
// ============================================================
if ($event_type === 'recolte') {

    // Anti-spam : cooldown mini depuis la dernière récolte
    $stmt = $pdo->prepare("
        SELECT created_at FROM `{$tEvents}`
        WHERE user_id=? AND event_type='recolte'
        ORDER BY created_at DESC LIMIT 1
    ");
    $stmt->execute([$userId]);
    $last = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($last) {
        $elapsed = time() - strtotime($last['created_at']);
        if ($elapsed < COOLDOWN_RECOLTE_SEC) {
            http_response_code(429);
            echo json_encode(['success'=>false,'error'=>'Trop rapide, réessaie dans un instant']);
            exit;
        }
    }

    // Anti-spam : plafond horaire
    $stmt = $pdo->prepare("
        SELECT COUNT(*) AS c FROM `{$tEvents}`
        WHERE user_id=? AND event_type='recolte'
          AND created_at > (NOW() - INTERVAL 1 HOUR)
    ");
    $stmt->execute([$userId]);
    $countLastHour = (int)$stmt->fetch(PDO::FETCH_ASSOC)['c'];
    if ($countLastHour >= MAX_RECOLTES_PAR_HEURE) {
        http_response_code(429);
        echo json_encode(['success'=>false,'error'=>'Limite horaire de récoltes atteinte']);
        exit;
    }

    $pointsToAward = SERVER_POINTS_RECOLTE;

} elseif ($event_type === 'ad_reward' || $event_type === 'admob_reward') {

    // Le bonus n'est accordé que s'il correspond à une vue de pub
    // réellement enregistrée aujourd'hui (table ad_views, alimentée
    // par ad_view.php) et pas déjà "consommée" par un précédent bonus.
    $today = date('Y-m-d');

    $stmt = $pdo->prepare("
        SELECT COUNT(*) AS c FROM `{$tAdViews}`
        WHERE user_id=? AND view_date=?
    ");
    $stmt->execute([$userId, $today]);
    $adViewsToday = (int)$stmt->fetch(PDO::FETCH_ASSOC)['c'];

    $stmt = $pdo->prepare("
        SELECT COUNT(*) AS c FROM `{$tEvents}`
        WHERE user_id=? AND event_type IN ('ad_reward','admob_reward')
          AND DATE(created_at)=?
    ");
    $stmt->execute([$userId, $today]);
    $bonusesToday = (int)$stmt->fetch(PDO::FETCH_ASSOC)['c'];

    if ($bonusesToday >= $adViewsToday) {
        http_response_code(422);
        echo json_encode(['success'=>false,'error'=>'Aucune vue de pub valide disponible pour un bonus']);
        exit;
    }

    $pointsToAward = SERVER_POINTS_PER_AD;

} elseif ($event_type === 'saison') {
    // Marqueur de fin de saison, aucun point accordé directement.
    $pointsToAward = 0;
}

// ============================================================
// Écriture : log d'audit + mise à jour du score authoritatif
// ============================================================
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare("
        INSERT INTO `{$tEvents}`
            (user_id, event_type, points_awarded, client_score_report, ip)
        VALUES (:uid, :etype, :pts, :creport, :ip)
    ");
    $stmt->execute([
        ':uid'     => $userId,
        ':etype'   => $event_type,
        ':pts'     => $pointsToAward,
        ':creport' => $client_score_report,
        ':ip'      => $ip,
    ]);

    $incRecoltes = ($event_type === 'recolte') ? 1 : 0;

    $stmt = $pdo->prepare("
        INSERT INTO `{$tScore}`
            (user_id, whatsapp, score_total, nombre_recoltes, event_type, bonus_total)
        VALUES
            (:uid, :wa, :pts, :inc, :etype, :bonus)
        ON DUPLICATE KEY UPDATE
            score_total     = score_total + :pts2,
            nombre_recoltes = nombre_recoltes + :inc2,
            event_type      = VALUES(event_type),
            bonus_total     = bonus_total + :bonus2
    ");
    $bonusPart = ($event_type === 'ad_reward' || $event_type === 'admob_reward') ? $pointsToAward : 0;
    $stmt->execute([
        ':uid'    => $userId,
        ':wa'     => $user['whatsapp'],
        ':pts'    => $pointsToAward,
        ':inc'    => $incRecoltes,
        ':etype'  => $event_type,
        ':bonus'  => $bonusPart,
        ':pts2'   => $pointsToAward,
        ':inc2'   => $incRecoltes,
        ':bonus2' => $bonusPart,
    ]);

    $pdo->commit();
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'Erreur d\'enregistrement']);
    exit;
}

// Relire le score authoritatif pour le renvoyer au client
$stmt = $pdo->prepare("SELECT score_total FROM `{$tScore}` WHERE user_id=?");
$stmt->execute([$userId]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

echo json_encode([
    'success'         => true,
    'score_total'     => (int)($row['score_total'] ?? 0),
    'points_awarded'  => $pointsToAward,
    'event_type'      => $event_type,
    'user'            => $user['nom'],
]);
