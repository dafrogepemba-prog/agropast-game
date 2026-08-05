/**
 * leaderboard.ts — Classement hebdomadaire & réinitialisation bio_points
 *
 * Scheduled Function (CRON) : chaque dimanche à 23h59 WAT (Africa/Brazzaville)
 *
 * Pipeline d'exécution :
 *   1. Lire tous les users triés par bio_points DESC
 *   2. Snapshot Top 20 → leaderboards/{weekId}
 *   3. Réinitialiser bio_points de TOUS les users → 0 (Batch Writes Firestore)
 *
 * Contraintes Firestore :
 *   - Un Batch Write est limité à 500 opérations → pagination automatique.
 *   - La lecture du classement et la réinit sont deux phases séquentielles
 *     (pas atomiques entre elles) : le snapshot est écrit en premier pour
 *     garantir qu'on ne perd pas le classement en cas d'erreur sur la réinit.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

const db = getFirestore();

/** Taille maximale d'un Batch Write Firestore */
const BATCH_LIMIT = 499;

/** Nombre d'entrées dans le classement hebdomadaire */
const TOP_N = 20;

// ── Helpers ────────────────────────────────────────────────

/**
 * Calcule l'identifiant ISO de la semaine courante.
 * Format : "week_YYYY_WNN" (ex: "week_2026_W32")
 */
function getWeekId(date: Date): string {
  // Algorithme ISO 8601 : semaine 1 = semaine contenant le premier jeudi
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() === 0 ? 7 : d.getUTCDay(); // lundi=1 … dimanche=7
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNum = Math.ceil(
    ((d.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7,
  );
  const year = d.getUTCFullYear();
  return `week_${year}_W${String(weekNum).padStart(2, "0")}`;
}

// ── Cloud Function ─────────────────────────────────────────

export const weeklyLeaderboardReset = onSchedule(
  {
    // Dimanche 23h59 WAT = dimanche 22h59 UTC (WAT = UTC+1)
    schedule:  "59 22 * * 0",
    timeZone:  "Africa/Brazzaville",
    region:    "europe-west1",
    memory:    "512MiB",
    timeoutSeconds: 540, // 9 min — laisse le temps pour de gros volumes
  },
  async () => {
    const now    = new Date();
    const weekId = getWeekId(now);

    logger.info(`[weeklyLeaderboardReset] Démarrage — semaine : ${weekId}`);

    // ── Phase 1 : Snapshot Top 20 bio_points ──────────────
    await _snapshotTopN(weekId, now);

    // ── Phase 2 : Réinitialiser bio_points de tous les users
    await _resetAllBioPoints();

    logger.info(`[weeklyLeaderboardReset] Terminé — semaine : ${weekId}`);
  },
);

// ── Phase 1 : Snapshot ────────────────────────────────────

async function _snapshotTopN(weekId: string, now: Date): Promise<void> {
  const usersSnap = await db
    .collection("users")
    .orderBy("balances.bio_points", "desc")
    .limit(TOP_N)
    .get();

  if (usersSnap.empty) {
    logger.warn("[weeklyLeaderboardReset] Aucun utilisateur trouvé pour le classement.");
    return;
  }

  const entries = usersSnap.docs.map((doc, index) => {
    const data = doc.data();
    return {
      rank:        index + 1,
      userId:      doc.id,
      displayName: (data.profile?.displayName as string | null) ?? "Fermier",
      country:     (data.profile?.country as string | null) ?? "CG",
      bio_points:  (data.balances?.bio_points as number) ?? 0,
      // Lien legacy optionnel pour jointure côté MySQL
      legacy_mysql_id: (data.legacy_mysql_id as string | null) ?? null,
    };
  });

  const leaderboardRef = db.doc(`leaderboards/${weekId}`);
  await leaderboardRef.set({
    weekId,
    generatedAt: Timestamp.fromDate(now),
    entries,
    totalParticipants: usersSnap.size,
    immutable: true, // signal logique — les règles Firestore bloquent déjà l'écriture client
  });

  logger.info(
    `[weeklyLeaderboardReset] Snapshot écrit : leaderboards/${weekId} (${entries.length} entrées)`,
  );
}

// ── Phase 2 : Réinitialisation bio_points ─────────────────

async function _resetAllBioPoints(): Promise<void> {
  // Pagination : on lit par tranches pour éviter de tout charger en mémoire
  let totalReset  = 0;
  let lastDoc     = null as FirebaseFirestore.DocumentSnapshot | null;
  let batchCount  = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query = db.collection("users").limit(BATCH_LIMIT);
    if (lastDoc) query = query.startAfter(lastDoc) as typeof query;

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();

    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        "balances.bio_points": 0,
        "updatedAt":           FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    totalReset += snap.size;
    batchCount++;
    lastDoc = snap.docs[snap.docs.length - 1];

    logger.debug(
      `[weeklyLeaderboardReset] Batch ${batchCount} validé — ${snap.size} users réinitialisés`,
    );

    // Si le lot était inférieur à la limite, on a atteint la fin
    if (snap.size < BATCH_LIMIT) break;
  }

  logger.info(
    `[weeklyLeaderboardReset] bio_points réinitialisés : ${totalReset} utilisateurs (${batchCount} batch(es))`,
  );
}
