/**
 * auth.ts — Pré-filtrage OTP : validation numéros Congo-Brazzaville (+242)
 *
 * Opérateurs acceptés :
 *   MTN Congo  : +24206XXXXXXX, +24205XXXXXXX
 *   Airtel Congo: +24204XXXXXXX, +24207XXXXXXX
 *
 * Format attendu en entrée : chaîne avec ou sans le + initial,
 * espaces et tirets ignorés.
 */

/** Préfixes valides après l'indicatif +242 (5 premiers chiffres après 242). */
const VALID_CONGO_PREFIXES = ["06", "05", "04", "07"] as const;

/** Longueur totale attendue : +242 (3) + opérateur (2) + abonné (7) = 12 chiffres */
const CONGO_PHONE_LENGTH = 12;

export interface PhoneValidationResult {
  valid: boolean;
  normalised?: string; // Format E.164 : +242XXXXXXXXX
  operator?: "MTN" | "Airtel";
  error?: string;
}

/**
 * Valide et normalise un numéro de téléphone Congo-Brazzaville.
 * À appeler AVANT tout envoi d'OTP Firebase pour éviter les frais inutiles.
 *
 * @example
 *   validateCongoPhone("+242 06 123 45 67") → { valid: true, normalised: "+24206 1234567", operator: "MTN" }
 *   validateCongoPhone("+33612345678")       → { valid: false, error: "Indicatif non pris en charge (+242 uniquement)" }
 */
export function validateCongoPhone(raw: string): PhoneValidationResult {
  // 1. Nettoyer : retirer espaces, tirets, parenthèses
  const cleaned = raw.replace(/[\s\-().]/g, "");

  // 2. Normaliser le + initial
  let digits: string;
  if (cleaned.startsWith("+")) {
    digits = cleaned.slice(1); // retirer le +
  } else if (cleaned.startsWith("00")) {
    digits = cleaned.slice(2); // 00242... → 242...
  } else {
    digits = cleaned;
  }

  // 3. Vérifier que c'est entièrement numérique
  if (!/^\d+$/.test(digits)) {
    return { valid: false, error: "Le numéro contient des caractères invalides." };
  }

  // 4. Vérifier l'indicatif +242
  if (!digits.startsWith("242")) {
    return {
      valid: false,
      error: `Indicatif non pris en charge. Seuls les numéros congolais (+242) sont acceptés.`,
    };
  }

  // 5. Vérifier la longueur totale (242 + 9 chiffres = 12)
  if (digits.length !== CONGO_PHONE_LENGTH) {
    return {
      valid: false,
      error: `Longueur invalide (${digits.length} chiffres, attendu ${CONGO_PHONE_LENGTH}).`,
    };
  }

  // 6. Extraire le préfixe opérateur (2 chiffres après 242)
  const prefix = digits.slice(3, 5); // ex: "06" pour +24206XXXXXXX

  if (!(VALID_CONGO_PREFIXES as readonly string[]).includes(prefix)) {
    return {
      valid: false,
      error: `Préfixe opérateur invalide (${prefix}). Acceptés : MTN (05, 06) et Airtel (04, 07).`,
    };
  }

  const operator: "MTN" | "Airtel" = ["05", "06"].includes(prefix) ? "MTN" : "Airtel";
  const normalised = `+${digits}`;

  return { valid: true, normalised, operator };
}

/**
 * Version strict pour utilisation dans Cloud Functions :
 * lève une HttpsError si le numéro est invalide.
 */
import { HttpsError } from "firebase-functions/v2/https";

export function assertValidCongoPhone(raw: string): string {
  const result = validateCongoPhone(raw);
  if (!result.valid || !result.normalised) {
    throw new HttpsError(
      "invalid-argument",
      result.error ?? "Numéro de téléphone invalide.",
    );
  }
  return result.normalised;
}
