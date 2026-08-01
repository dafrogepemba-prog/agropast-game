<?php
// ============================================================
// admin/view_id.php — Affiche une pièce d'identité uploadée
// Seul point d'accès à ces fichiers : session admin obligatoire,
// jamais d'URL publique directe vers /api/uploads/.
// ============================================================
session_start();
if (empty($_SESSION['admin_logged_in'])) {
    http_response_code(403);
    exit('Accès refusé');
}

require_once dirname(__DIR__) . '/api/config.php';

try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    http_response_code(500);
    exit('Erreur DB');
}

$tIdVerif = DB_PREFIX . 'id_verifications';
$id = (int)($_GET['id'] ?? 0);

$stmt = $pdo->prepare("SELECT file_path FROM `{$tIdVerif}` WHERE id=?");
$stmt->execute([$id]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row || empty($row['file_path'])) {
    http_response_code(404);
    exit('Fichier introuvable ou déjà supprimé (vérification déjà traitée).');
}

// Empêche toute tentative de traversée de répertoire (../..)
$relPath = str_replace(['..', "\0"], '', $row['file_path']);
$fullPath = realpath(dirname(__DIR__) . '/api/uploads/' . $relPath);
$uploadsRoot = realpath(dirname(__DIR__) . '/api/uploads');

if (!$fullPath || strpos($fullPath, $uploadsRoot) !== 0 || !file_exists($fullPath)) {
    http_response_code(404);
    exit('Fichier introuvable.');
}

$ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
$mimeMap = ['jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp'];
header('Content-Type: ' . ($mimeMap[$ext] ?? 'application/octet-stream'));
header('Content-Length: ' . filesize($fullPath));
header('Cache-Control: no-store, private');
readfile($fullPath);
