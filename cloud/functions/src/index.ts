/**
 * LexiconFlow Cloud Functions - Main Entry Point
 *
 * Backend-for-Frontend (BFF) proxy providing secure access to AI services
 * with App Check verification, rate limiting, and intelligent provider routing.
 *
 * **Architecture**:
 * 1. Security Layer: App Check + Rate Limiting
 * 2. AI Router: Gemini 2.5 Flash ←→ Zhipu GLM-4.7
 * 3. Quota Management: Firestore-backed token tracking
 *
 * **Endpoints**:
 * - translateV2: Translation with CEFR levels
 * - ttsV2: Text-to-speech with device-aware routing
 * - generateSentences: Context sentence generation
 */

import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export Cloud Functions
export { translateV2 } from "./ai/translate";
export { ttsV2 } from "./ai/tts";
export { generateSentences } from "./ai/sentences";

// Log function startup
logger.info("LexiconFlow Cloud Functions initialized", {
  region: "us-central1",
  nodeVersion: process.version,
});

/**
 * Structured logger for Cloud Functions
 */
const logger = {
  debug: (message: string, metadata?: Record<string, unknown>) => {
    functions.logger.debug(message, metadata);
  },
  info: (message: string, metadata?: Record<string, unknown>) => {
    functions.logger.info(message, metadata);
  },
  warning: (message: string, metadata?: Record<string, unknown>) => {
    functions.logger.warn(message, metadata);
  },
  error: (message: string, error?: unknown) => {
    functions.logger.error(message, error);
  },
};
