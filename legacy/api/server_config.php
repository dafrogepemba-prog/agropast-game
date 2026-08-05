<?php
// server_config.php — généré par CI, ne pas committer de valeurs réelles ici
// Dernière mise à jour forcée : 2026-07-12 (fix APP_SECRET_KEY manquant)
// Ce fichier est écrasé à chaque déploiement par deploy.yml
if (getenv("APP_SECRET_KEY") === false) {
    // putenv appelé par le CI avec la vraie valeur — placeholder ici
    putenv("APP_SECRET_KEY=placeholder_overwritten_by_ci");
}
