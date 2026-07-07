<?php
// ============================================================
// ENDPOINT : POST /api/withdraw.php
// Demande de retrait — seuil minimum 2 000 FCFA
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    { http_response_code(405); exit; }

if (!defined('SECRET_KEY')) define('SECRET_KEY', 'AgroPast_S3cr3t_2025!');

try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
         PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'Erreur serveur']);
    exit;
}

$tLeads    = DB_PREFIX . 'leads';
$tScore    = DB_PREFIX . 'scores';
$tWithdraw = DB_PREFIX . 'withdrawals';
$tTok      = DB_PREFIX . 'tokens';

// --- Créer table withdrawals si nécessaire -------------------
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tWithdraw}` (
        `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`     INT UNSIGNED NOT NULL,
        `nom`         VARCHAR(60)  NOT NULL DEFAULT '',
        `telephone`   VARCHAR(20)  NOT NULL,
        `montant`     INT UNSIGNED NOT NULL DEFAULT 2000,
        `score_used`  INT UNSIGNED NOT NULL DEFAULT 0,
        `statut`      ENUM('en_attente','approuve','refuse') NOT NULL DEFAULT 'en_attente',
        `note_admin`  TEXT,
        `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_user` (`user_id`),
        INDEX `idx_statut` (`statut`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// --- Lire le body -------------------------------------------
$raw  = file_get_contents('php://input');
$body = $raw ? (json_decode($raw, true) ?? []) : [];
$body = array_merge($_POST, $body);

$token     = trim($body['token']     ?? '');
$telephone = preg_replace('/[^+\d]/', '', $body['telephone'] ?? '');

// --- Vérifier le token --------------------------------------
if (strlen($token) < 10) {
    echo json_encode(['success'=>false,'error'=>'Non authentifié. Reconnecte-toi.']);
    exit;
}

$authRow = $pdo->prepare("
    SELECT l.id, l.nom, l.whatsapp, l.ref_id
    FROM `{$tTok}` t
    JOIN `{$tLeads}` l ON l.id = t.user_id
    WHERE t.token=? AND t.expires_at > NOW()
");
$authRow->execute([$token]);
$user = $authRow->fetch();

if (!$user) {
    echo json_encode(['success'=>false,'error'=>'Session expirée. Reconnecte-toi.']);
    exit;
}

// --- Vérifier le téléphone ----------------------------------
if (strlen($telephone) < 8) {
    echo json_encode(['success'=>false,'error'=>'Numéro de téléphone invalide.']);
    exit;
}

// --- Récupérer le score -------------------------------------
$scoreRow = $pdo->prepare("SELECT score_total FROM `{$tScore}` WHERE user_id=?");
$scoreRow->execute([$user['id']]);
$sc = $scoreRow->fetch();
$scoreTotal = $sc ? (int)$sc['score_total'] : 0;

// --- Seuil minimum : 33 334 pts = 2 000 FCFA ---------------
// Modèle : 60 FCFA / 1 000 pts → 2 000 FCFA = 33 334 pts
$SEUIL_PTS   = 33334;
$MONTANT_MIN = 2000; // FCFA

if ($scoreTotal < $SEUIL_PTS) {
    $manquant = $SEUIL_PTS - $scoreTotal;
    echo json_encode([
        'success' => false,
        'error'   => "Score insuffisant. Il te faut {$SEUIL_PTS} pts minimum pour retirer {$MONTANT_MIN} FCFA. Il te manque {$manquant} pts.",
        'score_actuel' => $scoreTotal,
        'score_requis' => $SEUIL_PTS,
    ]);
    exit;
}

// --- Vérifier qu'il n'y a pas déjà une demande en attente ---
$pending = $pdo->prepare("
    SELECT id FROM `{$tWithdraw}`
    WHERE user_id=? AND statut='en_attente'
");
$pending->execute([$user['id']]);
if ($pending->fetchColumn()) {
    echo json_encode([
        'success' => false,
        'error'   => 'Tu as déjà une demande de retrait en attente. L\'admin la traitera sous 24-48h.',
    ]);
    exit;
}

// --- Insérer la demande de retrait --------------------------
$pdo->prepare("
    INSERT INTO `{$tWithdraw}` (user_id, nom, telephone, montant, score_used)
    VALUES (?, ?, ?, ?, ?)
")->execute([$user['id'], $user['nom'], $telephone, $MONTANT_MIN, $scoreTotal]);

$withdrawId = $pdo->lastInsertId();

echo json_encode([
    'success'    => true,
    'message'    => "Demande de retrait de {$MONTANT_MIN} FCFA envoyée ! L'admin te contactera sur le {$telephone} sous 24-48h.",
    'montant'    => $MONTANT_MIN,
    'telephone'  => $telephone,
    'withdraw_id'=> $withdrawId,
]);
