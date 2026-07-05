<?php
// FICHIER TEMPORAIRE — À SUPPRIMER APRÈS USAGE
// Accéder à https://agropast-game.online/admin/genhash.php
// Copier le hash, l'insérer dans index.php, puis supprimer ce fichier

$pass = 'AgroPast@2025!';
$hash = password_hash($pass, PASSWORD_BCRYPT, ['cost' => 12]);
echo '<pre>';
echo 'Mot de passe : ' . htmlspecialchars($pass) . "\n";
echo 'Hash bcrypt  : ' . $hash . "\n";
echo 'Vérification : ' . (password_verify($pass, $hash) ? 'OK ✅' : 'ERREUR ❌');
echo '</pre>';
