<?php
// ============================================================
// ENDPOINT : POST /api/leads.php
// Reçoit les données du formulaire index.html,
// insère en base MySQL, redirige vers merci.html
// ============================================================

require_once __DIR__ . '/config.php';

// --- CORS : autorise uniquement le site Netlify -----------
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin === ALLOWED_ORIGIN || $origin === 'https://www.' . str_replace('https://', '', ALLOWED_ORIGIN)) {
    header('Access-Control-Allow-Origin: ' . $origin);
}
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Répondre aux pre-flight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// --- Accepter uniquement POST ----------------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Méthode non autorisée');
}

// --- Sanitisation des entrées ----------------------------
function clean(string $val, int $max = 255): string {
    return substr(trim(htmlspecialchars($val, ENT_QUOTES, 'UTF-8')), 0, $max);
}

$name    = clean($_POST['name']    ?? '');
$email   = clean($_POST['email']   ?? '');
$country = clean($_POST['country'] ?? '');
$source  = clean($_POST['source']  ?? '');

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
    // Ne pas exposer les détails en production
    error_log('DB connexion échouée : ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur, réessaie dans quelques instants.');
}

// --- Création de la table si elle n'existe pas -----------
$table = DB_PREFIX . 'leads';
$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$table}` (
        `id`                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `nom`               VARCHAR(60)  NOT NULL,
        `email`             VARCHAR(120) NOT NULL,
        `pays`              VARCHAR(60)  DEFAULT '',
        `source`            VARCHAR(60)  DEFAULT '',
        `date_inscription`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_email` (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// --- Insertion -------------------------------------------
try {
    $stmt = $pdo->prepare("
        INSERT INTO `{$table}` (nom, email, pays, source)
        VALUES (:nom, :email, :pays, :source)
    ");
    $stmt->execute([
        ':nom'    => $name,
        ':email'  => $email,
        ':pays'   => $country,
        ':source' => $source,
    ]);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        // Email déjà inscrit — on redirige quand même (UX fluide)
        header('Location: ../merci.html?already=1');
        exit;
    }
    error_log('DB insertion échouée : ' . $e->getMessage());
    http_response_code(500);
    exit('Erreur serveur, réessaie dans quelques instants.');
}

// --- Redirection vers merci.html -------------------------
header('Location: ../merci.html');
exit;
