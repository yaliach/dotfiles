---
name: api-response-typing
description: >
  Consistent typed API response patterns for Next.js API routes. Use when creating
  API routes or handling API responses in components. Covers the ApiResponse<T> type,
  success/error shapes, HTTP status codes, type inference, and client-side handling.
  Enforces compile-time verification with the satisfies operator.
---

This skill covers the complete API response typing pattern used in this project.
All API routes return a consistent `ApiResponse<T>` shape, providing type safety
from server to client and enabling predictable error handling.

Cross-reference the `api-routes-js`, `error-handling-js`, and `typescript-typing`
skills when implementing API routes.

## Core Type Definition (types/api.ts)

The `ApiResponse<T>` type is a discriminated union that represents either success
or failure. It's simple, type-safe, and works seamlessly with TypeScript's control
flow analysis.

```typescript
// types/api.ts

/**
 * Standard API response wrapper used across all API routes.
 * 
 * Success: { data: T, error: null }
 * Failure: { data: null, error: string }
 * 
 * The discriminated union allows TypeScript to narrow types in client code.
 */
export type ApiResponse<T> = 
  | { data: T; error: null } 
  | { data: null; error: string }
```

### Why This Pattern?

**Type Safety:**
- Discriminated union enables automatic type narrowing
- No need for `?.` optional chaining when checking `error` first
- Generic `T` parameter preserves actual data types

**Consistency:**
- Every API route uses the same shape
- Predictable error handling in client code
- Easy to write generic API wrapper functions

**Simplicity:**
- No complex error objects or status codes in response body
- HTTP status codes handled separately (in response headers)
- Error messages are simple strings

**Example of Type Narrowing:**
```typescript
const result: ApiResponse<User[]> = await fetchUsers()

if (result.error) {
  // TypeScript knows: result.data is null, result.error is string
  console.error(result.error)
} else {
  // TypeScript knows: result.data is User[], result.error is null
  console.log(result.data.length)  // ✅ No optional chaining needed
}
```

## Usage in API Routes

### Success Response

Always use `satisfies ApiResponse<T>` to get compile-time verification of the response shape.

```typescript
import { NextResponse } from 'next/server'
import type { ApiResponse } from '@/types'

export async function GET(req: Request) {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
      }
    })

    // ✅ Correct: satisfies enforces shape at compile-time
    return NextResponse.json(
      { data: users, error: null } satisfies ApiResponse<typeof users>
    )
    
    // ❌ Wrong: No type checking
    return NextResponse.json({ data: users, error: null })
    
    // ❌ Wrong: Would fail compilation (missing error field)
    return NextResponse.json({ data: users })
  } catch (err) {
    // Error handling...
  }
}
```

**Key Points:**
- Use `typeof` to infer the data type from the variable
- `satisfies` provides compile-time checking without widening the type
- Always set `error: null` in success responses

### Error Response

Error responses follow the same pattern but with `data: null` and `error: string`.

```typescript
import { NextResponse } from 'next/server'
import type { ApiResponse } from '@/types'

export async function GET(req: Request) {
  try {
    const session = await auth.api.getSession({ headers: req.headers })
    
    if (!session?.user) {
      // 401 Unauthorized
      return NextResponse.json(
        { data: null, error: 'Unauthorized' } satisfies ApiResponse<never>,
        { status: 401 }
      )
    }

    if (!hasPermission(session.user.role)) {
      // 403 Forbidden
      return NextResponse.json(
        { data: null, error: 'Forbidden' } satisfies ApiResponse<never>,
        { status: 403 }
      )
    }

    // Business logic...
  } catch (err) {
    requestLogger.error({ err, requestId }, 'Failed to fetch data')
    
    // 500 Internal Server Error
    return NextResponse.json(
      { data: null, error: 'Failed to fetch data' } satisfies ApiResponse<never>,
      { status: 500 }
    )
  }
}
```

**Key Points:**
- Use `ApiResponse<never>` for error responses (data type is never used)
- Always set `data: null` in error responses
- Include appropriate HTTP status code
- Keep error messages generic (don't leak implementation details)

### Created Response (201)

For POST endpoints that create resources, use 201 status:

```typescript
export async function POST(req: Request) {
  try {
    const body = await req.json()
    const parsed = CreateUserSchema.safeParse(body)
    
    if (!parsed.success) {
      // 400 Bad Request
      return NextResponse.json(
        { data: null, error: 'Invalid request body' } satisfies ApiResponse<never>,
        { status: 400 }
      )
    }

    const newUser = await prisma.user.create({
      data: parsed.data
    })

    // 201 Created
    return NextResponse.json(
      { data: newUser, error: null } satisfies ApiResponse<typeof newUser>,
      { status: 201 }
    )
  } catch (err) {
    // Error handling...
  }
}
```

### Conflict Response (409)

For duplicate resource errors:

```typescript
export async function POST(req: Request) {
  try {
    const { email } = parsed.data

    // Check if email already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    })

    if (existingUser) {
      requestLogger.warn({ email }, 'Email already exists')
      
      // 409 Conflict
      return NextResponse.json(
        { data: null, error: 'Email already exists' } satisfies ApiResponse<never>,
        { status: 409 }
      )
    }

    // Create user...
  } catch (err) {
    // Error handling...
  }
}
```

## HTTP Status Codes

Use consistent status codes across all API routes:

| Status | When to Use | Example |
|--------|-------------|---------|
| **200** | Successful GET, PUT, DELETE | Fetched users, updated user, deleted user |
| **201** | Successful POST (resource created) | Created new user |
| **400** | Validation error, bad input | Invalid request body, missing required field |
| **401** | Not authenticated | No session, invalid token |
| **403** | Authenticated but not authorized | User lacks required role |
| **404** | Resource not found | User ID doesn't exist |
| **409** | Resource conflict | Email already exists, duplicate key |
| **500** | Server error, unexpected exception | Database error, uncaught exception |

**Examples:**

```typescript
// 200 - Success (default, can omit status parameter)
return NextResponse.json(
  { data: result, error: null } satisfies ApiResponse<typeof result>
)

// 201 - Created
return NextResponse.json(
  { data: newResource, error: null } satisfies ApiResponse<typeof newResource>,
  { status: 201 }
)

// 400 - Bad Request
return NextResponse.json(
  { data: null, error: 'Invalid request body' } satisfies ApiResponse<never>,
  { status: 400 }
)

// 401 - Unauthorized
return NextResponse.json(
  { data: null, error: 'Unauthorized' } satisfies ApiResponse<never>,
  { status: 401 }
)

// 403 - Forbidden
return NextResponse.json(
  { data: null, error: 'Forbidden' } satisfies ApiResponse<never>,
  { status: 403 }
)

// 404 - Not Found
return NextResponse.json(
  { data: null, error: 'User not found' } satisfies ApiResponse<never>,
  { status: 404 }
)

// 409 - Conflict
return NextResponse.json(
  { data: null, error: 'Email already exists' } satisfies ApiResponse<never>,
  { status: 409 }
)

// 500 - Internal Server Error
return NextResponse.json(
  { data: null, error: 'Failed to fetch users' } satisfies ApiResponse<never>,
  { status: 500 }
)
```

## Client-Side Usage

### Fetching Data in Client Components

```typescript
"use client"
import { useState, useEffect } from "react"
import type { ApiResponse } from "@/types"
import { toast } from "sonner"

interface User {
  id: string
  name: string
  email: string
}

export default function UsersComponent() {
  const [users, setUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchUsers()
  }, [])

  const fetchUsers = async () => {
    try {
      const response = await fetch("/api/v1/users")
      const result: ApiResponse<User[]> = await response.json()

      // Check for errors
      if (result.error) {
        toast.error(result.error)
        return
      }

      // TypeScript knows result.data is User[] here
      setUsers(result.data)
    } catch (err) {
      toast.error("Failed to fetch users")
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading...</div>
  
  return (
    <div>
      {users.map(user => (
        <div key={user.id}>{user.name}</div>
      ))}
    </div>
  )
}
```

### Creating Resources

```typescript
const handleCreateUser = async () => {
  try {
    const response = await fetch("/api/v1/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(newUser),
    })

    const result: ApiResponse<User> = await response.json()

    if (result.error) {
      toast.error(result.error)
      return
    }

    // Success - result.data is User
    toast.success("User created successfully")
    setUsers([...users, result.data])
  } catch (err) {
    toast.error("Failed to create user")
  }
}
```

### Updating Resources

```typescript
const handleUpdateUser = async (id: string) => {
  try {
    const response = await fetch(`/api/v1/users/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(updatedData),
    })

    const result: ApiResponse<User> = await response.json()

    if (result.error) {
      toast.error(result.error)
      return
    }

    // Update local state
    setUsers(users.map(u => u.id === id ? result.data : u))
    toast.success("User updated successfully")
  } catch (err) {
    toast.error("Failed to update user")
  }
}
```

### Deleting Resources

```typescript
const handleDeleteUser = async (id: string) => {
  if (!confirm("Are you sure?")) return

  try {
    const response = await fetch(`/api/v1/users/${id}`, {
      method: "DELETE",
    })

    const result: ApiResponse<{ id: string }> = await response.json()

    if (result.error) {
      toast.error(result.error)
      return
    }

    // Remove from local state
    setUsers(users.filter(u => u.id !== id))
    toast.success("User deleted successfully")
  } catch (err) {
    toast.error("Failed to delete user")
  }
}
```

### Handling HTTP Status Codes

Some operations may need to check the HTTP status code directly:

```typescript
const response = await fetch("/api/v1/users", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(newUser),
})

// Check HTTP status
if (!response.ok) {
  const result: ApiResponse<never> = await response.json()
  
  if (response.status === 409) {
    toast.error("Email already exists")
  } else if (response.status === 400) {
    toast.error("Invalid input")
  } else {
    toast.error(result.error || "An error occurred")
  }
  return
}

// Success
const result: ApiResponse<User> = await response.json()
toast.success("User created")
```

## Type Inference Patterns

### Using typeof for Dynamic Types

```typescript
// Let TypeScript infer the exact type
const users = await prisma.user.findMany({
  select: { id: true, name: true, email: true }
})

// Use typeof to get the inferred type
return NextResponse.json(
  { data: users, error: null } satisfies ApiResponse<typeof users>
)

// Equivalent to:
// type UserSubset = { id: string; name: string; email: string }[]
// ApiResponse<UserSubset>
```

### Explicit Type Annotations

When you need to ensure a specific type:

```typescript
import type { User } from "@prisma/client"

export async function GET(req: Request) {
  const users: User[] = await prisma.user.findMany()
  
  return NextResponse.json(
    { data: users, error: null } satisfies ApiResponse<User[]>
  )
}
```

### Prisma Payloads for Complex Types

```typescript
import type { Prisma } from "@prisma/client"

// Define the exact shape you're fetching
type UserWithSessions = Prisma.UserGetPayload<{
  include: { sessions: true }
}>

export async function GET(req: Request) {
  const users = await prisma.user.findMany({
    include: { sessions: true }
  })
  
  return NextResponse.json(
    { data: users, error: null } satisfies ApiResponse<UserWithSessions[]>
  )
}
```

## Error Message Best Practices

### Generic Messages (Preferred)

Don't leak implementation details or database structure:

```typescript
// ✅ Good: Generic, user-friendly
{ data: null, error: 'Failed to fetch users' }
{ data: null, error: 'Failed to create user' }
{ data: null, error: 'Invalid request body' }
{ data: null, error: 'Unauthorized' }
{ data: null, error: 'Forbidden' }

// ❌ Bad: Leaks implementation details
{ data: null, error: 'Database connection failed on port 5432' }
{ data: null, error: 'Prisma query error: column "xyz" does not exist' }
{ data: null, error: 'User table constraint violation' }
```

### Specific Messages (When Appropriate)

For user-facing errors that help them fix the issue:

```typescript
// ✅ Good: Actionable, specific
{ data: null, error: 'Email already exists' }
{ data: null, error: 'User not found' }
{ data: null, error: 'Cannot delete your own account' }
{ data: null, error: 'Invalid email format' }

// ❌ Bad: Too specific, security risk
{ data: null, error: 'Email user@example.com exists with ID 123' }
```

### Logging vs. Response Messages

- **Response message:** Generic, user-safe
- **Log message:** Detailed, includes error object and context

```typescript
try {
  const user = await prisma.user.create({ data })
} catch (err) {
  // Detailed log (internal)
  requestLogger.error(
    { err, email: data.email, requestId }, 
    'Failed to create user - database constraint violation'
  )
  
  // Generic message (user-facing)
  return NextResponse.json(
    { data: null, error: 'Failed to create user' } satisfies ApiResponse<never>,
    { status: 500 }
  )
}
```

## Advanced Patterns

### Generic API Wrapper Function

Create a reusable wrapper for API calls:

```typescript
// lib/api-client.ts
import type { ApiResponse } from "@/types"

export async function apiCall<T>(
  url: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetch(url, options)
  const result: ApiResponse<T> = await response.json()

  if (result.error) {
    throw new Error(result.error)
  }

  return result.data
}

// Usage:
const users = await apiCall<User[]>("/api/v1/users")
```

### Typed API Client with Methods

```typescript
// lib/api-client.ts
export const api = {
  async get<T>(url: string): Promise<T> {
    const response = await fetch(url)
    const result: ApiResponse<T> = await response.json()
    if (result.error) throw new Error(result.error)
    return result.data
  },

  async post<T>(url: string, body: unknown): Promise<T> {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    })
    const result: ApiResponse<T> = await response.json()
    if (result.error) throw new Error(result.error)
    return result.data
  },

  // ... put, delete, etc.
}

// Usage:
const users = await api.get<User[]>("/api/v1/users")
const newUser = await api.post<User>("/api/v1/users", userData)
```

### React Hook for API Calls

```typescript
// hooks/useApi.ts
import { useState } from "react"
import type { ApiResponse } from "@/types"

export function useApi<T>() {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const execute = async (
    url: string,
    options?: RequestInit
  ): Promise<T | null> => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch(url, options)
      const result: ApiResponse<T> = await response.json()

      if (result.error) {
        setError(result.error)
        return null
      }

      setData(result.data)
      return result.data
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error"
      setError(message)
      return null
    } finally {
      setLoading(false)
    }
  }

  return { data, error, loading, execute }
}

// Usage:
const { data, error, loading, execute } = useApi<User[]>()

useEffect(() => {
  execute("/api/v1/users")
}, [])
```

## Testing

### Unit Testing API Routes

```typescript
import { GET } from "./route"
import type { ApiResponse } from "@/types"

describe("GET /api/v1/users", () => {
  it("returns users on success", async () => {
    const req = new Request("http://localhost:3000/api/v1/users")
    const response = await GET(req)
    const result: ApiResponse<User[]> = await response.json()

    expect(result.error).toBeNull()
    expect(result.data).toBeInstanceOf(Array)
  })

  it("returns error on auth failure", async () => {
    const req = new Request("http://localhost:3000/api/v1/users")
    const response = await GET(req)
    const result: ApiResponse<never> = await response.json()

    expect(result.data).toBeNull()
    expect(result.error).toBe("Unauthorized")
    expect(response.status).toBe(401)
  })
})
```

## Common Mistakes

### ❌ Forgetting error field in success response

```typescript
// Wrong
return NextResponse.json({ data: users })

// Correct
return NextResponse.json({ data: users, error: null })
```

### ❌ Forgetting data field in error response

```typescript
// Wrong
return NextResponse.json({ error: "Failed" }, { status: 500 })

// Correct
return NextResponse.json(
  { data: null, error: "Failed" },
  { status: 500 }
)
```

### ❌ Not using satisfies operator

```typescript
// Wrong - no compile-time checking
return NextResponse.json({ data: users, error: null })

// Correct - TypeScript verifies shape
return NextResponse.json(
  { data: users, error: null } satisfies ApiResponse<typeof users>
)
```

### ❌ Wrong generic parameter for errors

```typescript
// Wrong - T is never used in error responses
return NextResponse.json(
  { data: null, error: "Failed" } satisfies ApiResponse<User>,
  { status: 500 }
)

// Correct
return NextResponse.json(
  { data: null, error: "Failed" } satisfies ApiResponse<never>,
  { status: 500 }
)
```

## Related Skills

- **api-routes-js** - Complete API route patterns with this response type
- **error-handling-js** - Error handling strategies in API routes
- **typescript-typing** - Advanced TypeScript patterns for type safety
- **rbac-permissions** - Authorization checks that return typed responses
