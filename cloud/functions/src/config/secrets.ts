/**
 * Google Cloud Secret Manager Integration
 *
 * Provides secure access to API keys stored in Google Cloud Secret Manager.
 * Keys are loaded into function instance memory at runtime, never logged.
 */

import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import { logger } from "../utils/logger";

// Secret Manager client
const client = new SecretManagerServiceClient();

/**
 * Cached secrets (in-memory for function instance lifetime)
 * Reduces Secret Manager API calls for warm function instances
 */
const secretCache = new Map<string, string>();

/**
 * Get a secret value from Secret Manager
 *
 * @param name - Secret name (without "projects/{project}/secrets/" prefix)
 * @returns The secret value as a string
 * @throws Error if secret cannot be accessed
 */
export async function getSecret(name: string): Promise<string> {
  // Check cache first
  if (secretCache.has(name)) {
    logger.debug(`Secret cache hit: ${name}`);
    return secretCache.get(name)!;
  }

  try {
    const projectId = process.env.GCP_PROJECT_ID || process.env.GCLOUD_PROJECT;
    if (!projectId) {
      throw new Error("GCP_PROJECT_ID or GCLOUD_PROJECT environment variable not set");
    }

    const secretPath = `projects/${projectId}/secrets/${name}/versions/latest`;

    logger.debug(`Fetching secret: ${name}`);

    const [version] = await client.accessSecretVersion({
      name: secretPath,
    });

    if (!version.payload?.data) {
      throw new Error(`Secret ${name} has no data`);
    }

    const secretValue = version.payload.data.toString();

    // Cache the secret
    secretCache.set(name, secretValue);

    logger.debug(`Secret fetched and cached: ${name}`);

    return secretValue;
  } catch (error) {
    logger.error(`Failed to fetch secret ${name}:`, error);
    throw new Error(`Failed to access secret: ${name}`);
  }
}

/**
 * Get the Gemini API key
 */
export async function getGeminiAPIKey(): Promise<string> {
  return getSecret("gemini-api-key");
}

/**
 * Get the Zhipu API key
 */
export async function getZhipuAPIKey(): Promise<string> {
  return getSecret("zhipu-api-key");
}

/**
 * Clear the secret cache (for testing or force refresh)
 */
export function clearSecretCache(): void {
  secretCache.clear();
  logger.debug("Secret cache cleared");
}
