---
name: error-handling-js
description: >
  Enforce consistent error handling patterns.
  Use when writing API routes, service functions, or any code that can fail —
  covers try/catch structure, HTTP status codes, error logging, and safe response shaping.
---

This skill defines how errors are caught, logged, and returned across the codebase.
Read all rules before writing any try/catch or error response.

## API Route Pattern

Every API route wraps its logic in a single top-level try/catch. The catch block:
1. Logs the error with full context using the request-scoped logger
2. Returns a properly-shaped `ApiResponse<T>` with an appropriate HTTP status code
3. Never exposes internal error details in the response body

```typescript
import { logger } from '@/lib/logger'
import { NextResponse } from 'next/server'
import type { ApiResponse } from '@/types'
import type { Client } from '@prisma/client'

export async function GET(req: Request) {
  const requestId = crypto.randomUUID()
  const requestLogger = logger.child({ requestId, path: '/api/clients', method: 'GET' })

  requestLogger.info('API request received')

  try {
    const clients = await prisma.client.findMany()
    requestLogger.info({ count: clients.length }, 'Clients fetched')
    return NextResponse.json({ data: clients, error: null } satisfies ApiResponse<Client[]>)
  } catch (err) {
    requestLogger.error({ err, requestId }, 'Failed to fetch clients')
    return NextResponse.json(
      { data: null, error: 'Failed to fetch clients' } satisfies ApiResponse<never>,
      { status: 500 }
    )
  }
}
```

## HTTP Status Code Reference

Use the correct status code — never return 200 for an error.

| Scenario | Status |
|---|---|
| Success | `200` |
| Created | `201` |
| Bad request / validation failure | `400` |
| Unauthenticated | `401` |
| Unauthorized (authenticated but not allowed) | `403` |
| Resource not found | `404` |
| Conflict (e.g. duplicate) | `409` |
| Unprocessable entity | `422` |
| Internal server error | `500` |

## Throw Errors in Application Logic

Service functions and library code should `throw new Error(...)` rather than returning
sentinel values or null on failure. Let the calling API route catch and handle it.

```typescript
// ✅ Throw in service layer
export async function getClientOrThrow(id: string): Promise<Client> {
  const client = await prisma.client.findUnique({ where: { id } })
  if (!client) throw new Error(`Client not found: ${id}`)
  return client
}

// ✅ Catch in API route
try {
  const client = await getClientOrThrow(id)
  return NextResponse.json({ data: client, error: null })
} catch (err) {
  requestLogger.error({ err, clientId: id }, 'Client lookup failed')
  return NextResponse.json({ data: null, error: 'Client not found' }, { status: 404 })
}
```

## Never Expose Internals in Response Bodies

The `error` field in `ApiResponse<T>` is a user-facing string. It must never contain:
- Stack traces
- Prisma error messages
- SQL query fragments
- Internal IDs or file paths

Log the full error internally, return a sanitized message externally.

```typescript
// ❌ Leaks internals
return NextResponse.json({ data: null, error: err.message })

// ✅ Safe external message, full detail in log
requestLogger.error({ err, alertId }, 'QRadar sync failed')
return NextResponse.json({ data: null, error: 'Alert sync failed' }, { status: 500 })
```

## Validation Errors (Zod)

When Zod validation fails, return `400` with the formatted Zod errors — these are
safe to return because they describe input shape, not internals.

```typescript
import { z } from 'zod'

const BodySchema = z.object({ clientId: z.string().uuid(), severity: z.enum(['low', 'medium', 'high']) })

const parsed = BodySchema.safeParse(await req.json())
if (!parsed.success) {
  requestLogger.warn({ errors: parsed.error.flatten() }, 'Request validation failed')
  return NextResponse.json(
    { data: null, error: 'Invalid request body' },
    { status: 400 }
  )
}
```

## Error Context IDs

The error log must include every ID available at the point of failure so the incident
can be traced end-to-end without reading the code:

```typescript
requestLogger.error({ err, requestId, userId, clientId, alertId }, 'Alert processing failed')
```

Include as many as are relevant: `requestId`, `userId`, `clientId`, `alertId`,
`messageId`, `conversationId`, `queryId`, `offenseId`, `agentId`, `threatId`.

## Checklist

- [ ] Every API route has a single top-level try/catch
- [ ] catch block logs `{ err, requestId, ...entityIds }` before responding
- [ ] Response body error string is sanitized — no internal details
- [ ] HTTP status code matches the failure type (not always 500)
- [ ] Service/lib functions throw `new Error(...)` rather than returning null on failure
- [ ] Zod parse failures return 400, not 500
- [ ] No `catch (err) { }` (swallowed errors) anywhere
