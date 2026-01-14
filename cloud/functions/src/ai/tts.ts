/**
 * Text-to-Speech Cloud Function
 *
 * Generates audio using cloud TTS APIs or routes to on-device
 * synthesis depending on hardware capabilities.
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {
  TTSRequest,
  TTSResponse,
  RATE_LIMIT_CONFIG,
  AUDIO_CACHE_CONFIG,
} from "../config/models";
import { getGeminiAPIKey } from "../config/secrets";
import { verifyAppCheck } from "../security/appCheck";
import { checkRateLimit } from "../security/rateLimit";
import { createScopedLogger } from "../utils/logger";

const logger = createScopedLogger("tts");
const firestore = admin.firestore();

/**
 * Text-to-Speech V2 Cloud Function
 *
 * Generates audio with device-aware routing:
 * - A19/A18: Use on-device synthesis (client-side)
 * - A14-A17: Use cloud TTS with caching
 */
export const ttsV2 = functions.https.onCall(
  {
    region: "us-central1",
    memory: "512MiB",
    maxInstances: 100,
    secrets: ["gemini-api-key"],
    enforceAppCheck: true,
  },
  async (request): Promise<TTSResponse> => {
    const data = request.data as TTSRequest;

    logger.info("TTS request received", {
      userId: data.userId,
      textLength: data.text.length,
      language: data.language,
      voiceQuality: data.voiceQuality,
      deviceChip: data.deviceChip,
    });

    // 1. Verify App Check (handled automatically)
    // 2. Check rate limit
    try {
      await checkRateLimit(data.userId, "tts", RATE_LIMIT_CONFIG.costs.tts);
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      logger.error("Rate limit check failed", error);
    }

    // 3. Check if device supports on-device synthesis
    const supportsOnDevice = ["A18", "A19"].includes(data.deviceChip);

    if (supportsOnDevice) {
      // Client should use on-device synthesis
      logger.info("Device supports on-device synthesis", { deviceChip: data.deviceChip });

      return {
        audioData: "", // Empty - client uses on-device
        duration: 0,
        format: "mp3",
        provider: "on-device",
        cached: false,
      };
    }

    // 4. Check cache for existing audio
    const textHash = hashText(data.text + data.language + data.voiceQuality);
    const cached = await getCachedAudio(textHash);

    if (cached) {
      logger.info("Audio cache hit", { textHash });

      return {
        audioData: cached.audioData,
        duration: cached.duration,
        format: cached.format,
        provider: cached.provider,
        cached: true,
      };
    }

    // 5. Generate audio using cloud TTS
    const response = await generateCloudAudio(data, textHash);

    // 6. Cache the audio
    await cacheAudio(textHash, response);

    logger.info("TTS completed", {
      userId: data.userId,
      provider: response.provider,
      duration: response.duration,
      cached: false,
    });

    return response;
  }
);

/**
 * Generate audio using cloud TTS API
 */
async function generateCloudAudio(
  request: TTSRequest,
  textHash: string
): Promise<TTSResponse> {
  // TODO: Implement actual Gemini Audio API or Zhipu TTS API
  // For now, return a mock response

  // Mock: Simulate audio generation time
  const estimatedDuration = estimateAudioDuration(request.text);

  // Mock: Base64-encoded audio data (placeholder)
  // In production, this would be actual MP3/WAV data from the TTS API
  const mockAudioData = Buffer.from(`mock-audio-${textHash}`).toString("base64");

  return {
    audioData: mockAudioData,
    duration: estimatedDuration,
    format: "mp3",
    provider: "gemini", // or "zhipu"
    cached: false,
  };
}

/**
 * Get cached audio from Firestore
 */
async function getCachedAudio(
  textHash: string
): Promise<{ audioData: string; duration: number; format: string; provider: string } | null> {
  const docRef = firestore.collection("audioCache").doc(textHash);
  const doc = await docRef.get();

  if (!doc.exists) {
    return null;
  }

  const data = doc.data()!;
  const createdAt = data.createdAt?.toDate() || new Date(0);
  const age = Date.now() - createdAt.getTime();

  // Check TTL
  if (age > AUDIO_CACHE_CONFIG.ttl * 1000) {
    // Cache expired
    await docRef.delete();
    logger.debug("Audio cache expired", { textHash });
    return null;
  }

  // Increment access count
  await docRef.update({
    accessCount: admin.firestore.FieldValue.increment(1),
  });

  return {
    audioData: data.audioData,
    duration: data.duration,
    format: data.format,
    provider: data.provider,
  };
}

/**
 * Cache audio in Firestore
 */
async function cacheAudio(
  textHash: string,
  response: Omit<TTSResponse, "cached">
): Promise<void> {
  const docRef = firestore.collection("audioCache").doc(textHash);

  await docRef.set({
    audioData: response.audioData,
    duration: response.duration,
    format: response.format,
    provider: response.provider,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    accessCount: 0,
    ttl: AUDIO_CACHE_CONFIG.ttl,
  });

  logger.debug("Audio cached", { textHash });
}

/**
 * Hash text for cache key
 */
function hashText(text: string): string {
  return crypto.createHash("sha256").update(text).digest("hex");
}

/**
 * Estimate audio duration based on text length
 */
function estimateAudioDuration(text: string): number {
  // Average speech rate: ~130-150 words per minute
  // Average word length: ~5 characters
  const wordCount = text.length / 5;
  const durationMinutes = wordCount / 140;
  return durationMinutes * 60; // Convert to seconds
}
