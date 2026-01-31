/**
 * Custom Error Classes
 * Provides typed errors for validation and business logic failures
 * 
 * @module utils/errors
 */

/**
 * ValidationError - Thrown when data doesn't meet schema requirements
 * Used by mappers and adapters to reject invalid payloads BEFORE network requests
 */
export class ValidationError extends Error {
    public readonly field: string;
    public readonly expectedType: string;
    public readonly receivedValue: any;

    constructor(
        field: string,
        message: string,
        options?: { expectedType?: string; receivedValue?: any }
    ) {
        super(`[ValidationError] ${field}: ${message}`);
        this.name = 'ValidationError';
        this.field = field;
        this.expectedType = options?.expectedType || 'unknown';
        this.receivedValue = options?.receivedValue;

        // Maintains proper stack trace for where error was thrown
        Error.captureStackTrace?.(this, ValidationError);
    }

    /**
     * Logs the validation error to console with structured format
     */
    logToConsole(): void {
        console.error(`🚫 ${this.name}:`, {
            field: this.field,
            message: this.message,
            expected: this.expectedType,
            received: this.receivedValue
        });
    }
}

/**
 * RLSViolationError - Thrown when RLS-required fields are missing
 */
export class RLSViolationError extends ValidationError {
    constructor(field: string, message?: string) {
        super(
            field,
            message || `RLS-required field "${field}" is missing or invalid`,
            { expectedType: 'uuid (non-empty)', receivedValue: undefined }
        );
        this.name = 'RLSViolationError';
    }
}

/**
 * SchemaDriftError - Thrown when payload structure doesn't match DB schema
 */
export class SchemaDriftError extends Error {
    public readonly obsoleteFields: string[];
    public readonly missingFields: string[];

    constructor(tableName: string, obsoleteFields: string[], missingFields: string[]) {
        super(`[SchemaDriftError] Table "${tableName}": Payload structure incompatible with DB schema`);
        this.name = 'SchemaDriftError';
        this.obsoleteFields = obsoleteFields;
        this.missingFields = missingFields;
    }
}
