/**
 * Translation Cloud Function
 *
 * Routes translation requests to optimal AI provider (Gemini or Zhipu)
 * based on cost, capabilities, and user quota.
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {
  TranslateRequest,
  TranslateResponse,
  AIProvider,
  MODEL_CONFIG,
  RATE_LIMIT_CONFIG,
} from "../config/models";
import { getGeminiAPIKey, getZhipuAPIKey } from "../config/secrets";
import { verifyAppCheck } from "../security/appCheck";
import { checkRateLimit } from "../security/rateLimit";
import { createScopedLogger } from "../utils/logger";

const logger = createScopedLogger("translate");
const firestore = admin.firestore();

/**
 * Translation V2 Cloud Function
 *
 * Routes translation requests to optimal AI provider with automatic
 * fallback, rate limiting, and quota tracking.
 */
export const translateV2 = functions.https.onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    maxInstances: 100,
    secrets: ["gemini-api-key", "zhipu-api-key"],
    enforceAppCheck: true,
  },
  async (request): Promise<TranslateResponse> => {
    const data = request.data as TranslateRequest;

    logger.info("Translation request received", {
      userId: data.userId,
      textCount: data.texts.length,
      sourceLanguage: data.sourceLanguage,
      targetLanguage: data.targetLanguage,
      includeContext: data.includeContext,
    });

    // 1. Verify App Check (handled automatically by enforceAppCheck)
    // 2. Check rate limit
    try {
      await checkRateLimit(data.userId, "translate", RATE_LIMIT_CONFIG.costs.translate);
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      logger.error("Rate limit check failed", error);
    }

    // 3. Select optimal provider
    const provider = await selectProvider(data);

    logger.info(`Selected provider: ${provider}`);

    // 4. Route to provider
    let response: TranslateResponse;

    if (provider === "gemini") {
      response = await translateWithGemini(data);
    } else {
      response = await translateWithZhipu(data);
    }

    // 5. Update quota
    await updateQuota(data.userId, provider, response.tokensUsed);

    logger.info("Translation completed", {
      userId: data.userId,
      provider,
      textCount: data.texts.length,
      tokensUsed: response.tokensUsed,
      quotaRemaining: response.quotaRemaining,
    });

    return response;
  }
);

/**
 * Select optimal AI provider based on request and quota
 */
async function selectProvider(request: TranslateRequest): Promise<AIProvider> {
  const userQuota = await getUserQuota(request.userId);

  // Priority: Zhipu Free (text-only) → Gemini (multimodal)
  if (!request.includeContext && userQuota.zhipuRemaining > 0) {
    return "zhipu";
  }

  if (userQuota.geminiRemaining > 0) {
    return "gemini";
  }

  // Fallback: try Zhipu even if quota is low
  return "zhipu";
}

/**
 * Translate using Gemini 2.5 Flash
 */
async function translateWithGemini(request: TranslateRequest): Promise<TranslateResponse> {
  const apiKey = await getGeminiAPIKey();

  // Call Gemini API
  // Note: This is a simplified implementation
  // In production, use the @google/generative-ai SDK

  const prompt = buildPrompt(request);
  const tokensUsed = estimateTokens(request.texts);

  // TODO: Implement actual Gemini API call
  // const response = await callGeminiAPI(apiKey, prompt);

  // Mock response for now
  const translations = request.texts.map((text) => ({
    sourceText: text,
    translatedText: `[Gemini] ${text} translated`,
    contextSentence: request.includeContext ? "Example sentence" : undefined,
    cefrLevel: "B1",
  }));

  return {
    translations,
    provider: "gemini",
    tokensUsed,
    quotaRemaining: 100, // TODO: Fetch from Firestore
  };
}

/**
 * Translate using Zhipu GLM-4 Flash
 */
async function translateWithZhipu(request: TranslateRequest): Promise<TranslateResponse> {
  const apiKey = await getZhipuAPIKey();

  // Call Zhipu API
  // Note: This is a simplified implementation

  const prompt = buildPrompt(request);
  const tokensUsed = estimateTokens(request.texts);

  // TODO: Implement actual Zhipu API call
  // const response = await callZhipuAPI(apiKey, prompt);

  // Mock response for now
  const translations = request.texts.map((text) => ({
    sourceText: text,
    translatedText: `[Zhipu] ${text} translated`,
    contextSentence: request.includeContext ? "Example sentence" : undefined,
    cefrLevel: "B2",
  }));

  return {
    translations,
    provider: "zhipu",
    tokensUsed,
    quotaRemaining: 500, // TODO: Fetch from Firestore
  };
}

/**
 * Build prompt for AI model
 */
function buildPrompt(request: TranslateRequest): string {
  const contextInstruction = request.includeContext
    ? "Include context sentences and CEFR level."
    : "Translate only.";

  return `Translate the following ${request.texts.length} texts from ${request.sourceLanguage} to ${request.targetLanguage}. ${contextInstruction}`;
}

/**
 * Estimate token count for a batch of texts
 */
function estimateTokens(texts: string[]): number {
  // Rough estimate: ~4 characters per token
  const totalChars = texts.reduce((sum, text) => sum + text.length, 0);
  return Math.ceil(totalChars / 4);
}

/**
 * Get user's remaining quota for each provider
 */
async function getUserQuota(userId: string): Promise<{
  geminiRemaining: number;
  zhipuRemaining: number;
}> {
  const docRef = firestore.collection("userQuotas").doc(userId);
  const doc = await docRef.get();

  if (!doc.exists) {
    // New user - initialize with free tier quotas
    return {
      geminiRemaining: 1_000_000, // 1M tokens
      zhipuRemaining: 500_000, // 500K tokens
    };
  }

  const data = doc.data() || {};
  return {
    geminiRemaining: (data.geminiTokens?.total || 1_000_000) - (data.geminiTokens?.used || 0),
    zhipuRemaining: (data.zhipuTokens?.total || 500_000) - (data.zhipuTokens?.used || 0),
  };
}

/**
 * Update user's quota after API call
 */
async function updateQuota(userId: string, provider: AIProvider, tokensUsed: number): Promise<void> {
  const docRef = firestore.collection("userQuotas").doc(userId);

  await firestore.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (!doc.exists) {
      // Initialize quota document
      transaction.set(docRef, {
        userId,
        geminiTokens: {
          total: 1_000_000,
          used: provider === "gemini" ? tokensUsed : 0,
          resetAt: getNextResetTime(),
        },
        zhipuTokens: {
          total: 500_000,
          used: provider === "zhipu" ? tokensUsed : 0,
          resetAt: getNextResetTime(),
        },
      });
    } else {
      // Update existing quota
      const data = doc.data()!;
      const fieldName = provider === "gemini" ? "geminiTokens" : "zhipuTokens";

      transaction.update(docRef, {
        [`${fieldName}.used`]: admin.firestore.FieldValue.increment(tokensUsed),
      });
    }
  });
}

/**
 * Get next quota reset time (1st of next month)
 */
function getNextResetTime(): admin.firestore.Timestamp {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return admin.firestore.Timestamp.fromDate(nextMonth);
}
