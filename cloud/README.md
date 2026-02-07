# LexiconFlow Cloud Functions Backend

Firebase Cloud Functions 2nd Gen backend providing secure access to AI services (Gemini 2.5 Flash, Zhipu GLM-4.7) for the LexiconFlow iOS app.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LexiconFlow iOS App                      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Translation │  │  TTS/Audio   │  │  Sentences   │      │
│  │  Service     │  │  Service     │  │  Service     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │               │
│         └─────────────────┴─────────────────┘               │
│                           │                                 │
│                           ▼                                 │
│                   ┌───────────────┐                         │
│                   │ Firebase SDK  │                         │
│                   │ + App Check   │                         │
│                   └───────┬───────┘                         │
└───────────────────────────┼───────────────────────────────┘
                            │ HTTPS (Callable)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Firebase Cloud Functions (BFF)                 │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Security Layer:                                      │  │
│  │  - App Check verification                           │  │
│  │  - Rate limiting (token bucket)                     │  │
│  │  - Quota management                                  │  │
│  └─────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ AI Router:                                           │  │
│  │  - Zhipu GLM-4 Flash (free tier, text-only)         │  │
│  │  - Gemini 2.5 Flash (paid, multimodal)              │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────┬───────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           Google Cloud Secret Manager (API Keys)            │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │ gemini-api-key  │  │ zhipu-api-key   │                 │
│  └─────────────────┘  └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
cloud/
├── firebase.json              # Firebase project configuration
├── .firebaserc                # Firebase project aliases
├── firestore/                 # Firestore configuration
│   ├── firestore.rules        # Security rules
│   └── firestore.indexes.json # Database indexes
├── functions/
│   ├── package.json           # Node.js dependencies
│   ├── tsconfig.json          # TypeScript configuration
│   └── src/
│       ├── index.ts           # Main entry point
│       ├── config/            # Configuration
│       │   ├── models.ts      # Type definitions & constants
│       │   └── secrets.ts     # Secret Manager wrapper
│       ├── security/          # Security layer
│       │   ├── appCheck.ts    # App Check verification
│       │   └── rateLimit.ts   # Token bucket rate limiter
│       ├── ai/                # AI endpoints
│       │   ├── translate.ts   # Translation function
│       │   ├── tts.ts         # Text-to-speech function
│       │   └── sentences.ts   # Sentence generation function
│       └── utils/             # Utilities
│           └── logger.ts      # Structured logging
└── README.md                  # This file
```

## Cloud Functions Endpoints

| Endpoint | Purpose | Provider Selection |
|----------|---------|-------------------|
| `translateV2` | Translation with CEFR levels | Zhipu Free → Gemini |
| `ttsV2` | Text-to-speech | Cloud (A14-A17) / On-device (A18-A19) |
| `generateSentences` | Context sentence generation | Gemini 2.5 Flash |

## Deployment

### Prerequisites

1. **Firebase Project** created (see `../docs/FIREBASE_SETUP.md`)
2. **Node.js** 20+ LTS installed
3. **Firebase CLI** installed: `npm install -g firebase-tools`
4. **Google Cloud CLI** installed: `gcloud init`

### Deploy to Production

```bash
cd cloud

# Build and deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:translateV2

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes
```

### Deploy to Test Environment

```bash
cd cloud

# Use emulator for local testing
firebase emulators:start --only functions,firestore,auth
```

## Configuration

### Environment Variables

Set via Google Cloud Console or `firebase functions:config:set`:

```bash
# Set GCP project ID
firebase functions:config:set gcp.project_id=lexiconflow-cloud
```

### Secrets (Secret Manager)

API keys are stored in Google Cloud Secret Manager:

```bash
# Gemini API Key
gcloud secrets create gemini-api-key --replication-policy="automatic"
echo "YOUR_GEMINI_KEY" | gcloud secrets versions add gemini-api-key --data-file=-

# Zhipu API Key
gcloud secrets create zhipu-api-key --replication-policy="automatic"
echo "YOUR_ZHIPU_KEY" | gcloud secrets versions add zhipu-api-key --data-file=-
```

## Monitoring

### View Logs

```bash
# Real-time logs
firebase logs --only functions

# Specific function
firebase functions:log --only translateV2

# Tail logs
firebase functions:log --tail
```

### Monitoring in Firebase Console

- **Functions Logs**: https://console.firebase.google.com/project/lexiconflow-cloud/functions/logs
- **Firestore Database**: https://console.firebase.google.com/project/lexiconflow-cloud/firestore
- **App Check**: https://console.firebase.google.com/project/lexiconflow-cloud/appcheck

## Cost Estimation

Based on 10,000 Monthly Active Users (MAU), 10 requests/day:

| Component | Usage | Est. Cost (Monthly) |
|-----------|-------|---------------------|
| Cloud Functions Invocations | 3M | $1.20 |
| Cloud Functions Compute | ~100GB-sec | $5-10 |
| Firestore Reads/Writes | 6M | $8.00 |
| App Check Attestations | 3M | Free |
| Gemini API (1M tokens) | 300M tokens | $120 (if no free tier) |
| **Total (with Zhipu Free)** | - | **~$15-25** |
| **Total (all Gemini)** | - | **~$135-145** |

## Development

### Local Development

```bash
cd cloud/functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Watch mode
npm run build:watch

# Run linter
npm run lint
npm run lint:fix

# Start emulator
cd ..
firebase emulators:start --only functions,firestore,auth
```

### Testing

```bash
# Run tests (when implemented)
npm test

# Manual testing with emulator
firebase emulators:start
# Then use iOS app in debug mode (uses emulator)
```

## Security

### App Check

- **Production**: Apple App Attest (cryptographic device verification)
- **Development**: Debug tokens (add in Firebase Console)

### Rate Limiting

- Token bucket algorithm: 100 tokens, refills at 10/minute
- Per-user limits stored in Firestore
- Costs: Translate (1 token), TTS (2 tokens), Sentences (3 tokens)

### API Keys

- Stored in Google Cloud Secret Manager
- Never logged or exposed in client code
- Access limited to Cloud Functions service account

## Troubleshooting

### Functions Not Deploying

**Error**: "PERMISSION_DENIED: IAM permission"

**Solution**:
```bash
gcloud projects add-iam-policy-binding lexiconflow-cloud \
  --member="serviceAccount:service-PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com" \
  --role="roles/cloudfunctions.serviceAgent"
```

### Secret Access Denied

**Error**: "Permission 'secretmanager.versions.access' denied"

**Solution**: Verify IAM policy bindings:
```bash
gcloud secrets get-iam-policy gemini-api-key --project=lexiconflow-cloud
```

### App Check Token Invalid

**Error**: "App Check token is invalid"

**Solution**: Add debug token in Firebase Console → App Check → Apps → LexiconFlow → Debug Tokens

## Next Steps

1. **Complete Firebase Setup**: Follow `../docs/FIREBASE_SETUP.md`
2. **Deploy Functions**: Run `firebase deploy --only functions`
3. **Update iOS Client**: Continue with Phase 3 (Cloud Translation Service)
4. **Monitor**: Set up Cloud Monitoring alerts

## Support

For issues or questions:
- Check Firebase Console logs
- Review `../docs/FIREBASE_SETUP.md`
- Open an issue on GitHub
