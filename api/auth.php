<?php
// ============================================================
// ENDPOINT : POST /api/auth.php
// Gère inscription + connexion (WhatsApp ou Email + PIN)
// PIN généré automatiquement par le serveur (6 chiffres).
// Vérification de l'email par code envoyé via Brevo.
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
$tVerif = DB_PREFIX . 'email_verifications';

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
        `email_verified`   TINYINT(1)   NOT NULL DEFAULT 0,
        `source_declaree`  VARCHAR(60)  DEFAULT '',
        `utm_source`       VARCHAR(120) DEFAULT '',
        `referrer_ref_id`  VARCHAR(12)  DEFAULT '',
        `date_inscription` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_whatsapp` (`whatsapp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// Ajouter colonnes manquantes si migration depuis ancien schéma
$cols = array_column($pdo->query("SHOW COLUMNS FROM `{$table}`")->fetchAll(),'Field');
if (!in_array('whatsapp',       $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `whatsapp` VARCHAR(20) NOT NULL DEFAULT '' AFTER `ref_id`");
if (!in_array('pin_hash',       $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `pin_hash` VARCHAR(255) NOT NULL DEFAULT '' AFTER `email`");
if (!in_array('ref_id',         $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `ref_id` VARCHAR(12) NOT NULL DEFAULT '' AFTER `id`");
if (!in_array('email_verified', $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `email_verified` TINYINT(1) NOT NULL DEFAULT 0 AFTER `pin_hash`");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tVerif}` (
        `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`    INT UNSIGNED NOT NULL,
        `code`       VARCHAR(6)   NOT NULL,
        `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `expires_at` DATETIME     NOT NULL,
        `used`       TINYINT(1)   NOT NULL DEFAULT 0,
        KEY `idx_user` (`user_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

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

// Génère un PIN aléatoire à 6 chiffres (jamais choisi par l'utilisateur)
function generatePin(): string {
    return str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
}

// Génère un code de vérification à 6 chiffres
function generateVerificationCode(): string {
    return str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
}

// --- Envoi d'email via Brevo (SMTP) ---------------------------
// Retourne true si l'envoi a été accepté, false sinon (ne bloque jamais l'inscription)
function sendEmail(string $to, string $subject, string $htmlBody): bool {
    if (empty(BREVO_SMTP_LOGIN) || empty(BREVO_SMTP_KEY)) {
        error_log('sendEmail: Brevo non configuré, envoi ignoré');
        return false;
    }
    require_once __DIR__ . '/PHPMailer/src/Exception.php';
    require_once __DIR__ . '/PHPMailer/src/PHPMailer.php';
    require_once __DIR__ . '/PHPMailer/src/SMTP.php';

    $mail = new PHPMailer\PHPMailer\PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host       = 'smtp-relay.brevo.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = BREVO_SMTP_LOGIN;
        $mail->Password   = BREVO_SMTP_KEY;
        $mail->SMTPSecure = PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom('reddympassi@gmail.com', 'AgroPast-Game');
        $mail->addAddress($to);
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $htmlBody;

        $mail->send();
        return true;
    } catch (Exception $e) {
        error_log('sendEmail error: ' . $mail->ErrorInfo);
        return false;
    }
}

// --- Lire le body JSON ou POST form -------------------------
$body = [];
$raw  = file_get_contents('php://input');
if ($raw) { $body = json_decode($raw, true) ?? []; }
$body = array_merge($_POST, $body);

$action     = clean($body['action']     ?? '');
$whatsapp   = clean($body['whatsapp']   ?? '', 20);
$identifier = clean($body['identifier'] ?? '', 120); // whatsapp OU email pour login
$pin        = clean($body['pin']        ?? '', 6);
$nom        = clean($body['nom']        ?? '', 60);
$email      = clean($body['email']      ?? '', 120);
$pays       = clean($body['pays']       ?? '', 60);
$token      = clean($body['token']      ?? '', 70);
$code       = clean($body['code']       ?? '', 6);

// Normaliser numéro WhatsApp (retirer espaces/tirets)
$whatsapp   = preg_replace('/[^+\d]/', '', $whatsapp);
$identifier = trim($identifier);

// ============================================================
// ACTION : register — inscription (PIN généré automatiquement)
// ============================================================
if ($action === 'register') {
    if (strlen($whatsapp) < 8) {
        echo json_encode(['success'=>false,'error'=>'Numéro WhatsApp invalide']);
        exit;
    }
    if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        echo json_encode(['success'=>false,'error'=>'Email valide requis']);
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
    $pin      = generatePin(); // le serveur génère le PIN, pas le client
    $pin_hash = password_hash($pin, PASSWORD_BCRYPT, ['cost'=>10]);
    $newToken = generateToken($whatsapp);

    try {
        $stmt = $pdo->prepare("
            INSERT INTO `{$table}` (ref_id, whatsapp, nom, email, pays, pin_hash, email_verified)
            VALUES (:ref_id, :whatsapp, :nom, :email, :pays, :pin_hash, 0)
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
        _saveToken($pdo, (int)$userId, $newToken);

        // Générer + envoyer le code de vérification email
        $verifCode = generateVerificationCode();
        $expires   = date('Y-m-d H:i:s', strtotime('+15 minutes'));
        $pdo->prepare("
            INSERT INTO `{$tVerif}` (user_id, code, expires_at) VALUES (:uid, :code, :exp)
        ")->execute([':uid'=>$userId, ':code'=>$verifCode, ':exp'=>$expires]);

        $displayNom = htmlspecialchars($nom ?: 'Fermier');
        $emailSent = sendEmail(
            $email,
            'Bienvenue sur AgroPast-Game — Confirme ton compte',
            "<p>Bonjour {$displayNom},</p>
             <p>Merci de ton inscription sur AgroPast-Game !</p>
             <p>Ton code de confirmation est : <strong style='font-size:20px'>{$verifCode}</strong></p>
             <p>Entre ce code sur le site pour confirmer ton compte (valable 15 minutes).</p>
             <hr>
             <p>Ton PIN de connexion (à conserver précieusement) : <strong style='font-size:20px'>{$pin}</strong></p>
             <p>Tu peux te connecter avec ton numéro WhatsApp ou cet email, accompagné de ce PIN.</p>"
        );

        echo json_encode([
            'success'      => true,
            'token'        => $newToken,
            'ref_id'       => $ref_id,
            'nom'          => $nom ?: 'Fermier',
            'whatsapp'     => $whatsapp,
            'pin'          => $pin,
            'email_sent'   => $emailSent,
            'whatsapp_url' => _buildWaUrl($whatsapp, $pin, $nom ?: 'Fermier', $ref_id),
        ]);
    } catch (PDOException $e) {
        error_log('register error: '.$e->getMessage());
        echo json_encode(['success'=>false,'error'=>'Erreur inscription']);
    }
    exit;
}

// ============================================================
// ACTION : verify_email — confirmer le code reçu par email
// ============================================================
if ($action === 'verify_email') {
    $result = _verifyToken($pdo, $token);
    if (!$result['success']) {
        echo json_encode($result);
        exit;
    }
    $userId = (int)$result['user']['id'];

    if (strlen($code) !== 6 || !ctype_digit($code)) {
        echo json_encode(['success'=>false,'error'=>'Code invalide']);
        exit;
    }

    $row = $pdo->prepare("
        SELECT id FROM `{$tVerif}`
        WHERE user_id=? AND code=? AND used=0 AND expires_at > NOW()
        ORDER BY id DESC LIMIT 1
    ");
    $row->execute([$userId, $code]);
    $verif = $row->fetch();

    if (!$verif) {
        echo json_encode(['success'=>false,'error'=>'Code invalide ou expiré']);
        exit;
    }

    $pdo->prepare("UPDATE `{$tVerif}` SET used=1 WHERE id=?")->execute([$verif['id']]);
    $pdo->prepare("UPDATE `{$table}` SET email_verified=1 WHERE id=?")->execute([$userId]);

    echo json_encode(['success'=>true,'message'=>'Email confirmé avec succès']);
    exit;
}

// ============================================================
// ACTION : resend_verification — renvoyer un nouveau code
// ============================================================
if ($action === 'resend_verification') {
    $result = _verifyToken($pdo, $token);
    if (!$result['success']) {
        echo json_encode($result);
        exit;
    }
    $userId = (int)$result['user']['id'];

    $userRow = $pdo->prepare("SELECT email, nom, email_verified FROM `{$table}` WHERE id=?");
    $userRow->execute([$userId]);
    $user = $userRow->fetch();

    if (!$user || empty($user['email'])) {
        echo json_encode(['success'=>false,'error'=>'Aucun email associé']);
        exit;
    }
    if ((int)$user['email_verified'] === 1) {
        echo json_encode(['success'=>false,'error'=>'Email déjà confirmé']);
        exit;
    }

    $verifCode = generateVerificationCode();
    $expires   = date('Y-m-d H:i:s', strtotime('+15 minutes'));
    $pdo->prepare("
        INSERT INTO `{$tVerif}` (user_id, code, expires_at) VALUES (:uid, :code, :exp)
    ")->execute([':uid'=>$userId, ':code'=>$verifCode, ':exp'=>$expires]);

    $displayNom = htmlspecialchars($user['nom'] ?: 'Fermier');
    $emailSent = sendEmail(
        $user['email'],
        'AgroPast-Game — Nouveau code de confirmation',
        "<p>Bonjour {$displayNom},</p>
         <p>Voici ton nouveau code de confirmation : <strong style='font-size:20px'>{$verifCode}</strong></p>
         <p>Valable 15 minutes.</p>"
    );

    echo json_encode(['success'=>true, 'email_sent'=>$emailSent]);
    exit;
}

// ============================================================
// ACTION : login — connexion (WhatsApp OU email + PIN)
// ============================================================
if ($action === 'login') {
    $loginId = $identifier ?: $whatsapp;
    if (strlen($loginId) < 4 || strlen($pin) < 4) {
        echo json_encode(['success'=>false,'error'=>'Identifiant ou PIN invalide']);
        exit;
    }

    $normalizedWa = preg_replace('/[^+\d]/', '', $loginId);

    $row = $pdo->prepare("
        SELECT id, ref_id, nom, whatsapp, pin_hash
        FROM `{$table}`
        WHERE whatsapp = :wa OR email = :email
        LIMIT 1
    ");
    $row->execute([':wa' => $normalizedWa, ':email' => $loginId]);
    $user = $row->fetch();

    if (!$user || !password_verify($pin, $user['pin_hash'])) {
        echo json_encode(['success'=>false,'error'=>'Identifiant ou PIN incorrect']);
        exit;
    }

    $newToken = generateToken($user['whatsapp']);
    _saveToken($pdo, (int)$user['id'], $newToken);

    echo json_encode([
        'success' => true,
        'token'   => $newToken,
        'ref_id'  => $user['ref_id'],
        'nom'     => $user['nom'],
        'whatsapp'=> $user['whatsapp'],
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
