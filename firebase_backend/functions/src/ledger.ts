/**
 * ledger.ts — Cloud Function Callable : processAction
 *
 * Zero-Trust Ledger pour AgroPastGame.
 * Toutes les mutations de devises virtuelles passent par cette fonction.
 *
 * Devises gérées :
 *   coins       — économie interne de la ferme
 *   bio_points  — points de fidélité / classement hebdomadaire
 *
 * Chaque opération crée un enregistrement immuable dans :
 *   - users/{userId}/transactions  (historique personnel)
 *   - ledger_global                (audit global)
 *
 * Note : initializeApp() est appelé une seule fois dans index.ts.
 */

import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db = getFirestore();

// ── Types ──────────────────────────────────────────────────

type Currency = "coins" | "bio_points";

type ActionType =
  | "gain_reward"     // récompense pub / culture récoltée
  | "buy_item"        // achat dans la boutique
  | "sell_item"       // vente d'un item
  | "admin_credit"    // crédit manuel par un admin
  | "admin_debit"     // débit manuel par un admin
  | "weekly_bonus"    // bonus classement hebdomadaire
  | "referral_bonus"; // bonus parrainage

interface ProcessActionRequest {
  action:    ActionType;
  currency:  Currency;
  amount:    number;
  metadata?: Record<string, unknown>; // contexte optionnel (itemId, etc.)
}

interface ProcessActionResponse {
  success:    boolean;
  newBalance: number;
  txId:       string;
}

// ── Constantes ─────────────────────────────────────────────

/** Montant maximum par opération (anti-triche) */
const MAX_AMOUNT_PER_TX: Record<Currency, number> = {
  coins:      100_000,
  bio_points: 10_000,
};

/** Actions qui débitent le solde */
const DEBIT_ACTIONS: ActionType[] = ["buy_item", "admin_debit"];

// ── Cloud Function ─────────────────────────────────────────

export const processAction = onCall<
  ProcessActionRequest,
  Promise<ProcessActionResponse>
>(
  {
    region:          "europe-west1",
    enforceAppCheck: false, // passer à true en prod avec App Check activé
    maxInstances:    10,
  },
  async (callRequest) => {
    // 1. Vérifier l'authentification
    if (!callRequest.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }

    const userId = callRequest.auth.uid;
    const { action, currency, amount, metadata = {} } = callRequest.data;

    // 2. Valider les paramètres entrants
    _validateRequest(action, currency, amount);

    const isDebit = DEBIT_ACTIONS.includes(action);
    const delta   = isDebit ? -Math.abs(amount) : Math.abs(amount);

    // 3. Références Firestore
    const userRef   = db.doc(`users/${userId}`);
    const txRef     = userRef.collection("transactions").doc();
    const ledgerRef = db.collection("ledger_global").doc();

    // 4. Transaction atomique
    const newBalance = await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);

      const userData      = userSnap.exists ? userSnap.data()! : _defaultUserData(userId);
      const currentBalance: number = (userData.balances?.[currency] as number) ?? 0;
      const computed = currentBalance + delta;

      // 5. Refuser si solde insuffisant (débit)
      if (computed < 0) {
        throw new HttpsError(
          "failed-precondition",
          `Solde ${currency} insuffisant. Actuel : ${currentBalance}, requis : ${Math.abs(amount)}.`,
        );
      }

      const now         = Timestamp.now();
      const balancePath = `balances.${currency}`;

      // 6a. Transaction immuable (historique utilisateur)
      tx.set(txRef, {
        userId,
        action,
        currency,
        amount:        delta,
        balanceBefore: currentBalance,
        balanceAfter:  computed,
        metadata,
        createdAt:     now,
        immutable:     true,
      });

      // 6b. Grand livre global
      tx.set(ledgerRef, {
        userId,
        action,
        currency,
        amount:    delta,
        txId:      txRef.id,
        createdAt: now,
        immutable: true,
      });

      // 6c. Mise à jour du solde utilisateur
      if (userSnap.exists) {
        tx.update(userRef, {
          [balancePath]: computed,
          updatedAt:     FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(userRef, {
          ...userData,
          balances: {
            coins:      currency === "coins"      ? computed : 0,
            bio_points: currency === "bio_points" ? computed : 0,
          },
          createdAt:  now,
          updatedAt:  FieldValue.serverTimestamp(),
        });
      }

      return computed;
    });

    logger.info("processAction OK", {
      userId, action, currency, amount: delta, newBalance, txId: txRef.id,
    });

    return { success: true, newBalance, txId: txRef.id };
  },
);

// ── Helpers ────────────────────────────────────────────────

function _validateRequest(action: string, currency: string, amount: number): void {
  const validActions: ActionType[] = [
    "gain_reward", "buy_item", "sell_item",
    "admin_credit", "admin_debit", "weekly_bonus", "referral_bonus",
  ];
  const validCurrencies: Currency[] = ["coins", "bio_points"];

  if (!validActions.includes(action as ActionType)) {
    throw new HttpsError("invalid-argument", `Action inconnue : ${action}.`);
  }
  if (!validCurrencies.includes(currency as Currency)) {
    throw new HttpsError(
      "invalid-argument",
      `Devise inconnue : ${currency}. Utiliser 'coins' ou 'bio_points'.`,
    );
  }
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Le montant doit être un nombre positif fini.");
  }
  const max = MAX_AMOUNT_PER_TX[currency as Currency];
  if (amount > max) {
    throw new HttpsError(
      "invalid-argument",
      `Montant trop élevé (${amount} > max autorisé ${max} pour ${currency}).`,
    );
  }
}

function _defaultUserData(userId: string) {
  return {
    uid:             userId,
    legacy_mysql_id: null, // lien optionnel vers apg_leads.id (migration MySQL)
    balances: {
      coins:      0,
      bio_points: 0,
    },
    profile: {
      displayName: null,
      phone:       null,
      country:     "CG",
    },
  };
}
