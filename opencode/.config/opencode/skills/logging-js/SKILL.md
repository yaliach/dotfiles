---
name: logging-js
description: >
  Enforce Pino structured logging conventions.
  Use when writing any JavaScript/TypeScript server-side code that emits logs — API routes, lib functions,
  background jobs, or any service layer. Replaces all console.* usage.
---

This skill defines how logging must be done across the project. All server-side code must
follow these patterns exactly. No `console.log`, `console.error`, or any `console.*` call
is ever acceptable — they must all be replaced with Pino logger calls.

## The Logger

Import the shared Pino instance from `@/lib/logger`. Never instantiate a new Pino logger
directly in a feature file.

```typescript
import { logger } from '@/lib/logger'
```

## API Route Logging

Every API route creates a **request-scoped child logger** at the top of the handler.
This attaches a `requestId` and route context to every log line emitted during that request.

```typescript
import { logger } from '@/lib/logger'
import type { ApiResponse } from '@/types'

export async function GET(req: Request) {
  const requestId = crypto.randomUUID()
  const requestLogger = logger.child({ requestId, path: '/api/clients', method: 'GET' })

  requestLogger.info('API request received')

  try {
    // ... handler logic
    requestLogger.info({ count: clients.length }, 'Clients fetched successfully')
    return NextResponse.json({ data: clients, error: null })
  } catch (err) {
    requestLogger.error({ err, requestId }, 'Failed to fetch clients')
    return NextResponse.json({ data: null, error: 'Internal server error' }, { status: 500 })
  }
}
```

## Library / Service Function Logging

Functions in `@/lib/*` or service modules create a **function-scoped child logger** with
a `service` tag and any relevant entity IDs.

```typescript
import { logger } from '@/lib/logger'

export async function syncAlertEmails(alertId: string) {
  const fnLogger = logger.child({ service: 'email-sync', alertId })

  fnLogger.info('Starting email sync')

  try {
    // ...
    fnLogger.info({ messageCount: messages.length }, 'Email sync complete')
  } catch (err) {
    fnLogger.error({ err }, 'Email sync failed')
    throw err
  }
}
```

## Structured First Parameter

The **first argument** to any log call must be an **object** for machine-readable fields.
The **second argument** is the human-readable message string.

```typescript
// ✅ Structured — filterable by field in any log aggregator
logger.info({ userId, count: results.length }, 'Users fetched successfully')
logger.warn({ clientId, retryAttempt }, 'QRadar query timeout, retrying')
logger.error({ err, alertId, requestId }, 'Alert processing failed')

// ❌ String concatenation — unstructured, unsearchable
logger.info('Fetched ' + results.length + ' users for ' + userId)
logger.error('Alert ' + alertId + ' failed: ' + err.message)
```

## Log Levels

| Level | When to use |
|---|---|
| `debug` | Verbose internals — query params, intermediate values, loop state. Off in production. |
| `info` | Normal lifecycle events — request received, operation complete, sync started/ended. |
| `warn` | Recoverable issues — retries, fallbacks, unexpected-but-handled states. |
| `error` | Failures that affect the user or require investigation. Always pass `{ err }`. |

## Error Logging

Always pass the error object as `err` inside the first-argument object. This captures the
full stack trace in the structured output.

```typescript
// ✅ Full stack trace captured
requestLogger.error({ err: error, userId, alertId }, 'Failed to process alert')

// ❌ Only the message, no stack trace
requestLogger.error('Failed to process alert: ' + error.message)
```

## Context IDs to Include

Include relevant entity IDs so every log line can be correlated:

- API routes: `requestId` (always), `userId` (if authenticated), route-specific entity IDs
- Alert operations: `alertId`, `clientId`
- Email operations: `alertId`, `messageId`, `conversationId`
- QRadar operations: `queryId`, `offenseId`
- SentinelOne operations: `agentId`, `threatId`

## Security

The logger at `@/lib/logger` is configured to **automatically redact**:
- `password`, `token`, `apiKey`, `secret`, `authorization`

Never manually log these fields. If you need to confirm a token was received, log its
presence, not its value:

```typescript
// ✅ Safe
fnLogger.info({ hasToken: !!token }, 'Graph API token resolved')

// ❌ Never
fnLogger.info({ token }, 'Graph API token resolved')
```

## Checklist

- [ ] Zero `console.*` calls in the diff
- [ ] API routes have a `requestLogger` with `requestId`, `path`, and `method`
- [ ] Lib functions have a child logger with `service` and relevant entity IDs
- [ ] First argument to every log call is an object, second is a string
- [ ] Errors are logged with `{ err: error, ...context }`, not just the message
- [ ] No sensitive values (tokens, passwords, keys) in any log call
- [ ] Log level matches the severity described in the level table above
