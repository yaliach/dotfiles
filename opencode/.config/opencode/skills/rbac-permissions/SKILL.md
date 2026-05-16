---
name: rbac-permissions
description: >
  Centralized role-based access control (RBAC) system for Next.js applications.
  Use when adding new pages, API routes, or implementing permission checks.
  Covers page-level permissions, API route permissions, helper functions, and
  usage patterns in Server Components, Client Components, and API routes.
---

This skill covers the complete RBAC implementation pattern used in this project.
All permissions are defined in a single centralized configuration file, with
type-safe helper functions for checking access throughout the application.

Cross-reference the `better-auth-integration`, `api-routes-js`, and `typescript-typing`
skills when implementing authorization.

## Core Permissions Configuration (lib/permissions.ts)

The PERMISSIONS object is the single source of truth for all authorization rules.
It defines roles, page-level permissions, and API route permissions in one place.

```typescript
// lib/permissions.ts

// Role-based access control configuration
export const PERMISSIONS = {
  // Available roles in the system
  roles: ["admin", "user"] as const,

  // Page-level permissions (route groups and pages)
  pages: {
    "/users": ["admin"],
    "/api-keys": ["admin"],
    "/dashboard": ["admin", "user"],
    // Add new pages here
  },

  // API route permissions (per HTTP method)
  routes: {
    "/api/v1/users": {
      GET: ["admin"],
      POST: ["admin"],
    },
    "/api/v1/users/[id]": {
      GET: ["admin"],
      PUT: ["admin"],
      DELETE: ["admin"],
    },
    "/api/v1/users/[id]/restart-2fa": {
      POST: ["admin"],
    },
    "/api/v1/api-keys": {
      GET: ["admin"],
      POST: ["admin"],
    },
    "/api/v1/api-keys/[id]": {
      GET: ["admin"],
      PUT: ["admin"],
      DELETE: ["admin"],
    },
    // Add new routes here
  },
} as const

// Type definitions for better TypeScript support
export type Role = typeof PERMISSIONS.roles[number]
export type PagePath = keyof typeof PERMISSIONS.pages
export type RoutePath = keyof typeof PERMISSIONS.routes
export type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
```

### Adding New Roles

To add a new role (e.g., "moderator"):

1. Add to `roles` array
2. Update permission lists to include the new role
3. Update Better-auth admin plugin default roles if needed

```typescript
export const PERMISSIONS = {
  roles: ["admin", "moderator", "user"] as const,
  pages: {
    "/users": ["admin", "moderator"],  // Allow moderators
  },
}
```

### Adding New Pages

When creating a new page, add its path and allowed roles:

```typescript
pages: {
  "/users": ["admin"],
  "/api-keys": ["admin"],
  "/settings": ["admin", "user"],  // New page accessible by both
  "/reports": ["admin"],           // New admin-only page
}
```

### Adding New API Routes

When creating a new API route, add its path and per-method permissions:

```typescript
routes: {
  "/api/v1/reports": {
    GET: ["admin", "user"],     // Both can read
    POST: ["admin"],             // Only admin can create
  },
  "/api/v1/reports/[id]": {
    GET: ["admin", "user"],
    PUT: ["admin"],
    DELETE: ["admin"],
  },
}
```

## Helper Functions

### hasPageAccess - Check Page Permissions

```typescript
export const hasPageAccess = (userRole: Role, page: PagePath): boolean => {
  const pageRoles = PERMISSIONS.pages[page] as readonly Role[]
  return pageRoles?.includes(userRole) ?? false
}
```

**Usage:**
```typescript
const userRole = session.user.role as Role
const canAccessUsers = hasPageAccess(userRole, "/users")  // true if admin

if (!hasPageAccess(userRole, "/users")) {
  redirect("/dashboard")
}
```

### hasRouteAccess - Check API Route Permissions

```typescript
export const hasRouteAccess = (
  userRole: Role, 
  route: RoutePath, 
  method: HttpMethod
): boolean => {
  const routePerms = PERMISSIONS.routes[route]
  if (!routePerms) return false
  
  const methodPerms = (routePerms as any)[method] as readonly Role[] | undefined
  return methodPerms?.includes(userRole) ?? false
}
```

**Usage:**
```typescript
const userRole = session.user.role as Role
const canGetUsers = hasRouteAccess(userRole, "/api/v1/users", "GET")

if (!hasRouteAccess(userRole, "/api/v1/users", "POST")) {
  throw new Error("Forbidden")
}
```

### getRolePermissions - Get All Permissions for a Role

```typescript
export const getRolePermissions = (role: Role) => {
  const pages = Object.keys(PERMISSIONS.pages).filter(page => 
    hasPageAccess(role, page as PagePath)
  )
  
  return { pages }
}
```

**Usage:**
```typescript
const adminPerms = getRolePermissions("admin")
// { pages: ["/users", "/api-keys", ...] }

const userPerms = getRolePermissions("user")
// { pages: [] }
```

### checkApiPermission - Throw on Unauthorized (Legacy)

```typescript
export const checkApiPermission = (
  userRole: Role | null | undefined,
  route: RoutePath,
  method: HttpMethod
): void => {
  if (!userRole) {
    throw new Error('UNAUTHORIZED')
  }

  if (!hasRouteAccess(userRole, route, method)) {
    throw new Error('FORBIDDEN')
  }
}
```

**Note:** This helper throws errors. Prefer `requireApiPermission` for cleaner code.

### requireApiPermission - Return NextResponse or Null (RECOMMENDED)

This is the **primary helper** for API route protection. It returns a NextResponse
on error, or null if authorized (allowing the route to continue).

```typescript
type NextResponseType = typeof import('next/server').NextResponse
type ApiResponseType<T> = { data: T; error: null } | { data: null; error: string }

export const requireApiPermission = (
  requestLogger: any,       // Pino logger instance
  session: any,             // Better-auth session
  route: RoutePath,
  method: HttpMethod,
  NextResponse: NextResponseType
): ReturnType<NextResponseType['json']> | null => {
  // Check authentication
  if (!session?.user) {
    requestLogger.warn('Unauthenticated request')
    return NextResponse.json(
      { data: null, error: 'Unauthorized' } satisfies ApiResponseType<never>,
      { status: 401 }
    )
  }

  // @ts-ignore - role is a custom field added by Better-auth admin plugin
  const userRole = session.user.role as Role | undefined

  // Check authorization
  if (!userRole || !hasRouteAccess(userRole, route, method)) {
    requestLogger.warn(
      { userId: session.user.id, role: userRole }, 
      'Forbidden access attempt'
    )
    return NextResponse.json(
      { data: null, error: 'Forbidden' } satisfies ApiResponseType<never>,
      { status: 403 }
    )
  }

  // Authorized - return null to signal route can continue
  return null
}
```

**Why this pattern?**
- Clean early return pattern (no throw/catch needed)
- Consistent error response shape (ApiResponse<T>)
- Structured logging of auth failures
- Type-safe with satisfies operator

## Usage Patterns

### In Server Components (Pages)

Server Components should check permissions and redirect if unauthorized.

```typescript
// app/(app)/users/page.tsx
import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"

export default async function UsersPage() {
  // Get session
  const session = await auth.api.getSession({ headers: await headers() })
  
  // Check authentication
  if (!session?.user) {
    redirect("/auth/sign-in")
  }

  // Check authorization (simple check for single role)
  const userRole = session.user.role
  if (userRole !== "admin") {
    redirect("/dashboard")  // Or show 403 page
  }

  // Or use helper for multi-role support
  import { hasPageAccess } from "@/lib/permissions"
  if (!hasPageAccess(userRole, "/users")) {
    redirect("/dashboard")
  }

  // Fetch data and render...
  const users = await prisma.user.findMany()
  return <UsersTable users={users} />
}
```

**Key Points:**
- Always check authentication first (`session?.user`)
- Then check authorization (`role` check)
- Use `redirect()` for unauthorized access
- Don't throw errors in Server Components (use redirects instead)

### In Server Components (Layouts)

Layouts can check permissions to show/hide UI elements.

```typescript
// app/(app)/layout.tsx
import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import Sidebar from "@/components/Sidebar"

export default async function AppLayout({ children }: Props) {
  const session = await auth.api.getSession({ headers: await headers() })
  
  if (!session?.user) {
    redirect("/auth/sign-in")
  }

  const userRole = session.user.role

  return (
    <div>
      <Sidebar userRole={userRole} />
      {children}
    </div>
  )
}
```

### In Client Components (Navigation)

Client components can filter navigation items based on user role.

```typescript
// components/Sidebar.tsx
"use client"
import { hasPageAccess, type Role } from "@/lib/permissions"
import { Users, Key, BarChart } from "lucide-react"

interface SidebarProps {
  userRole: Role
}

export default function Sidebar({ userRole }: SidebarProps) {
  // Define all possible nav items
  const allNavItems = [
    { href: "/users", label: "Users", icon: Users },
    { href: "/api-keys", label: "API Keys", icon: Key },
    { href: "/reports", label: "Reports", icon: BarChart },
  ]

  // Filter items based on user role
  const navItems = allNavItems.filter(item => 
    hasPageAccess(userRole, item.href as any)
  )

  return (
    <nav>
      {navItems.map(item => (
        <NavItem key={item.href} {...item} />
      ))}
    </nav>
  )
}
```

**Key Points:**
- Pass `userRole` as prop from Server Component
- Filter items client-side using `hasPageAccess`
- This prevents users from seeing links they can't access
- Server-side protection still required (defense in depth)

### In API Routes (Recommended Pattern)

Use `requireApiPermission` for clean, consistent authorization checks.

```typescript
// app/api/v1/users/route.ts
import { NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { requireApiPermission } from '@/lib/permissions'
import { logger } from '@/lib/logger'
import type { ApiResponse } from '@/types'

export async function GET(req: Request) {
  const requestId = crypto.randomUUID()
  const requestLogger = logger.child({ 
    requestId, 
    path: '/api/v1/users', 
    method: 'GET' 
  })
  
  requestLogger.info('API request received')

  try {
    // Get session
    const session = await auth.api.getSession({ headers: req.headers })
    
    // Check permissions (returns early if unauthorized)
    const permissionError = requireApiPermission(
      requestLogger, 
      session, 
      '/api/v1/users', 
      'GET', 
      NextResponse
    )
    if (permissionError) return permissionError

    // User is authenticated and authorized - continue with business logic
    const users = await prisma.user.findMany()
    
    requestLogger.info({ count: users.length }, 'Users fetched successfully')
    
    return NextResponse.json(
      { data: users, error: null } satisfies ApiResponse<typeof users>
    )
  } catch (err) {
    requestLogger.error({ err, requestId }, 'Failed to fetch users')
    return NextResponse.json(
      { data: null, error: 'Failed to fetch users' } satisfies ApiResponse<never>,
      { status: 500 }
    )
  }
}

export async function POST(req: Request) {
  const requestId = crypto.randomUUID()
  const requestLogger = logger.child({ 
    requestId, 
    path: '/api/v1/users', 
    method: 'POST' 
  })
  
  requestLogger.info('API request received')

  try {
    const session = await auth.api.getSession({ headers: req.headers })
    
    // Same permission check, different method
    const permissionError = requireApiPermission(
      requestLogger, 
      session, 
      '/api/v1/users', 
      'POST', 
      NextResponse
    )
    if (permissionError) return permissionError

    // Business logic...
  } catch (err) {
    requestLogger.error({ err, requestId }, 'Failed to create user')
    return NextResponse.json(
      { data: null, error: 'Failed to create user' } satisfies ApiResponse<never>,
      { status: 500 }
    )
  }
}
```

**Pattern breakdown:**
1. Create request-scoped logger
2. Get session from request headers
3. Call `requireApiPermission` with route path and method
4. If it returns a value, return that value (unauthorized/forbidden response)
5. If it returns null, continue with business logic

### In API Routes (Dynamic Routes)

For dynamic routes like `/api/v1/users/[id]`, use the base route pattern:

```typescript
// app/api/v1/users/[id]/route.ts
export async function PUT(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const requestLogger = logger.child({ requestId: crypto.randomUUID() })
  
  try {
    const session = await auth.api.getSession({ headers: req.headers })
    
    // Use the route path from PERMISSIONS (not the actual URL)
    const permissionError = requireApiPermission(
      requestLogger,
      session,
      '/api/v1/users/[id]',  // Use the pattern, not actual ID
      'PUT',
      NextResponse
    )
    if (permissionError) return permissionError

    // Get actual ID from params
    const { id } = await params
    
    // Business logic with ID...
  } catch (err) {
    // Error handling...
  }
}
```

## Testing Permissions

### Manual Testing Checklist

For each new protected resource:
- [ ] Unauthenticated users cannot access (401)
- [ ] Authenticated users without permission cannot access (403)
- [ ] Authenticated users with permission can access (200)
- [ ] Navigation doesn't show unauthorized links
- [ ] Direct URL access is blocked (not just hidden links)

### Testing Different Roles

Create test users for each role:

```bash
# Admin user
node scripts/create-user.js --email admin@test.com --password test1234 --role admin

# Regular user
node scripts/create-user.js --email user@test.com --password test1234 --role user
```

Test with each user:
1. Sign in with admin → should see all pages
2. Sign in with user → should see limited pages
3. Try accessing admin pages as user (direct URL) → should redirect/403

## Common Patterns

### Allow access to multiple roles

```typescript
pages: {
  "/dashboard": ["admin", "user"],  // Both roles
  "/reports": ["admin", "moderator"],
}
```

### Public pages (no auth required)

Don't add to PERMISSIONS. Instead, skip auth check in page:

```typescript
// app/public-page/page.tsx
export default async function PublicPage() {
  // No auth check - fully public
  return <div>Public content</div>
}
```

### User-specific resources (own data only)

```typescript
// Check permission, then check ownership
const permissionError = requireApiPermission(...)
if (permissionError) return permissionError

const resourceUserId = await getResourceUserId(resourceId)
if (resourceUserId !== session.user.id && session.user.role !== "admin") {
  return NextResponse.json(
    { data: null, error: 'Forbidden' },
    { status: 403 }
  )
}
```

### Conditional UI based on role

```typescript
// In client component
"use client"
export default function UserActions({ userRole }: { userRole: Role }) {
  return (
    <div>
      {userRole === "admin" && <AdminActions />}
      {userRole === "user" && <UserActions />}
      <SharedActions />
    </div>
  )
}
```

### Prevent self-deletion

```typescript
// In delete user endpoint
const { id } = await params
if (id === session.user.id) {
  return NextResponse.json(
    { data: null, error: 'Cannot delete your own account' },
    { status: 400 }
  )
}
```

## Security Best Practices

### Defense in Depth
- **Always check permissions on the server** (pages and API routes)
- Client-side filtering is UX only, not security
- Don't trust client-provided role data

### Explicit Permission Lists
- Use explicit role arrays: `["admin", "user"]`
- Avoid wildcard permissions or "allow all"
- Review permissions when adding new roles

### Consistent Error Messages
- 401 Unauthorized → Not authenticated (no valid session)
- 403 Forbidden → Authenticated but lacks permission
- Don't leak information in error messages (e.g., "user exists")

### Logging
- Always log authentication failures
- Always log authorization failures
- Include userId and requested resource in logs
- Don't log sensitive data (passwords, tokens)

### Regular Audits
- Review PERMISSIONS object when adding features
- Test with different roles regularly
- Use TypeScript to catch permission typos

## Debugging Tips

**403 Forbidden but user should have access:**
- Check PERMISSIONS object has the route/page
- Verify user's role in database matches expected role
- Check HTTP method matches (GET vs POST)
- Ensure Better-auth admin plugin is configured

**Type errors with Role:**
- Import Role type: `import type { Role } from "@/lib/permissions"`
- Use type assertion: `session.user.role as Role`
- Better-auth role field is not typed by default

**Permission check not firing:**
- Verify `requireApiPermission` is called before business logic
- Check early return: `if (permissionError) return permissionError`
- Ensure session is awaited: `await auth.api.getSession(...)`

## Related Skills

- **better-auth-integration** - Session management and authentication
- **api-routes-js** - Complete API route implementation with permissions
- **logging-js** - Structured logging of auth/authz events
- **typescript-typing** - Type-safe permission checks
