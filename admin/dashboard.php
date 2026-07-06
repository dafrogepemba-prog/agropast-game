<?php
// ============================================================
// admin/dashboard.php — Dashboard leads AgroPast-Game
// ============================================================
session_start();
if (empty($_SESSION['admin_logged_in'])) {
    header('Location: index.php');
    exit;
}

require_once dirname(__DIR__) . '/api/config.php';

// Connexion DB
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (PDOException $e) {
    die('Erreur DB : ' . htmlspecialchars($e->getMessage()));
}

$table  = DB_PREFIX . 'leads';
$tScore = DB_PREFIX . 'scores';

// --- Token CSRF session ----------------------------------
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
$csrf = $_SESSION['csrf_token'];

// --- ACTION : Supprimer un utilisateur -------------------
$delete_msg   = '';
$delete_error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action_delete'])) {
    $token_ok  = isset($_POST['csrf_token']) && hash_equals($csrf, $_POST['csrf_token']);
    $delete_id = (int)($_POST['delete_id'] ?? 0);

    if (!$token_ok) {
        $delete_error = 'Token de sécurité invalide.';
    } elseif ($delete_id < 1) {
        $delete_error = 'ID invalide.';
    } else {
        try {
            // Récupérer infos avant suppression (pour le message)
            $info = $pdo->prepare("SELECT nom, whatsapp FROM `{$table}` WHERE id = ?");
            $info->execute([$delete_id]);
            $user = $info->fetch();

            if (!$user) {
                $delete_error = 'Utilisateur introuvable (id=' . $delete_id . ').';
            } else {
                // Supprimer les scores liés si la table existe
                try {
                    $pdo->prepare("DELETE FROM `{$tScore}` WHERE lead_id = ?")->execute([$delete_id]);
                } catch (PDOException $ignored) { /* table scores absente = pas grave */ }

                // Supprimer le lead
                $pdo->prepare("DELETE FROM `{$table}` WHERE id = ?")->execute([$delete_id]);

                $delete_msg = '✅ Utilisateur <strong>' . htmlspecialchars($user['nom'] ?: $user['whatsapp'])
                            . '</strong> supprimé avec succès. Il peut se réinscrire.';
            }
        } catch (PDOException $e) {
            $delete_error = 'Erreur DB : ' . htmlspecialchars($e->getMessage());
        }
    }
    // Invalider le token après usage
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    $csrf = $_SESSION['csrf_token'];
}

// --- Statistiques globales --------------------------------
$stats = $pdo->query("
    SELECT
        COUNT(*)                                      AS total,
        COUNT(DISTINCT pays)                          AS nb_pays,
        SUM(referrer_ref_id != '')                    AS avec_parrain,
        SUM(DATE(date_inscription) = CURDATE())       AS aujourd_hui,
        SUM(date_inscription >= DATE_SUB(NOW(), INTERVAL 7 DAY))  AS cette_semaine
    FROM `{$table}`
")->fetch();

// --- Répartition par pays --------------------------------
$pays_data = $pdo->query("
    SELECT pays, COUNT(*) AS nb
    FROM `{$table}`
    WHERE pays != ''
    GROUP BY pays ORDER BY nb DESC LIMIT 10
")->fetchAll();

// --- Répartition par source ------------------------------
$source_data = $pdo->query("
    SELECT
        COALESCE(NULLIF(utm_source,''), NULLIF(source_declaree,''), 'Non renseigné') AS src,
        COUNT(*) AS nb
    FROM `{$table}`
    GROUP BY src ORDER BY nb DESC LIMIT 8
")->fetchAll();

// --- Top parrains ----------------------------------------
$parrains = $pdo->query("
    SELECT l.ref_id, l.nom, l.email, COUNT(f.id) AS nb_filleuls
    FROM `{$table}` l
    LEFT JOIN `{$table}` f ON f.referrer_ref_id = l.ref_id
    GROUP BY l.ref_id, l.nom, l.email
    HAVING nb_filleuls > 0
    ORDER BY nb_filleuls DESC LIMIT 10
")->fetchAll();

// --- Liste des leads (pagination) ------------------------
$page     = max(1, (int)($_GET['page'] ?? 1));
$per_page = 20;
$offset   = ($page - 1) * $per_page;
$search   = trim($_GET['q'] ?? '');

$where = $search
    ? "WHERE nom LIKE :q OR email LIKE :q OR pays LIKE :q"
    : '';
$count_stmt = $pdo->prepare("SELECT COUNT(*) FROM `{$table}` {$where}");
if ($search) $count_stmt->execute([':q' => "%{$search}%"]);
else         $count_stmt->execute();
$total_leads = $count_stmt->fetchColumn();
$total_pages = max(1, ceil($total_leads / $per_page));

$leads_stmt = $pdo->prepare("
    SELECT id, ref_id, nom, email, pays, source_declaree, utm_source, referrer_ref_id, date_inscription, whatsapp
    FROM `{$table}` {$where}
    ORDER BY date_inscription DESC
    LIMIT {$per_page} OFFSET {$offset}
");
if ($search) $leads_stmt->execute([':q' => "%{$search}%"]);
else         $leads_stmt->execute();
$leads = $leads_stmt->fetchAll();

// --- Export CSV ------------------------------------------
if (isset($_GET['export']) && $_GET['export'] === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="leads_agropast_' . date('Ymd') . '.csv"');
    $out = fopen('php://output', 'w');
    fprintf($out, chr(0xEF).chr(0xBB).chr(0xBF)); // BOM UTF-8
    fputcsv($out, ['ID','Ref','Nom','Email','Pays','Source','UTM','Parrain','Date']);
    $all = $pdo->query("SELECT id,ref_id,nom,email,pays,source_declaree,utm_source,referrer_ref_id,date_inscription FROM `{$table}` ORDER BY date_inscription DESC")->fetchAll();
    foreach ($all as $row) fputcsv($out, array_values($row));
    fclose($out);
    exit;
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Dashboard — AgroPast-Game Admin</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --green: #2e7d32; --green-l: #4caf50; --yellow: #f9a825;
      --dark: #1b2a1b; --bg: #f1f8e9; --white: #fff;
      --shadow: 0 2px 12px rgba(0,0,0,.08);
      --radius: 10px;
    }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: var(--bg); color: #222; }

    /* HEADER */
    header {
      background: var(--dark); color: var(--white);
      padding: 1rem 2rem;
      display: flex; align-items: center; justify-content: space-between;
    }
    header h1 { font-size: 1.2rem; color: var(--yellow); }
    header .user { font-size: .85rem; opacity: .7; }
    .btn-logout {
      background: rgba(255,255,255,.1); color: var(--white);
      border: 1px solid rgba(255,255,255,.2); border-radius: 6px;
      padding: .4rem .9rem; font-size: .85rem; cursor: pointer;
      text-decoration: none; transition: background .2s;
    }
    .btn-logout:hover { background: rgba(255,255,255,.2); }

    /* MAIN */
    main { max-width: 1200px; margin: 0 auto; padding: 2rem 1.5rem; }

    /* STAT CARDS */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 1rem; margin-bottom: 2rem;
    }
    .stat-card {
      background: var(--white); border-radius: var(--radius);
      padding: 1.2rem 1.5rem; box-shadow: var(--shadow);
      text-align: center;
    }
    .stat-card .num { font-size: 2rem; font-weight: 800; color: var(--green); }
    .stat-card .lbl { font-size: .8rem; color: #666; margin-top: .2rem; }

    /* SECTIONS */
    .section-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.5rem; margin-bottom: 2rem;
    }
    @media (max-width: 700px) { .section-grid { grid-template-columns: 1fr; } }

    .card {
      background: var(--white); border-radius: var(--radius);
      padding: 1.5rem; box-shadow: var(--shadow);
    }
    .card h2 { font-size: 1rem; font-weight: 700; margin-bottom: 1rem; color: var(--green); }

    /* BARRES */
    .bar-row { margin-bottom: .7rem; }
    .bar-label { display: flex; justify-content: space-between; font-size: .85rem; margin-bottom: .2rem; }
    .bar-wrap { background: #e8f5e9; border-radius: 50px; height: 8px; }
    .bar-fill { background: var(--green-l); border-radius: 50px; height: 100%; transition: width .5s; }

    /* TABLE */
    .table-header {
      display: flex; align-items: center; justify-content: space-between;
      flex-wrap: wrap; gap: 1rem; margin-bottom: 1rem;
    }
    .table-header h2 { font-size: 1rem; font-weight: 700; color: var(--green); }
    .search-wrap { display: flex; gap: .5rem; }
    .search-wrap input {
      padding: .4rem .8rem; border: 1.5px solid #ddd;
      border-radius: 6px; font-size: .9rem;
    }
    .search-wrap input:focus { outline: none; border-color: var(--green); }
    .btn-export {
      background: var(--green); color: var(--white);
      border: none; border-radius: 6px;
      padding: .4rem .9rem; font-size: .85rem;
      cursor: pointer; text-decoration: none;
      white-space: nowrap;
    }
    .btn-export:hover { background: #1b5e20; }

    table { width: 100%; border-collapse: collapse; font-size: .85rem; }
    thead { background: var(--green); color: var(--white); }
    th, td { padding: .65rem .9rem; text-align: left; border-bottom: 1px solid #eee; }
    tbody tr:hover { background: #f1f8e9; }
    .badge-src {
      background: #e8f5e9; color: var(--green);
      border-radius: 50px; padding: .1rem .5rem;
      font-size: .78rem; font-weight: 600;
    }
    .ref-code { font-family: monospace; font-size: .8rem; color: #888; }

    /* PAGINATION */
    .pagination { display: flex; gap: .5rem; justify-content: center; margin-top: 1rem; flex-wrap: wrap; }
    .pagination a, .pagination span {
      padding: .35rem .7rem; border-radius: 6px;
      font-size: .85rem; text-decoration: none;
      border: 1px solid #ddd; color: #444;
    }
    .pagination a:hover { background: var(--bg); }
    .pagination .active { background: var(--green); color: var(--white); border-color: var(--green); }

    /* SUPPRESSION */
    .btn-del {
      background: none; border: 1px solid #e53935; color: #e53935;
      border-radius: 5px; padding: .25rem .55rem; font-size: .78rem;
      cursor: pointer; white-space: nowrap; transition: background .15s, color .15s;
    }
    .btn-del:hover { background: #e53935; color: #fff; }
    .alert { padding: .75rem 1rem; border-radius: 8px; margin-bottom: 1.2rem; font-size: .9rem; }
    .alert-success { background: #e8f5e9; border: 1px solid #a5d6a7; color: #2e7d32; }
    .alert-error   { background: #ffebee; border: 1px solid #ef9a9a; color: #c62828; }

    /* Modal confirmation */
    .modal-overlay {
      display: none; position: fixed; inset: 0;
      background: rgba(0,0,0,.5); z-index: 1000;
      align-items: center; justify-content: center;
    }
    .modal-overlay.open { display: flex; }
    .modal-box {
      background: #fff; border-radius: 12px; padding: 2rem;
      max-width: 380px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,.2);
    }
    .modal-box h3 { margin-bottom: .8rem; color: #c62828; }
    .modal-box p  { font-size: .9rem; color: #555; margin-bottom: 1.2rem; }
    .modal-actions { display: flex; gap: .7rem; justify-content: flex-end; }
    .btn-cancel {
      background: #eee; border: none; border-radius: 6px;
      padding: .45rem 1rem; cursor: pointer; font-size: .9rem;
    }
    .btn-confirm-del {
      background: #e53935; color: #fff; border: none; border-radius: 6px;
      padding: .45rem 1rem; cursor: pointer; font-size: .9rem; font-weight: 600;
    }
    .btn-confirm-del:hover { background: #b71c1c; }
  </style>
</head>
<body>

<header>
  <h1>🍉 AgroPast-Game — Dashboard Admin</h1>
  <div style="display:flex;align-items:center;gap:1rem">
    <span class="user">👤 <?= htmlspecialchars($_SESSION['admin_user']) ?></span>
    <a href="logout.php" class="btn-logout">Déconnexion</a>
  </div>
</header>

<main>

  <!-- MESSAGES SUPPRESSION -->
  <?php if ($delete_msg): ?>
    <div class="alert alert-success"><?= $delete_msg ?></div>
  <?php endif; ?>
  <?php if ($delete_error): ?>
    <div class="alert alert-error">❌ <?= htmlspecialchars($delete_error) ?></div>
  <?php endif; ?>

  <!-- STATS GLOBALES -->
  <div class="stats-grid">
    <div class="stat-card">
      <div class="num"><?= number_format($stats['total']) ?></div>
      <div class="lbl">Total inscrits</div>
    </div>
    <div class="stat-card">
      <div class="num"><?= $stats['aujourd_hui'] ?></div>
      <div class="lbl">Aujourd'hui</div>
    </div>
    <div class="stat-card">
      <div class="num"><?= $stats['cette_semaine'] ?></div>
      <div class="lbl">Cette semaine</div>
    </div>
    <div class="stat-card">
      <div class="num"><?= $stats['nb_pays'] ?></div>
      <div class="lbl">Pays représentés</div>
    </div>
    <div class="stat-card">
      <div class="num"><?= $stats['avec_parrain'] ?></div>
      <div class="lbl">Via parrainage</div>
    </div>
  </div>

  <!-- PAYS + SOURCES -->
  <div class="section-grid">

    <!-- Top pays -->
    <div class="card">
      <h2>🌍 Top pays</h2>
      <?php
      $max_pays = $pays_data[0]['nb'] ?? 1;
      foreach ($pays_data as $row):
        $pct = round($row['nb'] / $max_pays * 100);
      ?>
      <div class="bar-row">
        <div class="bar-label">
          <span><?= htmlspecialchars($row['pays']) ?></span>
          <span><?= $row['nb'] ?></span>
        </div>
        <div class="bar-wrap"><div class="bar-fill" style="width:<?= $pct ?>%"></div></div>
      </div>
      <?php endforeach; ?>
    </div>

    <!-- Sources d'acquisition -->
    <div class="card">
      <h2>📣 Sources d'acquisition</h2>
      <?php
      $max_src = $source_data[0]['nb'] ?? 1;
      foreach ($source_data as $row):
        $pct = round($row['nb'] / $max_src * 100);
      ?>
      <div class="bar-row">
        <div class="bar-label">
          <span><?= htmlspecialchars($row['src']) ?></span>
          <span><?= $row['nb'] ?></span>
        </div>
        <div class="bar-wrap"><div class="bar-fill" style="width:<?= $pct ?>%"></div></div>
      </div>
      <?php endforeach; ?>
    </div>

  </div>

  <!-- TOP PARRAINS -->
  <?php if (!empty($parrains)): ?>
  <div class="card" style="margin-bottom:2rem">
    <h2>🏆 Top parrains (boucle virale)</h2>
    <table>
      <thead><tr><th>Nom</th><th>Email</th><th>Ref</th><th>Filleuls</th></tr></thead>
      <tbody>
      <?php foreach ($parrains as $p): ?>
        <tr>
          <td><?= htmlspecialchars($p['nom']) ?></td>
          <td><?= htmlspecialchars($p['email']) ?></td>
          <td class="ref-code"><?= htmlspecialchars($p['ref_id']) ?></td>
          <td><strong><?= $p['nb_filleuls'] ?></strong></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
  <?php endif; ?>

  <!-- LISTE DES LEADS -->
  <div class="card">
    <div class="table-header">
      <h2>📋 Liste des inscrits (<?= $total_leads ?>)</h2>
      <div class="search-wrap">
        <form method="GET" action="">
          <input type="text" name="q" placeholder="Rechercher…"
                 value="<?= htmlspecialchars($search) ?>" />
        </form>
        <a href="?export=csv" class="btn-export">⬇ Export CSV</a>
      </div>
    </div>

    <div style="overflow-x:auto">
    <table>
      <thead>
        <tr>
          <th>#</th>
          <th>Nom</th>
          <th>Email</th>
          <th>Pays</th>
          <th>Source</th>
          <th>Ref</th>
          <th>Parrain</th>
          <th>Date</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
      <?php foreach ($leads as $lead): ?>
        <tr>
          <td><?= $lead['id'] ?></td>
          <td><?= htmlspecialchars($lead['nom']) ?></td>
          <td><?= htmlspecialchars($lead['email']) ?></td>
          <td><?= htmlspecialchars($lead['pays']) ?></td>
          <td>
            <?php
            $src = $lead['utm_source'] ?: $lead['source_declaree'] ?: '—';
            echo '<span class="badge-src">' . htmlspecialchars($src) . '</span>';
            ?>
          </td>
          <td class="ref-code"><?= htmlspecialchars($lead['ref_id']) ?></td>
          <td class="ref-code"><?= $lead['referrer_ref_id'] ? htmlspecialchars($lead['referrer_ref_id']) : '—' ?></td>
          <td><?= date('d/m/y H:i', strtotime($lead['date_inscription'])) ?></td>
          <td>
            <button
              class="btn-del"
              onclick="openDeleteModal(<?= $lead['id'] ?>, <?= json_encode($lead['nom'] ?: $lead['whatsapp'] ?? '') ?>)"
              title="Supprimer cet utilisateur">
              🗑 Suppr.
            </button>
          </td>
        </tr>
      <?php endforeach; ?>
      <?php if (empty($leads)): ?>
        <tr><td colspan="9" style="text-align:center;padding:2rem;color:#888">Aucun résultat</td></tr>
      <?php endif; ?>
      </tbody>
    </table>
    </div>

    <!-- Pagination -->
    <?php if ($total_pages > 1): ?>
    <div class="pagination">
      <?php for ($i = 1; $i <= $total_pages; $i++): ?>
        <?php if ($i === $page): ?>
          <span class="active"><?= $i ?></span>
        <?php else: ?>
          <a href="?page=<?= $i ?><?= $search ? '&q='.urlencode($search) : '' ?>"><?= $i ?></a>
        <?php endif; ?>
      <?php endfor; ?>
    </div>
    <?php endif; ?>

  </div>

</main>

<!-- MODAL CONFIRMATION SUPPRESSION -->
<div class="modal-overlay" id="deleteModal">
  <div class="modal-box">
    <h3>🗑 Supprimer l'utilisateur ?</h3>
    <p id="modalUserName"></p>
    <p style="color:#e53935;font-size:.85rem">
      ⚠️ Cette action est <strong>irréversible</strong>. L'utilisateur pourra se réinscrire avec le même numéro.
    </p>
    <form method="POST" action="" id="deleteForm">
      <input type="hidden" name="action_delete" value="1" />
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf) ?>" />
      <input type="hidden" name="delete_id" id="deleteIdInput" value="" />
      <div class="modal-actions">
        <button type="button" class="btn-cancel" onclick="closeDeleteModal()">Annuler</button>
        <button type="submit" class="btn-confirm-del">Oui, supprimer</button>
      </div>
    </form>
  </div>
</div>

<script>
function openDeleteModal(id, name) {
  document.getElementById('deleteIdInput').value = id;
  document.getElementById('modalUserName').textContent =
    'Utilisateur : ' + (name || '#' + id);
  document.getElementById('deleteModal').classList.add('open');
}
function closeDeleteModal() {
  document.getElementById('deleteModal').classList.remove('open');
}
// Fermer en cliquant sur l'overlay
document.getElementById('deleteModal').addEventListener('click', function(e) {
  if (e.target === this) closeDeleteModal();
});
</script>

</body>
</html>
