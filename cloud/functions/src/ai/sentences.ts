/**
 * Sentence Generation Cloud Function
 *
 * Generates contextual example sentences for vocabulary cards
 * using AI models (Gemini 2.5 Flash or Zhipu GLM-4).
 */

import * as functions from "firebase-functions/v2";
import { SentenceRequest, SentenceResponse, RATE_LIMIT_CONFIG } from "../config/models";
import { getGeminiAPIKey } from "../config/secrets";
import { verifyAppCheck } from "../security/appCheck";
import { checkRateLimit } from "../security/rateLimit";
import { createScopedLogger } from "../utils/logger";

const logger = createScopedLogger("sentences");

/**
 * Sentence Generation Cloud Function
 *
 * Generates contextual sentences for vocabulary words.
 */
export const generateSentences = functions.https.onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    maxInstances: 100,
    secrets: ["gemini-api-key"],
    enforceAppCheck: true,
  },
  async (request): Promise<SentenceResponse> => {
    const data = request.data as SentenceRequest;

    logger.info("Sentence generation request received", {
      userId: data.userId,
      wordCount: data.words.length,
      targetLanguage: data.targetLanguage,
    });

    // 1. Verify App Check (handled automatically)
    // 2. Check rate limit
    try {
      await checkRateLimit(data.userId, "sentences", RATE_LIMIT_CONFIG.costs.sentences);
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      logger.error("Rate limit check failed", error);
    }

    // 3. Generate sentences using Gemini (best for context)
    const sentences = await generateSentencesWithGemini(data);

    logger.info("Sentence generation completed", {
      userId: data.userId,
      provider: sentences.provider,
      sentenceCount: sentences.sentences.length,
    });

    return sentences;
  }
);

/**
 * Generate sentences using Gemini 2.5 Flash
 */
async function generateSentencesWithGemini(request: SentenceRequest): Promise<SentenceResponse> {
  const apiKey = await getGeminiAPIKey();

  // TODO: Implement actual Gemini API call
  // For now, return a mock response

  const sentences: SentenceResponse["sentences"] = request.words.map((word) => ({
    word: word.word,
    sentence: `This is an example sentence using the word "${word.word}".`,
    translation: `Translation of the sentence for "${word.word}".`,
  }));

  return {
    sentences,
    provider: "gemini",
  };
}
