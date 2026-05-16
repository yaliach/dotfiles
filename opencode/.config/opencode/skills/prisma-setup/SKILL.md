---
name: prisma-setup
description: >
  Prisma ORM setup and configuration patterns for Next.js applications with PostgreSQL.
  Use when setting up Prisma in new projects, adding models, configuring database
  connections, or working with migrations. Covers schema conventions, Prisma client
  initialization with native PostgreSQL adapter, custom output paths, model relationships,
  and migration workflows.
---

This skill covers the complete Prisma setup used in this project with PostgreSQL
as the database. This configuration uses the native PostgreSQL adapter for optimal
performance and a custom client output path for better organization.

Cross-reference the `better-auth-integration` skill for required Better-auth models,
`api-routes-js` for Prisma usage patterns in routes, and `typescript-typing` for
type inference from Prisma models.

## Prisma Configuration Overview

This project uses:
- **Prisma 7.5.0** - Latest ORM with improved performance
- **PostgreSQL** - Production database
- **Native PostgreSQL adapter** - `@prisma/adapter-pg` for better performance
- **Custom output path** - `generated/prisma/client` (not default `node_modules`)

## File Structure

```
project/
├── prisma/
│   ├── schema.prisma       # Database schema
│   ├── migrations/         # Migration files (auto-generated)
│   └── seed.ts            # (Optional) Seed script
├── generated/
│   └── prisma/
│       └── client/         # Generated Prisma Client (custom path)
├── lib/
│   └── prisma.ts          # Prisma Client singleton
├── prisma.config.ts        # Prisma configuration (optional)
└── .env                    # Environment variables
```

## Environment Variables

```env
# .env
DATABASE_URL="postgresql://user:password@localhost:5432/dbname"

# Optional: Direct connection for migrations (if using connection pooling)
# DIRECT_URL="postgresql://user:password@localhost:5432/dbname"
```

### Connection String Format

```
postgresql://[user]:[password]@[host]:[port]/[database]?[options]
```

**Examples:**

**Local development:**
```
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/myapp"
```

**Production (with SSL):**
```
DATABASE_URL="postgresql://user:pass@db.example.com:5432/prod_db?sslmode=require"
```

**Connection pooling (Supabase, Neon, etc.):**
```
# Pooled connection for queries
DATABASE_URL="postgresql://user:pass@pooler.example.com:6543/db?pgbouncer=true"

# Direct connection for migrations
DIRECT_URL="postgresql://user:pass@db.example.com:5432/db"
```

## Prisma Schema (schema.prisma)

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
  output   = "../generated/prisma"  // Custom output path
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  // directUrl = env("DIRECT_URL")  // Uncomment if using connection pooling
}

// User model (required by Better-auth)
model User {
  id                String         @id @default(cuid())
  name              String
  email             String         @unique
  emailVerified     Boolean        @default(false)
  image             String?
  createdAt         DateTime       @default(now())
  updatedAt         DateTime       @updatedAt
  
  // Better-auth fields
  role              String         @default("user")
  banned            Boolean?       @default(false)
  banReason         String?
  twoFactorEnabled  Boolean?       @default(false)
  
  // Relations
  sessions          Session[]
  accounts          Account[]
  twoFactor         TwoFactor[]
  
  @@index([email])
}

// Session model (required by Better-auth)
model Session {
  id                String    @id
  expiresAt         DateTime
  token             String    @unique
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  ipAddress         String?
  userAgent         String?
  userId            String
  
  // Impersonation support (Better-auth admin plugin)
  impersonatedBy    String?
  activeOrganizationId String?
  
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

// Account model (required by Better-auth)
model Account {
  id                String    @id
  accountId         String
  providerId        String
  userId            String
  accessToken       String?
  refreshToken      String?
  idToken           String?
  accessTokenExpiresAt DateTime?
  refreshTokenExpiresAt DateTime?
  scope             String?
  password          String?   // For email/password auth
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

// Verification model (required by Better-auth)
model Verification {
  id                String    @id
  identifier        String
  value             String
  expiresAt         DateTime
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  
  @@unique([identifier, value])
}

// TwoFactor model (required by Better-auth twoFactor plugin)
model TwoFactor {
  id                String    @id
  secret            String
  backupCodes       String    // Encrypted JSON array
  userId            String
  
  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])
}

// Apikey model (required by Better-auth apiKey plugin)
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
  
  @@index([userId])
  @@index([hashedKey])
}

// rateLimit model (required by Better-auth rate limiting)
model rateLimit {
  id                String    @id
  key               String    @unique
  count             Int       @default(0)
  lastRequest       DateTime  @default(now())
}
```

## Schema Conventions

### Model Naming
- **PascalCase** for model names: `User`, `Session`, `ApiKey`
- **Singular** form: `User` not `Users`

### Field Naming
- **camelCase** for field names: `userId`, `createdAt`, `emailVerified`
- **Descriptive** names: `bannedAt` not `bAt`

### ID Fields
- Use `@id @default(cuid())` for primary keys
- CUID provides better randomness than UUID for database indexing
- Use `String` type (not `Int`) for better scalability

```prisma
id    String  @id @default(cuid())
```

### Timestamps
- Always include `createdAt` and `updatedAt`
- Use `@default(now())` and `@updatedAt`

```prisma
createdAt  DateTime  @default(now())
updatedAt  DateTime  @updatedAt
```

### Relations

**One-to-Many:**
```prisma
model User {
  id       String    @id @default(cuid())
  sessions Session[]  // Relation field (no column in DB)
}

model Session {
  id       String  @id @default(cuid())
  userId   String  // Foreign key
  user     User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  
  @@index([userId])  // Index for performance
}
```

**Cascade Deletion:**
- Use `onDelete: Cascade` to automatically delete child records
- Example: Deleting User deletes all their Sessions

**Indexes:**
- Always index foreign keys: `@@index([userId])`
- Index frequently queried fields: `@@index([email])`
- Unique indexes: `@unique` or `@@unique([field1, field2])`

### Optional vs. Required Fields

**Required (default):**
```prisma
name   String
email  String
```

**Optional:**
```prisma
image       String?
banReason   String?
```

**Required with default:**
```prisma
role     String  @default("user")
banned   Boolean @default(false)
```

## Prisma Client Setup (lib/prisma.ts)

```typescript
// lib/prisma.ts
import { PrismaPg } from "@prisma/adapter-pg"
import { Pool } from "pg"
import { PrismaClient } from "../generated/prisma/client"

// Create PostgreSQL connection pool
const connectionString = process.env.DATABASE_URL!

const pool = new Pool({ connectionString })

// Create adapter
const adapter = new PrismaPg(pool)

// Singleton pattern for Prisma Client
const prismaClientSingleton = () => {
  return new PrismaClient({ adapter })
}

declare global {
  var prismaGlobal: undefined | ReturnType<typeof prismaClientSingleton>
}

export const prisma = globalThis.prismaGlobal ?? prismaClientSingleton()

// Prevent multiple instances in development (hot reload)
if (process.env.NODE_ENV !== "production") {
  globalThis.prismaGlobal = prisma
}
```

### Why This Pattern?

**Singleton:**
- Prevents creating multiple Prisma Client instances
- Important in development (Next.js hot reload)
- Saves database connections

**Native Adapter:**
- `@prisma/adapter-pg` uses native PostgreSQL driver
- Better performance than default driver
- Required for connection pooling with some providers

**Connection Pool:**
- Reuses database connections
- Better performance under load
- Configurable pool size

### Custom Pool Configuration

```typescript
const pool = new Pool({
  connectionString,
  max: 20,              // Maximum pool size
  idleTimeoutMillis: 30000,  // Close idle connections after 30s
  connectionTimeoutMillis: 2000,  // Timeout after 2s
})
```

## Usage in API Routes

```typescript
// app/api/v1/users/route.ts
import { prisma } from "@/lib/prisma"

export async function GET() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      name: true,
      email: true,
    },
  })
  
  return NextResponse.json({ data: users, error: null })
}
```

### Query Patterns

**Find many:**
```typescript
const users = await prisma.user.findMany({
  where: { role: "admin" },
  orderBy: { createdAt: "desc" },
  take: 10,
  skip: 0,
})
```

**Find unique:**
```typescript
const user = await prisma.user.findUnique({
  where: { id: userId },
})

// Returns null if not found
if (!user) {
  return NextResponse.json(
    { data: null, error: "User not found" },
    { status: 404 }
  )
}
```

**Find unique or throw:**
```typescript
try {
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
  })
} catch (err) {
  // Throws if not found
  return NextResponse.json(
    { data: null, error: "User not found" },
    { status: 404 }
  )
}
```

**Create:**
```typescript
const newUser = await prisma.user.create({
  data: {
    name: "John Doe",
    email: "john@example.com",
    role: "user",
  },
})
```

**Update:**
```typescript
const updatedUser = await prisma.user.update({
  where: { id: userId },
  data: {
    name: "Jane Doe",
    banned: true,
  },
})
```

**Delete:**
```typescript
const deletedUser = await prisma.user.delete({
  where: { id: userId },
})
```

**Relations:**
```typescript
// Include relations
const user = await prisma.user.findUnique({
  where: { id: userId },
  include: {
    sessions: true,  // Include all sessions
    accounts: true,
  },
})

// Select specific fields from relations
const user = await prisma.user.findUnique({
  where: { id: userId },
  include: {
    sessions: {
      select: {
        id: true,
        createdAt: true,
      },
      orderBy: { createdAt: "desc" },
      take: 5,
    },
  },
})
```

## Type Inference

### Use Generated Types

```typescript
import type { User, Session } from "../generated/prisma/client"

// Or import from @prisma/client if using default output
// import type { User, Session } from "@prisma/client"

const user: User = await prisma.user.findUnique({ where: { id } })
```

### Prisma Payload Types

For complex queries with select/include:

```typescript
import type { Prisma } from "../generated/prisma/client"

// Type for User with sessions included
type UserWithSessions = Prisma.UserGetPayload<{
  include: { sessions: true }
}>

// Type for User with specific fields selected
type UserSubset = Prisma.UserGetPayload<{
  select: { id: true; name: true; email: true }
}>

// Use in function
async function getUser(id: string): Promise<UserWithSessions> {
  return await prisma.user.findUniqueOrThrow({
    where: { id },
    include: { sessions: true },
  })
}
```

### Infer from Query

```typescript
const user = await prisma.user.findUnique({
  where: { id },
  select: { id: true, name: true, email: true },
})

// Infer type from query result
type UserSubset = NonNullable<typeof user>
```

## Migration Workflow

### Initial Setup (New Database)

```bash
# Push schema to database (for development)
npx prisma db push

# Or create initial migration (for production)
npx prisma migrate dev --name init
```

**db push vs. migrate dev:**
- `db push` - Quick sync for development, no migration files
- `migrate dev` - Creates migration files, recommended for production

### Making Schema Changes

1. **Edit schema.prisma**
   ```prisma
   model User {
     // Add new field
     phoneNumber  String?
   }
   ```

2. **Create migration**
   ```bash
   npx prisma migrate dev --name add_phone_number
   ```

3. **Migration file created**
   ```
   prisma/migrations/20240315123456_add_phone_number/migration.sql
   ```

4. **Applied automatically in dev**

### Applying Migrations in Production

```bash
# Apply pending migrations (CI/CD)
npx prisma migrate deploy
```

**Important:** Never use `migrate dev` in production - use `migrate deploy`.

### Checking Migration Status

```bash
npx prisma migrate status
```

Shows:
- Applied migrations
- Pending migrations
- Schema drift

### Resetting Database (Development Only)

```bash
# WARNING: Deletes all data
npx prisma migrate reset
```

This:
1. Drops database
2. Creates new database
3. Applies all migrations
4. Runs seed script (if exists)

## Prisma Studio

Interactive GUI for viewing and editing data:

```bash
npx prisma studio
```

Opens at `http://localhost:5555`

**Features:**
- View all tables
- Filter and sort data
- Edit records
- Useful for development and debugging

## Seeding Database (Optional)

```typescript
// prisma/seed.ts
import { PrismaClient } from "../generated/prisma/client"
import bcrypt from "bcrypt"

const prisma = new PrismaClient()

async function main() {
  // Create admin user
  const hashedPassword = await bcrypt.hash("admin123", 10)
  
  const admin = await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {},
    create: {
      email: "admin@example.com",
      name: "Admin User",
      role: "admin",
      emailVerified: true,
      accounts: {
        create: {
          accountId: "admin-account",
          providerId: "credential",
          password: hashedPassword,
        },
      },
    },
  })

  console.log("Created admin user:", admin.email)
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
```

**Run seed:**
```bash
npx prisma db seed
```

**Configure in package.json:**
```json
{
  "prisma": {
    "seed": "ts-node prisma/seed.ts"
  }
}
```

## Common Issues

### "PrismaClient is unable to run in this browser environment"

**Cause:** Importing Prisma Client in client component.

**Solution:** Only use Prisma in Server Components and API routes.

```typescript
// ❌ Wrong - Client Component
"use client"
import { prisma } from "@/lib/prisma"  // Error!

// ✅ Correct - Server Component
import { prisma } from "@/lib/prisma"
export default async function Page() {
  const users = await prisma.user.findMany()
}
```

### "Can't reach database server"

**Cause:** Wrong connection string or database not running.

**Solutions:**
1. Check `DATABASE_URL` in `.env`
2. Ensure database is running
3. Check firewall rules
4. Verify credentials

### "Type error: Cannot find module '../generated/prisma/client'"

**Cause:** Prisma Client not generated.

**Solution:**
```bash
npx prisma generate
```

### "Migration failed: Table already exists"

**Cause:** Schema out of sync with database.

**Solutions:**
```bash
# Check status
npx prisma migrate status

# Reset (development only - deletes data)
npx prisma migrate reset

# Or manually resolve with introspect
npx prisma db pull
```

### Multiple Prisma Client instances

**Cause:** Not using singleton pattern.

**Solution:** Use the singleton pattern shown in `lib/prisma.ts`.

## Performance Tips

### Select Only Needed Fields

```typescript
// ❌ Bad - Fetches all fields
const users = await prisma.user.findMany()

// ✅ Good - Only needed fields
const users = await prisma.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
  },
})
```

### Use Indexes

```prisma
model User {
  email  String  @unique  // Automatic index
  role   String
  
  @@index([role])  // Manual index for filtering
  @@index([createdAt])  // Index for sorting
}
```

### Avoid N+1 Queries

```typescript
// ❌ Bad - N+1 queries
const users = await prisma.user.findMany()
for (const user of users) {
  const sessions = await prisma.session.findMany({ where: { userId: user.id } })
}

// ✅ Good - Single query with include
const users = await prisma.user.findMany({
  include: { sessions: true },
})
```

### Use Connection Pooling

Already configured in `lib/prisma.ts` with `@prisma/adapter-pg`.

## Related Skills

- **better-auth-integration** - Required Prisma models for Better-auth
- **api-routes-js** - Prisma usage patterns in API routes
- **typescript-typing** - Type inference from Prisma models
- **logging-js** - Log database errors with structured logging
