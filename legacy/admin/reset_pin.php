<?php
// ============================================================
// admin/reset_pin.php — Réinitialisation manuelle du PIN
//
// Le PIN est haché (bcrypt) en base, donc impossible à retrouver
// une fois perdu. Cet outil en génère un nouveau pour un compte
// donné, réservé à l'admin, avec le même niveau de protection et
// de journalisation que credit_test.php.
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
$tAudit = DB_PREFIX . 'admin_pin_reset_log';

$pdo->exec("
    CREATE TABLE IF NOT EXISTS `{$tAudit}` (
        `id`         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `admin_user` VARCHAR(100) NOT NULL,
        `target_user_id` INT UNSIGNED NOT NULL,
        `ip`         VARCHAR(45)  DEFAULT '',
        `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

function generatePin(): string {
    return str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
}

$message = '';
$error   = '';
$newPin  = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = $_POST['csrf_token'] ?? '';
    if (!hash_equals($_SESSION['csrf_token'], $csrf)) {
        $error = 'Session invalide, recharge la page et réessaie.';
    } else {
        $targetUserId = (int)($_POST['user_id'] ?? 0);
        if ($targetUserId <= 0) {
            $error = 'Compte cible invalide.';
        } else {
            $userRow = $pdo->prepare("SELECT id, whatsapp, nom FROM `{$tLeads}` WHERE id=?");
            $userRow->execute([$targetUserId]);
            $target = $userRow->fetch();

            if (!$target) {
                $error = 'Compte introuvable.';
            } else {
                $newPin  = generatePin();
                $pinHash = password_hash($newPin, PASSWORD_BCRYPT, ['cost' => 10]);

                $stmt = $pdo->prepare("UPDATE `{$tLeads}` SET pin_hash = ? WHERE id = ?");
                $stmt->execute([$pinHash, $targetUserId]);

                $stmt = $pdo->prepare("
                    INSERT INTO `{$tAudit}` (admin_user, target_user_id, ip)
                    VALUES (:admin, :uid, :ip)
                ");
                $stmt->execute([
                    ':admin' => $_SESSION['admin_user'] ?? 'inconnu',
                    ':uid'   => $targetUserId,
                    ':ip'    => $_SERVER['REMOTE_ADDR'] ?? '',
                ]);

                $message = "Nouveau PIN généré pour {$target['nom']} ({$target['whatsapp']}).";
            }
        }
    }
}

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
<title>Réinitialiser un PIN — AgroPast Admin</title>
<meta name="robots" content="noindex, nofollow">
<style>
  body { font-family: system-ui, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 20px; background:#f4f6f5; }
  h1 { font-size: 1.3rem; }
  .warn { background:#fff3cd; border:1px solid #ffe08a; padding:12px 16px; border-radius:8px; margin-bottom:20px; font-size:0.9rem; }
  form { background:#fff; padding:20px; border-radius:10px; box-shadow:0 1px 3px rgba(0,0,0,.08); }
  label { display:block; margin:12px 0 4px; font-weight:600; font-size:0.9rem; }
  input[type=number] { width:100%; padding:8px 10px; border:1px solid #ccc; border-radius:6px; box-sizing:border-box; }
  button { margin-top:16px; background:#2f7a3f; color:#fff; border:0; padding:10px 18px; border-radius:6px; cursor:pointer; font-weight:600; }
  .msg-ok { color:#1a6b2e; background:#e6f6ea; padding:14px; border-radius:6px; margin-bottom:16px; }
  .pin-display { font-size:1.6rem; font-weight:800; letter-spacing:4px; color:#1a6b2e; }
  .msg-err { color:#8a1f1f; background:#fbe7e7; padding:10px; border-radius:6px; margin-bottom:16px; }
  table { width:100%; border-collapse:collapse; margin-top:24px; font-size:0.85rem; background:#fff; }
  th, td { text-align:left; padding:6px 8px; border-bottom:1px solid #eee; }
  a.back { display:inline-block; margin-bottom:16px; color:#2f7a3f; }
</style>
</head>
<body>
  <a class="back" href="dashboard.php">&larr; Retour au dashboard</a>
  <h1>🔑 Réinitialiser le PIN d'un compte</h1>
  <div class="warn">
    ⚠️ Le PIN précédent devient immédiatement invalide. Transmets le nouveau PIN au joueur de façon sécurisée (pas par un canal public).
  </div>

  <?php if ($message): ?>
    <div class="msg-ok">
      <?= htmlspecialchars($message) ?><br>
      Nouveau PIN : <span class="pin-display"><?= htmlspecialchars($newPin) ?></span>
    </div>
  <?php endif; ?>
  <?php if ($error): ?><div class="msg-err"><?= htmlspecialchars($error) ?></div><?php endif; ?>

  <form method="POST">
    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
    <label for="user_id">ID utilisateur (visible dans le dashboard leads)</label>
    <input type="number" id="user_id" name="user_id" required min="1">
    <button type="submit">Générer un nouveau PIN</button>
  </form>

  <h2 style="font-size:1rem;margin-top:28px;">Historique des réinitialisations</h2>
  <table>
    <tr><th>Date</th><th>Admin</th><th>Compte</th></tr>
    <?php foreach ($history as $h): ?>
    <tr>
      <td><?= htmlspecialchars($h['created_at']) ?></td>
      <td><?= htmlspecialchars($h['admin_user']) ?></td>
      <td><?= htmlspecialchars(($h['nom'] ?? '?') . ' / ' . ($h['whatsapp'] ?? '?')) ?></td>
    </tr>
    <?php endforeach; ?>
  </table>
</body>
</html>
