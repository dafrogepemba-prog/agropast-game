<?php
// ============================================================
// ENDPOINT : POST /api/auth.php
// Gère inscription + connexion par numéro WhatsApp + PIN
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    { http_response_code(405); exit; }

// --- Connexion DB -------------------------------------------
try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
         PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    error_log('auth.php DB: '.$e->getMessage());
    http_response_code(500);
    echo json_encode(['success'=>false,'error'=>'Erreur serveur']);
    exit;
}

$table  = DB_PREFIX . 'leads';
$tScore = DB_PREFIX . 'scores';

// --- Créer / migrer les tables ------------------------------
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$table}` (
        `id`               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_id`           VARCHAR(12)  NOT NULL DEFAULT '',
        `whatsapp`         VARCHAR(20)  NOT NULL,
        `nom`              VARCHAR(60)  DEFAULT '',
        `email`            VARCHAR(120) DEFAULT '',
        `pays`             VARCHAR(60)  DEFAULT '',
        `pin_hash`         VARCHAR(255) NOT NULL DEFAULT '',
        `source_declaree`  VARCHAR(60)  DEFAULT '',
        `utm_source`       VARCHAR(120) DEFAULT '',
        `referrer_ref_id`  VARCHAR(12)  DEFAULT '',
        `date_inscription` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_whatsapp` (`whatsapp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// Ajouter colonne whatsapp et pin_hash si migration depuis ancien schéma
$cols = array_column($pdo->query("SHOW COLUMNS FROM `{$table}`")->fetchAll(),'Field');
if (!in_array('whatsapp',  $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `whatsapp` VARCHAR(20) NOT NULL DEFAULT '' AFTER `ref_id`");
if (!in_array('pin_hash',  $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `pin_hash` VARCHAR(255) NOT NULL DEFAULT '' AFTER `email`");
if (!in_array('ref_id',    $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `ref_id` VARCHAR(12) NOT NULL DEFAULT '' AFTER `id`");

// --- Helpers -------------------------------------------------
function clean(string $v, int $max=255): string {
    return substr(trim(htmlspecialchars($v, ENT_QUOTES, 'UTF-8')), 0, $max);
}

function generateRefId(PDO $pdo, string $table): string {
    $chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    do {
        $id = '';
        for ($i=0;$i<6;$i++) $id .= $chars[random_int(0,strlen($chars)-1)];
        $r = $pdo->prepare("SELECT 1 FROM `{$table}` WHERE ref_id=?");
        $r->execute([$id]);
    } while ($r->fetchColumn());
    return $id;
}

function generateToken(string $whatsapp): string {
    return hash('sha256', $whatsapp . SECRET_KEY . time() . random_bytes(8));
}

// Clé secrète pour signer les tokens (à définir dans config.php)
if (!defined('SECRET_KEY')) define('SECRET_KEY', 'AgroPast_S3cr3t_2025!');

// --- Lire le body JSON ou POST form -------------------------
$body = [];
$raw  = file_get_contents('php://input');
if ($raw) { $body = json_decode($raw, true) ?? []; }
$body = array_merge($_POST, $body);

$action    = clean($body['action']    ?? '');
$whatsapp  = clean($body['whatsapp']  ?? '', 20);
$pin       = clean($body['pin']       ?? '', 4);
$nom       = clean($body['nom']       ?? '', 60);
$email     = clean($body['email']     ?? '', 120);
$pays      = clean($body['pays']      ?? '', 60);
$token     = clean($body['token']     ?? '', 70);

// Normaliser numéro WhatsApp (retirer espaces/tirets)
$whatsapp = preg_replace('/[^+\d]/', '', $whatsapp);

// ============================================================
// ACTION : register — inscription
// ============================================================
if ($action === 'register') {

    if (strlen($whatsapp) < 8) {
        echo json_encode(['success'=>false,'error'=>'Numéro WhatsApp invalide']);
        exit;
    }
    if (strlen($pin) !== 4 || !ctype_digit($pin)) {
        echo json_encode(['success'=>false,'error'=>'Le PIN doit être 4 chiffres']);
        exit;
    }

    // Vérifier si le numéro existe déjà
    $check = $pdo->prepare("SELECT id FROM `{$table}` WHERE whatsapp=?");
    $check->execute([$whatsapp]);
    if ($check->fetchColumn()) {
        echo json_encode(['success'=>false,'error'=>'Numéro déjà inscrit. Utilise "Connexion".','code'=>'ALREADY_EXISTS']);
        exit;
    }

    $ref_id   = generateRefId($pdo, $table);
    $pin_hash = password_hash($pin, PASSWORD_BCRYPT, ['cost'=>10]);
    $newToken = generateToken($whatsapp);

    try {
        $stmt = $pdo->prepare("
            INSERT INTO `{$table}` (ref_id, whatsapp, nom, email, pays, pin_hash)
            VALUES (:ref_id, :whatsapp, :nom, :email, :pays, :pin_hash)
        ");
        $stmt->execute([
            ':ref_id'   => $ref_id,
            ':whatsapp' => $whatsapp,
            ':nom'      => $nom ?: 'Fermier',
            ':email'    => $email,
            ':pays'     => $pays,
            ':pin_hash' => $pin_hash,
        ]);
        $userId = $pdo->lastInsertId();

        // Stocker le token en session (table dédiée)
        _saveToken($pdo, (int)$userId, $newToken);

        echo json_encode([
            'success'      => true,
            'token'        => $newToken,
            'ref_id'       => $ref_id,
            'nom'          => $nom ?: 'Fermier',
            'whatsapp'     => $whatsapp,
            'whatsapp_url' => _buildWaUrl($whatsapp, $pin, $nom ?: 'Fermier', $ref_id),
        ]);
    } catch (PDOException $e) {
        error_log('register error: '.$e->getMessage());
        echo json_encode(['success'=>false,'error'=>'Erreur inscription']);
    }
    exit;
}

// ============================================================
// ACTION : login — connexion
// ============================================================
if ($action === 'login') {
    if (strlen($whatsapp) < 8 || strlen($pin) !== 4) {
        echo json_encode(['success'=>false,'error'=>'Numéro ou PIN invalide']);
        exit;
    }

    $row = $pdo->prepare("SELECT id, nom, ref_id, pin_hash FROM `{$table}` WHERE whatsapp=?");
    $row->execute([$whatsapp]);
    $user = $row->fetch();

    if (!$user || !password_verify($pin, $user['pin_hash'])) {
        sleep(1); // Anti brute-force
        echo json_encode(['success'=>false,'error'=>'Numéro ou PIN incorrect']);
        exit;
    }

    $newToken = generateToken($whatsapp);
    _saveToken($pdo, (int)$user['id'], $newToken);

    echo json_encode([
        'success' => true,
        'token'   => $newToken,
        'ref_id'  => $user['ref_id'],
        'nom'     => $user['nom'],
        'whatsapp'=> $whatsapp,
    ]);
    exit;
}

// ============================================================
// ACTION : verify — vérifier un token
// ============================================================
if ($action === 'verify') {
    $result = _verifyToken($pdo, $token);
    echo json_encode($result);
    exit;
}

// ============================================================
// HELPER : Construire lien wa.me avec PIN pré-rempli
// ============================================================
function _buildWaUrl(string $whatsapp, string $pin, string $nom, string $ref_id): string {
    // Nettoyer le numéro (retirer le +)
    $numero = ltrim($whatsapp, '+');
    $msg = "🍉 AgroPast-Game — Mon inscription\n\n"
         . "Bonjour ! Voici mes informations de connexion :\n"
         . "👤 Pseudo : {$nom}\n"
         . "🔑 Mon PIN : {$pin}\n"
         . "🔗 Mon lien parrain : https://agropast-game.online?ref={$ref_id}\n\n"
         . "⚠️ Garde ce message précieusement pour te connecter !";
    return 'https://wa.me/' . $numero . '?text=' . rawurlencode($msg);
}

// ============================================================
// HELPERS TOKENS
// ============================================================
function _saveToken(PDO $pdo, int $userId, string $token): void {
    // Table tokens (créée si nécessaire)
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `" . DB_PREFIX . "tokens` (
            `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            `user_id`    INT UNSIGNED NOT NULL,
            `token`      VARCHAR(70)  NOT NULL,
            `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` DATETIME     NOT NULL,
            UNIQUE KEY `uq_user` (`user_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
    $expires = date('Y-m-d H:i:s', strtotime('+30 days'));
    $pdo->prepare("
        INSERT INTO `" . DB_PREFIX . "tokens` (user_id, token, expires_at)
        VALUES (:uid, :tok, :exp)
        ON DUPLICATE KEY UPDATE token=VALUES(token), expires_at=VALUES(expires_at)
    ")->execute([':uid'=>$userId, ':tok'=>$token, ':exp'=>$expires]);
}

function _verifyToken(PDO $pdo, string $token): array {
    if (strlen($token) < 10) return ['success'=>false,'error'=>'Token manquant'];
    $table = DB_PREFIX . 'leads';
    $tTok  = DB_PREFIX . 'tokens';
    $row = $pdo->prepare("
        SELECT l.id, l.nom, l.ref_id, l.whatsapp
        FROM `{$tTok}` t
        JOIN `{$table}` l ON l.id = t.user_id
        WHERE t.token=? AND t.expires_at > NOW()
    ");
    $row->execute([$token]);
    $user = $row->fetch();
    if (!$user) return ['success'=>false,'error'=>'Session expirée'];
    return ['success'=>true, 'user'=>$user];
}

echo json_encode(['success'=>false,'error'=>'Action inconnue']);
