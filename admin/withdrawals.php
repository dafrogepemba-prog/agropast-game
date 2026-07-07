<?php
// ============================================================
// admin/withdrawals.php — Gestion des demandes de retrait
// ============================================================
session_start();
if (empty($_SESSION['admin_logged_in'])) { header('Location: index.php'); exit; }

require_once dirname(__DIR__) . '/api/config.php';

try {
    $pdo = new PDO(
        'mysql:host='.DB_HOST.';dbname='.DB_NAME.';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) { die('Erreur DB'); }

$tW = DB_PREFIX . 'withdrawals';

// --- Action : approuver ou refuser --------------------------
$msg = ''; $err = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $wid    = (int)($_POST['wid']    ?? 0);
    $action = $_POST['action_w']     ?? '';
    $note   = substr(trim($_POST['note_admin'] ?? ''), 0, 255);

    if ($wid > 0 && in_array($action, ['approuve','refuse'])) {
        $pdo->prepare("UPDATE `{$tW}` SET statut=?, note_admin=? WHERE id=?")
            ->execute([$action, $note, $wid]);
        $msg = $action === 'approuve'
            ? '✅ Retrait approuvé et marqué comme payé.'
            : '❌ Retrait refusé.';
    }
}

// --- Stats rapides ------------------------------------------
$stats = $pdo->query("
    SELECT
        COUNT(*) AS total,
        SUM(statut='en_attente') AS en_attente,
        SUM(statut='approuve')   AS approuves,
        SUM(statut='refuse')     AS refuses,
        SUM(CASE WHEN statut='approuve' THEN montant ELSE 0 END) AS total_paye
    FROM `{$tW}`
")->fetch();

// --- Liste ---------------------------------------------------
$filtre = $_GET['f'] ?? 'en_attente';
$allowed = ['en_attente', 'approuve', 'refuse', 'tous'];
if (!in_array($filtre, $allowed)) $filtre = 'en_attente';

if ($filtre === 'tous') {
    $list = $pdo->query("
        SELECT w.*, l.whatsapp, l.pays
        FROM `{$tW}` w
        LEFT JOIN `" . DB_PREFIX . "leads` l ON l.id = w.user_id
        ORDER BY w.created_at DESC
        LIMIT 100
    ")->fetchAll();
} else {
    $stmt = $pdo->prepare("
        SELECT w.*, l.whatsapp, l.pays
        FROM `{$tW}` w
        LEFT JOIN `" . DB_PREFIX . "leads` l ON l.id = w.user_id
        WHERE w.statut = ?
        ORDER BY w.created_at DESC
        LIMIT 100
    ");
    $stmt->execute([$filtre]);
    $list = $stmt->fetchAll();
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Retraits — Admin AgroPast-Game</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root { --green:#2e7d32; --yellow:#f9a825; --dark:#1b2a1b; --bg:#f1f8e9; --radius:10px; }
    body { font-family:'Segoe UI',Arial,sans-serif; background:var(--bg); color:#222; }
    header { background:var(--dark); color:#fff; padding:1rem 2rem;
      display:flex; align-items:center; justify-content:space-between; }
    header h1 { font-size:1.1rem; color:var(--yellow); }
    .btn-back { background:rgba(255,255,255,.1); color:#fff;
      border:1px solid rgba(255,255,255,.2); border-radius:6px;
      padding:.4rem .9rem; font-size:.85rem; text-decoration:none; }
    main { max-width:1100px; margin:0 auto; padding:2rem 1.5rem; }
    .stats { display:grid; grid-template-columns:repeat(5,1fr); gap:1rem; margin-bottom:2rem; }
    .stat { background:#fff; border-radius:var(--radius); padding:1.2rem; text-align:center;
      box-shadow:0 2px 10px rgba(0,0,0,.07); }
    .stat .n { font-size:1.8rem; font-weight:900; color:var(--green); }
    .stat .l { font-size:.75rem; color:#888; margin-top:.2rem; }
    .card { background:#fff; border-radius:var(--radius); padding:1.5rem;
      box-shadow:0 2px 10px rgba(0,0,0,.07); }
    .filters { display:flex; gap:.5rem; margin-bottom:1rem; flex-wrap:wrap; }
    .filters a { padding:.35rem .8rem; border-radius:6px; font-size:.85rem;
      text-decoration:none; border:1px solid #ddd; color:#444; }
    .filters a.active { background:var(--green); color:#fff; border-color:var(--green); }
    .alert-ok  { background:#e8f5e9; border:1px solid #a5d6a7; color:#2e7d32;
      padding:.7rem 1rem; border-radius:8px; margin-bottom:1rem; }
    table { width:100%; border-collapse:collapse; font-size:.84rem; }
    thead { background:var(--green); color:#fff; }
    th,td { padding:.6rem .8rem; text-align:left; border-bottom:1px solid #eee; }
    tbody tr:hover { background:#f9fbe7; }
    .badge { display:inline-block; padding:.1rem .5rem; border-radius:20px;
      font-size:.75rem; font-weight:700; }
    .badge-wait   { background:#fff8e1; color:#f57f17; }
    .badge-ok     { background:#e8f5e9; color:#2e7d32; }
    .badge-refuse { background:#ffebee; color:#c62828; }
    .action-form { display:inline; }
    .btn-ok  { background:#2e7d32; color:#fff; border:none; border-radius:5px;
      padding:.3rem .7rem; font-size:.78rem; cursor:pointer; margin-right:.2rem; }
    .btn-no  { background:#e53935; color:#fff; border:none; border-radius:5px;
      padding:.3rem .7rem; font-size:.78rem; cursor:pointer; }
    .btn-ok:hover  { background:#1b5e20; }
    .btn-no:hover  { background:#b71c1c; }
    @media(max-width:700px){ .stats { grid-template-columns:repeat(2,1fr); } }
  </style>
</head>
<body>
<header>
  <h1>💸 Demandes de retrait — AgroPast-Game</h1>
  <a href="dashboard.php" class="btn-back">← Dashboard</a>
</header>
<main>

  <?php if ($msg): ?><div class="alert-ok"><?= $msg ?></div><?php endif; ?>

  <!-- STATS -->
  <div class="stats">
    <div class="stat"><div class="n"><?= $stats['en_attente'] ?></div><div class="l">⏳ En attente</div></div>
    <div class="stat"><div class="n"><?= $stats['approuves'] ?></div><div class="l">✅ Approuvés</div></div>
    <div class="stat"><div class="n"><?= $stats['refuses'] ?></div><div class="l">❌ Refusés</div></div>
    <div class="stat"><div class="n"><?= $stats['total'] ?></div><div class="l">Total demandes</div></div>
    <div class="stat"><div class="n" style="color:#f9a825"><?= number_format($stats['total_paye']) ?> F</div><div class="l">Total payé (FCFA)</div></div>
  </div>

  <div class="card">
    <div class="filters">
      <a href="?f=en_attente" class="<?= $filtre==='en_attente'?'active':'' ?>">⏳ En attente (<?= $stats['en_attente'] ?>)</a>
      <a href="?f=approuve"   class="<?= $filtre==='approuve'?'active':'' ?>">✅ Approuvés</a>
      <a href="?f=refuse"     class="<?= $filtre==='refuse'?'active':'' ?>">❌ Refusés</a>
      <a href="?f=tous"       class="<?= $filtre==='tous'?'active':'' ?>">Tous</a>
    </div>

    <div style="overflow-x:auto">
    <table>
      <thead>
        <tr>
          <th>#</th><th>Joueur</th><th>Téléphone retrait</th><th>WhatsApp</th>
          <th>Montant</th><th>Score</th><th>Statut</th><th>Date</th><th>Actions</th>
        </tr>
      </thead>
      <tbody>
      <?php foreach ($list as $w): ?>
        <tr>
          <td><?= $w['id'] ?></td>
          <td><strong><?= htmlspecialchars($w['nom']) ?></strong></td>
          <td style="font-weight:700;color:#1565c0"><?= htmlspecialchars($w['telephone']) ?></td>
          <td style="font-family:monospace"><?= htmlspecialchars($w['whatsapp'] ?? '—') ?></td>
          <td style="font-weight:700;color:#2e7d32"><?= number_format($w['montant']) ?> FCFA</td>
          <td><?= number_format($w['score_used']) ?> pts</td>
          <td>
            <?php if ($w['statut']==='en_attente'): ?>
              <span class="badge badge-wait">⏳ En attente</span>
            <?php elseif ($w['statut']==='approuve'): ?>
              <span class="badge badge-ok">✅ Payé</span>
            <?php else: ?>
              <span class="badge badge-refuse">❌ Refusé</span>
            <?php endif; ?>
          </td>
          <td><?= date('d/m/y H:i', strtotime($w['created_at'])) ?></td>
          <td>
            <?php if ($w['statut']==='en_attente'): ?>
            <form method="POST" class="action-form"
                  onsubmit="return confirm('Confirmer le paiement de <?= $w['montant'] ?> FCFA à <?= htmlspecialchars($w['nom']) ?> ?')">
              <input type="hidden" name="wid" value="<?= $w['id'] ?>">
              <input type="hidden" name="action_w" value="approuve">
              <input type="hidden" name="note_admin" value="Paiement manuel effectué">
              <button type="submit" class="btn-ok">✅ Payé</button>
            </form>
            <form method="POST" class="action-form"
                  onsubmit="return confirm('Refuser ce retrait ?')">
              <input type="hidden" name="wid" value="<?= $w['id'] ?>">
              <input type="hidden" name="action_w" value="refuse">
              <input type="hidden" name="note_admin" value="Refusé par admin">
              <button type="submit" class="btn-no">❌ Refuser</button>
            </form>
            <?php else: ?>
              <span style="font-size:.78rem;color:#aaa"><?= htmlspecialchars($w['note_admin'] ?? '') ?></span>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; ?>
      <?php if (empty($list)): ?>
        <tr><td colspan="9" style="text-align:center;padding:2rem;color:#aaa">Aucune demande</td></tr>
      <?php endif; ?>
      </tbody>
    </table>
    </div>
  </div>

</main>
</body>
</html>
