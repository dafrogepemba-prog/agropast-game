<?php
// ============================================================
// admin/save_note.php — Sauvegarder note admin sur un joueur
// ============================================================
session_start();
if (empty($_SESSION['admin_logged_in'])) { http_response_code(403); exit; }

require_once dirname(__DIR__) . '/api/config.php';

try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) { http_response_code(500); exit; }

$table = DB_PREFIX . 'leads';

// Ajouter colonne admin_note si elle n'existe pas
$cols = array_column($pdo->query("SHOW COLUMNS FROM `{$table}`")->fetchAll(PDO::FETCH_ASSOC), 'Field');
if (!in_array('admin_note', $cols)) {
    $pdo->exec("ALTER TABLE `{$table}` ADD COLUMN `admin_note` TEXT DEFAULT NULL");
}

$id   = (int)($_POST['id']   ?? 0);
$note = substr(trim($_POST['note'] ?? ''), 0, 1000);

if ($id < 1) { http_response_code(400); exit; }

$pdo->prepare("UPDATE `{$table}` SET admin_note=? WHERE id=?")->execute([$note, $id]);

echo json_encode(['success' => true]);
