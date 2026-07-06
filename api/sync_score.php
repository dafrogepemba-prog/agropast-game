<?php
// ============================================================
// ENDPOINT : POST /api/sync_score.php
// Synchronise le score du joueur depuis l'app Flutter
// Appelé après chaque récolte et après chaque Rewarded Ad
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

// Sanitisation
function clean(string $v, int $max = 255): string {
    return substr(trim(htmlspecialchars($v, ENT_QUOTES, 'UTF-8')), 0, $max);
}

$pseudo         = clean($_POST['pseudo']          ?? '');
$email          = clean($_POST['email']           ?? '');
$score_total    = (int)($_POST['score_total']     ?? 0);
$nombre_recoltes= (int)($_POST['nombre_recoltes'] ?? 0);
$event_type     = clean($_POST['event_type']      ?? 'recolte');
$bonus_points   = (int)($_POST['bonus_points']    ?? 0);

// Validation
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(422);
    echo json_encode(['success' => false, 'error' => 'Email invalide']);
    exit;
}

// Connexion DB
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    error_log('sync_score DB error: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'DB error']);
    exit;
}

$table = DB_PREFIX . 'leads';

// Créer table scores si besoin
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `" . DB_PREFIX . "scores` (
        `id`              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `email`           VARCHAR(120) NOT NULL,
        `pseudo`          VARCHAR(60)  NOT NULL,
        `score_total`     INT UNSIGNED DEFAULT 0,
        `nombre_recoltes` INT UNSIGNED DEFAULT 0,
        `event_type`      VARCHAR(30)  DEFAULT 'recolte',
        `bonus_points`    INT UNSIGNED DEFAULT 0,
        `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
            ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_email` (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// Upsert score (INSERT ou UPDATE si email existe déjà)
try {
    $stmt = $pdo->prepare("
        INSERT INTO `" . DB_PREFIX . "scores`
            (email, pseudo, score_total, nombre_recoltes, event_type, bonus_points)
        VALUES
            (:email, :pseudo, :score_total, :nombre_recoltes, :event_type, :bonus_points)
        ON DUPLICATE KEY UPDATE
            pseudo          = VALUES(pseudo),
            score_total     = GREATEST(score_total, VALUES(score_total)),
            nombre_recoltes = GREATEST(nombre_recoltes, VALUES(nombre_recoltes)),
            event_type      = VALUES(event_type),
            bonus_points    = bonus_points + VALUES(bonus_points)
    ");
    $stmt->execute([
        ':email'           => $email,
        ':pseudo'          => $pseudo,
        ':score_total'     => $score_total,
        ':nombre_recoltes' => $nombre_recoltes,
        ':event_type'      => $event_type,
        ':bonus_points'    => $bonus_points,
    ]);

    echo json_encode([
        'success'      => true,
        'score_total'  => $score_total,
        'event_type'   => $event_type,
    ]);

} catch (PDOException $e) {
    error_log('sync_score insert error: ' . $e->getMessage());
    echo json_encode(['success' => false, 'error' => 'Insert error']);
}
