---
name: better-auth-integration
description: >
  Better-auth v1.5+ setup and configuration patterns for Next.js 16 App Router.
  Use when setting up authentication, configuring plugins (2FA, admin, API keys),
  implementing rate limiting, or integrating session management in Server Components
  and API routes. Covers both server and client configuration.
---

This skill covers the complete Better-auth integration pattern used in this project.
Better-auth is a modern authentication library with a plugin system that provides
email/password auth, 2FA, admin roles, API keys, and rate limiting out of the box.

Cross-reference the `typescript-typing`, `logging-js`, and `rbac-permissions` skills
when implementing auth-related features.

## Server Configuration (lib/auth.ts)

The server-side auth configuration is the single source of truth for authentication
behavior. This file exports the `auth` object used throughout the application.

```typescript
import { betterAuth } from "better-auth"
import { prismaAdapter } from "better-auth/adapters/prisma"
import { twoFactor, admin } from "better-auth/plugins" 
import { apiKey } from "@better-auth/api-key"
import { nextCookies } from "better-auth/next-js"
import { prisma } from "./prisma"

export const auth = betterAuth({
  // Database adapter - MUST use Prisma adapter with provider specified
  database: prismaAdapter(prisma, { provider: "postgresql" }),

  // Email and password authentication configuration
  emailAndPassword: {
    enabled: true,
    autoSignIn: false,              // IMPORTANT: Don't auto sign-in to allow 2FA
    requireEmailVerification: false, // Set to true in production if email service configured
    minPasswordLength: 8,
    maxPasswordLength: 128,
  },

  // Global rate limiting - applies to all auth endpoints
  rateLimit: {
    enabled: true,
    window: 10,        // Time window in seconds
    max: 100,          // Max requests per window
    storage: "database",
    modelName: "rateLimit", // Prisma model name for rate limit storage
    
    // Custom rules for specific endpoints (stricter on sensitive routes)
    customRules: {
      "/sign-in/email": { window: 60, max: 10 }, // Prevent brute force
    },
  },

  // Plugin configuration
  plugins: [
    // Two-factor authentication (TOTP)
    twoFactor({
      issuer: "App",  // Displayed in authenticator apps
      totpOptions: {
        period: 30,  // TOTP code validity period (30 seconds)
      },
      backupCodeOptions: {
        storeBackupCodes: "encrypted", // Encrypt backup codes at rest
      },
    }),

    // Admin plugin - adds role-based access control
    admin({
      defaultRole: "user",   // Role assigned on sign-up
      adminRole: "admin",    // Role that gets admin privileges
    }),

    // API Key plugin - programmatic access with x-api-key header
    apiKey({
      enableSessionForAPIKeys: true,  // API key acts as session
      rateLimit: {
        enabled: true,
        timeWindow: 60_000,           // 1 minute in milliseconds
        maxRequests: 100,
      },
      defaultPrefix: "ya_",  // All keys start with "ya_"
    }),

    // Next.js cookies plugin - handles cookie serialization
    nextCookies(),
  ],
})
```

### Key Configuration Decisions

**autoSignIn: false**
- Required for 2FA flow - user must complete 2FA setup/verification before full access
- Without this, users bypass 2FA on first sign-in

**Rate Limiting Strategy**
- Global: 100 req/10s (generous for normal use, blocks spam)
- Sign-in: 10 req/60s (strict to prevent brute force)
- API keys: 100 req/minute (separate from global limits)

**Database Storage**
- Rate limits stored in database (not memory) for persistence across restarts
- Requires `rateLimit` model in Prisma schema

## Client Configuration (lib/auth-client.ts)

The client-side auth configuration provides React hooks and methods for authentication
actions. This is used in client components and auth pages.

```typescript
import { createAuthClient } from "better-auth/react"
import { twoFactorClient } from "better-auth/client/plugins"

export const authClient = createAuthClient({
  baseURL: process.env.NEXT_PUBLIC_APP_URL,
  
  plugins: [
    twoFactorClient({
      // Redirect callback when 2FA is required
      onTwoFactorRedirect() {
        window.location.href = "/auth/2fa-verify"
      }
    })
  ]
})

// Export hooks for convenience
export const { useSession, signIn, signOut } = authClient
```

### Client Hooks Usage

```typescript
// In client components
"use client"
import { useSession } from "@/lib/auth-client"

export default function Component() {
  const { data: session, isPending } = useSession()
  
  if (isPending) return <div>Loading...</div>
  if (!session) return <div>Not authenticated</div>
  
  return <div>Welcome {session.user.name}</div>
}
```

## Session Management Patterns

### In Server Components (Pages, Layouts)

```typescript
import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"

export default async function ProtectedPage() {
  // Get session from request headers
  const session = await auth.api.getSession({ 
    headers: await headers() 
  })
  
  // Check authentication
  if (!session?.user) {
    redirect("/auth/sign-in")
  }
  
  // Access user data (Better-auth auto-adds custom fields like role)
  const userName = session.user.name
  const userRole = session.user.role  // From admin plugin
  
  return <div>Welcome {userName}</div>
}
```

**IMPORTANT:** Always use `await headers()` in Next.js 15+ to access headers.

### In API Routes

```typescript
import { auth } from "@/lib/auth"
import { NextResponse } from "next/server"
import type { ApiResponse } from "@/types"

export async function GET(req: Request) {
  const requestLogger = logger.child({ requestId: crypto.randomUUID() })
  
  // Get session from request headers (no await headers() needed in API routes)
  const session = await auth.api.getSession({ headers: req.headers })
  
  // Check authentication
  if (!session?.user) {
    requestLogger.warn('Unauthenticated request')
    return NextResponse.json(
      { data: null, error: 'Unauthorized' } satisfies ApiResponse<never>,
      { status: 401 }
    )
  }
  
  // Use session data
  const userId = session.user.id
  const userRole = session.user.role
  
  // Continue with business logic...
}
```

### In Client Components

```typescript
"use client"
import { useSession } from "@/lib/auth-client"
import { useRouter } from "next/navigation"
import { useEffect } from "react"

export default function ClientComponent() {
  const { data: session, isPending } = useSession()
  const router = useRouter()
  
  // Redirect if not authenticated
  useEffect(() => {
    if (!isPending && !session) {
      router.push("/auth/sign-in")
    }
  }, [session, isPending, router])
  
  if (isPending) return <div>Loading...</div>
  if (!session) return null
  
  return <div>Protected content</div>
}
```

## Auth Route Protection (Whitelisting)

Better-auth provides a catch-all route handler at `/api/auth/[...all]`. In production,
you should whitelist only the endpoints your app uses to reduce attack surface.

```typescript
// app/api/auth/[...all]/route.ts
import { auth } from "@/lib/auth"
import { toNextJsHandler } from "better-auth/next-js"
import { NextRequest, NextResponse } from "next/server"

// Whitelist specific Better-auth actions
const ALLOWED_AUTH_PREFIXES = [
  "sign-in",
  "sign-out", 
  "sign-up",
  "get-session",
  "csrf",
  "two-factor",
  "callback",
]

export const GET = async (req: NextRequest) => {
  const pathname = req.nextUrl.pathname
  const action = pathname.split("/api/auth/")[1]?.split("/")[0]
  
  // Check if action is whitelisted
  if (!ALLOWED_AUTH_PREFIXES.some(prefix => action?.startsWith(prefix))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }
  
  return toNextJsHandler(auth)(req)
}

export const POST = async (req: NextRequest) => {
  // Same whitelisting logic for POST
  const pathname = req.nextUrl.pathname
  const action = pathname.split("/api/auth/")[1]?.split("/")[0]
  
  if (!ALLOWED_AUTH_PREFIXES.some(prefix => action?.startsWith(prefix))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 })
  }
  
  return toNextJsHandler(auth)(req)
}
```

## Sign-Up Flow

```typescript
// Using better-auth's sign-up method (via auth.api in server context)
const result = await auth.api.signUpEmail({
  body: {
    email: "user@example.com",
    password: "securepassword",
    name: "John Doe",
  },
})

if (!result || !result.user) {
  throw new Error('Failed to create user')
}

// Update role if needed (default is "user" from admin plugin)
if (role !== 'user') {
  await prisma.user.update({
    where: { id: result.user.id },
    data: { role },
  })
}
```

## API Key Authentication

API keys work seamlessly with the session system. When a request includes the
`x-api-key` header, Better-auth validates it and creates a session automatically.

```typescript
// Client making API request with key
const response = await fetch("/api/v1/users", {
  headers: {
    "x-api-key": "ya_your_api_key_here",
    "Content-Type": "application/json",
  },
})

// Server handling request (same code as session-based auth)
const session = await auth.api.getSession({ headers: req.headers })
if (!session?.user) {
  return NextResponse.json({ data: null, error: 'Unauthorized' }, { status: 401 })
}

// session.user contains the API key owner's user data
```

## Prisma Schema Requirements

Better-auth requires specific models in your Prisma schema. With the plugins enabled,
you need:

```prisma
model User {
  id                String         @id @default(cuid())
  name              String
  email             String         @unique
  emailVerified     Boolean        @default(false)
  image             String?
  createdAt         DateTime       @default(now())
  updatedAt         DateTime       @updatedAt
  role              String         @default("user")  // From admin plugin
  banned            Boolean?       @default(false)
  banReason         String?
  twoFactorEnabled  Boolean?       @default(false)   // From twoFactor plugin
  
  sessions          Session[]
  accounts          Account[]
  twoFactor         TwoFactor[]
}

model Session {
  id                String    @id
  expiresAt         DateTime
  token             String    @unique
  ipAddress         String?
  userAgent         String?
  userId            String
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

model Account {
  id                String    @id
  accountId         String
  providerId        String
  userId            String
  accessToken       String?
  refreshToken      String?
  idToken           String?
  expiresAt         DateTime?
  password          String?   // For email/password auth
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

model Verification {
  id                String    @id
  identifier        String
  value             String
  expiresAt         DateTime
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
}

model TwoFactor {
  id                String    @id
  secret            String
  backupCodes       String    // Encrypted JSON array
  userId            String
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

model Apikey {
  id                      String    @id @default(cuid())
  name                    String
  keyPrefix               String
  hashedKey               String    @unique
  userId                  String
  expiresAt               DateTime?
  createdAt               DateTime  @default(now())
  lastUsedAt              DateTime?
  enabled                 Boolean   @default(true)
  
  // Rate limiting fields (managed by apiKey plugin)
  requestCount            Int?      @default(0)
  remaining               Int?
  lastRequest             DateTime?
  rateLimitTimeWindow     Int?      @default(60000)
  rateLimitMax            Int?      @default(100)
}

model rateLimit {
  id                String    @id
  key               String    @unique
  count             Int       @default(0)
  lastRequest       DateTime  @default(now())
}
```

## Environment Variables

Required environment variables for Better-auth:

```env
# Database connection (required)
DATABASE_URL="postgresql://user:password@localhost:5432/myapp"

# App URL (required for redirects and cookies)
NEXT_PUBLIC_APP_URL="http://localhost:3000"

# Better-auth secret (generate with: openssl rand -base64 32)
BETTER_AUTH_SECRET="your-secret-here"

# Optional: Email service for verification
# EMAIL_SERVER_HOST=smtp.example.com
# EMAIL_SERVER_PORT=587
# EMAIL_FROM=noreply@example.com
```

## Common Patterns

### Check if user is admin

```typescript
const session = await auth.api.getSession({ headers: req.headers })
const isAdmin = session?.user?.role === "admin"
```

### Force 2FA setup on first login

```typescript
// In sign-in callback or after successful sign-in
if (!session.user.twoFactorEnabled) {
  redirect("/auth/2fa-setup")
}
```

### Restart user's 2FA (admin action)

```typescript
// Delete user's 2FA records
await prisma.twoFactor.deleteMany({
  where: { userId: targetUserId }
})

// Update user's twoFactorEnabled flag
await prisma.user.update({
  where: { id: targetUserId },
  data: { twoFactorEnabled: false }
})
```

## Testing Authentication

### Manual Testing Checklist
- [ ] Sign up with email/password
- [ ] Sign in redirects to 2FA setup
- [ ] QR code scans successfully
- [ ] Backup codes displayed once
- [ ] 2FA verification works with valid code
- [ ] 2FA verification fails with invalid code
- [ ] Sign out clears session
- [ ] API key works with x-api-key header
- [ ] Rate limiting triggers after threshold
- [ ] Protected routes redirect when not authenticated

### Debugging Tips

**Session not persisting:**
- Check `NEXT_PUBLIC_APP_URL` matches actual URL
- Verify cookies are being set (check DevTools → Application → Cookies)
- Ensure `nextCookies()` plugin is enabled

**2FA not redirecting:**
- Verify `onTwoFactorRedirect` callback in client config
- Check `autoSignIn: false` in server config

**API keys not working:**
- Verify `enableSessionForAPIKeys: true` in apiKey plugin
- Check `x-api-key` header spelling and value
- Ensure key is enabled in database (`enabled: true`)

**Rate limiting not working:**
- Verify `rateLimit` model exists in Prisma schema
- Check `storage: "database"` in rate limit config
- Ensure migrations are applied

## Related Skills

- **rbac-permissions** - Use with Better-auth roles for authorization
- **auth-flow-patterns** - Complete authentication flows (sign-in, 2FA, etc.)
- **logging-js** - Log authentication events with sensitive data redaction
- **api-routes-js** - Integrate session checks in API routes
