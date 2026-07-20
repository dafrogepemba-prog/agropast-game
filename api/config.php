<?php
// ============================================================
// CONFIG BASE DE DONNÉES — LWS Mutualisé (epsylon-cg.com)
// Ce fichier ne contient aucune valeur en dur.
// Il lit tous les credentials depuis getenv() / server_config.php
// généré par le pipeline CI à partir des GitHub Secrets.
// Déployé automatiquement par CI via FTP.
// ============================================================

// Load DB credentials from environment variables. In production, set
// `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` in the server environment
// (or via .htaccess SetEnv / host control panel).

// If the CI wrote a server_config.php during deployment, include it so
// it can populate environment variables (putenv/$_ENV) or provide fallbacks.
if (file_exists(__DIR__ . '/server_config.php')) {
        require_once __DIR__ . '/server_config.php';
}

// Environment and secret handling
// APP_ENV: use 'local' during development to allow safe fallbacks.
if (!defined('APP_ENV')) define('APP_ENV', getenv('APP_ENV') ?: 'production');

function require_env_or_fail(array $vars): array {
    $values = [];
    $missing = [];
    foreach ($vars as $var) {
        $value = getenv($var);
        if ($value === false || $value === null || $value === '') {
            $missing[] = $var;
        } else {
            $values[$var] = $value;
        }
    }

    if (!empty($missing)) {
        if (defined('APP_ENV') && APP_ENV === 'local') {
            return $values;
        }

        $missingList = implode(', ', $missing);
        error_log('ERROR: Missing environment variables in production: ' . $missingList . '. Aborting request.');
        if (php_sapi_name() !== 'cli') {
            http_response_code(500);
            header('Content-Type: application/json; charset=utf-8');
            echo json_encode(['success' => false, 'error' => 'Server misconfiguration: missing environment variables', 'missing' => $missing]);
        }
        exit(1);
    }

    return $values;
}

$env = require_env_or_fail(['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASS', 'APP_SECRET_KEY']);

define('DB_HOST',   $env['DB_HOST'] ?? '127.0.0.1');
define('DB_NAME',   $env['DB_NAME'] ?? 'agropast_dev');
define('DB_USER',   $env['DB_USER'] ?? 'root');
define('DB_PASS',   $env['DB_PASS'] ?? '');
if (!defined('APP_SECRET_KEY') && isset($env['APP_SECRET_KEY'])) define('APP_SECRET_KEY', $env['APP_SECRET_KEY']);

// APP_SECRET_KEY / SECRET_KEY handling
if (!defined('APP_SECRET_KEY')) {
        if (APP_ENV === 'local') {
                // Development fallback only
                define('APP_SECRET_KEY', 'valeur_par_defaut_dev_uniquement');
        } else {
                error_log('ERROR: Missing APP_SECRET_KEY environment variable in production. Aborting request.');
                if (php_sapi_name() !== 'cli') {
                        http_response_code(500);
                        header('Content-Type: application/json; charset=utf-8');
                        echo json_encode(['success' => false, 'error' => 'Server misconfiguration: missing APP_SECRET_KEY']);
                }
                exit(1);
        }
}

if (!defined('SECRET_KEY')) define('SECRET_KEY', APP_SECRET_KEY);

// Identifiants Brevo (SMTP transactionnel) — optionnels, l'envoi d'email
// est simplement désactivé si absents (pas d'erreur bloquante).
if (!defined('BREVO_SMTP_LOGIN')) define('BREVO_SMTP_LOGIN', getenv('BREVO_SMTP_LOGIN') ?: '');
if (!defined('BREVO_SMTP_KEY'))   define('BREVO_SMTP_KEY',   getenv('BREVO_SMTP_KEY')   ?: '');

// Préfixe obligatoire : base partagée avec epsylon-cg.com
// Toutes les tables AgroPast-Game commencent par apg_
define('DB_PREFIX', 'apg_');

// Origines autorisées (conservé pour référence future)
// define('ALLOWED_ORIGINS', ['https://agropast-game.online']);
