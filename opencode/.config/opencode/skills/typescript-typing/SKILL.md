---
name: typescript-typing
description: >
  Enforce strict TypeScript typing standards.
  Use when writing or reviewing TypeScript — functions, API boundaries, Prisma models,
  Zod schemas, shared contracts, or any import statement that touches a type.
---

This skill defines the TypeScript typing conventions. All generated or reviewed
code must comply with these rules. Read every rule before emitting any TypeScript.

## Core Principle: Infer Where Obvious, Explicit Where It Matters

TypeScript can infer primitives and simple return values — don't annotate what the compiler
already knows. But anything crossing a boundary (function param, API shape, shared contract)
must be explicitly typed.

```typescript
// ❌ Bad — annotating what TS already knows
const name: string = "yali"
const count: number = results.length

// ✅ Good — let TS infer trivial assignments
const name = "yali"
const count = results.length

// ✅ Always explicit — function params and return types at API/shared boundaries
function getClient(id: string): Promise<Client> { ... }
```

## Prisma Types

Use generated types from `@prisma/client` directly. Never manually retype DB models.

```typescript
import type { Client, Alert, Prisma } from '@prisma/client'

// Relations: use Prisma.XGetPayload
type ClientWithAlerts = Prisma.ClientGetPayload<{ include: { alerts: true } }>

// Partials: use Pick / Omit on generated types
type ClientSummary = Pick<Client, 'id' | 'name'>
```

## External Library Types

Import types from the library itself — never write manual interfaces for already-typed libs.

```typescript
import type { NextApiRequest, NextApiResponse } from 'next'
import type { Session } from 'next-auth'
import type { Message } from '@microsoft/microsoft-graph-types'
```

Only write a minimal `interface` or `declare module` for **untyped** libraries that ship no types
and have no `@types/*` package.

## Zod Is the Source of Truth — At Runtime Boundaries Only

Zod is for **runtime validation**, not for replacing TypeScript types everywhere.
Use it where data arrives from outside your codebase at runtime.
Derive TypeScript types from Zod schemas using `z.infer` — never write a separate interface
for something Zod already validates.

```typescript
const ClientSchema = z.object({ id: z.string(), name: z.string() })

// ✅ Derive — don't duplicate
type Client = z.infer<typeof ClientSchema>

// ❌ Never write this alongside a Zod schema
interface Client { id: string; name: string }
```

**Where Zod belongs:**

| Location | Use Zod? | Reason |
|---|---|---|
| API route input (POST body, query params) | ✅ Yes | Runtime unknown — user or client sent it |
| Third-party API responses (QRadar, Graph API) | ✅ Yes | External, can drift or be malformed |
| Webhook payloads (n8n, Telegram, Graph notifications) | ✅ Yes | Arrives over HTTP from outside |
| `searchParams` / `localStorage` / URL values | ✅ Yes | Runtime strings, shape is unknown |
| Your own internal API responses | ❌ No | TS already enforces the contract at build time |
| React component props | ❌ No | Compile-time — TS catches mismatches in the editor |
| Prisma query results (internal) | ❌ No | Already typed by Prisma |

**Shared schemas across the API boundary** — define once, use on both sides:

```typescript
// shared/schemas/alert.ts
export const CreateAlertSchema = z.object({
  clientId: z.string().cuid(),
  severity: z.enum(["LOW", "MEDIUM", "HIGH", "CRITICAL"]),
  description: z.string().min(1).max(2000),
})
export type CreateAlertInput = z.infer<typeof CreateAlertSchema>

// API route: parse incoming body with CreateAlertSchema
// Form: use CreateAlertSchema with zodResolver
// One source of truth — no duplication
```

## When to Write Explicit `type` or `interface`

Prefer `type` over `interface` — it's more flexible (unions, intersections, mapped types).
Write types explicitly only when they can't be inferred or derived:

```typescript
// ✅ Component props — still the clearest pattern
type AlertCardProps = {
  alert: AlertPreview
  onAcknowledge: (id: string) => void
}

// ✅ Domain aggregates that combine multiple sources
type ClientDashboardData = {
  client: Pick<Client, 'id' | 'name'>
  openAlerts: number
  lastActivity: Date
}

// ✅ ApiResponse wrapper — app-wide shared contract
type ApiResponse<T> = { data: T; error: null } | { data: null; error: string }
```

Do **not** write types for things already defined by Prisma, Zod, or a well-typed library.

## `import type` Is Mandatory

All type-only imports must use `import type`. This enforces erasure at compile time and
avoids accidental runtime imports.

```typescript
// ❌ Bad
import { Client } from '@prisma/client'

// ✅ Good
import type { Client } from '@prisma/client'
```

## API Response Shape

Every API route must return a typed `ApiResponse<T>` wrapper — never raw objects or
untyped shapes.

```typescript
// src/types/api.ts
type ApiResponse<T> = { data: T; error: null } | { data: null; error: string }
```

Usage in a route:

```typescript
import type { ApiResponse } from '@/types'
import type { Client } from '@prisma/client'

export async function GET(): Promise<NextResponse<ApiResponse<Client[]>>> {
  try {
    const clients = await prisma.client.findMany()
    return NextResponse.json({ data: clients, error: null })
  } catch (err) {
    return NextResponse.json({ data: null, error: 'Failed to fetch clients' }, { status: 500 })
  }
}
```

## Type File Placement

| Scope | Where to define |
|---|---|
| Used in **1 file** | Top of that file |
| Shared within a **feature** | Feature folder (e.g. `src/features/alerts/types.ts`) |
| Shared **app-wide (3+ unrelated files)** | `src/types/`, exported via `src/types/index.ts` |
| Shared across API boundary (form + route) | `src/shared/schemas/` — Zod schema + inferred type |

## Explicit Don'ts

| Rule | Bad | Good |
|---|---|---|
| No `any` | `let x: any` | `let x: unknown` + type guard |
| No silent assertions | `value as Client` | `value as Client // safe: validated by Zod above` |
| No duplicate types | Manual `interface User` next to `User` from Prisma | `import type { User } from '@prisma/client'` |
| No inline string concat types | `"pending" \| "active"` scattered everywhere | Single `Status` type in `src/types/` |
| No Zod for props | `z.object({ id: z.string() })` for React props | `type Props = { id: string }` |
| No Zod on your own API responses | Parsing `ApiResponse<T>` at client with Zod | Trust TS inference — you control both ends |
| No generated Zod from Prisma schema | `prisma-zod-generator` output used directly | Hand-written schemas scoped to each API contract |

## Checklist Before Submitting TypeScript Code

- [ ] All function parameters have explicit types
- [ ] All `import { SomeType }` changed to `import type { SomeType }`
- [ ] No `any` — replaced with `unknown` or proper narrowing
- [ ] Prisma model types imported from `@prisma/client`, not redefined
- [ ] Zod schemas own their types via `z.infer`, no duplicate interfaces
- [ ] Zod is only used at runtime trust boundaries (external APIs, webhooks, form input, URL params)
- [ ] Component props use explicit `type`, not Zod schemas
- [ ] Schemas shared across the API boundary live in `src/shared/schemas/`
- [ ] New types placed in the correct scope (file / feature / `src/types/`)
- [ ] API routes return `ApiResponse<T>`, not raw objects
- [ ] Any `as X` assertion has an inline comment explaining why it's safe
