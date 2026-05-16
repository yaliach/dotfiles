---
name: client-table-crud
description: >
  Client-side admin table with full CRUD operations (Create, Read, Update, Delete).
  Use when building admin interfaces with search, filter, dialogs, and data management.
  Covers state management, API calls, shadcn UI components, toast notifications,
  optimistic updates, and user feedback patterns.
---

This skill covers the complete pattern for building admin tables with CRUD operations
used in this project. This pattern provides a rich, interactive user experience while
maintaining clean code organization and type safety.

Cross-reference the `api-response-typing`, `server-client-components`, and
`typescript-typing` skills when implementing table components.

## Core Pattern Overview

The pattern consists of:

1. **Server Component (Page)** - Fetches initial data from database
2. **Client Component (Table)** - Manages UI state and API interactions
3. **API Routes** - Handle CRUD operations with authorization
4. **shadcn UI Components** - Dialog, DropdownMenu, Table, Input, etc.
5. **Toast Notifications** - User feedback with sonner

**Data Flow:**
```
Server Component (fetch) → Client Component (display + mutate) → API Route (persist)
                                    ↓
                            Update local state (optimistic or refetch)
```

## File Structure

```
app/
  (app)/
    users/
      page.tsx              # Server Component - fetches initial data
components/
  UsersTable.tsx            # Client Component - CRUD UI
  ui/
    table.tsx               # shadcn table primitives
    dialog.tsx              # shadcn dialog for forms
    dropdown-menu.tsx       # shadcn dropdown for actions
    input.tsx               # shadcn input
    button.tsx              # shadcn button
    badge.tsx               # shadcn badge for status
app/
  api/
    v1/
      users/
        route.ts            # GET, POST
        [id]/
          route.ts          # PUT, DELETE
```

## Server Component (Page)

The page is a Server Component that fetches initial data and passes it to the Client Component:

```typescript
// app/(app)/users/page.tsx
import { auth } from "@/lib/auth"
import { prisma } from "@/lib/prisma"
import { headers } from "next/headers"
import { redirect } from "next/navigation"
import UsersTable from "@/components/UsersTable"

export default async function UsersPage() {
  // 1. Authentication check
  const session = await auth.api.getSession({ headers: await headers() })
  if (!session?.user) redirect("/auth/sign-in")

  // 2. Authorization check
  const userRole = session.user.role
  if (userRole !== "admin") redirect("/dashboard")

  // 3. Fetch data (select only needed fields for performance)
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

  return (
    <div className="container mx-auto py-10">
      <h1 className="text-3xl font-bold mb-6">User Management</h1>
      <UsersTable users={users} />
    </div>
  )
}
```

## Client Component (Table) - Complete Pattern

```typescript
// components/UsersTable.tsx
"use client"

import { useState, useMemo } from "react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { MoreHorizontal, Plus, Search } from "lucide-react"
import { toast } from "sonner"
import type { ApiResponse } from "@/types"

// 1. Type definitions
interface User {
  id: string
  name: string
  email: string
  emailVerified: boolean
  role: string | null
  twoFactorEnabled: boolean | null
  banned: boolean | null
  banReason: string | null
  createdAt: Date
  updatedAt: Date
}

interface UsersTableProps {
  users: User[]
}

export default function UsersTable({ users: initialUsers }: UsersTableProps) {
  // 2. State management
  const [users, setUsers] = useState(initialUsers)
  const [searchTerm, setSearchTerm] = useState("")
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false)
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false)
  const [editingUser, setEditingUser] = useState<User | null>(null)
  
  // Form state
  const [newUser, setNewUser] = useState({
    name: "",
    email: "",
    password: "",
    role: "user" as "admin" | "user",
  })
  
  const [editingUserData, setEditingUserData] = useState({
    name: "",
    role: "user" as "admin" | "user",
  })

  // 3. Computed values (memoized for performance)
  const filteredUsers = useMemo(() => {
    if (!searchTerm.trim()) return users

    const searchLower = searchTerm.toLowerCase()
    return users.filter((user) => {
      return (
        user.name.toLowerCase().includes(searchLower) ||
        user.email.toLowerCase().includes(searchLower) ||
        user.role?.toLowerCase().includes(searchLower)
      )
    })
  }, [users, searchTerm])

  // 4. CRUD handlers (see sections below)
  const handleCreateUser = async () => { /* ... */ }
  const handleUpdateUser = async () => { /* ... */ }
  const handleDeleteUser = async (userId: string) => { /* ... */ }
  const handleToggleBanStatus = async (userId: string, currentBanned: boolean | null) => { /* ... */ }

  // 5. UI helpers
  const openEditDialog = (user: User) => {
    setEditingUser(user)
    setEditingUserData({
      name: user.name,
      role: (user.role as "admin" | "user") || "user",
    })
    setIsEditDialogOpen(true)
  }

  // 6. Render (see sections below)
  return (
    <div>
      {/* Search bar + Create button */}
      {/* Create dialog */}
      {/* Edit dialog */}
      {/* Table */}
    </div>
  )
}
```

## State Management Pattern

### Core State

```typescript
// 1. Main data (initialized from server)
const [users, setUsers] = useState(initialUsers)

// 2. UI state
const [searchTerm, setSearchTerm] = useState("")
const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false)
const [isEditDialogOpen, setIsEditDialogOpen] = useState(false)
const [editingUser, setEditingUser] = useState<User | null>(null)

// 3. Form state
const [newUser, setNewUser] = useState({
  name: "",
  email: "",
  password: "",
  role: "user" as "admin" | "user",
})

const [editingUserData, setEditingUserData] = useState({
  name: "",
  role: "user" as "admin" | "user",
})
```

### Computed State (Memoized)

```typescript
// Filter/search with useMemo to avoid re-computation on every render
const filteredUsers = useMemo(() => {
  if (!searchTerm.trim()) return users

  const searchLower = searchTerm.toLowerCase()
  return users.filter((user) => {
    return (
      user.name.toLowerCase().includes(searchLower) ||
      user.email.toLowerCase().includes(searchLower) ||
      user.role?.toLowerCase().includes(searchLower)
    )
  })
}, [users, searchTerm])
```

**Why useMemo?**
- Filtering is re-computed only when `users` or `searchTerm` changes
- Prevents expensive filtering on every render (e.g., when dialog opens/closes)

## CRUD Operations

### CREATE - Add New Item

```typescript
const handleCreateUser = async () => {
  // 1. Validation
  if (!newUser.name.trim() || !newUser.email.trim() || !newUser.password.trim()) {
    toast.error("Please fill in all fields")
    return
  }

  try {
    // 2. API call
    const response = await fetch("/api/v1/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(newUser),
    })

    // 3. Error handling
    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(errorData.error || "Failed to create user")
    }

    // 4. Refetch data (server-authoritative)
    const usersResponse = await fetch("/api/v1/users")
    const usersResult: ApiResponse<User[]> = await usersResponse.json()
    
    if (!usersResult.error) {
      setUsers(usersResult.data)
    }

    // 5. UI cleanup + feedback
    setNewUser({ name: "", email: "", password: "", role: "user" })
    setIsCreateDialogOpen(false)
    toast.success("User created successfully")
  } catch (error) {
    console.error("Error creating user:", error)
    toast.error(error instanceof Error ? error.message : "Failed to create user")
  }
}
```

**Pattern breakdown:**
- Validate input before API call
- Call POST endpoint with data
- Check response status (`response.ok`)
- Refetch data to get server state (includes ID, timestamps, etc.)
- Close dialog and reset form
- Show success/error toast

### READ - Refetch Data

```typescript
const refetchUsers = async () => {
  try {
    const response = await fetch("/api/v1/users")
    const result: ApiResponse<User[]> = await response.json()

    if (result.error) {
      toast.error(result.error)
      return
    }

    setUsers(result.data)
  } catch (error) {
    toast.error("Failed to fetch users")
  }
}
```

**When to refetch:**
- After creating a new item (to get server-assigned ID)
- After updating (to get server-computed fields)
- Periodically (if real-time updates needed)

### UPDATE - Edit Existing Item

```typescript
const handleUpdateUser = async () => {
  // 1. Validation
  if (!editingUser || !editingUserData.name.trim()) {
    toast.error("Please enter a valid name")
    return
  }

  try {
    // 2. API call
    const response = await fetch(`/api/v1/users/${editingUser.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(editingUserData),
    })

    if (!response.ok) {
      throw new Error("Failed to update user")
    }

    // 3. Get updated data from response
    const result: ApiResponse<User> = await response.json()
    const updatedUser = result.data

    if (!updatedUser) {
      throw new Error("No data returned")
    }

    // 4. Update local state (optimistic, using server response)
    setUsers(
      users.map((user) => (user.id === updatedUser.id ? updatedUser : user))
    )

    // 5. UI cleanup + feedback
    setIsEditDialogOpen(false)
    setEditingUser(null)
    toast.success("User updated successfully")
  } catch (error) {
    console.error("Error updating user:", error)
    toast.error("Failed to update user")
  }
}
```

**Pattern breakdown:**
- Similar to CREATE but uses PUT and includes ID in URL
- Update local state with response data (not form data)
- Use `map` to replace specific item in array

### DELETE - Remove Item

```typescript
const handleDeleteUser = async (userId: string) => {
  // 1. Confirmation (prevent accidental deletion)
  if (!confirm("Are you sure you want to delete this user? This action cannot be undone.")) {
    return
  }

  try {
    // 2. API call
    const response = await fetch(`/api/v1/users/${userId}`, {
      method: "DELETE",
    })

    // 3. Error handling
    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(errorData.error || "Failed to delete user")
    }

    // 4. Optimistic update (remove from local state)
    setUsers(users.filter((user) => user.id !== userId))

    // 5. Feedback
    toast.success("User deleted successfully")
  } catch (error) {
    console.error("Error deleting user:", error)
    toast.error(error instanceof Error ? error.message : "Failed to delete user")
  }
}
```

**Pattern breakdown:**
- Always confirm destructive actions
- Optimistic update for better UX (instant feedback)
- Use `filter` to remove item from array

### Custom Actions (e.g., Toggle Status)

```typescript
const handleToggleBanStatus = async (userId: string, currentBanned: boolean | null) => {
  const newStatus = !currentBanned
  const action = newStatus ? "ban" : "unban"

  // Confirmation
  if (!confirm(`Are you sure you want to ${action} this user?`)) return

  try {
    const response = await fetch(`/api/v1/users/${userId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        banned: newStatus,
        banReason: newStatus ? "Banned by administrator" : null,
      }),
    })

    if (!response.ok) {
      throw new Error(`Failed to ${action} user`)
    }

    const result: ApiResponse<User> = await response.json()
    const updatedUser = result.data

    if (!updatedUser) {
      throw new Error("No data returned")
    }

    // Update local state
    setUsers(
      users.map((user) => (user.id === updatedUser.id ? updatedUser : user))
    )

    toast.success(`User ${action}ned successfully`)
  } catch (error) {
    console.error(`Error ${action}ning user:`, error)
    toast.error(`Failed to ${action} user`)
  }
}
```

## UI Components

### Search Bar + Create Button

```typescript
<div className="mb-6 flex items-center justify-between">
  {/* Search */}
  <div className="flex items-center gap-4">
    <div className="relative w-80">
      <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
      <Input
        placeholder="Search users..."
        className="pl-8"
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
      />
    </div>
    <div className="text-sm text-muted-foreground">
      Showing {filteredUsers.length} of {users.length} users
    </div>
  </div>

  {/* Create button */}
  <Dialog
    open={isCreateDialogOpen}
    onOpenChange={(open) => {
      setIsCreateDialogOpen(open)
      if (!open) {
        setNewUser({ name: "", email: "", password: "", role: "user" })
      }
    }}
  >
    <DialogTrigger asChild>
      <Button variant="outline" className="flex items-center gap-2">
        <Plus className="h-4 w-4" />
        Create User
      </Button>
    </DialogTrigger>
    {/* Dialog content... */}
  </Dialog>
</div>
```

### Create Dialog

```typescript
<Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Create User</DialogTitle>
      <DialogDescription>
        Create a new user account with email and password.
      </DialogDescription>
    </DialogHeader>
    
    <div className="space-y-4">
      {/* Name field */}
      <div className="space-y-2">
        <Label htmlFor="userName">Name</Label>
        <Input
          id="userName"
          placeholder="John Doe"
          value={newUser.name}
          onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
        />
      </div>

      {/* Email field */}
      <div className="space-y-2">
        <Label htmlFor="userEmail">Email</Label>
        <Input
          id="userEmail"
          type="email"
          placeholder="john@example.com"
          value={newUser.email}
          onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
        />
      </div>

      {/* Password field */}
      <div className="space-y-2">
        <Label htmlFor="userPassword">Password</Label>
        <Input
          id="userPassword"
          type="password"
          placeholder="Minimum 8 characters"
          value={newUser.password}
          onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
        />
      </div>

      {/* Role select */}
      <div className="space-y-2">
        <Label htmlFor="userRole">Role</Label>
        <Select
          value={newUser.role}
          onValueChange={(value: "admin" | "user") =>
            setNewUser({ ...newUser, role: value })
          }
        >
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="user">User</SelectItem>
            <SelectItem value="admin">Admin</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>

    <DialogFooter>
      <Button variant="outline" onClick={() => setIsCreateDialogOpen(false)}>
        Cancel
      </Button>
      <Button onClick={handleCreateUser}>Create</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

### Edit Dialog

Similar to Create Dialog but:
- Pre-fills form with existing data
- Uses `editingUserData` state
- Calls `handleUpdateUser` instead of `handleCreateUser`

```typescript
<Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Edit User</DialogTitle>
      <DialogDescription>Update user information.</DialogDescription>
    </DialogHeader>
    <div className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="editUserName">Name</Label>
        <Input
          id="editUserName"
          value={editingUserData.name}
          onChange={(e) =>
            setEditingUserData({ ...editingUserData, name: e.target.value })
          }
        />
      </div>
      {/* More fields... */}
    </div>
    <DialogFooter>
      <Button variant="outline" onClick={() => setIsEditDialogOpen(false)}>
        Cancel
      </Button>
      <Button onClick={handleUpdateUser}>Save</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

### Table with Actions

```typescript
<div className="rounded-md border bg-background">
  <Table>
    <TableHeader>
      <TableRow>
        <TableHead>Name</TableHead>
        <TableHead>Email</TableHead>
        <TableHead>Role</TableHead>
        <TableHead>Status</TableHead>
        <TableHead className="w-32">Actions</TableHead>
      </TableRow>
    </TableHeader>
    <TableBody>
      {filteredUsers.length === 0 ? (
        <TableRow>
          <TableCell colSpan={5} className="text-center text-muted-foreground">
            {searchTerm ? "No users match your search." : "No users found."}
          </TableCell>
        </TableRow>
      ) : (
        filteredUsers.map((user) => (
          <TableRow key={user.id}>
            <TableCell className="font-medium">{user.name}</TableCell>
            <TableCell>{user.email}</TableCell>
            <TableCell>
              <Badge variant={user.role === "admin" ? "default" : "secondary"}>
                {(user.role || "user").charAt(0).toUpperCase() + (user.role || "user").slice(1)}
              </Badge>
            </TableCell>
            <TableCell>
              {user.banned ? (
                <Badge variant="destructive">Banned</Badge>
              ) : (
                <Badge className="bg-green-100 text-green-700">Active</Badge>
              )}
            </TableCell>
            <TableCell>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button size="icon" variant="ghost">
                    <MoreHorizontal className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => openEditDialog(user)}>
                    Edit User
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => handleToggleBanStatus(user.id, user.banned)}>
                    {user.banned ? "Unban User" : "Ban User"}
                  </DropdownMenuItem>
                  <DropdownMenuItem
                    onClick={() => handleDeleteUser(user.id)}
                    className="text-red-600"
                  >
                    Delete User
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </TableCell>
          </TableRow>
        ))
      )}
    </TableBody>
  </Table>
</div>
```

## Toast Notifications

Use sonner for user feedback:

```typescript
import { toast } from "sonner"

// Success
toast.success("User created successfully")

// Error
toast.error("Failed to create user")

// With dynamic message
toast.error(error instanceof Error ? error.message : "An error occurred")

// Custom duration
toast.success("Saved!", { duration: 2000 })
```

**When to show toasts:**
- After every successful mutation
- After every failed mutation
- For validation errors
- For confirmation of destructive actions

## Optimistic vs. Server-Authoritative Updates

### Optimistic Updates (Instant UX)

Update local state immediately, revert on error:

```typescript
// Good for: DELETE operations
const handleDelete = async (id: string) => {
  // Save original state
  const originalUsers = users
  
  // Optimistic update
  setUsers(users.filter(u => u.id !== id))
  toast.success("User deleted")
  
  try {
    await fetch(`/api/v1/users/${id}`, { method: "DELETE" })
  } catch (error) {
    // Revert on error
    setUsers(originalUsers)
    toast.error("Failed to delete user")
  }
}
```

### Server-Authoritative Updates (Safer)

Wait for server response before updating:

```typescript
// Good for: CREATE, UPDATE operations (need server-assigned fields)
const handleCreate = async () => {
  try {
    const response = await fetch("/api/v1/users", {
      method: "POST",
      body: JSON.stringify(newUser),
    })
    
    // Refetch to get server state
    const refetchResponse = await fetch("/api/v1/users")
    const result = await refetchResponse.json()
    setUsers(result.data)
    
    toast.success("User created")
  } catch (error) {
    toast.error("Failed to create user")
  }
}
```

**Recommendation:** Use server-authoritative for this pattern (as shown in examples).
It's simpler and safer, trading a small UX delay for correctness.

## Performance Optimizations

### Memoize Expensive Computations

```typescript
// ✅ Good
const filteredUsers = useMemo(() => {
  return users.filter(u => u.name.includes(searchTerm))
}, [users, searchTerm])

// ❌ Bad - recomputes on every render
const filteredUsers = users.filter(u => u.name.includes(searchTerm))
```

### Debounce Search Input

For large datasets or API-based search:

```typescript
import { useDeferredValue } from "react"

const deferredSearchTerm = useDeferredValue(searchTerm)

const filteredUsers = useMemo(() => {
  return users.filter(u => u.name.includes(deferredSearchTerm))
}, [users, deferredSearchTerm])
```

### Virtualize Large Tables

For 1000+ rows, use react-window or @tanstack/react-virtual:

```typescript
import { useVirtualizer } from "@tanstack/react-virtual"

// Virtual scrolling for performance
const rowVirtualizer = useVirtualizer({
  count: filteredUsers.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 50,
})
```

## Accessibility

### Dialog Keyboard Navigation

shadcn Dialog handles this automatically:
- ESC to close
- Tab to cycle through focusable elements
- Focus trap while open

### Confirmation Dialogs

Use native `confirm()` for simple confirmations:

```typescript
if (!confirm("Are you sure?")) return
```

Or use shadcn AlertDialog for custom styling:

```typescript
<AlertDialog>
  <AlertDialogTrigger>Delete</AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogHeader>
      <AlertDialogTitle>Are you sure?</AlertDialogTitle>
      <AlertDialogDescription>This action cannot be undone.</AlertDialogDescription>
    </AlertDialogHeader>
    <AlertDialogFooter>
      <AlertDialogCancel>Cancel</AlertDialogCancel>
      <AlertDialogAction onClick={handleDelete}>Delete</AlertDialogAction>
    </AlertDialogFooter>
  </AlertDialogContent>
</AlertDialog>
```

### Table Semantics

Use proper table markup:
- `<Table>`, `<TableHeader>`, `<TableBody>`, `<TableRow>`, `<TableHead>`, `<TableCell>`
- shadcn components use semantic HTML under the hood

## Common Patterns

### Prevent Self-Actions

```typescript
const handleDelete = async (userId: string) => {
  // Assuming you have current user session
  if (userId === currentUserId) {
    toast.error("Cannot delete your own account")
    return
  }
  // Continue with delete...
}
```

### Conditional Actions

```typescript
<DropdownMenuContent>
  <DropdownMenuItem onClick={() => openEditDialog(user)}>
    Edit
  </DropdownMenuItem>
  
  {/* Show "Ban" or "Unban" based on status */}
  {user.banned ? (
    <DropdownMenuItem onClick={() => handleUnban(user.id)}>
      Unban User
    </DropdownMenuItem>
  ) : (
    <DropdownMenuItem onClick={() => handleBan(user.id)}>
      Ban User
    </DropdownMenuItem>
  )}
  
  {/* Show "Restart 2FA" only if 2FA enabled */}
  {user.twoFactorEnabled && (
    <DropdownMenuItem onClick={() => handleRestart2FA(user.id)}>
      Restart 2FA
    </DropdownMenuItem>
  )}
</DropdownMenuContent>
```

### Empty States

```typescript
{filteredUsers.length === 0 ? (
  <TableRow>
    <TableCell colSpan={5} className="text-center text-muted-foreground">
      {searchTerm 
        ? "No users match your search." 
        : "No users found. Create one to get started."}
    </TableCell>
  </TableRow>
) : (
  // Render rows...
)}
```

## Related Skills

- **api-response-typing** - Type-safe API responses in CRUD operations
- **server-client-components** - Server/Client split pattern for data fetching
- **typescript-typing** - Type definitions for table data and props
- **rbac-permissions** - Authorization checks in CRUD operations
