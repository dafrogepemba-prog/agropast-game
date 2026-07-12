<?php
// ============================================================
// ENDPOINT : GET /api/leaderboard.php
// Retourne le top 20 des joueurs avec leur score réel
// v2 — 2026-07-12
// ============================================================

require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://agropast-game.online');
header('Access-Control-Allow-Methods: GET, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

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

$tLeads = DB_PREFIX . 'leads';
$tScore = DB_PREFIX . 'scores';

// Top 20 joueurs par score
try {
    $rows = $pdo->query("
        SELECT
            l.nom,
            l.pays,
            COALESCE(s.score_total, 0)     AS score,
            COALESCE(s.nombre_recoltes, 0) AS recoltes,
            s.updated_at
        FROM `{$tLeads}` l
        LEFT JOIN `{$tScore}` s ON s.user_id = l.id
        WHERE COALESCE(s.score_total, 0) > 0
        ORDER BY score DESC
        LIMIT 20
    ")->fetchAll();

    $leaders = [];
    foreach ($rows as $i => $row) {
        $leaders[] = [
            'rank'     => $i + 1,
            'pseudo'   => $row['nom']      ?: 'Fermier',
            'pays'     => $row['pays']     ?: '',
            'score'    => (int)$row['score'],
            'recoltes' => (int)$row['recoltes'],
        ];
    }

    echo json_encode(['success' => true, 'leaders' => $leaders]);

} catch (PDOException $e) {
    // Table scores pas encore créée → retourner liste vide
    echo json_encode(['success' => true, 'leaders' => []]);
}
