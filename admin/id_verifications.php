<?php
// ============================================================
// admin/id_verifications.php — Traiter les vérifications d'identité
//
// Le fichier est supprimé du disque dès qu'un admin traite la
// demande (approuvé ou refusé) — on ne garde que le statut en
// base, jamais le document lui-même une fois la décision prise
// (minimisation des données, cf. politiques Google Play).
// ============================================================
session_start();
if (empty($_SESSION['admin_logged_in'])) {
    header('Location: index.php');
    exit;
}

require_once dirname(__DIR__) . '/api/config.php';

try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    die('Erreur DB : ' . htmlspecialchars($e->getMessage()));
}

$tLeads   = DB_PREFIX . 'leads';
$tIdVerif = DB_PREFIX . 'id_verifications';

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tIdVerif}` (
        `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `user_id`     INT UNSIGNED NOT NULL,
        `file_path`   VARCHAR(255) DEFAULT NULL,
        `statut`      ENUM('en_attente','approuve','refuse') NOT NULL DEFAULT 'en_attente',
        `note_admin`  VARCHAR(255) DEFAULT '',
        `reviewed_by` VARCHAR(100) DEFAULT '',
        `reviewed_at` DATETIME DEFAULT NULL,
        `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_user` (`user_id`),
        INDEX `idx_statut` (`statut`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

$message = '';
$error   = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = $_POST['csrf_token'] ?? '';
    if (!hash_equals($_SESSION['csrf_token'], $csrf)) {
        $error = 'Session invalide, recharge la page et réessaie.';
    } else {
        $id     = (int)($_POST['id'] ?? 0);
        $action = $_POST['action'] ?? '';

        if (!in_array($action, ['approuver', 'refuser'], true)) {
            $error = 'Action invalide.';
        } else {
            $stmt = $pdo->prepare("SELECT * FROM `{$tIdVerif}` WHERE id=?");
            $stmt->execute([$id]);
            $verif = $stmt->fetch();

            if (!$verif) {
                $error = 'Vérification introuvable.';
            } else {
                // Supprime le fichier du disque, quelle que soit la décision —
                // on ne conserve jamais le document une fois traité.
                if (!empty($verif['file_path'])) {
                    $fullPath = dirname(__DIR__) . '/api/uploads/' . $verif['file_path'];
                    if (file_exists($fullPath)) {
                        @unlink($fullPath);
                    }
                }

                $nouveauStatut = $action === 'approuver' ? 'approuve' : 'refuse';
                $stmt = $pdo->prepare("
                    UPDATE `{$tIdVerif}`
                    SET statut = ?, file_path = NULL, reviewed_by = ?, reviewed_at = NOW()
                    WHERE id = ?
                ");
                $stmt->execute([$nouveauStatut, $_SESSION['admin_user'] ?? 'inconnu', $id]);

                $message = $action === 'approuver'
                    ? 'Vérification approuvée. Le joueur peut maintenant retirer ses gains.'
                    : 'Vérification refusée. Le joueur devra soumettre une nouvelle photo.';
            }
        }
    }
}

$filtre = $_GET['f'] ?? 'en_attente';
$where  = in_array($filtre, ['en_attente', 'approuve', 'refuse'], true) ? "WHERE v.statut = '{$filtre}'" : '';

$verifs = $pdo->query("
    SELECT v.*, l.nom, l.whatsapp
    FROM `{$tIdVerif}` v
    LEFT JOIN `{$tLeads}` l ON l.id = v.user_id
    {$where}
    ORDER BY v.created_at DESC
    LIMIT 100
")->fetchAll();

$counts = $pdo->query("
    SELECT statut, COUNT(*) AS nb FROM `{$tIdVerif}` GROUP BY statut
")->fetchAll(PDO::FETCH_KEY_PAIR);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Vérifications d'identité — AgroPast Admin</title>
<meta name="robots" content="noindex, nofollow">
<style>
  body { font-family: system-ui, sans-serif; max-width: 900px; margin: 0 auto; padding: 24px 20px 60px; background:#f4f6f5; color:#1b2a1b; }
  h1 { font-size: 1.4rem; }
  a.back { display:inline-block; margin-bottom:16px; color:#2f7a3f; }
  .tabs { display:flex; gap:8px; margin: 16px 0; }
  .tabs a { padding:6px 14px; border-radius:20px; border:1px solid #2f7a3f; color:#2f7a3f; text-decoration:none; font-size:.85rem; }
  .tabs a.active { background:#2f7a3f; color:#fff; }
  .msg-ok { background:#e6f6ea; color:#1a6b2e; padding:10px 14px; border-radius:6px; margin-bottom:16px; }
  .msg-err { background:#fbe7e7; color:#8a1f1f; padding:10px 14px; border-radius:6px; margin-bottom:16px; }
  .card { background:#fff; border-radius:10px; padding:16px; margin-bottom:14px; box-shadow:0 1px 3px rgba(0,0,0,.08); display:flex; gap:16px; }
  .card img { width:140px; height:auto; border-radius:6px; object-fit:cover; background:#eee; }
  .card .info { flex:1; }
  .card .info h3 { margin:0 0 4px; font-size:1rem; }
  .card .info p { margin:2px 0; font-size:.85rem; color:#555; }
  .card .actions { display:flex; gap:8px; margin-top:10px; }
  .btn-ok { background:#2f7a3f; color:#fff; border:0; padding:8px 14px; border-radius:6px; cursor:pointer; font-weight:600; }
  .btn-refuse { background:#c62828; color:#fff; border:0; padding:8px 14px; border-radius:6px; cursor:pointer; font-weight:600; }
  .badge { font-size:.75rem; padding:2px 8px; border-radius:10px; font-weight:700; }
  .badge.en_attente { background:#fff3cd; color:#8a6d00; }
  .badge.approuve { background:#e6f6ea; color:#1a6b2e; }
  .badge.refuse { background:#fbe7e7; color:#8a1f1f; }
</style>
</head>
<body>
  <a class="back" href="dashboard.php">&larr; Retour au dashboard</a>
  <h1>🪪 Vérifications d'identité</h1>

  <?php if ($message): ?><div class="msg-ok"><?= htmlspecialchars($message) ?></div><?php endif; ?>
  <?php if ($error): ?><div class="msg-err"><?= htmlspecialchars($error) ?></div><?php endif; ?>

  <div class="tabs">
    <a href="?f=en_attente" class="<?= $filtre==='en_attente'?'active':'' ?>">En attente (<?= $counts['en_attente'] ?? 0 ?>)</a>
    <a href="?f=approuve" class="<?= $filtre==='approuve'?'active':'' ?>">Approuvées (<?= $counts['approuve'] ?? 0 ?>)</a>
    <a href="?f=refuse" class="<?= $filtre==='refuse'?'active':'' ?>">Refusées (<?= $counts['refuse'] ?? 0 ?>)</a>
  </div>

  <?php if (empty($verifs)): ?>
    <p style="color:#777">Aucune vérification dans cette catégorie.</p>
  <?php endif; ?>

  <?php foreach ($verifs as $v): ?>
  <div class="card">
    <?php if (!empty($v['file_path'])): ?>
      <img src="view_id.php?id=<?= $v['id'] ?>" alt="Pièce d'identité" loading="lazy">
    <?php else: ?>
      <div style="width:140px;height:100px;display:flex;align-items:center;justify-content:center;
           background:#eee;border-radius:6px;color:#999;font-size:.8rem;text-align:center;">
        Fichier supprimé<br>(déjà traité)
      </div>
    <?php endif; ?>
    <div class="info">
      <h3><?= htmlspecialchars($v['nom'] ?? '?') ?> <span class="badge <?= $v['statut'] ?>"><?= $v['statut'] ?></span></h3>
      <p>📱 <?= htmlspecialchars($v['whatsapp'] ?? '?') ?></p>
      <p>Envoyé le <?= htmlspecialchars($v['created_at']) ?></p>
      <?php if ($v['reviewed_by']): ?>
        <p>Traité par <?= htmlspecialchars($v['reviewed_by']) ?> le <?= htmlspecialchars($v['reviewed_at']) ?></p>
      <?php endif; ?>

      <?php if ($v['statut'] === 'en_attente'): ?>
      <div class="actions">
        <form method="POST" style="display:inline">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
          <input type="hidden" name="id" value="<?= $v['id'] ?>">
          <input type="hidden" name="action" value="approuver">
          <button type="submit" class="btn-ok">✅ Approuver</button>
        </form>
        <form method="POST" style="display:inline">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
          <input type="hidden" name="id" value="<?= $v['id'] ?>">
          <input type="hidden" name="action" value="refuser">
          <button type="submit" class="btn-refuse">❌ Refuser</button>
        </form>
      </div>
      <?php endif; ?>
    </div>
  </div>
  <?php endforeach; ?>

</body>
</html>
