---
name: auth-flow-patterns
description: >
  Complete authentication flow patterns including sign-in, sign-up, 2FA setup,
  2FA verification, sign-out, and session management. Use when implementing or
  modifying authentication pages and flows. Covers Better-auth client methods,
  redirect patterns, QR code generation, backup codes, and error handling.
---

This skill covers all authentication flow patterns used in this project with
Better-auth. These flows provide a secure, user-friendly authentication experience
with optional two-factor authentication.

Cross-reference the `better-auth-integration`, `server-client-components`, and
`api-response-typing` skills when implementing auth flows.

## Authentication Flow Overview

```
Sign Up → Sign In → (2FA Setup) → 2FA Verify → Protected App
                 ↓
           (Skip 2FA Setup)
                 ↓
            2FA Verify (on next login if enabled)
```

### Flow Decision Points

1. **Sign Up** - Creates user account
2. **Sign In** - Authenticates user
   - If 2FA enabled → Redirect to 2FA Verify
   - If 2FA not enabled → Redirect to 2FA Setup (optional, can skip)
3. **2FA Setup** - First-time 2FA configuration
   - Scan QR code
   - Save backup codes
   - Verify code to enable
   - Can skip and set up later
4. **2FA Verify** - Subsequent logins require code
5. **Protected App** - Authenticated pages

## Sign-In Flow

### Sign-In Page Structure

```typescript
// app/(auth)/auth/sign-in/page.tsx
"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { authClient } from "@/lib/auth-client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { toast } from "sonner"
import Link from "next/link"

export default function SignInPage() {
  const router = useRouter()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      // Better-auth sign-in with email/password
      const { data, error } = await authClient.signIn.email({
        email,
        password,
        callbackURL: "/users",  // Where to go after successful auth
      })

      if (error) {
        toast.error(error.message || "Failed to sign in")
        return
      }

      // Note: If 2FA is enabled, onTwoFactorRedirect callback handles redirect
      // If 2FA not enabled, redirect to callback URL or 2FA setup
      
      if (!data?.user.twoFactorEnabled) {
        // Optionally redirect to 2FA setup
        router.push("/auth/2fa-setup")
      }
    } catch (err) {
      toast.error("An error occurred during sign in")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md space-y-6">
        <div className="space-y-2 text-center">
          <h1 className="text-3xl font-bold">Sign In</h1>
          <p className="text-muted-foreground">
            Enter your credentials to access your account
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "Signing in..." : "Sign In"}
          </Button>
        </form>

        <p className="text-center text-sm text-muted-foreground">
          Don't have an account?{" "}
          <Link href="/auth/sign-up" className="text-primary hover:underline">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  )
}
```

### Sign-In with 2FA Redirect

Better-auth handles 2FA redirects via the `onTwoFactorRedirect` callback in client config:

```typescript
// lib/auth-client.ts
import { createAuthClient } from "better-auth/react"
import { twoFactorClient } from "better-auth/client/plugins"

export const authClient = createAuthClient({
  baseURL: process.env.NEXT_PUBLIC_APP_URL,
  plugins: [
    twoFactorClient({
      // Automatically redirect to 2FA verify if user has 2FA enabled
      onTwoFactorRedirect() {
        window.location.href = "/auth/2fa-verify"
      }
    })
  ]
})
```

**Flow:**
1. User submits email/password
2. Better-auth validates credentials
3. If 2FA enabled → `onTwoFactorRedirect` called → Redirect to `/auth/2fa-verify`
4. If 2FA not enabled → Use `callbackURL` or custom redirect logic

## 2FA Setup Flow

### 2FA Setup Page

```typescript
// app/(auth)/auth/2fa-setup/page.tsx
"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { authClient } from "@/lib/auth-client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { toast } from "sonner"
import QRCode from "react-qr-code"

export default function TwoFactorSetupPage() {
  const router = useRouter()
  const [password, setPassword] = useState("")
  const [verificationCode, setVerificationCode] = useState("")
  const [qrCodeUri, setQrCodeUri] = useState<string | null>(null)
  const [backupCodes, setBackupCodes] = useState<string[]>([])
  const [loading, setLoading] = useState(false)
  const [step, setStep] = useState<"password" | "verify" | "codes">("password")

  // Step 1: Generate TOTP secret and QR code
  const handleGenerateQR = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      // Call Better-auth to enable 2FA
      const { data, error } = await authClient.twoFactor.enable({
        password,  // Verify user's password before enabling 2FA
      })

      if (error) {
        toast.error(error.message || "Failed to generate 2FA setup")
        return
      }

      // Response includes QR code URI and backup codes
      setQrCodeUri(data.totpURI)
      setBackupCodes(data.backupCodes)
      setStep("verify")
    } catch (err) {
      toast.error("Failed to set up 2FA")
    } finally {
      setLoading(false)
    }
  }

  // Step 2: Verify TOTP code
  const handleVerifyCode = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const { data, error } = await authClient.twoFactor.verifyTotp({
        code: verificationCode,
      })

      if (error) {
        toast.error("Invalid verification code")
        return
      }

      // Verification successful - show backup codes
      setStep("codes")
      toast.success("2FA enabled successfully")
    } catch (err) {
      toast.error("Failed to verify code")
    } finally {
      setLoading(false)
    }
  }

  // Step 3: Complete setup
  const handleComplete = () => {
    router.push("/users")  // or wherever user should go
  }

  // Skip 2FA setup (optional)
  const handleSkip = () => {
    router.push("/users")
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md space-y-6">
        {/* Step 1: Enter password */}
        {step === "password" && (
          <>
            <div className="space-y-2 text-center">
              <h1 className="text-3xl font-bold">Set Up 2FA</h1>
              <p className="text-muted-foreground">
                Add an extra layer of security to your account
              </p>
            </div>

            <form onSubmit={handleGenerateQR} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="password">Confirm Your Password</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>

              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? "Generating..." : "Generate QR Code"}
              </Button>
            </form>

            <Button
              variant="ghost"
              className="w-full"
              onClick={handleSkip}
            >
              Setup Later
            </Button>
          </>
        )}

        {/* Step 2: Scan QR code and verify */}
        {step === "verify" && qrCodeUri && (
          <>
            <div className="space-y-2 text-center">
              <h1 className="text-3xl font-bold">Scan QR Code</h1>
              <p className="text-muted-foreground">
                Use your authenticator app to scan this QR code
              </p>
            </div>

            <div className="flex justify-center p-6 bg-white rounded-lg">
              <QRCode value={qrCodeUri} size={200} />
            </div>

            <form onSubmit={handleVerifyCode} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="code">Verification Code</Label>
                <Input
                  id="code"
                  type="text"
                  placeholder="000000"
                  value={verificationCode}
                  onChange={(e) => setVerificationCode(e.target.value)}
                  maxLength={6}
                  required
                />
                <p className="text-xs text-muted-foreground">
                  Enter the 6-digit code from your authenticator app
                </p>
              </div>

              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? "Verifying..." : "Verify Code"}
              </Button>
            </form>
          </>
        )}

        {/* Step 3: Show backup codes */}
        {step === "codes" && (
          <>
            <div className="space-y-2 text-center">
              <h1 className="text-3xl font-bold">Backup Codes</h1>
              <p className="text-muted-foreground">
                Save these codes in a safe place. You can use them to sign in if you lose access to your authenticator app.
              </p>
            </div>

            <div className="rounded-lg border p-4 space-y-2">
              {backupCodes.map((code, index) => (
                <div
                  key={index}
                  className="font-mono text-sm bg-muted p-2 rounded"
                >
                  {code}
                </div>
              ))}
            </div>

            <div className="space-y-2">
              <Button className="w-full" onClick={handleComplete}>
                I've Saved My Codes
              </Button>
              <Button
                variant="outline"
                className="w-full"
                onClick={() => {
                  navigator.clipboard.writeText(backupCodes.join("\n"))
                  toast.success("Backup codes copied to clipboard")
                }}
              >
                Copy Codes
              </Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
```

### 2FA Setup Flow Breakdown

**Step 1: Password Verification**
- User enters current password
- Call `authClient.twoFactor.enable({ password })`
- Response includes `totpURI` (for QR code) and `backupCodes`

**Step 2: QR Code Scanning**
- Display QR code using `react-qr-code`
- User scans with authenticator app (Google Authenticator, Authy, etc.)
- User enters 6-digit code from app
- Call `authClient.twoFactor.verifyTotp({ code })`

**Step 3: Backup Codes**
- Display backup codes (one-time use emergency codes)
- User saves codes in safe location
- Allow copy to clipboard
- Emphasize importance of saving codes

**Optional Skip:**
- Allow users to skip 2FA setup
- Redirect to app
- Can set up later from settings

## 2FA Verification Flow

### 2FA Verify Page

```typescript
// app/(auth)/auth/2fa-verify/page.tsx
"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { authClient } from "@/lib/auth-client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { toast } from "sonner"

export default function TwoFactorVerifyPage() {
  const router = useRouter()
  const [code, setCode] = useState("")
  const [loading, setLoading] = useState(false)
  const [useBackupCode, setUseBackupCode] = useState(false)

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const { data, error } = await authClient.twoFactor.verifyTotp({
        code,
        callbackURL: "/users",  // Where to go after successful verification
      })

      if (error) {
        toast.error("Invalid verification code")
        return
      }

      // Success - redirect handled by Better-auth
      toast.success("Verification successful")
      router.push("/users")
    } catch (err) {
      toast.error("Failed to verify code")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md space-y-6">
        <div className="space-y-2 text-center">
          <h1 className="text-3xl font-bold">Two-Factor Authentication</h1>
          <p className="text-muted-foreground">
            {useBackupCode 
              ? "Enter one of your backup codes"
              : "Enter the code from your authenticator app"}
          </p>
        </div>

        <form onSubmit={handleVerify} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="code">
              {useBackupCode ? "Backup Code" : "Verification Code"}
            </Label>
            <Input
              id="code"
              type="text"
              placeholder={useBackupCode ? "XXXX-XXXX-XXXX" : "000000"}
              value={code}
              onChange={(e) => setCode(e.target.value)}
              maxLength={useBackupCode ? 14 : 6}
              required
            />
          </div>

          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "Verifying..." : "Verify"}
          </Button>
        </form>

        <Button
          variant="ghost"
          className="w-full"
          onClick={() => setUseBackupCode(!useBackupCode)}
        >
          {useBackupCode 
            ? "Use authenticator app instead"
            : "Use backup code instead"}
        </Button>
      </div>
    </div>
  )
}
```

### 2FA Verification Options

**Standard Verification:**
- User enters 6-digit code from authenticator app
- Code is time-based (TOTP, 30-second validity)
- Call `authClient.twoFactor.verifyTotp({ code })`

**Backup Code Verification:**
- User enters one backup code
- Backup codes are single-use
- Same API endpoint, Better-auth detects backup code format

## Sign-Out Flow

Simple and straightforward:

```typescript
// components/UserMenu.tsx
"use client"

import { authClient } from "@/lib/auth-client"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"

export default function UserMenu() {
  const router = useRouter()

  const handleSignOut = async () => {
    try {
      await authClient.signOut()
      router.push("/auth/sign-in")
    } catch (err) {
      toast.error("Failed to sign out")
    }
  }

  return (
    <Button onClick={handleSignOut} variant="ghost">
      Sign Out
    </Button>
  )
}
```

## Session Management Patterns

### Check Session in Pages

```typescript
// Server Component
import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"

export default async function ProtectedPage() {
  const session = await auth.api.getSession({ headers: await headers() })
  
  if (!session?.user) {
    redirect("/auth/sign-in")
  }

  return <div>Welcome {session.user.name}</div>
}
```

### Use Session Hook in Components

```typescript
// Client Component
"use client"
import { useSession } from "@/lib/auth-client"

export default function Component() {
  const { data: session, isPending } = useSession()
  
  if (isPending) return <div>Loading...</div>
  if (!session) return <div>Not authenticated</div>
  
  return <div>Welcome {session.user.name}</div>
}
```

## Admin 2FA Management

### Restart User's 2FA (Admin Only)

```typescript
// API route: app/api/v1/users/[id]/restart-2fa/route.ts
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const requestLogger = logger.child({ requestId: crypto.randomUUID() })
  
  try {
    const session = await auth.api.getSession({ headers: req.headers })
    
    // Check permissions
    const permissionError = requireApiPermission(
      requestLogger,
      session,
      '/api/v1/users/[id]/restart-2fa',
      'POST',
      NextResponse
    )
    if (permissionError) return permissionError

    const { id } = await params

    // Delete 2FA records
    await prisma.twoFactor.deleteMany({
      where: { userId: id }
    })

    // Update user's twoFactorEnabled flag
    await prisma.user.update({
      where: { id },
      data: { twoFactorEnabled: false }
    })

    requestLogger.info({ userId: id }, '2FA restarted')

    return NextResponse.json(
      { data: { success: true }, error: null },
      { status: 200 }
    )
  } catch (err) {
    requestLogger.error({ err }, 'Failed to restart 2FA')
    return NextResponse.json(
      { data: null, error: 'Failed to restart 2FA' },
      { status: 500 }
    )
  }
}
```

### UI for Admin 2FA Restart

```typescript
// components/UsersTable.tsx
const handleRestart2FA = async (userId: string) => {
  if (!confirm("Are you sure you want to restart 2FA for this user? They will need to set up 2FA again.")) {
    return
  }

  try {
    const response = await fetch(`/api/v1/users/${userId}/restart-2fa`, {
      method: "POST",
    })

    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(errorData.error || "Failed to restart 2FA")
    }

    // Update local state
    setUsers(
      users.map((user) =>
        user.id === userId ? { ...user, twoFactorEnabled: false } : user
      )
    )
    
    toast.success("2FA restarted successfully")
  } catch (error) {
    toast.error(error instanceof Error ? error.message : "Failed to restart 2FA")
  }
}
```

## Redirect Patterns

### Post-Auth Redirects

```typescript
// In sign-in
await authClient.signIn.email({
  email,
  password,
  callbackURL: "/users",  // Default redirect after successful auth
})

// In 2FA verify
await authClient.twoFactor.verifyTotp({
  code,
  callbackURL: "/dashboard",  // Where to go after 2FA verification
})
```

### Conditional Redirects

```typescript
// After sign-in, check if user has 2FA enabled
const { data } = await authClient.signIn.email({ email, password })

if (data?.user) {
  if (!data.user.twoFactorEnabled) {
    // First-time user, offer 2FA setup
    router.push("/auth/2fa-setup")
  } else {
    // 2FA enabled, redirect will be handled by onTwoFactorRedirect
  }
}
```

### Preserve Original Destination

Use query parameters to remember where user wanted to go:

```typescript
// Middleware or server component
if (!session) {
  const callbackUrl = encodeURIComponent(pathname)
  redirect(`/auth/sign-in?callbackUrl=${callbackUrl}`)
}

// In sign-in page
const searchParams = useSearchParams()
const callbackUrl = searchParams.get("callbackUrl") || "/users"

const handleSignIn = async () => {
  await authClient.signIn.email({
    email,
    password,
    callbackURL: callbackUrl,  // Redirect to original destination
  })
}
```

## Error Handling

### Common Errors

```typescript
// Invalid credentials
if (error?.message === "Invalid email or password") {
  toast.error("Invalid email or password")
}

// Account locked
if (error?.message === "Account is banned") {
  toast.error("Your account has been suspended. Please contact support.")
}

// 2FA required
if (error?.message === "Two-factor authentication required") {
  // This is usually handled by onTwoFactorRedirect
  router.push("/auth/2fa-verify")
}

// Rate limit exceeded
if (error?.message === "Too many requests") {
  toast.error("Too many attempts. Please try again later.")
}
```

### User-Friendly Messages

```typescript
try {
  await authClient.signIn.email({ email, password })
} catch (err) {
  // Don't leak implementation details
  if (err instanceof Error) {
    if (err.message.includes("credentials")) {
      toast.error("Invalid email or password")
    } else if (err.message.includes("network")) {
      toast.error("Network error. Please check your connection.")
    } else {
      toast.error("Failed to sign in. Please try again.")
    }
  }
}
```

## Security Best Practices

### Password Requirements

Enforce in validation:
```typescript
const passwordSchema = z.string()
  .min(8, "Password must be at least 8 characters")
  .max(128, "Password must be less than 128 characters")
```

### Rate Limiting

Better-auth handles this automatically:
```typescript
// In lib/auth.ts
rateLimit: {
  customRules: {
    "/sign-in/email": { window: 60, max: 10 },  // 10 attempts per minute
  },
}
```

### Backup Code Security

- Display codes only once during setup
- Encourage users to save in password manager
- Single-use (deleted after use)
- Encrypted in database

### Session Security

- Secure cookies (httpOnly, sameSite, secure in production)
- Short session expiry (configurable in Better-auth)
- IP and user agent tracking (Better-auth automatically logs this)

## Testing Auth Flows

### Manual Test Checklist

**Sign-In:**
- [ ] Valid credentials → successful sign-in
- [ ] Invalid credentials → error message
- [ ] Banned user → "Account suspended" message
- [ ] With 2FA enabled → redirect to 2FA verify
- [ ] Without 2FA → redirect to 2FA setup or app

**2FA Setup:**
- [ ] QR code displays correctly
- [ ] Code from authenticator app verifies successfully
- [ ] Backup codes display after verification
- [ ] Can skip setup
- [ ] Can copy backup codes

**2FA Verify:**
- [ ] Valid TOTP code → successful verification
- [ ] Invalid code → error message
- [ ] Backup code → successful verification
- [ ] Used backup code → cannot reuse

**Sign-Out:**
- [ ] Sign-out clears session
- [ ] Cannot access protected pages after sign-out
- [ ] Redirect to sign-in page

**Admin 2FA Restart:**
- [ ] Admin can restart user's 2FA
- [ ] User's twoFactorEnabled flag set to false
- [ ] User must set up 2FA again on next login

## Related Skills

- **better-auth-integration** - Better-auth configuration and setup
- **server-client-components** - Server/Client component patterns for auth
- **api-response-typing** - Type-safe API responses in auth flows
- **rbac-permissions** - Authorization checks after authentication
