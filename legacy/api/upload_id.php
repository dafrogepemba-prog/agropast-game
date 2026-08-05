<?php
// ============================================================
// ENDPOINT : POST /api/upload_id.php
// Upload d'une pièce d'identité pour vérification avant retrait.
//
// Sécurité :
//  - Authentifié par token (même mécanisme que les autres endpoints)
//  - Fichier stocké HORS de tout dossier public (uploads/ protégé
//    par .htaccess "Deny from all"), jamais servi par une URL directe
//  - Consultable uniquement via admin/view_id.php (session admin requise)
//  - Supprimé automatiquement une fois la vérification traitée
//    (approuvée ou refusée) — on ne garde qu'une trace du statut,
//    pas le document lui-même (principe de minimisation des données)
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Client-Platform');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    { http_response_code(405); exit; }

// Réservé à l'app native, comme le retrait lui-même.
$clientPlatform = $_SERVER['HTTP_X_CLIENT_PLATFORM'] ?? '';
if ($clientPlatform !== 'app') {
    http_response_code(403);
    echo json_encode(['success'=>false,'error'=>"Réservé à l'application Android."]);
    exit;
}

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

$tLeads   = DB_PREFIX . 'leads';
$tTok     = DB_PREFIX . 'tokens';
$tIdVerif = DB_PREFIX . 'id_verifications';

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tIdVerif}` (
        `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`     INT UNSIGNED NOT NULL,
        `file_path`   VARCHAR(255) DEFAULT NULL,
        `statut`      ENUM('en_attente','approuve','refuse') NOT NULL DEFAULT 'en_attente',
        `note_admin`  VARCHAR(255) DEFAULT '',
        `reviewed_by` VARCHAR(100) DEFAULT '',
        `reviewed_at` DATETIME DEFAULT NULL,
        `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_user` (`user_id`),
        INDEX `idx_statut` (`statut`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

$raw  = file_get_contents('php://input');
$body = $raw ? (json_decode($raw, true) ?? []) : [];

$token      = trim($body['token'] ?? '');
$imageB64   = $body['image_base64'] ?? '';
$mime       = $body['mime'] ?? 'image/jpeg';

if (strlen($token) < 10) {
    echo json_encode(['success'=>false,'error'=>'Non authentifié. Reconnecte-toi.']);
    exit;
}

$authRow = $pdo->prepare("
    SELECT l.id FROM `{$tTok}` t
    JOIN `{$tLeads}` l ON l.id = t.user_id
    WHERE t.token=? AND t.expires_at > NOW()
");
$authRow->execute([$token]);
$user = $authRow->fetch();

if (!$user) {
    echo json_encode(['success'=>false,'error'=>'Session expirée. Reconnecte-toi.']);
    exit;
}

// --- Ne pas accepter un nouvel envoi si une demande est déjà en attente ---
$pending = $pdo->prepare("
    SELECT id FROM `{$tIdVerif}` WHERE user_id=? AND statut='en_attente'
");
$pending->execute([$user['id']]);
if ($pending->fetchColumn()) {
    echo json_encode(['success'=>false,'error'=>'Ta pièce est déjà en cours de vérification.']);
    exit;
}

// --- Validation basique de l'image ---------------------------
$allowedMimes = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
if (!isset($allowedMimes[$mime])) {
    echo json_encode(['success'=>false,'error'=>'Format d\'image non supporté (JPEG/PNG/WEBP uniquement).']);
    exit;
}
if (empty($imageB64)) {
    echo json_encode(['success'=>false,'error'=>'Aucune image reçue.']);
    exit;
}

$imageData = base64_decode($imageB64, true);
if ($imageData === false) {
    echo json_encode(['success'=>false,'error'=>'Image invalide.']);
    exit;
}
// 8 Mo max
if (strlen($imageData) > 8 * 1024 * 1024) {
    echo json_encode(['success'=>false,'error'=>'Image trop volumineuse (8 Mo max).']);
    exit;
}

// --- Stockage hors dossier public -----------------------------
$uploadDir = __DIR__ . '/uploads/id_verifications';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0750, true);
}
// .htaccess de protection (créé si absent, ceinture+bretelles en plus
// du .htaccess déjà déployé au niveau uploads/ parent)
$htaccessProtect = __DIR__ . '/uploads/.htaccess';
if (!file_exists($htaccessProtect)) {
    file_put_contents($htaccessProtect, "Order Allow,Deny\nDeny from all\n");
}

$filename = 'id_' . $user['id'] . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $allowedMimes[$mime];
$filepath = $uploadDir . '/' . $filename;

if (!file_put_contents($filepath, $imageData)) {
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'Échec de l\'enregistrement, réessaie.']);
    exit;
}

$stmt = $pdo->prepare("
    INSERT INTO `{$tIdVerif}` (user_id, file_path, statut)
    VALUES (?, ?, 'en_attente')
");
$stmt->execute([$user['id'], 'id_verifications/' . $filename]);

echo json_encode([
    'success' => true,
    'message' => "Pièce reçue ! Elle sera vérifiée sous 24-48h.",
]);
