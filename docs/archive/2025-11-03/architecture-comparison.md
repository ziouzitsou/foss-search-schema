# Search System Architecture Comparison

Comparison between the test app implementation and FOSSAPP integration approach.

**Date**: 2025-11-03

---

## 🏗️ Two Approaches, Same Backend

Both approaches use the **same SQL functions** and **same database**, but differ in how they call them:

| Aspect | Test App | FOSSAPP Integration |
|--------|----------|---------------------|
| **Client** | `createClient(url, anonKey)` | `createClient(url, serviceRoleKey)` |
| **Location** | Browser (client component) | Server (server actions) |
| **Call Pattern** | `supabase.rpc('search_products', ...)` | `supabaseServer.rpc('search_products', ...)` |
| **Security** | Anon key (limited by RLS) | Service role key (full access) |
| **Code Location** | `app/page.tsx` | `src/lib/actions.ts` |
| **Input Validation** | Client-side only | Server-side (secure) |

---

## 📋 Test App Architecture

### Purpose
Quick testing and validation of search functionality with minimal setup.

### File Structure
```
search-test-app/
├── app/page.tsx              ← Client component with UI
├── lib/supabase.ts           ← Client with ANON key
└── .env.local                ← Anon key exposed to browser
```

### Code Flow

```typescript
// 1. Client Component (Browser)
'use client'
import { supabase } from '@/lib/supabase'  // Anon key client

async function handleSearch() {
  // 2. Direct RPC call from browser
  const { data } = await supabase.rpc('search_products', {
    p_indoor: true,
    p_power_min: 10,
    p_power_max: 50
  })

  // 3. Display results
  setProducts(data)
}
```

### Security Model
- Uses anon key (safe to expose to browser)
- Limited by Row Level Security (RLS)
- Permissions granted in `05-grant-permissions.sql`:
  ```sql
  GRANT USAGE ON SCHEMA search TO anon, authenticated;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA search TO anon, authenticated;
  ```

### Pros
✅ Simple - single file, minimal setup
✅ Fast to test - immediate feedback
✅ Good for prototyping

### Cons
❌ Anon key exposed to browser
❌ No server-side validation
❌ Limited by RLS permissions
❌ Not suitable for production

---

## 🏢 FOSSAPP Integration Architecture

### Purpose
Production-ready search with full security and FOSSAPP's existing patterns.

### File Structure
```
fossapp/
├── src/lib/actions.ts         ← Server actions with search functions
├── src/lib/supabase-server.ts ← Service role client (NEVER in browser)
├── src/app/products/page.tsx  ← Client component calls server actions
└── .env.local                 ← Service role key (server-only)
```

### Code Flow

```typescript
// 1. Client Component (Browser)
'use client'

async function handleSearch() {
  // 2. Call SERVER ACTION (not direct DB call)
  const results = await searchProductsServerAction({
    indoor: true,
    powerMin: 10,
    powerMax: 50
  })

  // 3. Display results
  setProducts(results)
}

// --- SERVER BOUNDARY ---

// 4. Server Action (runs on server)
'use server'
import { supabaseServer } from './supabase-server'  // Service role

export async function searchProductsServerAction(filters: SearchFilters) {
  // 5. Validate input (server-side - secure!)
  const validated = validateSearchFilters(filters)

  // 6. RPC call from server (service role key)
  const { data } = await supabaseServer.rpc('search_products', {
    p_indoor: validated.indoor,
    p_power_min: validated.powerMin,
    p_power_max: validated.powerMax
  })

  return data || []
}
```

### Security Model
- Uses service role key (NEVER exposed to browser)
- Bypasses RLS (full admin access)
- Server-side input validation
- Follows FOSSAPP's existing security patterns

### Pros
✅ Production-ready security
✅ Server-side validation
✅ Full database access
✅ Matches existing FOSSAPP patterns
✅ No client-side key exposure

### Cons
❌ More code (but better organized)
❌ Requires understanding of server actions

---

## 🔐 Security Comparison

### Test App (Anon Key)

**Browser sees**:
```javascript
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Network request** (visible in DevTools):
```http
POST https://xxx.supabase.co/rest/v1/rpc/search_products
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{"p_indoor": true, "p_power_min": 10, "p_power_max": 50}
```

**Access**: Limited by permissions in `05-grant-permissions.sql`

---

### FOSSAPP (Service Role)

**Browser sees**:
```javascript
// Nothing! No Supabase keys in browser
// Only Next.js server action endpoint
```

**Network request** (visible in DevTools):
```http
POST http://localhost:8080/_next/data/searchProductsServerAction
Content-Type: application/json

{"indoor": true, "powerMin": 10, "powerMax": 50}
```

**Server then makes**:
```http
POST https://xxx.supabase.co/rest/v1/rpc/search_products
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...[SERVICE_ROLE_KEY]
```

**Access**: Full admin (service role bypasses RLS)

---

## 🎯 When to Use Each

### Use Test App When:
- ✅ Quick testing/prototyping
- ✅ Validating search logic
- ✅ Demonstrating to stakeholders
- ✅ Learning how search works
- ✅ Debugging search queries

### Use FOSSAPP Integration When:
- ✅ Production deployment
- ✅ Real user access
- ✅ Need full database access
- ✅ Want server-side validation
- ✅ Following security best practices

---

## 🔄 Migration Path

### Step 1: Test with Test App
```bash
cd /home/dimitris/foss/searchdb/search-test-app
# Already running at http://localhost:3001
```

Test all functionality:
- ✅ Search works
- ✅ Filters work
- ✅ Results display correctly
- ✅ Performance acceptable

### Step 2: Copy to FOSSAPP
```typescript
// Copy server actions from search-server-actions.ts
// to /home/dimitris/foss/fossapp/src/lib/actions.ts
```

### Step 3: Build UI in FOSSAPP
```typescript
// Create search page using server actions
// Follow patterns from FOSSAPP_INTEGRATION_GUIDE.md
```

### Step 4: Test in FOSSAPP
```bash
cd /home/dimitris/foss/nextjs/fossapp
npm run dev  # Port 8080
```

### Step 5: Deploy
```bash
cd /home/dimitris/foss/nextjs/fossapp
docker-compose up -d
```

---

## 📊 Performance Comparison

Both approaches have **identical query performance** because they:
- Use the same SQL functions
- Query the same materialized views
- Hit the same database

**Differences**:

| Metric | Test App | FOSSAPP |
|--------|----------|---------|
| **Network hops** | 1 (browser → Supabase) | 2 (browser → Next.js → Supabase) |
| **Latency** | ~100-200ms | ~120-250ms |
| **Bundle size** | Slightly larger (Supabase client) | Smaller (no client) |
| **Caching** | Limited (client-side) | Full (server-side) |

The ~20-50ms difference is negligible for user experience.

---

## 🛠️ Both Use the Same Backend

Both approaches call the **exact same PostgreSQL functions**:

### Public Schema Wrappers (created in 05-grant-permissions.sql)
```sql
-- These wrappers make RPC calls work from both approaches
CREATE FUNCTION public.search_products(...) AS $$
BEGIN
    RETURN QUERY SELECT * FROM search.search_products(...);
END;
$$ LANGUAGE plpgsql STABLE;
```

### Actual Search Logic (in search schema)
```sql
-- The real search happens here (same for both approaches)
CREATE FUNCTION search.search_products(...) AS $$
BEGIN
    -- Query materialized views
    -- Apply filters
    -- Calculate relevance
    -- Return results
END;
$$ LANGUAGE plpgsql STABLE;
```

So:
- **Test App**: `browser → public.search_products() → search.search_products()`
- **FOSSAPP**: `browser → server action → public.search_products() → search.search_products()`

Same final destination, just different routes!

---

## 📝 Code Comparison

### Test App: Client-Side

```typescript
// app/page.tsx - ALL IN ONE FILE
'use client'

import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!  // ⚠️ Exposed to browser
)

export default function SearchPage() {
  async function search() {
    const { data } = await supabase.rpc('search_products', {
      p_indoor: true  // ⚠️ No validation
    })
    setResults(data)
  }

  return <button onClick={search}>Search</button>
}
```

### FOSSAPP: Server-Side

```typescript
// app/products/page.tsx - CLIENT COMPONENT
'use client'

import { searchProductsServerAction } from '@/lib/actions'

export default function ProductsPage() {
  async function search() {
    const results = await searchProductsServerAction({
      indoor: true  // ✅ Will be validated on server
    })
    setResults(results)
  }

  return <button onClick={search}>Search</button>
}

// --- SERVER BOUNDARY ---

// src/lib/actions.ts - SERVER ACTION
'use server'

import { supabaseServer } from './supabase-server'

export async function searchProductsServerAction(filters: SearchFilters) {
  // ✅ Validate input
  const validated = validateSearchFilters(filters)

  // ✅ Use service role (server-only)
  const { data } = await supabaseServer.rpc('search_products', {
    p_indoor: validated.indoor
  })

  return data || []
}

// src/lib/supabase-server.ts - SERVICE ROLE CLIENT
const supabaseServer = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!  // ✅ NEVER exposed
)
```

---

## ✅ Summary

### Test App
**Purpose**: Quick testing and validation
**Security**: Anon key (safe but limited)
**Complexity**: Low (single file)
**Use for**: Testing, prototyping, demos

### FOSSAPP Integration
**Purpose**: Production deployment
**Security**: Service role (full access, secure)
**Complexity**: Medium (server actions pattern)
**Use for**: Real users, production, long-term

### Both approaches:
- ✅ Use same SQL functions
- ✅ Query same database
- ✅ Return same results
- ✅ Have same performance
- ✅ Are fully functional

**Choose based on your use case!**

---

## 🚀 Recommendation

1. **Test with test app** (http://localhost:3001) to validate functionality
2. **Integrate into FOSSAPP** using server actions for production
3. **Keep test app** as a development/debugging tool

Both can coexist! The test app is great for quick experiments, while FOSSAPP integration is for real users.
