---
name: api-routes-js
description: >
  Standards for writing Next.js App Router API routes.
  Use when creating or modifying any file under `app/api/`. Covers request handling,
  Zod validation, Prisma queries, authentication, response shaping, and logging setup.
---

This skill covers the full anatomy of a correct API route in this project. Follow every
section. Cross-reference the `typescript-typing`, `logging`, and `error-handling` skills
when writing any route — they are all required to be applied together.

## Route File Anatomy

A complete API route follows this exact structure, top-to-bottom:

```typescript
// 1. Imports — external first, then internal, then types
import { NextResponse } from 'next/server'
import { z } from 'zod'
import { prisma } from '@/lib/prisma'
import { logger } from '@/lib/logger'
import { auth } from '@/lib/auth'
import type { ApiResponse } from '@/types'
import type { Alert } from '@prisma/client'

// 2. Input schema (if route accepts a body or query params)
const BodySchema = z.object({
  clientId: z.string().uuid(),
  severity: z.enum(['low', 'medium', 'high']),
})

// 3. Handler
export async function POST(req: Request) {
  // 3a. Request-scoped logger
  const requestId = crypto.randomUUID()
  const requestLogger = logger.child({ requestId, path: '/api/alerts', method: 'POST' })
  requestLogger.info('API request received')

  // 3b. Auth check
  const session = await auth()
  if (!session?.user) {
    requestLogger.warn('Unauthenticated request')
    return NextResponse.json(
      { data: null, error: 'Unauthorized' } satisfies ApiResponse<never>,
      { status: 401 }
    )
  }

  // 3c. Input validation
  const parsed = BodySchema.safeParse(await req.json())
  if (!parsed.success) {
    requestLogger.warn({ errors: parsed.error.flatten() }, 'Request validation failed')
    return NextResponse.json(
      { data: null, error: 'Invalid request body' } satisfies ApiResponse<never>,
      { status: 400 }
    )
  }

  const { clientId, severity } = parsed.data

  // 3d. Business logic inside try/catch
  try {
    const alert = await prisma.alert.create({
      data: { clientId, severity },
    })
    requestLogger.info({ alertId: alert.id, clientId }, 'Alert created')
    return NextResponse.json(
      { data: alert, error: null } satisfies ApiResponse<Alert>,
      { status: 201 }
    )
  } catch (err) {
    requestLogger.error({ err, requestId, clientId }, 'Failed to create alert')
    return NextResponse.json(
      { data: null, error: 'Failed to create alert' } satisfies ApiResponse<never>,
      { status: 500 }
    )
  }
}
```

## Response Shape

All routes return `ApiResponse<T>`. This type lives in `src/types/api.ts`:

```typescript
type ApiResponse<T> = { data: T; error: null } | { data: null; error: string }
```

Use `satisfies ApiResponse<T>` on every `NextResponse.json(...)` call to get compile-time
verification of the response shape.

Never return raw objects — not even for simple routes.

## Prisma Usage

- Import from `@/lib/prisma`, never instantiate `new PrismaClient()` in a route
- Include relations explicitly when needed — don't over-fetch by default
- Use generated Prisma types, never rewrite them

```typescript
import { prisma } from '@/lib/prisma'
import type { Prisma } from '@prisma/client'

// With relation
type ClientWithAlerts = Prisma.ClientGetPayload<{ include: { alerts: true } }>

const client = await prisma.client.findUnique({
  where: { id: clientId },
  include: { alerts: true },
})
```

## Zod Validation Rules

- Every route that accepts a request body **must** define and apply a Zod schema
- Use `.safeParse()` — never `.parse()` (throws uncaught errors)
- Return `400` on validation failure with `parsed.error.flatten()` in the log
- Derive TypeScript types from the schema with `z.infer`, don't duplicate them

```typescript
const BodySchema = z.object({ ... })
type Body = z.infer<typeof BodySchema>  // use this inside the handler
```

## Import Ordering

Group imports in this order with a blank line between groups:

```typescript
// 1. External packages
import { NextResponse } from 'next/server'
import { z } from 'zod'

// 2. Internal aliases (@/*)
import { prisma } from '@/lib/prisma'
import { logger } from '@/lib/logger'

// 3. Type-only imports (always `import type`)
import type { ApiResponse } from '@/types'
import type { Alert } from '@prisma/client'
```

## Authentication

Check the session before any DB access. Use `auth()` from `@/lib/auth` (Better Auth).

```typescript
const session = await auth()
if (!session?.user) {
  return NextResponse.json({ data: null, error: 'Unauthorized' }, { status: 401 })
}
```

For tenant isolation, always filter queries by the authenticated user's `clientId` or
`organizationId` — never trust a clientId from the request body alone without verifying
it matches the session's tenant.

## Route Segments Convention

- File names: `app/api/[resource]/route.ts` for collections, `app/api/[resource]/[id]/route.ts` for single resources
- Export named functions matching the HTTP verb: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
- Don't put multiple unrelated resources in one route file

## Checklist

- [ ] All imports ordered: external → internal → `import type`
- [ ] Request-scoped `requestLogger` created at top of handler with `requestId`, `path`, `method`
- [ ] Auth check before any DB access, returns `401` if unauthenticated
- [ ] Request body validated with `.safeParse()` against a Zod schema, returns `400` on failure
- [ ] All DB access uses `prisma` from `@/lib/prisma`
- [ ] Try/catch wraps DB and business logic
- [ ] All responses are `ApiResponse<T>` — never raw objects
- [ ] `satisfies ApiResponse<T>` used for compile-time shape checking
- [ ] Error response body contains a sanitized string, not `err.message` or stack
- [ ] Multi-tenant routes verify the requested resource belongs to the session's tenant
