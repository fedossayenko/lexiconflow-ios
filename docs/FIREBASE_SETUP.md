# Firebase Setup Guide for LexiconFlow

This guide walks through setting up the Firebase backend infrastructure for LexiconFlow's secure AI proxy.

---

## Prerequisites

- **Node.js** 20+ LTS (`node --version`)
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Google Cloud CLI** (`gcloud init`)
- **Google Cloud account** with billing enabled

---

## Step 1: Create Firebase Project

### 1.1 Create Project in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Enter project ID: `lexiconflow-cloud` (or your preferred ID)
4. Accept Firebase terms
5. **Disable Google Analytics** for this project (we use custom analytics)
6. Click **"Create project"**

### 1.2 Initialize Firebase Locally

```bash
# Navigate to your project root
cd /Users/fedirsaienko/IdeaProjects/side/lexiconflow-ios

# Create cloud directory
mkdir -p cloud/functions

# Initialize Firebase
cd cloud
firebase init

# Follow prompts:
# - Select: Functions, Firestore
# - Select: Use existing project → lexiconflow-cloud
# - Language: TypeScript
# - ESLint: Yes
# - Install dependencies: Yes
```

---

## Step 2: Set Up Authentication

### 2.1 Enable Anonymous Authentication

1. Go to [Firebase Console → Authentication](https://console.firebase.google.com/project/lexiconflow-cloud/authentication)
2. Click **"Get Started"**
3. Select **"Anonymous"** tab
4. Enable **"Allow anonymous sign-in"**
5. Click **"Save"**

### 2.2 Configure Anonymous Auth Limits

```bash
# Set anonymous auth quota (optional)
gcloud firebase projects identityplatform config update \
  --project=lexiconflow-cloud \
  --anonymous-user-enabled=true
```

---

## Step 3: Set Up Firestore Database

### 3.1 Create Firestore Database

1. Go to [Firebase Console → Firestore](https://console.firebase.google.com/project/lexiconflow-cloud/firestore)
2. Click **"Create database"**
3. Choose **"Start in production mode"** (we'll add rules later)
4. Select a location: `us-central1` (or nearest to your users)
5. Click **"Done"**

### 3.2 Create Firestore Indexes

Create `cloud/firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "rateLimits",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "lastRefill",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "audioCache",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "textHash",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "userQuotas",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "resetAt",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes:

```bash
cd cloud
firebase deploy --only firestore:indexes
```

### 3.3 Configure Firestore Security Rules

Create `cloud/firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Rate limits: users can read/write their own
    match /rateLimits/{document=**} {
      allow read, write: if request.auth != null;
    }

    // Audio cache: public read, authenticated write
    match /audioCache/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // User quotas: users can read their own
    match /userQuotas/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null; // Cloud Functions only
    }

    // Nonces: prevent replay attacks
    match /nonces/{document=**} {
      allow create: if request.auth != null;
      allow read, write: if false;
    }
  }
}
```

Deploy rules:

```bash
cd cloud
firebase deploy --only firestore:rules
```

---

## Step 4: Set Up Google Cloud Secret Manager

### 4.1 Enable Secret Manager API

```bash
gcloud services enable secretmanager.googleapis.com \
  --project=lexiconflow-cloud
```

### 4.2 Create Secrets

**Gemini API Key**:
```bash
# Create secret
gcloud secrets create gemini-api-key \
  --project=lexiconflow-cloud \
  --replication-policy="automatic"

# Add your API key
echo "YOUR_GEMINI_API_KEY_HERE" | \
  gcloud secrets versions add gemini-api-key \
  --project=lexiconflow-cloud \
  --data-file=-
```

**Zhipu API Key**:
```bash
# Create secret
gcloud secrets create zhipu-api-key \
  --project=lexiconflow-cloud \
  --replication-policy="automatic"

# Add your API key
echo "YOUR_ZHIPU_API_KEY_HERE" | \
  gcloud secrets versions add zhipu-api-key \
  --project=lexiconflow-cloud \
  --data-file=-
```

### 4.3 Grant Cloud Functions Access

```bash
# Get the default Cloud Functions service account
PROJECT_ID="lexiconflow-cloud"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
CLOUD_FUNCTIONS_SA="service-${PROJECT_NUMBER}@gcf-admin-robot.iam.gserviceaccount.com"

# Grant access to Gemini secret
gcloud secrets add-iam-policy-binding gemini-api-key \
  --project=$PROJECT_ID \
  --member="serviceAccount:$CLOUD_FUNCTIONS_SA" \
  --role="roles/secretmanager.secretAccessor"

# Grant access to Zhipu secret
gcloud secrets add-iam-policy-binding zhipu-api-key \
  --project=$PROJECT_ID \
  --member="serviceAccount:$CLOUD_FUNCTIONS_SA" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Step 5: Set Up App Check

### 5.1 Register iOS App in Firebase Console

1. Go to [Firebase Console → App Check](https://console.firebase.google.com/project/lexiconflow-cloud/appcheck)
2. Click **"Get Started"**
3. Select **"iOS"** platform
4. Enter bundle ID: `com.lexiconflow.LexiconFlow`
5. Click **"Register app"**

### 5.2 Configure App Attest (Production)

1. Download the `GoogleService-Info.plist` file
2. Add it to your Xcode project (target: LexiconFlow)
3. Enable **App Attest** for production use

### 5.3 Add Debug Token (Development)

1. In App Check console, click **"Add debug token"**
2. Enter a debug token label (e.g., "local-dev")
3. Copy the generated debug token
4. Use this token in development builds

---

## Step 6: Install Cloud Functions Dependencies

```bash
cd cloud/functions

# Install core dependencies
npm install --save firebase-functions@^5.0.0
npm install --save firebase-admin@^12.0.0

# Install AI SDKs
npm install --save @google/generative-ai@^0.21.0
npm install --save zhipuai@^4.0.0

# Install Secret Manager
npm install --save @google-cloud/secret-manager@^5.0.0

# Install development dependencies
npm install --save-dev typescript@^5.0.0
npm install --save-dev @types/node@^20.0.0
```

---

## Step 7: Deploy Cloud Functions

```bash
cd cloud

# Build and deploy
firebase deploy --only functions

# Verify deployment
firebase functions:list
```

Expected output:
```
✓ functions translateV2 (us-central1)
✓ functions ttsV2 (us-central1)
✓ functions generateSentences (us-central1)
```

---

## Step 8: Configure iOS App

### 8.1 Add Firebase SDKs via Swift Package Manager

In Xcode:
1. **File → Add Package Dependencies...**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select packages:
   - FirebaseAuth
   - FirebaseAppCheck
   - FirebaseFunctions
4. Add to **LexiconFlow** target

### 8.2 Add GoogleService-Info.plist

1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode project (target: LexiconFlow)
3. Verify it's included in "Copy Bundle Resources"

### 8.3 Test Connection

Run the app and verify console output:
```
[FirebaseService] Firebase configured successfully
[FirebaseService] Signed in anonymously: [USER_ID]
[FirebaseService] App Check debug token: [DEBUG_TOKEN]
```

---

## Step 9: Local Development (Optional)

### 9.1 Start Firebase Emulator

```bash
cd cloud
firebase emulators:start --only functions,firestore,auth
```

### 9.2 Configure iOS to Use Emulator

In `FirebaseService.swift` (development builds only):
```swift
#if DEBUG
Functions.functions().useFunctionsEmulator(origin: "http://localhost:5001")
#endif
```

---

## Verification Checklist

- [ ] Firebase project created
- [ ] Anonymous auth enabled
- [ ] Firestore database created
- [ ] Firestore indexes deployed
- [ ] Firestore security rules deployed
- [ ] Google Cloud secrets created
- [ ] Cloud Functions deployed
- [ ] App Check configured
- [ ] iOS Firebase SDKs added
- [ ] GoogleService-Info.plist added
- [ ] iOS app connects to Firebase successfully

---

## Troubleshooting

### Cloud Functions Deployment Fails

**Error**: "PERMISSION_DENIED: IAM permission"

**Solution**: Grant Cloud Functions service account the required roles:
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

### App Check Debug Token Invalid

**Error**: "App Check token is invalid"

**Solution**: Ensure the debug token is added in Firebase Console → App Check → Apps → [Your App] → Debug Tokens

---

## Next Steps

After completing this guide:

1. **Phase 3**: Migrate Translation Service to use Cloud Functions
2. **Phase 4**: Implement Cloud Audio Service
3. **Phase 5**: Cleanup and documentation

See the main implementation plan for details.
