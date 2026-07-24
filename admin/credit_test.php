<?php
// ============================================================
// admin/credit_test.php — Crédit manuel pour compte de TEST
//
// Remplace diag_boost.php (script public, sans authentification,
// qui permettait d'injecter n'importe quel score directement).
//
// Différences essentielles :
//  - Accessible UNIQUEMENT avec une session admin authentifiée
//    (même garde que dashboard.php)
//  - Protégé par token CSRF
//  - Chaque crédit est journalisé (qui, quand, combien, compte
//    ciblé, raison) dans une table d'audit dédiée — rien n'est
//    invisible ou "silencieux"
//  - N'écrase jamais le score : ajoute un événement, comme le
//    ferait une vraie action de jeu, via la même table
//    d'audit `score_events` que sync_score.php
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

$tLeads  = DB_PREFIX . 'leads';
$tScore  = DB_PREFIX . 'scores';
$tEvents = DB_PREFIX . 'score_events';
$tAudit  = DB_PREFIX . 'admin_credit_log';

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tAudit}` (
        `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `admin_user`  VARCHAR(100) NOT NULL,
        `target_user_id` INT UNSIGNED NOT NULL,
        `points`      INT NOT NULL,
        `reason`      VARCHAR(255) DEFAULT '',
        `ip`          VARCHAR(45)  DEFAULT '',
        `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
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
        $targetUserId = (int)($_POST['user_id'] ?? 0);
        $points       = (int)($_POST['points']  ?? 0);
        $reason       = trim(substr($_POST['reason'] ?? '', 0, 255));

        if ($targetUserId <= 0) {
            $error = 'Compte cible invalide.';
        } elseif ($points <= 0 || $points > 100000) {
            $error = 'Le montant doit être entre 1 et 100 000 points (crédit de test).';
        } elseif ($reason === '') {
            $error = 'Merci d\'indiquer une raison (ex : "test circuit retrait").';
        } else {
            $userRow = $pdo->prepare("SELECT id, whatsapp, nom FROM `{$tLeads}` WHERE id=?");
            $userRow->execute([$targetUserId]);
            $target = $userRow->fetch();

            if (!$target) {
                $error = 'Compte introuvable.';
            } else {
                // IMPORTANT : les CREATE TABLE doivent être exécutés AVANT
                // beginTransaction(). En MySQL/InnoDB, tout DDL déclenche un
                // commit implicite qui clôture silencieusement la transaction
                // en cours — un rollBack() ultérieur échoue alors avec
                // "There is no active transaction" et masque l'erreur réelle.
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS `{$tEvents}` (
                        `id`                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                        `user_id`             INT UNSIGNED NOT NULL,
                        `event_type`          VARCHAR(30)  NOT NULL,
                        `points_awarded`      INT NOT NULL,
                        `client_score_report` INT UNSIGNED DEFAULT 0,
                        `ip`                  VARCHAR(45)  DEFAULT '',
                        `created_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        INDEX `idx_user_time` (`user_id`, `created_at`),
                        INDEX `idx_user_type_time` (`user_id`, `event_type`, `created_at`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                ");

                $pdo->beginTransaction();
                try {
                    // Log d'audit : traçabilité complète de l'action admin
                    $stmt = $pdo->prepare("
                        INSERT INTO `{$tAudit}` (admin_user, target_user_id, points, reason, ip)
                        VALUES (:admin, :uid, :pts, :reason, :ip)
                    ");
                    $stmt->execute([
                        ':admin'  => $_SESSION['admin_user'] ?? 'inconnu',
                        ':uid'    => $targetUserId,
                        ':pts'    => $points,
                        ':reason' => $reason,
                        ':ip'     => $_SERVER['REMOTE_ADDR'] ?? '',
                    ]);

                    // Même table d'audit que le circuit de jeu normal,
                    // avec un event_type distinct pour rester traçable
                    $stmt = $pdo->prepare("
                        INSERT INTO `{$tEvents}` (user_id, event_type, points_awarded, client_score_report, ip)
                        VALUES (:uid, 'admin_credit_test', :pts, 0, :ip)
                    ");
                    $stmt->execute([
                        ':uid' => $targetUserId,
                        ':pts' => $points,
                        ':ip'  => $_SERVER['REMOTE_ADDR'] ?? '',
                    ]);

                    $stmt = $pdo->prepare("
                        INSERT INTO `{$tScore}` (user_id, whatsapp, score_total, nombre_recoltes, event_type, bonus_total)
                        VALUES (:uid, :wa, :pts, 0, 'admin_credit_test', 0)
                        ON DUPLICATE KEY UPDATE score_total = score_total + :pts2
                    ");
                    $stmt->execute([
                        ':uid'  => $targetUserId,
                        ':wa'   => $target['whatsapp'],
                        ':pts'  => $points,
                        ':pts2' => $points,
                    ]);

                    $pdo->commit();
                    $message = "Crédit de {$points} pts appliqué à {$target['nom']} ({$target['whatsapp']}). Journalisé.";
                } catch (Exception $e) {
                    if ($pdo->inTransaction()) {
                        $pdo->rollBack();
                    }
                    $error = 'Erreur lors du crédit : ' . $e->getMessage();
                }
            }
        }
    }
}

// Historique récent des crédits de test (transparence)
$history = $pdo->query("
    SELECT a.*, l.nom, l.whatsapp
    FROM `{$tAudit}` a
    LEFT JOIN `{$tLeads}` l ON l.id = a.target_user_id
    ORDER BY a.created_at DESC LIMIT 20
")->fetchAll();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Crédit compte de test — AgroPast Admin</title>
<meta name="robots" content="noindex, nofollow">
<style>
  body { font-family: system-ui, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 20px; background:#f4f6f5; }
  h1 { font-size: 1.3rem; }
  .warn { background:#fff3cd; border:1px solid #ffe08a; padding:12px 16px; border-radius:8px; margin-bottom:20px; font-size:0.9rem; }
  form { background:#fff; padding:20px; border-radius:10px; box-shadow:0 1px 3px rgba(0,0,0,.08); }
  label { display:block; margin:12px 0 4px; font-weight:600; font-size:0.9rem; }
  input[type=text], input[type=number] { width:100%; padding:8px 10px; border:1px solid #ccc; border-radius:6px; box-sizing:border-box; }
  button { margin-top:16px; background:#2f7a3f; color:#fff; border:0; padding:10px 18px; border-radius:6px; cursor:pointer; font-weight:600; }
  .msg-ok { color:#1a6b2e; background:#e6f6ea; padding:10px; border-radius:6px; margin-bottom:16px; }
  .msg-err { color:#8a1f1f; background:#fbe7e7; padding:10px; border-radius:6px; margin-bottom:16px; }
  table { width:100%; border-collapse:collapse; margin-top:24px; font-size:0.85rem; background:#fff; }
  th, td { text-align:left; padding:6px 8px; border-bottom:1px solid #eee; }
  a.back { display:inline-block; margin-bottom:16px; color:#2f7a3f; }
</style>
</head>
<body>
  <a class="back" href="dashboard.php">&larr; Retour au dashboard</a>
  <h1>🧪 Crédit manuel — compte de test</h1>
  <div class="warn">
    ⚠️ Réservé aux tests internes (ex : valider le circuit de retrait).
    Chaque crédit est journalisé avec ton identifiant admin, l'heure et la raison.
    N'utilise pas ceci pour créditer un vrai joueur.
  </div>

  <?php if ($message): ?><div class="msg-ok"><?= htmlspecialchars($message) ?></div><?php endif; ?>
  <?php if ($error): ?><div class="msg-err"><?= htmlspecialchars($error) ?></div><?php endif; ?>

  <form method="POST">
    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
    <label for="user_id">ID utilisateur (visible dans le dashboard leads)</label>
    <input type="number" id="user_id" name="user_id" required min="1">

    <label for="points">Points à créditer</label>
    <input type="number" id="points" name="points" required min="1" max="100000" value="2000">

    <label for="reason">Raison (obligatoire, apparaît dans le log)</label>
    <input type="text" id="reason" name="reason" required placeholder="ex: test circuit de retrait">

    <button type="submit">Créditer</button>
  </form>

  <h2 style="font-size:1rem;margin-top:28px;">Historique des crédits de test</h2>
  <table>
    <tr><th>Date</th><th>Admin</th><th>Compte</th><th>Points</th><th>Raison</th></tr>
    <?php foreach ($history as $h): ?>
    <tr>
      <td><?= htmlspecialchars($h['created_at']) ?></td>
      <td><?= htmlspecialchars($h['admin_user']) ?></td>
      <td><?= htmlspecialchars(($h['nom'] ?? '?') . ' / ' . ($h['whatsapp'] ?? '?')) ?></td>
      <td><?= (int)$h['points'] ?></td>
      <td><?= htmlspecialchars($h['reason']) ?></td>
    </tr>
    <?php endforeach; ?>
  </table>
</body>
</html>
