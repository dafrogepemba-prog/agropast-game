<?php
// ============================================================
// GET /api/referral_stats.php?ref_id=XXXX
// Retourne le nombre de filleuls pour un ref_id donné
// ============================================================

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: GET, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

require_once __DIR__ . '/config.php';

$refId = trim($_GET['ref_id'] ?? '');

if ($refId === '' || !preg_match('/^[a-zA-Z0-9]{3,12}$/', $refId)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'ref_id invalide']);
    exit;
}

try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
         PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );

    $tLeads = DB_PREFIX . 'leads';

    // Compte les joueurs qui ont ce ref_id comme parrain
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS filleuls FROM `{$tLeads}` WHERE referrer_ref_id = ?"
    );
    $stmt->execute([$refId]);
    $row   = $stmt->fetch();
    $count = (int)($row['filleuls'] ?? 0);

    echo json_encode([
        'success'  => true,
        'ref_id'   => $refId,
        'filleuls' => $count,
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Erreur serveur']);
}
