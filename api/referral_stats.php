<?php
/**
 * referral_stats.php
 * Retourne le nombre de filleuls (parrainages) pour un ref_id donné.
 * Usage : GET /api/referral_stats.php?ref_id=XXXX
 *
 * Réponse JSON :
 *   { "success": true, "ref_id": "XXXX", "filleuls": 3 }
 *   { "success": false, "error": "ref_id manquant" }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

// ── Config DB ────────────────────────────────────────────────
require_once __DIR__ . '/config.php'; // contient $pdo (PDO)

// ── Validation ───────────────────────────────────────────────
$refId = isset($_GET['ref_id']) ? trim($_GET['ref_id']) : '';

if ($refId === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'ref_id manquant']);
    exit;
}

// Autoriser seulement caractères alphanumériques + tirets/underscores
if (!preg_match('/^[a-zA-Z0-9_\-]{3,64}$/', $refId)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'ref_id invalide']);
    exit;
}

// ── Requête ──────────────────────────────────────────────────
try {
    /*
     * La table `users` est supposée avoir une colonne `parrain_ref_id`
     * qui stocke le ref_id du parrain lors de l'inscription.
     * Adaptez le nom de table / colonne à votre schéma réel.
     */
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) AS filleuls FROM users WHERE parrain_ref_id = :ref_id'
    );
    $stmt->execute([':ref_id' => $refId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $count = (int) ($row['filleuls'] ?? 0);

    echo json_encode([
        'success'  => true,
        'ref_id'   => $refId,
        'filleuls' => $count,
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Erreur serveur']);
}
