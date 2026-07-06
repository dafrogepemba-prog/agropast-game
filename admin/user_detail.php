<?php
// ============================================================
// admin/user_detail.php — Fiche détaillée d'un inscrit
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

$tLeads = DB_PREFIX . 'leads';
$tScore = DB_PREFIX . 'scores';

$id = (int)($_GET['id'] ?? 0);
if ($id < 1) { header('Location: dashboard.php'); exit; }

// --- Charger le joueur ------------------------------------
$user = $pdo->prepare("SELECT * FROM `{$tLeads}` WHERE id=?");
$user->execute([$id]);
$u = $user->fetch();
if (!$u) { header('Location: dashboard.php'); exit; }

// --- Score du joueur --------------------------------------
$scoreRow = null;
try {
    $s = $pdo->prepare("SELECT * FROM `{$tScore}` WHERE user_id=?");
    $s->execute([$id]);
    $scoreRow = $s->fetch();
} catch (PDOException $ignored) {}

$score      = $scoreRow ? (int)$scoreRow['score_total']     : 0;
$recoltes   = $scoreRow ? (int)$scoreRow['nombre_recoltes'] : 0;
$bonus      = $scoreRow ? (int)$scoreRow['bonus_total']     : 0;
$updatedAt  = $scoreRow ? $scoreRow['updated_at']           : null;

// --- Calculs revenus estimés ------------------------------
// Politique Google AdMob : estimation uniquement, jamais de garantie
// Taux de conversion : 1 USD = 600 FCFA (XAF – Congo-Brazzaville)
// Modèle indicatif : 1 000 pts ≈ 60 FCFA de revenus AdMob estimés
// Parrainage : 1 filleul actif ≈ 30 FCFA CPM estimé
$USD_TO_FCFA   = 600;
$CPT           = (0.10 / 1000) * $USD_TO_FCFA;  // FCFA par point
$CPF           = 0.05 * $USD_TO_FCFA;            // FCFA par filleul actif
$revPoints     = round($score * $CPT);

// Filleuls directs
$filleulsStmt = $pdo->prepare("SELECT COUNT(*) FROM `{$tLeads}` WHERE referrer_ref_id=?");
$filleulsStmt->execute([$u['ref_id']]);
$nbFilleuls = (int)$filleulsStmt->fetchColumn();

// Filleuls actifs (ayant un score > 0)
$filleulsActifsStmt = $pdo->prepare("
    SELECT COUNT(*) FROM `{$tLeads}` l
    JOIN `{$tScore}` sc ON sc.user_id = l.id
    WHERE l.referrer_ref_id=? AND sc.score_total > 0
");
try {
    $filleulsActifsStmt->execute([$u['ref_id']]);
    $nbFilleulsActifs = (int)$filleulsActifsStmt->fetchColumn();
} catch (PDOException $ignored) { $nbFilleulsActifs = 0; }

$revParrainage  = round($nbFilleulsActifs * $CPF);
$revTotal       = round($revPoints + $revParrainage);

// Estimation semaine (score / semaines actives)
$dateInscription = new DateTime($u['date_inscription']);
$now             = new DateTime();
$semaines        = max(1, (int)$dateInscription->diff($now)->days / 7);
$revParSemaine   = round($revTotal / $semaines);
$ptsParSemaine   = round($score / $semaines);

// --- Niveau joueur ----------------------------------------
$niveau = match(true) {
    $score >= 50000 => ['🏆 Légende', '#f9a825'],
    $score >= 20000 => ['💎 Expert',  '#29b6f6'],
    $score >= 5000  => ['🌟 Avancé',  '#66bb6a'],
    $score >= 1000  => ['🌱 Actif',   '#4caf50'],
    default         => ['🌾 Débutant','#90a4ae'],
};

// Sources UTM
$source = $u['utm_source'] ?: $u['source_declaree'] ?: '—';
?>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Fiche joueur #<?= $id ?> — Admin</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --green:#2e7d32; --green-l:#4caf50; --yellow:#f9a825;
      --dark:#1b2a1b; --bg:#f1f8e9; --white:#fff;
      --shadow:0 2px 12px rgba(0,0,0,.08); --radius:10px;
    }
    body { font-family:'Segoe UI',Arial,sans-serif; background:var(--bg); color:#222; }
    header {
      background:var(--dark); color:#fff;
      padding:1rem 2rem; display:flex; align-items:center; justify-content:space-between;
    }
    header h1 { font-size:1.1rem; color:var(--yellow); }
    .btn-back {
      background:rgba(255,255,255,.1); color:#fff;
      border:1px solid rgba(255,255,255,.2); border-radius:6px;
      padding:.4rem .9rem; font-size:.85rem; cursor:pointer;
      text-decoration:none; transition:background .2s;
    }
    .btn-back:hover { background:rgba(255,255,255,.2); }
    main { max-width:1000px; margin:0 auto; padding:2rem 1.5rem; }

    /* Grille principale */
    .grid { display:grid; grid-template-columns:1fr 1fr; gap:1.5rem; margin-bottom:1.5rem; }
    @media(max-width:650px){ .grid { grid-template-columns:1fr; } }

    .card {
      background:var(--white); border-radius:var(--radius);
      padding:1.5rem; box-shadow:var(--shadow);
    }
    .card h2 { font-size:.95rem; font-weight:700; color:var(--green); margin-bottom:1rem; }

    /* Profil */
    .avatar { font-size:3.5rem; text-align:center; margin-bottom:.5rem; }
    .player-name { font-size:1.4rem; font-weight:900; text-align:center; }
    .player-level {
      display:inline-block; padding:.2rem .8rem; border-radius:20px;
      font-size:.85rem; font-weight:700; margin:.3rem auto .8rem; display:block; text-align:center;
    }
    .info-row { display:flex; justify-content:space-between; padding:.4rem 0;
      border-bottom:1px solid #f0f0f0; font-size:.88rem; }
    .info-row:last-child { border-bottom:none; }
    .info-label { color:#888; }
    .info-val { font-weight:600; }

    /* Stats scores */
    .stat-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:.8rem; margin-bottom:1rem; }
    .stat-box { background:#f1f8e9; border-radius:8px; padding:.9rem; text-align:center; }
    .stat-box .num { font-size:1.6rem; font-weight:900; color:var(--green); }
    .stat-box .lbl { font-size:.72rem; color:#666; margin-top:.1rem; }

    /* Revenus */
    .rev-grid { display:grid; grid-template-columns:repeat(2,1fr); gap:.8rem; }
    .rev-box { border-radius:8px; padding:1rem; text-align:center; }
    .rev-box.gold   { background:#fff8e1; }
    .rev-box.blue   { background:#e3f2fd; }
    .rev-box.green  { background:#e8f5e9; }
    .rev-box.purple { background:#f3e5f5; }
    .rev-box .amount { font-size:1.5rem; font-weight:900; }
    .rev-box.gold   .amount { color:#f9a825; }
    .rev-box.blue   .amount { color:#1976d2; }
    .rev-box.green  .amount { color:#2e7d32; }
    .rev-box.purple .amount { color:#7b1fa2; }
    .rev-box .desc { font-size:.75rem; color:#666; margin-top:.2rem; }

    /* Parrainage */
    .ref-link {
      background:#e8f5e9; border:1px dashed var(--green-l);
      border-radius:8px; padding:.6rem 1rem; font-family:monospace;
      font-size:.85rem; word-break:break-all; color:var(--green);
    }
    .filleuls-bar { margin-top:1rem; }
    .bar-label { display:flex; justify-content:space-between; font-size:.82rem; margin-bottom:.25rem; }
    .bar-wrap { background:#e8f5e9; border-radius:50px; height:10px; }
    .bar-fill { background:var(--green-l); border-radius:50px; height:100%; transition:width .6s; }

    /* Timeline activité */
    .timeline { list-style:none; padding:0; }
    .timeline li {
      padding:.5rem 0 .5rem 1.2rem; border-left:2px solid #e8f5e9;
      position:relative; font-size:.85rem; color:#555;
    }
    .timeline li::before {
      content:''; width:8px; height:8px; border-radius:50%;
      background:var(--green-l); position:absolute; left:-5px; top:.7rem;
    }
    .timeline .tl-date { font-size:.75rem; color:#aaa; margin-right:.5rem; }

    /* Badges */
    .badge {
      display:inline-block; padding:.15rem .6rem; border-radius:20px;
      font-size:.75rem; font-weight:700; margin:.1rem;
    }
    .badge-green  { background:#e8f5e9; color:#2e7d32; }
    .badge-blue   { background:#e3f2fd; color:#1565c0; }
    .badge-orange { background:#fff3e0; color:#e65100; }

    /* Note admin */
    .note-section textarea {
      width:100%; height:80px; border:1.5px solid #ddd; border-radius:8px;
      padding:.6rem; font-size:.88rem; resize:vertical;
    }
    .btn-save {
      background:var(--green); color:#fff; border:none; border-radius:6px;
      padding:.45rem 1.2rem; font-size:.85rem; cursor:pointer; margin-top:.5rem;
    }
    .btn-save:hover { background:#1b5e20; }
    .btn-del {
      background:none; border:1px solid #e53935; color:#e53935;
      border-radius:5px; padding:.35rem .8rem; font-size:.85rem;
      cursor:pointer; transition:background .15s;
    }
    .btn-del:hover { background:#e53935; color:#fff; }
    .msg-ok { color:#2e7d32; font-size:.85rem; margin-top:.4rem; display:none; }
  </style>
</head>
<body>

<header>
  <h1>🍉 Fiche joueur — <?= htmlspecialchars($u['nom'] ?: 'Inconnu') ?></h1>
  <a href="dashboard.php" class="btn-back">← Retour au dashboard</a>
</header>

<main>

  <div class="grid">

    <!-- PROFIL -->
    <div class="card">
      <h2>👤 Profil</h2>
      <div class="avatar">🧑‍🌾</div>
      <div class="player-name"><?= htmlspecialchars($u['nom'] ?: '—') ?></div>
      <div class="player-level" style="background:<?= $niveau[1] ?>22; color:<?= $niveau[1] ?>">
        <?= $niveau[0] ?>
      </div>
      <div class="info-row">
        <span class="info-label">ID</span>
        <span class="info-val">#<?= $u['id'] ?></span>
      </div>
      <div class="info-row">
        <span class="info-label">Réf</span>
        <span class="info-val" style="font-family:monospace"><?= htmlspecialchars($u['ref_id']) ?></span>
      </div>
      <div class="info-row">
        <span class="info-label">WhatsApp</span>
        <span class="info-val"><?= htmlspecialchars($u['whatsapp']) ?></span>
      </div>
      <div class="info-row">
        <span class="info-label">Email</span>
        <span class="info-val"><?= htmlspecialchars($u['email'] ?: '—') ?></span>
      </div>
      <div class="info-row">
        <span class="info-label">Pays</span>
        <span class="info-val"><?= htmlspecialchars($u['pays'] ?: '—') ?></span>
      </div>
      <div class="info-row">
        <span class="info-label">Source</span>
        <span class="info-val">
          <span class="badge badge-blue"><?= htmlspecialchars($source) ?></span>
        </span>
      </div>
      <div class="info-row">
        <span class="info-label">Inscrit le</span>
        <span class="info-val"><?= date('d/m/Y H:i', strtotime($u['date_inscription'])) ?></span>
      </div>
      <?php if ($u['referrer_ref_id']): ?>
      <div class="info-row">
        <span class="info-label">Parrainé par</span>
        <span class="info-val" style="font-family:monospace">
          <?= htmlspecialchars($u['referrer_ref_id']) ?>
        </span>
      </div>
      <?php endif; ?>
    </div>

    <!-- SCORES & ACTIVITÉ -->
    <div class="card">
      <h2>🎮 Activité de jeu</h2>
      <div class="stat-grid">
        <div class="stat-box">
          <div class="num"><?= number_format($score) ?></div>
          <div class="lbl">Points totaux</div>
        </div>
        <div class="stat-box">
          <div class="num"><?= number_format($recoltes) ?></div>
          <div class="lbl">Récoltes</div>
        </div>
        <div class="stat-box">
          <div class="num"><?= number_format($bonus) ?></div>
          <div class="lbl">Bonus AdMob</div>
        </div>
      </div>
      <div class="stat-grid">
        <div class="stat-box">
          <div class="num"><?= number_format($ptsParSemaine) ?></div>
          <div class="lbl">Pts/semaine moy.</div>
        </div>
        <div class="stat-box">
          <div class="num"><?= number_format($semaines, 1) ?></div>
          <div class="lbl">Semaines actives</div>
        </div>
        <div class="stat-box">
          <div class="num"><?= $updatedAt ? date('d/m', strtotime($updatedAt)) : '—' ?></div>
          <div class="lbl">Dernière activité</div>
        </div>
      </div>

      <!-- Badges activité -->
      <div style="margin-top:.8rem">
        <?php if ($score > 0):    ?><span class="badge badge-green">✅ A joué</span><?php endif; ?>
        <?php if ($recoltes >= 10): ?><span class="badge badge-green">🌾 10+ récoltes</span><?php endif; ?>
        <?php if ($bonus > 0):    ?><span class="badge badge-orange">📺 Pub vue</span><?php endif; ?>
        <?php if ($nbFilleuls > 0): ?><span class="badge badge-blue">🤝 Parrain actif</span><?php endif; ?>
        <?php if ($u['referrer_ref_id']): ?><span class="badge badge-blue">👥 Via parrainage</span><?php endif; ?>
        <?php if (strpos($source, 'google') !== false || strpos($source, 'ads') !== false): ?>
          <span class="badge badge-orange">📣 Google Ads</span>
        <?php endif; ?>
      </div>
    </div>

  </div>

  <!-- REVENUS ESTIMÉS -->
  <div class="card" style="margin-bottom:1.5rem">
    <h2>💰 Revenus estimés — Indicatif uniquement (FCFA / XAF)</h2>
    <div class="rev-grid" style="grid-template-columns:repeat(4,1fr)">
      <div class="rev-box gold">
        <div class="amount"><?= number_format($revPoints) ?> F</div>
        <div class="desc">AdMob estimé<br>(pts × 60 F/1 000 pts)</div>
      </div>
      <div class="rev-box blue">
        <div class="amount"><?= number_format($revParrainage) ?> F</div>
        <div class="desc">Parrainage estimé<br>(<?= $nbFilleulsActifs ?> filleul(s) × 30 F)</div>
      </div>
      <div class="rev-box green">
        <div class="amount"><?= number_format($revTotal) ?> F</div>
        <div class="desc">Total estimé cumulé</div>
      </div>
      <div class="rev-box purple">
        <div class="amount"><?= number_format($revParSemaine) ?> F/sem</div>
        <div class="desc">Estimation moyenne par semaine</div>
      </div>
    </div>
    <p style="font-size:.75rem;color:#aaa;margin-top:.8rem">
      ⚠️ Estimation indicative en FCFA (XAF). Les revenus réels dépendent du CPM Google AdMob,
      du pays, du taux de clics et des performances publicitaires. Aucun revenu n'est garanti.
      Taux appliqué : 1 USD = 600 FCFA.
    </p>
  </div>

  <div class="grid">

    <!-- PARRAINAGE -->
    <div class="card">
      <h2>🔗 Parrainage</h2>
      <p style="font-size:.85rem;color:#666;margin-bottom:.7rem">Lien personnel :</p>
      <div class="ref-link">https://agropast-game.online?ref=<?= htmlspecialchars($u['ref_id']) ?></div>

      <div class="filleuls-bar" style="margin-top:1.2rem">
        <div class="bar-label">
          <span>Filleuls inscrits</span>
          <strong><?= $nbFilleuls ?></strong>
        </div>
        <div class="bar-wrap">
          <div class="bar-fill" style="width:<?= min(100, $nbFilleuls * 10) ?>%"></div>
        </div>
      </div>
      <div class="filleuls-bar" style="margin-top:.8rem">
        <div class="bar-label">
          <span>Filleuls actifs (ont joué)</span>
          <strong><?= $nbFilleulsActifs ?></strong>
        </div>
        <div class="bar-wrap">
          <div class="bar-fill" style="width:<?= $nbFilleuls > 0 ? min(100, round($nbFilleulsActifs/$nbFilleuls*100)) : 0 ?>%; background:#f9a825"></div>
        </div>
      </div>

      <?php if ($nbFilleuls > 0):
        // Lister les filleuls
        $filleulsList = $pdo->prepare("
          SELECT l.nom, l.date_inscription, COALESCE(sc.score_total,0) AS score
          FROM `{$tLeads}` l
          LEFT JOIN `{$tScore}` sc ON sc.user_id = l.id
          WHERE l.referrer_ref_id = ?
          ORDER BY l.date_inscription DESC LIMIT 5
        ");
        try { $filleulsList->execute([$u['ref_id']]); $flist = $filleulsList->fetchAll(); }
        catch (PDOException $ig) { $flist = []; }
      ?>
      <table style="width:100%;font-size:.82rem;margin-top:1rem;border-collapse:collapse">
        <thead><tr style="color:#888">
          <th style="text-align:left;padding:.3rem 0">Filleul</th>
          <th style="text-align:right;padding:.3rem 0">Score</th>
          <th style="text-align:right;padding:.3rem 0">Inscrit</th>
        </tr></thead>
        <tbody>
        <?php foreach ($flist as $f): ?>
          <tr style="border-top:1px solid #f5f5f5">
            <td style="padding:.3rem 0"><?= htmlspecialchars($f['nom'] ?: '—') ?></td>
            <td style="text-align:right;color:var(--green);font-weight:700"><?= number_format($f['score']) ?></td>
            <td style="text-align:right;color:#aaa"><?= date('d/m/y', strtotime($f['date_inscription'])) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
      <?php endif; ?>
    </div>

    <!-- TIMELINE & NOTE ADMIN -->
    <div class="card">
      <h2>📋 Historique & Note admin</h2>
      <ul class="timeline">
        <li>
          <span class="tl-date"><?= date('d/m/Y H:i', strtotime($u['date_inscription'])) ?></span>
          Inscription (source : <?= htmlspecialchars($source) ?>)
        </li>
        <?php if ($scoreRow): ?>
        <li>
          <span class="tl-date"><?= date('d/m/Y H:i', strtotime($scoreRow['updated_at'])) ?></span>
          Dernière sync score — <?= number_format($score) ?> pts
        </li>
        <?php endif; ?>
        <?php if ($nbFilleuls > 0): ?>
        <li>
          <span class="tl-date">Parrainage</span>
          <?= $nbFilleuls ?> filleul(s) invité(s), <?= $nbFilleulsActifs ?> actif(s)
        </li>
        <?php endif; ?>
      </ul>

      <hr style="margin:1rem 0;border:none;border-top:1px solid #eee">

      <!-- Note admin -->
      <form method="POST" action="save_note.php" onsubmit="saveNote(event,<?= $id ?>)">
        <label style="font-size:.82rem;color:#666;display:block;margin-bottom:.3rem">
          📝 Note interne (visible uniquement par l'admin)
        </label>
        <textarea name="note" id="admin-note" placeholder="Ajouter une note sur ce joueur…"><?= htmlspecialchars($u['admin_note'] ?? '') ?></textarea>
        <button type="submit" class="btn-save">💾 Sauvegarder</button>
        <div class="msg-ok" id="note-ok">✅ Note sauvegardée</div>
      </form>

      <hr style="margin:1rem 0;border:none;border-top:1px solid #eee">

      <!-- Supprimer -->
      <form method="POST" action="dashboard.php"
            onsubmit="return confirm('Supprimer ce joueur ? Action irréversible.')">
        <input type="hidden" name="action_delete" value="1">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token'] ?? '') ?>">
        <input type="hidden" name="delete_id" value="<?= $id ?>">
        <button type="submit" class="btn-del">🗑 Supprimer ce joueur</button>
      </form>
    </div>

  </div>

</main>

<script>
async function saveNote(e, userId) {
  e.preventDefault();
  const note = document.getElementById('admin-note').value;
  const res  = await fetch('save_note.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'id=' + userId + '&note=' + encodeURIComponent(note)
         + '&csrf=<?= htmlspecialchars($_SESSION['csrf_token'] ?? '') ?>'
  });
  const ok = document.getElementById('note-ok');
  ok.style.display = 'block';
  setTimeout(() => ok.style.display = 'none', 2500);
}
</script>

</body>
</html>
