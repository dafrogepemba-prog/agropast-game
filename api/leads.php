<?php
// ============================================================
// ENDPOINT : POST /api/leads.php
// Hébergé sur LWS mutualisé : ftp.epsylon-cg.com
// Chemin : /agropast-game.online/api/leads.php
// Base partagée epsyl2799210 — tables préfixées apg_
// ============================================================

require_once __DIR__ . '/config.php';

// Même serveur LWS — pas de CORS nécessaire

// --- Accepter uniquement POST ----------------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Méthode non autorisée');
}

// --- Sanitisation ----------------------------------------
function clean(string $val, int $max = 255): string {
    return substr(trim(htmlspecialchars($val, ENT_QUOTES, 'UTF-8')), 0, $max);
}

$name     = clean($_POST['name']     ?? '');
$email    = clean($_POST['email']    ?? '');
$country  = clean($_POST['country']  ?? '');
$source   = clean($_POST['source']   ?? '');   // canal déclaré (select)
$utm      = clean($_POST['utm']      ?? '');   // paramètre UTM capturé par JS
$referrer = clean($_POST['referrer'] ?? '');   // ?ref=ID parrain

// --- Validation ------------------------------------------
$errors = [];
if (strlen($name) < 2)                          $errors[] = 'Pseudo invalide';
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) $errors[] = 'Email invalide';

if (!empty($errors)) {
    http_response_code(422);
    echo json_encode(['errors' => $errors]);
    exit;
}

// --- Connexion MySQL --------------------------------------
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    error_log('DB connexion échouée : ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur, réessaie dans quelques instants.');
}

// --- Création / migration de la table --------------------
$table = DB_PREFIX . 'leads';
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$table}` (
        `id`                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_id`            VARCHAR(12)  NOT NULL UNIQUE,
        `nom`               VARCHAR(60)  NOT NULL,
        `email`             VARCHAR(120) NOT NULL,
        `pays`              VARCHAR(60)  DEFAULT '',
        `source_declaree`   VARCHAR(60)  DEFAULT '',
        `utm_source`        VARCHAR(120) DEFAULT '',
        `referrer_ref_id`   VARCHAR(12)  DEFAULT '',
        `date_inscription`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_email` (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// Ajouter les colonnes si elles n'existent pas encore (migration douce)
$cols = array_column(
    $pdo->query("SHOW COLUMNS FROM `{$table}`")->fetchAll(), 'Field'
);
if (!in_array('ref_id', $cols)) {
    $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `ref_id` VARCHAR(12) NOT NULL DEFAULT '' AFTER `id`");
}
if (!in_array('utm_source', $cols)) {
    $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `utm_source` VARCHAR(120) DEFAULT '' AFTER `source_declaree`");
}
if (!in_array('referrer_ref_id', $cols)) {
    $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `referrer_ref_id` VARCHAR(12) DEFAULT '' AFTER `utm_source`");
}

// --- Générer un ref_id unique (6 chars alphanum) ----------
function generateRefId(PDO $pdo, string $table): string {
    $chars = 'abcdefghjkmnpqrstuvwxyz23456789'; // sans 0,1,i,l,o
    do {
        $id = '';
        for ($i = 0; $i < 6; $i++) {
            $id .= $chars[random_int(0, strlen($chars) - 1)];
        }
        $exists = $pdo->prepare("SELECT 1 FROM `{$table}` WHERE ref_id = ?");
        $exists->execute([$id]);
    } while ($exists->fetchColumn());
    return $id;
}

$ref_id = generateRefId($pdo, $table);

// --- Source finale : UTM > select formulaire -------------
$source_finale = $utm ?: $source;

// --- Insertion -------------------------------------------
try {
    $stmt = $pdo->prepare("
        INSERT INTO `{$table}`
            (ref_id, nom, email, pays, source_declaree, utm_source, referrer_ref_id)
        VALUES
            (:ref_id, :nom, :email, :pays, :source_declaree, :utm_source, :referrer_ref_id)
    ");
    $stmt->execute([
        ':ref_id'          => $ref_id,
        ':nom'             => $name,
        ':email'           => $email,
        ':pays'            => $country,
        ':source_declaree' => $source,
        ':utm_source'      => $utm,
        ':referrer_ref_id' => $referrer,
    ]);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        // Email déjà inscrit — on récupère son ref_id pour lui redonner son lien
        $row = $pdo->prepare("SELECT ref_id, nom FROM `{$table}` WHERE email = ?");
        $row->execute([$email]);
        $existing = $row->fetch();
        $prenom   = urlencode(explode(' ', $existing['nom'])[0]);
        $ref      = $existing['ref_id'];
        header("Location: ../merci.html?prenom={$prenom}&ref={$ref}&already=1");
        exit;
    }
    error_log('DB insertion échouée : ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur, réessaie dans quelques instants.');
}

// --- Redirection vers merci.html avec prénom + ref_id ----
$prenom = urlencode(explode(' ', $name)[0]); // premier mot du pseudo
header("Location: ../merci.html?prenom={$prenom}&ref={$ref_id}");
exit;
