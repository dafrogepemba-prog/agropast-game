<?php
// ============================================================
// admin/kpi_financier.php — Vue financière "super admin"
//
// Combine :
//  - Ce qu'on paie aux joueurs (FCFA versés/en attente) : déjà en base
//  - Revenus publicitaires (AdMob / Unity Ads) : saisis manuellement,
//    car ces chiffres vivent sur les dashboards Google/Unity et
//    nécessiteraient une intégration API (OAuth AdMob, clé Unity)
//    non configurée à ce jour. Ceci permet de calculer un profit
//    net immédiatement, sans attendre cette intégration.
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

$tLeads = DB_PREFIX . 'leads';
$tW     = DB_PREFIX . 'withdrawals';
$tRev   = DB_PREFIX . 'ad_revenue_manual';

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tRev}` (
        `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `mois`        CHAR(7)      NOT NULL,   -- format 'YYYY-MM'
        `source`      VARCHAR(30)  NOT NULL,   -- 'admob' | 'unity' | 'autre'
        `montant_fcfa` INT UNSIGNED NOT NULL,
        `note`        VARCHAR(255) DEFAULT '',
        `updated_by`  VARCHAR(100) DEFAULT '',
        `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
            ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY `uq_mois_source` (`mois`, `source`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

$message = '';
$error   = '';

// --- Enregistrer/mettre à jour un revenu pub mensuel ------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = $_POST['csrf_token'] ?? '';
    if (!hash_equals($_SESSION['csrf_token'], $csrf)) {
        $error = 'Session invalide, recharge la page et réessaie.';
    } else {
        $mois   = preg_replace('/[^0-9\-]/', '', $_POST['mois'] ?? '');
        $source = in_array($_POST['source'] ?? '', ['admob', 'unity', 'autre'], true) ? $_POST['source'] : '';
        $montant = (int)($_POST['montant_fcfa'] ?? -1);
        $note    = trim(substr($_POST['note'] ?? '', 0, 255));

        if (!preg_match('/^\d{4}-\d{2}$/', $mois)) {
            $error = 'Mois invalide (format attendu : AAAA-MM).';
        } elseif ($source === '') {
            $error = 'Source invalide.';
        } elseif ($montant < 0) {
            $error = 'Montant invalide.';
        } else {
            $stmt = $pdo->prepare("
                INSERT INTO `{$tRev}` (mois, source, montant_fcfa, note, updated_by)
                VALUES (:mois, :source, :montant, :note, :admin)
                ON DUPLICATE KEY UPDATE
                    montant_fcfa = :montant2, note = :note2, updated_by = :admin2
            ");
            $stmt->execute([
                ':mois'     => $mois,
                ':source'   => $source,
                ':montant'  => $montant,
                ':note'     => $note,
                ':admin'    => $_SESSION['admin_user'] ?? 'inconnu',
                ':montant2' => $montant,
                ':note2'    => $note,
                ':admin2'   => $_SESSION['admin_user'] ?? 'inconnu',
            ]);
            $message = "Revenu {$source} de {$mois} enregistré : " . number_format($montant, 0, ',', ' ') . " FCFA.";
        }
    }
}

// --- Filtre période (par défaut : tout) --------------------------
$periode = $_GET['periode'] ?? 'tout';
$dateCond = '';
if ($periode === '7j')  $dateCond = "AND created_at >= (NOW() - INTERVAL 7 DAY)";
if ($periode === '30j') $dateCond = "AND created_at >= (NOW() - INTERVAL 30 DAY)";

// --- Ce qu'on a payé / doit payer --------------------------------
$payout = $pdo->query("
    SELECT
        COALESCE(SUM(CASE WHEN statut='approuve'   THEN montant ELSE 0 END), 0) AS total_paye,
        COALESCE(SUM(CASE WHEN statut='en_attente' THEN montant ELSE 0 END), 0) AS total_attente,
        COALESCE(SUM(CASE WHEN statut='refuse'     THEN montant ELSE 0 END), 0) AS total_refuse,
        COUNT(*) AS nb_demandes
    FROM `{$tW}` WHERE 1=1 {$dateCond}
")->fetch();

// --- Revenus pub (tout historique, indépendant du filtre période) ---
$revenus = $pdo->query("
    SELECT source, SUM(montant_fcfa) AS total
    FROM `{$tRev}` GROUP BY source
")->fetchAll();
$revenuTotal = 0;
$revenuParSource = ['admob' => 0, 'unity' => 0, 'autre' => 0];
foreach ($revenus as $r) {
    $revenuParSource[$r['source']] = (int)$r['total'];
    $revenuTotal += (int)$r['total'];
}

$profitNet = $revenuTotal - (int)$payout['total_paye'];

// --- Répartition par pays (campagnes) ----------------------------
$parPays = $pdo->query("
    SELECT pays, COUNT(*) AS nb
    FROM `{$tLeads}` WHERE pays != '' GROUP BY pays ORDER BY nb DESC LIMIT 10
")->fetchAll();

// --- Répartition par source d'acquisition ------------------------
$parSourceAcq = $pdo->query("
    SELECT COALESCE(NULLIF(utm_source,''), NULLIF(source_declaree,''), 'Non renseigné') AS src, COUNT(*) AS nb
    FROM `{$tLeads}` GROUP BY src ORDER BY nb DESC
")->fetchAll();

// --- Historique des saisies de revenu pub -------------------------
$histoRevenus = $pdo->query("
    SELECT * FROM `{$tRev}` ORDER BY mois DESC, source ASC LIMIT 24
")->fetchAll();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>KPI Financier — AgroPast Admin</title>
<meta name="robots" content="noindex, nofollow">
<style>
  body { font-family: system-ui, sans-serif; max-width: 1100px; margin: 0 auto; padding: 24px 20px 60px; background:#f4f6f5; color:#1b2a1b; }
  h1 { font-size: 1.4rem; margin-bottom: 4px; }
  h2 { font-size: 1.05rem; margin: 32px 0 12px; color:#2f7a3f; }
  a.back { display:inline-block; margin-bottom:16px; color:#2f7a3f; }
  .cards { display:grid; grid-template-columns: repeat(auto-fit, minmax(180px,1fr)); gap:14px; margin-top:16px; }
  .card { background:#fff; border-radius:10px; padding:18px; box-shadow:0 1px 3px rgba(0,0,0,.08); text-align:center; }
  .card .num { font-size:1.6rem; font-weight:800; }
  .card .lbl { font-size:.8rem; color:#666; margin-top:4px; }
  .num.pos { color:#1a6b2e; } .num.neg { color:#c62828; } .num.neutral { color:#f9a825; }
  .periode-tabs { margin-top:20px; display:flex; gap:8px; }
  .periode-tabs a { padding:6px 14px; border-radius:20px; border:1px solid #2f7a3f; color:#2f7a3f; text-decoration:none; font-size:.85rem; }
  .periode-tabs a.active { background:#2f7a3f; color:#fff; }
  table { width:100%; border-collapse:collapse; margin-top:10px; background:#fff; border-radius:8px; overflow:hidden; font-size:.88rem; }
  th, td { text-align:left; padding:8px 10px; border-bottom:1px solid #eee; }
  th { background:#eef4ee; }
  form.rev-form { background:#fff; padding:18px; border-radius:10px; box-shadow:0 1px 3px rgba(0,0,0,.08); display:flex; gap:10px; flex-wrap:wrap; align-items:end; margin-top:12px; }
  form.rev-form div { display:flex; flex-direction:column; gap:4px; }
  form.rev-form label { font-size:.8rem; font-weight:600; }
  form.rev-form input, form.rev-form select { padding:7px 9px; border:1px solid #ccc; border-radius:6px; }
  form.rev-form button { background:#2f7a3f; color:#fff; border:0; padding:9px 16px; border-radius:6px; cursor:pointer; font-weight:600; }
  .msg-ok { background:#e6f6ea; color:#1a6b2e; padding:10px 14px; border-radius:6px; margin-top:12px; }
  .msg-err { background:#fbe7e7; color:#8a1f1f; padding:10px 14px; border-radius:6px; margin-top:12px; }
  .note { font-size:.8rem; color:#777; margin-top:6px; }
</style>
</head>
<body>
  <a class="back" href="dashboard.php">&larr; Retour au dashboard</a>
  <h1>💰 KPI Financier</h1>
  <p class="note">Revenu pub saisi manuellement (AdMob/Unity ne sont pas connectés en API) — le reste est calculé en direct depuis la base.</p>

  <div class="periode-tabs">
    <a href="?periode=tout"  class="<?= $periode==='tout' ? 'active':'' ?>">Tout</a>
    <a href="?periode=30j"   class="<?= $periode==='30j'  ? 'active':'' ?>">30 derniers jours</a>
    <a href="?periode=7j"    class="<?= $periode==='7j'   ? 'active':'' ?>">7 derniers jours</a>
  </div>

  <div class="cards">
    <div class="card"><div class="num neutral"><?= number_format($revenuTotal,0,',',' ') ?> F</div><div class="lbl">Revenu pub total (historique)</div></div>
    <div class="card"><div class="num neg"><?= number_format($payout['total_paye'],0,',',' ') ?> F</div><div class="lbl">Payé aux joueurs (période)</div></div>
    <div class="card"><div class="num neutral"><?= number_format($payout['total_attente'],0,',',' ') ?> F</div><div class="lbl">En attente de paiement</div></div>
    <div class="card"><div class="num <?= $profitNet >= 0 ? 'pos' : 'neg' ?>"><?= number_format($profitNet,0,',',' ') ?> F</div><div class="lbl">Profit net estimé (total)</div></div>
  </div>

  <h2>📊 Revenu pub par source (total historique)</h2>
  <table>
    <tr><th>Source</th><th>Total FCFA</th></tr>
    <tr><td>AdMob</td><td><?= number_format($revenuParSource['admob'],0,',',' ') ?> F</td></tr>
    <tr><td>Unity Ads</td><td><?= number_format($revenuParSource['unity'],0,',',' ') ?> F</td></tr>
    <tr><td>Autre</td><td><?= number_format($revenuParSource['autre'],0,',',' ') ?> F</td></tr>
  </table>

  <h2>➕ Saisir / mettre à jour un revenu mensuel</h2>
  <?php if ($message): ?><div class="msg-ok"><?= htmlspecialchars($message) ?></div><?php endif; ?>
  <?php if ($error): ?><div class="msg-err"><?= htmlspecialchars($error) ?></div><?php endif; ?>
  <form class="rev-form" method="POST">
    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
    <div>
      <label>Mois</label>
      <input type="month" name="mois" required value="<?= date('Y-m') ?>">
    </div>
    <div>
      <label>Source</label>
      <select name="source" required>
        <option value="admob">AdMob</option>
        <option value="unity">Unity Ads</option>
        <option value="autre">Autre</option>
      </select>
    </div>
    <div>
      <label>Montant (FCFA)</label>
      <input type="number" name="montant_fcfa" min="0" required placeholder="ex: 25000">
    </div>
    <div style="flex:1;min-width:180px;">
      <label>Note (optionnel)</label>
      <input type="text" name="note" placeholder="ex: converti depuis $42 USD">
    </div>
    <button type="submit">Enregistrer</button>
  </form>
  <p class="note">Astuce : convertis d'abord le montant affiché sur ton dashboard AdMob/Unity (souvent en USD) en FCFA avant de le saisir ici.</p>

  <h2>🌍 Répartition par pays (top 10)</h2>
  <table>
    <tr><th>Pays</th><th>Inscrits</th></tr>
    <?php foreach ($parPays as $p): ?>
    <tr><td><?= htmlspecialchars($p['pays']) ?></td><td><?= $p['nb'] ?></td></tr>
    <?php endforeach; ?>
  </table>

  <h2>📣 Répartition par source d'acquisition (campagnes)</h2>
  <table>
    <tr><th>Source</th><th>Inscrits</th></tr>
    <?php foreach ($parSourceAcq as $s): ?>
    <tr><td><?= htmlspecialchars($s['src']) ?></td><td><?= $s['nb'] ?></td></tr>
    <?php endforeach; ?>
  </table>

  <h2>🕓 Historique des saisies de revenu pub</h2>
  <table>
    <tr><th>Mois</th><th>Source</th><th>Montant</th><th>Note</th><th>Par</th><th>Mis à jour</th></tr>
    <?php foreach ($histoRevenus as $h): ?>
    <tr>
      <td><?= htmlspecialchars($h['mois']) ?></td>
      <td><?= htmlspecialchars($h['source']) ?></td>
      <td><?= number_format($h['montant_fcfa'],0,',',' ') ?> F</td>
      <td><?= htmlspecialchars($h['note']) ?></td>
      <td><?= htmlspecialchars($h['updated_by']) ?></td>
      <td><?= htmlspecialchars($h['updated_at']) ?></td>
    </tr>
    <?php endforeach; ?>
  </table>

</body>
</html>
