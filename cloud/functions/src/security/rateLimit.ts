/**
 * Rate Limiting (Token Bucket Algorithm)
 *
 * Implements a token bucket rate limiter using Firestore to prevent abuse
 * and ensure fair usage of AI API quotas.
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { RATE_LIMIT_CONFIG } from "../config/models";
import { logger } from "../utils/logger";

/**
 * Initialize Firebase Admin (for Firestore access)
 */
const firestore = admin.firestore();

/**
 * Rate limit entry in Firestore
 */
interface RateLimitEntry {
  tokens: number;
  lastRefill: number; // Unix timestamp
}

/**
 * Check rate limit using token bucket algorithm
 *
 * @param userId - The user's Firebase Auth UID
 * @param action - The action being performed (e.g., "translate", "tts")
 * @param cost - The token cost for this action
 * @throws HttpsError if rate limit is exceeded
 */
export async function checkRateLimit(
  userId: string,
  action: string,
  cost: number
): Promise<void> {
  const docId = `${userId}_${action}`;
  const docRef = firestore.collection("rateLimits").doc(docId);

  const now = Date.now();
  const { bucketSize, refillRate } = RATE_LIMIT_CONFIG;

  try {
    await firestore.runTransaction(async (transaction) => {
      const doc = await transaction.get(docRef);

      let tokens: number;
      let lastRefill: number;

      if (doc.exists) {
        // Existing entry: refill tokens based on time elapsed
        const data = doc.data() as RateLimitEntry;
        tokens = data.tokens;
        lastRefill = data.lastRefill;

        // Calculate tokens to add based on elapsed time
        const elapsedMinutes = (now - lastRefill) / 60_000;
        const tokensToAdd = elapsedMinutes * refillRate;

        // Refill up to bucket size
        tokens = Math.min(bucketSize, tokens + tokensToAdd);
      } else {
        // New entry: start with full bucket
        tokens = bucketSize;
        lastRefill = now;
      }

      // Check if enough tokens
      if (tokens < cost) {
        // Calculate retry after time (when enough tokens will be available)
        const tokensNeeded = cost - tokens;
        const retryAfter = Math.ceil(tokensNeeded / refillRate * 60); // seconds

        logger.warning(`Rate limit exceeded for user ${userId}, action ${action}`, {
          tokensAvailable: tokens,
          tokensRequired: cost,
          retryAfter,
        });

        throw new functions.https.HttpsError(
          "resource-exhausted",
          `Rate limit exceeded. Try again in ${retryAfter} seconds.`,
          { retryAfter }
        );
      }

      // Consume tokens
      tokens -= cost;

      // Update Firestore
      transaction.set(docRef, {
        tokens,
        lastRefill: now,
      });

      logger.debug(`Rate limit check passed for user ${userId}, action ${action}`, {
        tokensRemaining: tokens,
        tokensConsumed: cost,
      });
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error; // Re-throw HttpsError
    }

    // Log unexpected errors
    logger.error(`Rate limit check failed for user ${userId}, action ${action}`, error);
    // Allow request to proceed if rate limiting fails (fail-open)
  }
}

/**
 * Get current rate limit status for a user
 *
 * @param userId - The user's Firebase Auth UID
 * @param action - The action to check
 * @returns Current token count and refill time
 */
export async function getRateLimitStatus(
  userId: string,
  action: string
): Promise<{ tokens: number; lastRefill: number }> {
  const docId = `${userId}_${action}`;
  const docRef = firestore.collection("rateLimits").doc(docId);

  const doc = await docRef.get();

  if (!doc.exists) {
    return {
      tokens: RATE_LIMIT_CONFIG.bucketSize,
      lastRefill: Date.now(),
    };
  }

  const data = doc.data() as RateLimitEntry;

  // Calculate current tokens based on time elapsed
  const now = Date.now();
  const elapsedMinutes = (now - data.lastRefill) / 60_000;
  const tokensToAdd = elapsedMinutes * RATE_LIMIT_CONFIG.refillRate;
  const tokens = Math.min(RATE_LIMIT_CONFIG.bucketSize, data.tokens + tokensToAdd);

  return {
    tokens,
    lastRefill: data.lastRefill,
  };
}

/**
 * Reset rate limit for a user (admin function)
 *
 * @param userId - The user's Firebase Auth UID
 * @param action - The action to reset
 */
export async function resetRateLimit(userId: string, action: string): Promise<void> {
  const docId = `${userId}_${action}`;
  const docRef = firestore.collection("rateLimits").doc(docId);

  await docRef.delete();

  logger.info(`Rate limit reset for user ${userId}, action ${action}`);
}
