<?php
// ============================================================
// ENDPOINT : POST /api/leads.php
// Formulaire landing page → inscription via WhatsApp + pseudo
// Email optionnel — WhatsApp est l'identifiant principal
// Le PIN et le numéro ne sont plus jamais exposés dans l'URL :
// ils transitent par un jeton à usage unique (voir handoff.php).
// ============================================================
require_once __DIR__ . '/config.php';
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Méthode non autorisée');
}
function clean(string $val, int $max = 255): string {
    return substr(trim(htmlspecialchars($val, ENT_QUOTES, 'UTF-8')), 0, $max);
}
$name     = clean($_POST['name']      ?? '');
$whatsapp = preg_replace('/[^+\d]/', '', $_POST['whatsapp'] ?? '');
$email    = clean($_POST['email']     ?? '');  // optionnel
$country  = clean($_POST['country']   ?? '');
$source   = clean($_POST['source']    ?? '');
$utm      = clean($_POST['utm']       ?? '');
$referrer = clean($_POST['referrer']  ?? '');

// --- Validation ------------------------------------------
$errors = [];
if (strlen($name) < 2)       $errors[] = 'Pseudo invalide (min 2 caractères)';
if (strlen($whatsapp) < 8)   $errors[] = 'Numéro WhatsApp invalide';
// Email optionnel — valider seulement s'il est renseigné
if ($email && !filter_var($email, FILTER_VALIDATE_EMAIL)) $errors[] = 'Email invalide';
if (!empty($errors)) {
    http_response_code(422);
    echo json_encode(['errors' => $errors]);
    exit;
}

// --- Connexion MySQL --------------------------------------
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
         PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
         PDO::ATTR_EMULATE_PREPARES => false]
    );
} catch (PDOException $e) {
    error_log('leads.php DB: ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur, réessaie dans quelques instants.');
}
$table  = DB_PREFIX . 'leads';
$tHandoff = DB_PREFIX . 'registration_handoff';

// --- Création / migration table --------------------------
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$table}` (
        `id`               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_id`           VARCHAR(12)  NOT NULL DEFAULT '',
        `whatsapp`         VARCHAR(20)  NOT NULL DEFAULT '',
        `nom`              VARCHAR(60)  NOT NULL,
        `email`            VARCHAR(120) DEFAULT '',
        `pays`             VARCHAR(60)  DEFAULT '',
        `pin_hash`         VARCHAR(255) DEFAULT '',
        `source_declaree`  VARCHAR(60)  DEFAULT '',
        `utm_source`       VARCHAR(120) DEFAULT '',
        `referrer_ref_id`  VARCHAR(12)  DEFAULT '',
        `date_inscription` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_whatsapp` (`whatsapp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// Migration : ajouter colonnes manquantes
$cols = array_column($pdo->query("SHOW COLUMNS FROM `{$table}`")->fetchAll(),'Field');
if (!in_array('whatsapp', $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `whatsapp` VARCHAR(20) NOT NULL DEFAULT '' AFTER `ref_id`");
if (!in_array('pin_hash', $cols)) $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `pin_hash` VARCHAR(255) DEFAULT '' AFTER `email`");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tHandoff}` (
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

// --- Générer ref_id unique --------------------------------
function generateRefId(PDO $pdo, string $table): string {
    $chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    do {
        $id = '';
        for ($i = 0; $i < 6; $i++) $id .= $chars[random_int(0, strlen($chars)-1)];
        $r = $pdo->prepare("SELECT 1 FROM `{$table}` WHERE ref_id=?");
        $r->execute([$id]);
    } while ($r->fetchColumn());
    return $id;
}

// Génère un jeton de transfert à usage unique (32 octets aléatoires)
function generateHandoffToken(): string {
    return bin2hex(random_bytes(32));
}

function storeHandoff(PDO $pdo, string $table, string $whatsapp, string $nom, string $pin, string $refId): string {
    $token   = generateHandoffToken();
    $expires = date('Y-m-d H:i:s', strtotime('+10 minutes'));
    $pdo->prepare("
        INSERT INTO `{$table}` (token, whatsapp, nom, pin, ref_id, expires_at)
        VALUES (:token, :whatsapp, :nom, :pin, :ref_id, :expires)
    ")->execute([
        ':token'    => $token,
        ':whatsapp' => $whatsapp,
        ':nom'      => $nom,
        ':pin'      => $pin,
        ':ref_id'   => $refId,
        ':expires'  => $expires,
    ]);
    return $token;
}

$ref_id        = generateRefId($pdo, $table);
$source_finale = $utm ?: $source;

// --- Générer PIN 4 chiffres aléatoire --------------------
$pin      = str_pad((string)random_int(0, 9999), 4, '0', STR_PAD_LEFT);
$pin_hash = password_hash($pin, PASSWORD_BCRYPT, ['cost' => 10]);

// --- Insertion -------------------------------------------
try {
    $stmt = $pdo->prepare("
        INSERT INTO `{$table}`
            (ref_id, whatsapp, nom, email, pays, pin_hash, source_declaree, utm_source, referrer_ref_id)
        VALUES
            (:ref_id, :whatsapp, :nom, :email, :pays, :pin_hash, :source_declaree, :utm_source, :referrer_ref_id)
    ");
    $stmt->execute([
        ':ref_id'          => $ref_id,
        ':whatsapp'        => $whatsapp,
        ':nom'             => $name,
        ':email'           => $email,
        ':pays'            => $country,
        ':pin_hash'        => $pin_hash,
        ':source_declaree' => $source,
        ':utm_source'      => $utm,
        ':referrer_ref_id' => $referrer,
    ]);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        // WhatsApp déjà inscrit → récupère ses infos et redirige
        $row = $pdo->prepare("SELECT ref_id, nom FROM `{$table}` WHERE whatsapp=?");
        $row->execute([$whatsapp]);
        $existing = $row->fetch();
        $prenom  = urlencode(explode(' ', $existing['nom'])[0]);
        $ref     = $existing['ref_id'];

        // Jeton pour récupérer le numéro côté merci.html sans l'exposer en URL
        $token = storeHandoff($pdo, $tHandoff, $whatsapp, $existing['nom'], '', $ref);
        header("Location: https://agropast-game.online/merci.html?prenom={$prenom}&ref={$ref}&already=1&handoff={$token}");
        exit;
    }
    error_log('leads.php insert: ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur.');
}

// --- Redirection vers merci.html -------------------------
$prenom = urlencode(explode(' ', $name)[0]);
$token  = storeHandoff($pdo, $tHandoff, $whatsapp, $name, $pin, $ref_id);
header("Location: https://agropast-game.online/merci.html?prenom={$prenom}&ref={$ref_id}&handoff={$token}");
exit;
