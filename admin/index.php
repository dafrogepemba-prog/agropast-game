<?php
// ============================================================
// admin/index.php — Page de login du dashboard
// Accès : https://agropast-game.online/admin/
// ============================================================
session_start();

// Si déjà connecté → rediriger vers dashboard
if (!empty($_SESSION['admin_logged_in'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user = trim($_POST['username'] ?? '');
    $pass = $_POST['password'] ?? '';

    // Identifiants admin (à changer en production)
    // Mot de passe stocké en hash bcrypt pour la sécurité
    $admin_user = 'admin';
    $admin_hash = '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'; // password: admin

    if ($user === $admin_user && password_verify($pass, $admin_hash)) {
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

      <button type="submit">🔐 Se connecter</button>
    </form>
  </div>
</body>
</html>
