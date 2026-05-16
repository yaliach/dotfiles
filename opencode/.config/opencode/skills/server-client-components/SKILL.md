---
name: server-client-components
description: >
  Next.js 16 App Router Server Component and Client Component patterns. Use when
  creating pages, layouts, or components. Covers when to use each type, data fetching
  patterns, data mutation flows, auth checks, provider patterns, and passing data
  between Server and Client Components.
---

This skill covers the complete Server Component vs Client Component patterns used
in Next.js 16 App Router applications. Understanding when to use each type is
critical for optimal performance and correct architecture.

Cross-reference the `better-auth-integration`, `rbac-permissions`, and `api-routes-js`
skills when implementing components with authentication and data access.

## Default: Server Components

**By default, all components in the App Router are Server Components.**

You don't need any special syntax - just write a regular React component:

```typescript
// app/users/page.tsx
// This is a Server Component (default)

import { prisma } from "@/lib/prisma"

export default async function UsersPage() {
  // ✅ Can access database directly
  const users = await prisma.user.findMany()
  
  return <div>{users.length} users</div>
}
```

Server Components:
- Run only on the server
- Can be async functions
- Can access databases, file systems, environment variables
- Don't increase client JavaScript bundle size
- Cannot use React hooks (useState, useEffect, etc.)
- Cannot use browser APIs (window, localStorage, etc.)
- Cannot have event handlers (onClick, onChange, etc.)

## Client Components: "use client"

Client Components require an explicit directive at the top of the file:

```typescript
// components/Counter.tsx
"use client"

import { useState } from "react"

export default function Counter() {
  const [count, setCount] = useState(0)
  
  return (
    <button onClick={() => setCount(count + 1)}>
      Count: {count}
    </button>
  )
}
```

Client Components:
- Run on both server (for SSR) and client (for interactivity)
- **Cannot** be async functions
- Increase client JavaScript bundle size
- Can use React hooks (useState, useEffect, etc.)
- Can use browser APIs (window, localStorage, etc.)
- Can have event handlers (onClick, onChange, etc.)
- Cannot access server-only APIs (databases, file systems)

## When to Use Each Type

### Use Server Components For:

1. **Pages that fetch data**
   ```typescript
   export default async function UsersPage() {
     const users = await prisma.user.findMany()
     return <UsersTable users={users} />
   }
   ```

2. **Layouts with auth checks**
   ```typescript
   export default async function AppLayout({ children }) {
     const session = await auth.api.getSession({ headers: await headers() })
     if (!session) redirect("/auth/sign-in")
     return <div>{children}</div>
   }
   ```

3. **Static content**
   ```typescript
   export default function AboutPage() {
     return <div>About us...</div>
   }
   ```

4. **Components that only render (no interactivity)**
   ```typescript
   export default function UserCard({ user }) {
     return <div>{user.name}</div>
   }
   ```

### Use Client Components For:

1. **Interactive forms**
   ```typescript
   "use client"
   export default function LoginForm() {
     const [email, setEmail] = useState("")
     return <input value={email} onChange={(e) => setEmail(e.target.value)} />
   }
   ```

2. **Components using hooks**
   ```typescript
   "use client"
   export default function UserMenu() {
     const { data: session } = useSession()
     const router = useRouter()
     return <button onClick={() => router.push("/profile")}>Profile</button>
   }
   ```

3. **Components with browser APIs**
   ```typescript
   "use client"
   export default function ThemeToggle() {
     useEffect(() => {
       const theme = localStorage.getItem("theme")
       // ...
     }, [])
   }
   ```

4. **Tables with client-side filtering/sorting**
   ```typescript
   "use client"
   export default function UsersTable({ users }) {
     const [searchTerm, setSearchTerm] = useState("")
     const filtered = users.filter(u => u.name.includes(searchTerm))
     return <div>{/* table */}</div>
   }
   ```

5. **Provider components**
   ```typescript
   "use client"
   export default function SessionProvider({ children }) {
     return <SessionContext.Provider value={...}>{children}</SessionContext.Provider>
   }
   ```

## Data Fetching Pattern (Server Components)

The recommended pattern is to **fetch data in Server Components** and pass it to
Client Components as props.

```typescript
// app/(app)/users/page.tsx (Server Component)
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/prisma"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import UsersTable from "@/components/UsersTable"

export default async function UsersPage() {
  // 1. Check authentication
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) redirect("/auth/sign-in")

  // 2. Check authorization
  const userRole = session.user.role
  if (userRole !== "admin") redirect("/dashboard")

  // 3. Fetch data from database (no API route needed!)
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      name: true,
      email: true,
      emailVerified: true,
      role: true,
      twoFactorEnabled: true,
      banned: true,
      banReason: true,
      createdAt: true,
      updatedAt: true,
    },
  })

  // 4. Pass data to Client Component
  return (
    <div>
      <h1>User Management</h1>
      <UsersTable users={users} />
    </div>
  )
}
```

**Why this pattern?**
- No unnecessary API route for initial data
- Direct database access is faster
- Auth check happens once on the server
- Data is serialized and sent to client automatically
- Type safety from database to client

## Data Mutation Pattern (Client Components + API Routes)

For data mutations (create, update, delete), use API routes called from Client Components.

```typescript
// components/UsersTable.tsx (Client Component)
"use client"

import { useState } from "react"
import { toast } from "sonner"
import type { ApiResponse } from "@/types"

interface User {
  id: string
  name: string
  email: string
  // ... other fields
}

interface UsersTableProps {
  users: User[]  // Initial data from Server Component
}

export default function UsersTable({ users: initialUsers }: UsersTableProps) {
  // 1. Local state initialized with server data
  const [users, setUsers] = useState(initialUsers)
  const [newUser, setNewUser] = useState({ name: "", email: "", password: "" })

  // 2. Mutation function that calls API route
  const handleCreateUser = async () => {
    try {
      // Call API route for mutation
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

      // 3. Refetch data after mutation
      const usersResponse = await fetch("/api/v1/users")
      const usersResult: ApiResponse<User[]> = await usersResponse.json()
      
      if (!usersResult.error) {
        setUsers(usersResult.data)
      }

      toast.success("User created successfully")
      setNewUser({ name: "", email: "", password: "" })
    } catch (error) {
      toast.error("Failed to create user")
    }
  }

  const handleDeleteUser = async (userId: string) => {
    if (!confirm("Are you sure?")) return

    try {
      const response = await fetch(`/api/v1/users/${userId}`, {
        method: "DELETE",
      })

      const result: ApiResponse<{ id: string }> = await response.json()

      if (result.error) {
        toast.error(result.error)
        return
      }

      // Optimistic update (remove from local state)
      setUsers(users.filter(user => user.id !== userId))
      toast.success("User deleted successfully")
    } catch (error) {
      toast.error("Failed to delete user")
    }
  }

  return (
    <div>
      {/* Create form */}
      <input
        value={newUser.name}
        onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
      />
      <button onClick={handleCreateUser}>Create</button>

      {/* Table */}
      <table>
        {users.map(user => (
          <tr key={user.id}>
            <td>{user.name}</td>
            <td>
              <button onClick={() => handleDeleteUser(user.id)}>Delete</button>
            </td>
          </tr>
        ))}
      </table>
    </div>
  )
}
```

**Pattern breakdown:**
1. Initialize state with `initialUsers` prop from Server Component
2. Mutations call API routes (not direct database access)
3. After mutation, either:
   - Refetch data from API (server-authoritative)
   - Optimistic update (update local state immediately)
4. Show toast notifications for user feedback

## Authentication Patterns

### In Server Components (Pages, Layouts)

```typescript
// app/(app)/layout.tsx
import { auth } from "@/lib/auth"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import Sidebar from "@/components/Sidebar"
import TopBar from "@/components/TopBar"

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  // Get session in Server Component
  const session = await auth.api.getSession({ headers: await headers() })
  
  // Redirect if not authenticated
  if (!session?.user) {
    redirect("/auth/sign-in")
  }

  const userRole = session.user.role

  return (
    <div className="flex h-screen">
      {/* Pass user data to Client Components */}
      <Sidebar userRole={userRole} />
      <div className="flex-1">
        <TopBar userName={session.user.name} userRole={userRole} />
        {children}
      </div>
    </div>
  )
}
```

**Key points:**
- Use `await headers()` in Next.js 15+ for dynamic rendering
- Session check happens once at layout level
- Pass only necessary user data to Client Components (not entire session)
- Use `redirect()` for navigation (not `useRouter()`)

### In Client Components (Using useSession Hook)

```typescript
// components/UserMenu.tsx
"use client"

import { useSession } from "@/lib/auth-client"
import { useRouter } from "next/navigation"
import { useEffect } from "react"

export default function UserMenu() {
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

  return (
    <div>
      <p>{session.user.name}</p>
      <button onClick={() => router.push("/profile")}>Profile</button>
    </div>
  )
}
```

**Key points:**
- Use `useSession()` hook from Better-auth client
- Check `isPending` before checking `session` (avoid flash of wrong state)
- Use `useRouter()` for navigation in Client Components
- Prefer Server Component auth when possible (better performance)

## Passing Data Between Components

### Server → Client (Props)

Server Components can pass data to Client Components via props:

```typescript
// app/page.tsx (Server Component)
import ClientComponent from "@/components/ClientComponent"

export default async function Page() {
  const data = await fetchData()
  
  // ✅ Pass data as props
  return <ClientComponent data={data} />
}

// components/ClientComponent.tsx (Client Component)
"use client"

interface Props {
  data: DataType
}

export default function ClientComponent({ data }: Props) {
  // Use data in client component
  return <div>{data.name}</div>
}
```

**Serialization rules:**
- Data must be JSON-serializable
- Cannot pass functions, classes, Date objects (convert to strings)
- Use `JSON.stringify()` / `JSON.parse()` if needed

### Client → Server (Not Possible Directly)

Client Components cannot pass data to Server Components. Instead:

1. **Use API routes** for data mutations
2. **Use Server Actions** (if needed, though not used in this template)

```typescript
// Client Component
"use client"

export default function Form() {
  const handleSubmit = async (formData) => {
    // Call API route, not Server Component
    await fetch("/api/v1/submit", {
      method: "POST",
      body: JSON.stringify(formData),
    })
  }
  
  return <form onSubmit={handleSubmit}>...</form>
}
```

### Client → Client (Context/Props)

Use React Context or props to share data between Client Components:

```typescript
// providers/SessionProvider.tsx
"use client"

import { createContext, useContext } from "react"
import { useSession } from "@/lib/auth-client"

const SessionContext = createContext(null)

export function SessionProvider({ children }) {
  const session = useSession()
  return <SessionContext.Provider value={session}>{children}</SessionContext.Provider>
}

export const useSessionContext = () => useContext(SessionContext)

// Usage in any Client Component:
const session = useSessionContext()
```

## Provider Pattern

Providers must be Client Components and should be used sparingly:

```typescript
// app/layout.tsx (Server Component)
import { SessionProvider } from "@/components/SessionProvider"
import { ThemeProvider } from "@/components/ThemeProvider"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider>
          <SessionProvider>
            {children}
          </SessionProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
```

```typescript
// components/SessionProvider.tsx
"use client"

export function SessionProvider({ children }: { children: React.ReactNode }) {
  // Minimal wrapper - Better-auth manages sessions internally
  return <>{children}</>
}
```

**Key points:**
- Providers go in root layout for app-wide state
- Keep providers minimal (don't fetch data in providers)
- Use `suppressHydrationWarning` on `<html>` if providers modify DOM

## Common Patterns

### Loading States in Server Components

Use `loading.tsx` files for automatic loading states:

```typescript
// app/(app)/users/loading.tsx
export default function Loading() {
  return <div>Loading users...</div>
}

// app/(app)/users/page.tsx
export default async function UsersPage() {
  const users = await fetchUsers()  // Automatic loading state
  return <UsersTable users={users} />
}
```

### Error Handling in Server Components

Use `error.tsx` files for automatic error boundaries:

```typescript
// app/(app)/users/error.tsx
"use client"  // Error boundaries must be Client Components

export default function Error({ error, reset }: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

### Conditional Client Components

Only make components Client Components if they need interactivity:

```typescript
// app/page.tsx (Server Component)
import StaticHeader from "@/components/StaticHeader"  // Server Component
import InteractiveForm from "@/components/InteractiveForm"  // Client Component

export default async function Page() {
  const data = await fetchData()
  
  return (
    <div>
      <StaticHeader data={data} />  {/* No "use client" needed */}
      <InteractiveForm />  {/* Has "use client" */}
    </div>
  )
}
```

### Composition Pattern

Compose Server and Client Components together:

```typescript
// app/page.tsx (Server Component)
import ClientWrapper from "@/components/ClientWrapper"
import ServerContent from "@/components/ServerContent"

export default async function Page() {
  const data = await fetchData()
  
  return (
    <ClientWrapper>
      <ServerContent data={data} />  {/* Still a Server Component! */}
    </ClientWrapper>
  )
}
```

**Note:** Components passed as `children` to Client Components remain Server Components
unless they have "use client".

## Performance Considerations

### Minimize Client JavaScript

```typescript
// ❌ Bad: Entire component is Client Component
"use client"

export default function Page() {
  const [count, setCount] = useState(0)
  
  return (
    <div>
      <StaticHeader />  {/* Now unnecessarily client-side */}
      <button onClick={() => setCount(count + 1)}>{count}</button>
    </div>
  )
}

// ✅ Good: Split into Server + Client
// app/page.tsx (Server Component)
import Counter from "@/components/Counter"

export default function Page() {
  return (
    <div>
      <StaticHeader />  {/* Stays server-side */}
      <Counter />  {/* Only this is client-side */}
    </div>
  )
}

// components/Counter.tsx (Client Component)
"use client"

export default function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}
```

### Use React.memo for Expensive Client Components

```typescript
"use client"

import { memo } from "react"

const ExpensiveComponent = memo(function ExpensiveComponent({ data }) {
  // Expensive computation...
  return <div>{data}</div>
})

export default ExpensiveComponent
```

### Avoid Re-fetching in Client Components

```typescript
// ❌ Bad: Fetch in Client Component
"use client"

export default function Users() {
  const [users, setUsers] = useState([])
  
  useEffect(() => {
    fetch("/api/v1/users").then(r => r.json()).then(setUsers)
  }, [])
  
  return <div>{users.map(...)}</div>
}

// ✅ Good: Fetch in Server Component, pass as props
// app/users/page.tsx (Server Component)
export default async function UsersPage() {
  const users = await prisma.user.findMany()
  return <UsersTable users={users} />
}
```

## Debugging Tips

### Check if Component is Server or Client

Add a console.log to see where it runs:

```typescript
export default function MyComponent() {
  console.log("Running on:", typeof window === "undefined" ? "server" : "client")
  // ...
}
```

### Common Errors

**"useState is not a function"**
- You forgot "use client" directive

**"Cannot use async component without streaming"**
- Client Components cannot be async
- Remove async or convert to Server Component

**"localStorage is not defined"**
- Accessing browser API in Server Component
- Add "use client" or check typeof window !== "undefined"

**"You're importing a component that needs X. It only works in a Client Component"**
- Component uses hooks but doesn't have "use client"
- Add "use client" to the component file

## Related Skills

- **better-auth-integration** - Session management in Server/Client Components
- **rbac-permissions** - Permission checks in both component types
- **api-routes-js** - API routes called from Client Components for mutations
- **client-table-crud** - Full CRUD patterns with Server/Client split
