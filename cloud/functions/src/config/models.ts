/**
 * AI Provider Configuration
 *
 * Defines model configurations for Gemini and Zhipu AI providers,
 * including token limits, pricing, and feature support.
 */

/**
 * Supported AI providers
 */
export type AIProvider = "gemini" | "zhipu";

/**
 * Translation request from iOS client
 */
export interface TranslateRequest {
  texts: string[];
  sourceLanguage: string;
  targetLanguage: string;
  includeContext?: boolean;
  userId: string;
}

/**
 * Translation response to iOS client
 */
export interface TranslateResponse {
  translations: TranslationItem[];
  provider: AIProvider;
  tokensUsed: number;
  quotaRemaining: number;
}

/**
 * Single translation item
 */
export interface TranslationItem {
  sourceText: string;
  translatedText: string;
  contextSentence?: string;
  cefrLevel?: string;
}

/**
 * Text-to-speech request
 */
export interface TTSRequest {
  text: string;
  language: string;
  voiceQuality: "premium" | "enhanced" | "default";
  deviceChip: "A14" | "A15" | "A16" | "A17" | "A18" | "A19";
  userId: string;
}

/**
 * Text-to-speech response
 */
export interface TTSResponse {
  audioData: string; // Base64-encoded MP3/WAV
  duration: number; // Seconds
  format: "mp3" | "wav";
  provider: AIProvider | "on-device";
  cached: boolean;
}

/**
 * Sentence generation request
 */
export interface SentenceRequest {
  words: Array<{
    word: string;
    definition: string;
    cefrLevel?: string;
  }>;
  targetLanguage: string;
  userId: string;
}

/**
 * Sentence generation response
 */
export interface SentenceResponse {
  sentences: SentenceItem[];
  provider: AIProvider;
}

/**
 * Generated sentence item
 */
export interface SentenceItem {
  word: string;
  sentence: string;
  translation: string;
}

/**
 * AI model configurations
 */
export const MODEL_CONFIG = {
  gemini: {
    model: "gemini-2.5-flash-preview",
    maxTokens: 8192,
    temperature: 0.1,
    contextWindow: 1_000_000,
  },
  zhipu: {
    model: "glm-4-flash",
    maxTokens: 4096,
    temperature: 0.1,
    contextWindow: 128_000,
  },
} as const;

/**
 * Rate limit configuration
 */
export const RATE_LIMIT_CONFIG = {
  bucketSize: 100, // Max tokens
  refillRate: 10, // Tokens per minute
  costs: {
    translate: 1,
    tts: 2,
    sentences: 3,
  },
};

/**
 * User quota configuration
 */
export const QUOTA_CONFIG = {
  gemini: {
    freeTierTokens: 1_000_000, // 1M tokens/month
    resetDay: 1, // 1st of each month
  },
  zhipu: {
    freeTierTokens: 500_000, // 500K tokens/month
    resetDay: 1,
  },
};

/**
 * Audio cache configuration
 */
export const AUDIO_CACHE_CONFIG = {
  ttl: 604_800, // 7 days in seconds
  maxSize: 100 * 1024 * 1024, // 100MB
  lruEvictPercent: 0.1, // Evict 10% when full
};
