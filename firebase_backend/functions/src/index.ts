/**
 * index.ts — Cloud Functions AgroPastGame
 *
 * Point d'entrée unique pour le déploiement Firebase Functions.
 *
 * Modules exportés :
 *   processAction          — Ledger Zero-Trust (Callable)
 *   weeklyLeaderboardReset — Classement hebdomadaire + reset bio_points (Scheduled)
 */

import { initializeApp } from "firebase-admin/app";

// Initialisation unique du SDK Admin (à faire avant tout import de module)
initializeApp();

// ── Exports ────────────────────────────────────────────────

// Ledger : toutes les mutations de devises virtuelles passent par ici
export { processAction } from "./ledger";

// Classement hebdomadaire : CRON dimanche 23h59 WAT
export { weeklyLeaderboardReset } from "./leaderboard";
