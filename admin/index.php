<?php
// ============================================================
// admin/index.php — Page de login du dashboard
// Accès : https://agropast-game.online/admin/
// Identifiants lus depuis l'environnement (injectés par le CI
// depuis les GitHub Secrets ADMIN_USERNAME / ADMIN_PASSWORD).
// ============================================================
session_start();

// Charge les secrets injectés par le CI au déploiement (putenv), le
// même mécanisme que celui déjà utilisé par dashboard.php et withdrawals.php.
// Sans ça, getenv() ne voit jamais ADMIN_USERNAME/ADMIN_PASSWORD : le
// SetEnv d'Apache seul n'est pas fiable avec PHP-FPM/CGI sur cet hébergement.
$serverConfig = dirname(__DIR__) . '/api/server_config.php';
if (file_exists($serverConfig)) {
    require_once $serverConfig;
}

// Si déjà connecté → rediriger vers dashboard
if (!empty($_SESSION['admin_logged_in'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';

// Identifiants admin — lus depuis l'environnement, avec repli
// de secours uniquement pour le développement local (jamais utilisé
// en production tant que ADMIN_USERNAME/ADMIN_PASSWORD sont définis).
$admin_user     = getenv('ADMIN_USERNAME') ?: 'admin';
$admin_password = getenv('ADMIN_PASSWORD') ?: null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user = trim($_POST['username'] ?? '');
    $pass = $_POST['password'] ?? '';

    if ($admin_password === null) {
        // Sécurité : si aucun mot de passe n'est configuré côté serveur,
        // on refuse toute connexion plutôt que d'accepter n'importe quoi.
        $error = 'Configuration serveur incomplète. Contacte l\'administrateur.';
        error_log('admin/index.php: ADMIN_PASSWORD non defini dans l\'environnement');
    } elseif ($user === $admin_user && hash_equals($admin_password, $pass)) {
        session_regenerate_id(true);
        $_SESSION['admin_logged_in'] = true;
        $_SESSION['admin_user']      = $user;
        header('Location: dashboard.php');
        exit;
    } else {
        $error = 'Identifiants incorrects.';
        // Pause anti-brute-force
        sleep(1);
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Admin — AgroPast-Game</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      background: linear-gradient(135deg, #1b2a1b 0%, #1a4620 100%);
      display: flex; align-items: center; justify-content: center;
      font-family: 'Segoe UI', Arial, sans-serif;
      padding: 1.5rem;
    }
    .card {
      background: #fff;
      border-radius: 14px;
      padding: 2.5rem 2rem;
      width: 100%; max-width: 380px;
      box-shadow: 0 8px 32px rgba(0,0,0,.25);
      text-align: center;
    }
    .logo { font-size: 2.5rem; margin-bottom: .5rem; }
    h1 { font-size: 1.4rem; color: #2e7d32; margin-bottom: .25rem; }
    .sub { font-size: .85rem; color: #888; margin-bottom: 1.8rem; }
    .error {
      background: #ffebee; color: #c62828;
      border-radius: 8px; padding: .6rem 1rem;
      font-size: .9rem; margin-bottom: 1rem;
    }
    label { display: block; text-align: left; font-size: .85rem; font-weight: 600; color: #444; margin-bottom: .3rem; }
    input {
      width: 100%; padding: .7rem 1rem;
      border: 1.5px solid #ddd; border-radius: 8px;
      font-size: 1rem; margin-bottom: 1rem;
      transition: border-color .2s;
    }
    input:focus { outline: none; border-color: #2e7d32; }
    button {
      width: 100%; padding: .85rem;
      background: #2e7d32; color: #fff;
      border: none; border-radius: 8px;
      font-size: 1rem; font-weight: 700;
      cursor: pointer; transition: background .2s;
    }
    button:hover { background: #1b5e20; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">🍉</div>
    <h1>AgroPast-Game</h1>
    <p class="sub">Dashboard Administrateur</p>

    <?php if ($error): ?>
      <div class="error" role="alert"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="POST" action="">
      <label for="username">Identifiant</label>
      <input type="text" id="username" name="username" required autocomplete="username"
             value="<?= htmlspecialchars($_POST['username'] ?? '') ?>" />

      <label for="password">Mot de passe</label>
      <input type="password" id="password" name="password" required autocomplete="current-password" />

      <button type="submit">🔓 Se connecter</button>
    </form>
  </div>
</body>
</html>
