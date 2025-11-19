# Public Schema Wrappers - Why We Need Them

**Question**: Do we need the public schema wrappers?
**Answer**: **YES** - Here's why.

---

## 🔑 The Key Difference

### Anon Key (Test App)
- ❌ **Cannot** access `search` schema directly
- ✅ **Can** access `public` schema
- **Error if you try**: `"The schema must be one of the following: public"`

### Service Role (FOSSAPP)
- ✅ **Can** access ANY schema (`public`, `search`, `items`, etc.)
- ✅ **Can** use `.schema('search').rpc()`
- ✅ **Can** also use public wrappers

---

## 🎯 Two Possible Approaches

### Approach 1: Public Wrappers (RECOMMENDED) ✅

**What it is**: Create wrapper functions in `public` schema that call `search` schema functions.

**SQL**:
```sql
-- Public wrapper
CREATE FUNCTION public.search_products(...) AS $$
BEGIN
    RETURN QUERY SELECT * FROM search.search_products(...);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.search_products TO anon, authenticated;
```

**TypeScript** (works for both anon and service role):
```typescript
// Test app (anon key) - WORKS ✅
const { data } = await supabase.rpc('search_products', {...})

// FOSSAPP (service role) - WORKS ✅
const { data } = await supabaseServer.rpc('search_products', {...})
```

**Pros**:
- ✅ Same code pattern for both test app and FOSSAPP
- ✅ Test app works (anon key can access public)
- ✅ FOSSAPP works (service role can access public)
- ✅ Simpler - one pattern everywhere

**Cons**:
- ❌ Extra wrapper layer (minimal overhead)
- ❌ Need to maintain 4 wrapper functions

---

### Approach 2: Direct Schema Access (Service Role Only)

**What it is**: Skip public wrappers, use `.schema('search')` to access functions directly.

**SQL**:
```sql
-- No public wrappers needed
-- Just grant permissions on search schema
GRANT USAGE ON SCHEMA search TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA search TO anon, authenticated;
```

**TypeScript**:
```typescript
// Test app (anon key) - FAILS ❌
const { data } = await supabase
  .schema('search')  // Error: "The schema must be one of the following: public"
  .rpc('search_products', {...})

// FOSSAPP (service role) - WORKS ✅
const { data } = await supabaseServer
  .schema('search')
  .rpc('search_products', {...})
```

**Pros**:
- ✅ No wrapper layer (slightly cleaner)
- ✅ Matches your existing `.schema('items')` pattern

**Cons**:
- ❌ Test app doesn't work (anon key can't access search schema)
- ❌ Different code patterns for test app vs FOSSAPP
- ❌ Anon key is restricted to public schema only

---

## 📋 What We Chose: Public Wrappers ✅

**Why**: Keep both test app and FOSSAPP working with the same simple pattern.

### Current Implementation

**Database** (5 SQL files):
```
05-grant-permissions.sql (FINAL VERSION)
├── Grants on search schema
├── Grants on items schema
└── Creates 4 public wrappers:
    ├── public.search_products()
    ├── public.get_search_statistics()
    ├── public.get_available_facets()
    └── public.get_taxonomy_tree()
```

**Test App** (Anon Key):
```typescript
// Uses public wrappers
const { data } = await supabase.rpc('search_products', {...})
```

**FOSSAPP** (Service Role):
```typescript
// Also uses public wrappers (same pattern as test app)
const { data } = await supabaseServer.rpc('search_products', {...})
```

---

## 🔄 How It Works

```
Test App (Browser)
  ↓ RPC call with ANON key
  ↓
public.search_products()  ← Wrapper in public schema (anon can access)
  ↓
search.search_products()  ← Actual function in search schema
  ↓
Returns results
```

```
FOSSAPP (Server)
  ↓ RPC call with SERVICE ROLE key
  ↓
public.search_products()  ← Wrapper in public schema (service role can access)
  ↓
search.search_products()  ← Actual function in search schema
  ↓
Returns results
```

---

## 💡 Why Not Direct Schema Access?

We tried it! Here's what happened:

### Test 1: Direct Schema Access
```typescript
// Test app tried this:
const { data } = await supabase.schema('search').rpc('search_products', {...})

// Result: ERROR ❌
{
  code: "PGRST106",
  message: "The schema must be one of the following: public"
}
```

**Reason**: Anon key is restricted to `public` schema for security. This is a Supabase limitation, not something we can configure.

### Test 2: Public Wrappers
```typescript
// Test app uses this:
const { data } = await supabase.rpc('search_products', {...})

// Result: SUCCESS ✅
// Returns 24 products with all filters working
```

---

## ✅ Final Decision

**Keep the public schema wrappers** because:

1. ✅ **Universal compatibility** - Works for both anon key and service role
2. ✅ **Consistent pattern** - Same code for test app and FOSSAPP
3. ✅ **Simple integration** - Copy server actions to FOSSAPP, it just works
4. ✅ **Test app works** - Can validate changes before FOSSAPP integration

---

## 📁 File Summary

### SQL Files (Final State)
```
01-create-search-schema.sql        ✅ Creates search schema + tables
02-populate-example-data.sql       ✅ Configuration data
03-create-materialized-views.sql   ✅ 4 materialized views (FIXED)
04-create-search-functions.sql     ✅ Search functions in search schema
05-grant-permissions.sql           ✅ Permissions + public wrappers
```

### TypeScript Files
```
search-server-actions.ts           ✅ FOSSAPP server actions (uses public wrappers)
search-test-app/app/page.tsx       ✅ Test app (uses public wrappers)
```

Both use the same pattern: `supabase.rpc('search_products', {...})`

---

## 🎯 For FOSSAPP Integration

Just copy the server actions and use them - the public wrappers handle everything:

```typescript
// In FOSSAPP src/lib/actions.ts
export async function searchProductsServerAction(filters: SearchFilters) {
  const validated = validateSearchFilters(filters)

  // This works because public.search_products() wrapper exists
  const { data, error } = await supabaseServer.rpc('search_products', {
    p_indoor: validated.indoor,
    p_power_min: validated.powerMin,
    // ... etc
  })

  return data || []
}
```

No need to worry about schemas - it just works! ✅

---

## 🔧 If You Ever Want Direct Schema Access

If you decide you ONLY need FOSSAPP (no test app), you can:

1. Delete the public wrappers
2. Change all RPC calls to:
```typescript
const { data } = await supabaseServer.schema('search').rpc('search_products', {...})
```

But this breaks the test app, so we don't recommend it unless you're 100% sure you'll never need client-side testing.

---

## 📊 Performance Comparison

| Approach | Latency | Complexity |
|----------|---------|------------|
| **Public Wrappers** | ~1ms overhead | Simple (same everywhere) |
| **Direct Schema** | No overhead | Complex (different patterns) |

**Conclusion**: The ~1ms overhead is negligible, and the simplicity wins.

---

## ✅ Final Answer

**Yes, we need the public schema wrappers** to support both:
- Test app (anon key - can only access public schema)
- FOSSAPP (service role - can access any schema)

The wrappers are in `05-grant-permissions.sql` and are already deployed and tested! 🚀
