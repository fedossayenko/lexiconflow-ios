/**
 * Structured Logger
 *
 * Provides consistent logging across Cloud Functions with metadata tracking.
 */

/**
 * Log level
 */
type LogLevel = "debug" | "info" | "warning" | "error";

/**
 * Structured log entry
 */
interface LogEntry {
  level: LogLevel;
  message: string;
  metadata?: Record<string, unknown>;
  timestamp: string;
}

/**
 * Logger utility with structured logging
 */
export const logger = {
  debug: (message: string, metadata?: Record<string, unknown>): void => {
    log("debug", message, metadata);
  },

  info: (message: string, metadata?: Record<string, unknown>): void => {
    log("info", message, metadata);
  },

  warning: (message: string, metadata?: Record<string, unknown>): void => {
    log("warning", message, metadata);
  },

  error: (message: string, error?: unknown): void => {
    const metadata = error instanceof Error ? {
      name: error.name,
      message: error.message,
      stack: error.stack,
    } : error;
    log("error", message, metadata as Record<string, unknown>);
  },
};

/**
 * Internal log function
 */
function log(level: LogLevel, message: string, metadata?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level,
    message,
    metadata,
    timestamp: new Date().toISOString(),
  };

  // In production, this would be sent to Cloud Logging
  // For now, use console with appropriate level
  const logFn = level === "error" ? console.error :
                  level === "warning" ? console.warn :
                  level === "debug" ? console.debug :
                  console.info;

  logFn(JSON.stringify(entry));
}

/**
 * Create a scoped logger with predefined metadata
 */
export function createScopedLogger(scope: string, metadata: Record<string, unknown> = {}) {
  return {
    debug: (message: string, additionalMetadata?: Record<string, unknown>) => {
      logger.debug(message, { scope, ...metadata, ...additionalMetadata });
    },
    info: (message: string, additionalMetadata?: Record<string, unknown>) => {
      logger.info(message, { scope, ...metadata, ...additionalMetadata });
    },
    warning: (message: string, additionalMetadata?: Record<string, unknown>) => {
      logger.warning(message, { scope, ...metadata, ...additionalMetadata });
    },
    error: (message: string, error?: unknown) => {
      logger.error(message, { scope, ...metadata, error });
    },
  };
}
