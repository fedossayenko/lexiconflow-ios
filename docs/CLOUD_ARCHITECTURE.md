# Cloud Architecture - LexiconFlow AI Proxy

This document describes the Firebase Cloud Functions backend architecture for LexiconFlow's secure AI services proxy.

---

## Overview

LexiconFlow uses a **Backend-for-Frontend (BFF)** pattern with Firebase Cloud Functions to provide secure AI services without exposing API keys on the client side. The backend handles:

- **AI Provider Routing**: Automatic selection between Gemini 2.5 Flash and Zhipu GLM-4.7
- **Security**: App Check verification, rate limiting, quota management
- **Hardware-Aware Routing**: On-device vs cloud TTS based on device capabilities
- **Cost Optimization**: Smart provider selection to minimize API costs

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      LexiconFlow iOS App                         │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │   Translation  │  │  Cloud Audio   │  │   Sentences   │   │
│  │     Service    │  │    Service     │  │   Service     │   │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘   │
│           │                   │                   │             │
│           └───────────────────┴───────────────────┘             │
│                                     │                           │
│                           ┌─────────┴─────────┐               │
│                           │ FirebaseService  │               │
│                           │ + App Check       │               │
│                           └─────────┬─────────┘               │
└───────────────────────────────┼───────────────────────────────┘
                                │ HTTPS (Callable)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│               Firebase Cloud Functions (BFF)                    │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ Security Layer                                        │    │
│  │  - Firebase App Check (Apple App Attest)             │    │
│  │  - Rate Limiting (Token Bucket: 100 tokens, 10/min)   │    │
│  │  - Quota Management (Firestore-backed)                 │    │
│  └───────────────────────────────────────────────────────┘    │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ AI Router (Cost Optimization)                        │    │
│  │  - Zhipu GLM-4 Flash (Free tier, text-only)          │    │
│  │  - Gemini 2.5 Flash (Paid, multimodal, 1M context)    │    │
│  │  - Fallback: Static sentences                        │    │
│  └───────────────────────────────────────────────────────┘    │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ Audio Router (Hardware-Aware)                        │    │
│  │  - A19/A18: On-device synthesis (AVSpeechSynth.prem) │    │
│  │  - A14-A17: Cloud TTS with 7-day cache               │    │
│  └───────────────────────────────────────────────────────┘    │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              Google Cloud Secret Manager                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐ │
│  │ gemini-api-key  │  │ zhipu-api-key   │  │ (API Secrets) │ │
│  └─────────────────┘  └─────────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cloud Functions Endpoints

### translateV2

**Purpose**: Translation with CEFR levels and context sentences

**Request**:
```typescript
{
  texts: string[];              // 1-100 texts
  sourceLanguage: string;       // e.g., "en"
  targetLanguage: string;       // e.g., "ru"
  includeContext: boolean;      // Include CEFR and sentences
  userId: string;               // Firebase Auth UID
}
```

**Response**:
```typescript
{
  translations: [{
    sourceText: string;
    translatedText: string;
    contextSentence?: string;   // If includeContext=true
    cefrLevel?: string;          // If includeContext=true
  }];
  provider: "gemini" | "zhipu";
  tokensUsed: number;
  quotaRemaining: number;
}
```

**Provider Selection**:
1. If `!includeContext` and Zhipu quota available → Use Zhipu (Free)
2. Otherwise → Use Gemini (1M context, multimodal)

### ttsV2

**Purpose**: Text-to-speech with device-aware routing

**Request**:
```typescript
{
  text: string;
  language: string;              // e.g., "en-US"
  voiceQuality: string;          // "premium" | "enhanced" | "default"
  deviceChip: string;            // "A14" | "A15" | "A16" | "A17" | "A18" | "A19"
  userId: string;
}
```

**Response**:
```typescript
{
  audioData: string;             // Base64 MP3/WAV (or empty for on-device)
  duration: number;              // Seconds
  format: "mp3" | "wav";
  provider: "gemini" | "zhipu" | "on-device";
  cached: boolean;
}
```

**Routing Logic**:
- **A19/A18**: Returns `provider: "on-device"` with empty `audioData`
  - Client uses `AVSpeechSynthesizer.premium`
  - No API cost, unlimited use
- **A14-A17**: Returns cached or generated audio
  - 7-day local cache on iOS client
  - Cloud TTS via Gemini or Zhipu

### generateSentences

**Purpose**: Generate contextual example sentences for vocabulary cards

**Request**:
```typescript
{
  words: Array<{
    word: string;
    definition: string;
    cefrLevel?: string;
  }>;
  targetLanguage: string;
  userId: string;
}
```

**Response**:
```typescript
{
  sentences: [{
    word: string;
    sentence: string;
    translation: string;
  }];
  provider: "gemini" | "zhipu";
}
```

---

## Security Model

### Firebase App Check

**Purpose**: Verify requests come from legitimate LexiconFlow app instances

**Implementation**:
- **Production**: Apple App Attest (cryptographic device attestation)
- **Development**: Debug tokens (manually added in Firebase Console)

**Verification Flow**:
1. iOS app generates App Check token using device Secure Enclave
2. Token sent with each Cloud Function request
3. Firebase verifies token signature before executing function
4. Invalid/replay tokens rejected with 401 Unauthorized

### Rate Limiting

**Algorithm**: Token Bucket

**Configuration**:
- Bucket size: 100 tokens
- Refill rate: 10 tokens/minute
- Costs: Translate (1), TTS (2), Sentences (3)

**Firestore Schema**:
```
rateLimits/{userId}_{action}
{
  tokens: number;        // Current token count
  lastRefill: number;    // Unix timestamp (seconds)
}
```

### Quota Management

**Monthly Quotas**:
- Gemini: 1M tokens/month (free tier)
- Zhipu: 500K tokens/month (free tier)

**Firestore Schema**:
```
userQuotas/{userId}
{
  geminiTokens: {
    total: number;       // 1_000_000
    used: number;        // Incremented on each call
    resetAt: Timestamp;  // 1st of next month
  };
  zhipuTokens: {
    total: number;       // 500_000
    used: number;
    resetAt: Timestamp;
  };
}
```

---

## AI Provider Configuration

### Gemini 2.5 Flash (Primary)

**Use Cases**:
- Multimodal requests (text + images)
- Context sentence generation
- Large context (up to 1M tokens)

**Configuration**:
```typescript
{
  model: "gemini-2.5-flash-preview",
  maxTokens: 8192,
  temperature: 0.1,
  contextWindow: 1_000_000
}
```

**Pricing** (Paid Tier):
- Input: ~$0.075 per 1M tokens
- Output: ~$0.30 per 1M tokens
- **Note**: 15 requests/minute free tier available

### Zhipu GLM-4 Flash (Fallback)

**Use Cases**:
- Basic translation (text-only)
- Cost-sensitive operations

**Configuration**:
```typescript
{
  model: "glm-4-flash",
  maxTokens: 4096,
  temperature: 0.1,
  contextWindow: 128_000
}
```

**Pricing**:
- **Free**: 500K tokens/month (no cost)
- **Paid**: ~$14 per 1M tokens (if quota exceeded)

---

## Firestore Collections

### rateLimits

Tracks user rate limit state (token bucket algorithm)

**Indexes**: `userId` (ASC), `lastRefill` (DESC)

### audioCache

Stores cached TTS audio to reduce API calls

**Schema**:
```
audioCache/{textHash}
{
  audioData: string;      // Base64 MP3/WAV
  duration: number;       // Seconds
  format: string;         // "mp3" or "wav"
  provider: string;       // "gemini" or "zhipu"
  createdAt: Timestamp;
  ttl: number;            // 604800 (7 days)
  accessCount: number;    // LRU tracking
}
```

**Indexes**: `createdAt` (DESC)

### userQuotas

Tracks user's monthly AI API usage

**Schema**:
```
userQuotas/{userId}
{
  userId: string;
  geminiTokens: { total, used, resetAt };
  zhipuTokens: { total, used, resetAt };
}
```

**Indexes**: `userId` (ASC), `resetAt` (ASC)

---

## Cost Estimation

### Per 10,000 MAU (Monthly Active Users)

Assumptions:
- 10 requests/day per user
- 1,000 tokens per request
- 300K total requests/month
- 300M total tokens/month

| Component | Usage | Est. Cost |
|-----------|-------|-----------|
| Cloud Functions Invocations | 3M | $1.20 |
| Cloud Functions Compute | ~100GB-sec | $5-10 |
| Firestore (Read/Write) | 6M ops | $8.00 |
| App Check Attestations | 3M | Free |
| **Zhipu (Free Tier)** | 300M tokens | **$0** |
| **Gemini (Paid)** | 300M tokens | **$120** |

**Total**: ~$15-25/month with Zhipu Free tier
**Total**: ~$135-145/month with Gemini only

### Cost Optimization Strategies

1. **Default to Zhipu Free** for text-only translation
2. **Use Gemini only for**:
   - Multimodal (images/video)
   - Context sentences (better quality)
   - When Zhipu quota exhausted
3. **Local caching** for TTS (7-day TTL)
4. **Rate limiting** to prevent abuse

---

## Deployment

### Prerequisites

1. Firebase project created (`lexiconflow-cloud`)
2. Google Cloud project linked
3. Secrets created in Secret Manager
4. Firebase CLI installed

### Deploy Commands

```bash
cd cloud

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:translateV2

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes
```

### Environment Variables

Set via Google Cloud Console:
- `GCP_PROJECT_ID`: Your Google Cloud project ID
- `GCLOUD_PROJECT`: Alias for `GCP_PROJECT_ID`

### Secrets

Created via Google Cloud Secret Manager:
- `gemini-api-key`: Gemini 2.5 Flash API key
- `zhipu-api-key`: Zhipu GLM-4 API key

---

## Monitoring

### Logs

```bash
# Real-time logs
firebase logs --only functions

# Specific function
firebase functions:log --only translateV2

# Tail logs
firebase functions:log --tail
```

### Metrics to Track

- **Latency**: P50, P95, P99 for each endpoint
- **Error Rate**: 4xx/5xx response percentages
- **Quota Usage**: Tokens consumed per user per month
- **Cache Hit Rate**: Audio cache effectiveness
- **Provider Distribution**: Gemini vs Zhipu usage ratio

### Alerts

Configure in Firebase Console or Google Cloud Monitoring:
- **High Error Rate**: > 5% error rate for 5 minutes
- **Quota Exhaustion**: > 80% of monthly quota used
- **Latency**: P95 > 3 seconds for any endpoint

---

## Client Integration (iOS)

### FirebaseService

**Purpose**: Centralized Firebase SDK initialization

**Methods**:
```swift
FirebaseService.shared.configure()
FirebaseService.shared.signInAnonymously()
FirebaseService.shared.getAppCheckToken()
FirebaseService.shared.currentUserId
```

### CloudTranslationService

**Purpose**: Translation via Cloud Functions

**Methods**:
```swift
let result = try await CloudTranslationService.shared.translate(
    texts: ["hello", "world"],
    from: "en",
    to: "ru",
    includeContext: true
)
```

### CloudAudioService

**Purpose**: TTS with hardware-aware routing

**Methods**:
```swift
try await CloudAudioService.shared.speak(
    "Hello world",
    language: "en-US",
    quality: .premium
)
```

---

## Security Best Practices

1. **Never log API keys** - Use Secret Manager
2. **Always verify App Check tokens** - Reject unauthorized requests
3. **Rate limit per user** - Prevent abuse and control costs
4. **Monitor quota usage** - Alert before exceeding free tier
5. **Use limited-use tokens** - For high-cost operations (prevents replay attacks)
6. **Rotate secrets regularly** - Every 90 days recommended
7. **Principle of least privilege** - Cloud Functions SA has minimum required permissions

---

## Troubleshooting

### App Check Failures

**Symptom**: 401 Unauthorized errors

**Solutions**:
1. Verify debug token added in Firebase Console (development)
2. Check App Attest enabled for production bundle ID
3. Verify `enforceAppCheck: true` in function configuration

### Rate Limit Errors

**Symptom**: "resource-exhausted" errors

**Solutions**:
1. Check token bucket size (default: 100)
2. Verify refill rate (default: 10/minute)
3. Check Firestore writes for rate limits document

### Secret Access Denied

**Symptom**: "Failed to access secret"

**Solutions**:
1. Verify secret exists: `gcloud secrets list`
2. Check IAM policy: `gcloud secrets get-iam-policy {secret}`
3. Grant access: `gcloud secrets add-iam-policy-binding {secret}`

### Quota Issues

**Symptom**: "QUOTA_EXCEEDED" errors

**Solutions**:
1. Check userQuotas document in Firestore
2. Verify resetAt timestamp (1st of month)
3. Consider increasing free tier limits or enabling billing

---

## Next Steps

1. **Complete Firebase Setup**: Follow `FIREBASE_SETUP.md`
2. **Deploy Cloud Functions**: Run deployment commands
3. **Test Integration**: Run iOS app in debug mode
4. **Monitor Metrics**: Set up Cloud Monitoring dashboards
5. **Optimize Costs**: Analyze provider usage and adjust routing

---

## References

- [Firebase Cloud Functions Docs](https://firebase.google.com/docs/functions)
- [Google Cloud Secret Manager](https://cloud.google.com/secret-manager)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- [Gemini API Documentation](https://ai.google.dev/gemini-api-docs)
- [Zhipu AI Documentation](https://open.bigmodel.cn/dev/api)
