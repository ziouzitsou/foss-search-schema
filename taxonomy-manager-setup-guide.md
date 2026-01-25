# 🎯 Taxonomy Manager - Setup Guide

## Project Overview

Create a standalone Next.js application for managing the product taxonomy system used by FOSSAPP. This tool will provide CRUD operations for the `search.taxonomy` table and related classification rules, with the potential to be integrated as an admin plugin into FOSSAPP later.

**Location**: `/home/sysadmin/tools/taxonomy-manager/`

## 🔧 Tech Stack (Match FOSSAPP)

**CRITICAL: Use the exact same stack as the main FOSSAPP application:**

- **Framework**: Next.js 16.0.0 with App Router + Turbopack
- **Language**: TypeScript (strict mode)
- **Authentication**: **NONE** (no NextAuth for now - if integrated into FOSSAPP later, it will inherit FOSSAPP's authentication)
- **Database**: Supabase PostgreSQL (connection details provided below)
- **UI Library**: shadcn/ui (Radix UI + Tailwind CSS)
- **Styling**: Tailwind CSS with HSL color system
- **Port**: Run on port 3003 (to avoid conflicts with FOSSAPP on 8080)

## 📊 Database Connection

**Supabase Project**: `hyppizgiozyyyelwdius.supabase.co`

**Required Environment Variables** (`.env.local`):
```bash
# Supabase (Read from main FOSSAPP .env.local)
NEXT_PUBLIC_SUPABASE_URL=https://hyppizgiozyyyelwdius.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<copy from FOSSAPP>
SUPABASE_SERVICE_ROLE_KEY=<copy from FOSSAPP>
```

**Note**: Since there's no authentication, this tool should only be run locally and not exposed publicly. When integrated into FOSSAPP, it will be protected by FOSSAPP's authentication.

## 🚫 CRITICAL: Database Access Rules

### READ-ONLY Objects (DO NOT MODIFY)

**NEVER modify these existing database objects:**

1. **Tables**:
   - `search.taxonomy` - Structure is read-only, but you CAN INSERT/UPDATE/DELETE rows
   - `search.classification_rules` - Structure is read-only, but you CAN INSERT/UPDATE/DELETE rows
   - `search.product_taxonomy_flags` - **MATERIALIZED VIEW** - Refresh only, never UPDATE
   - `items.product_info` - **READ-ONLY** - Use for product counts/previews only

2. **Functions**:
   - `search.get_taxonomy_tree()` - Use as-is
   - Any function in `search.*` or `items.*` schema

3. **Views**:
   - All materialized views are read-only (refresh only)

### ALLOWED Operations

✅ **You CAN**:
- INSERT/UPDATE/DELETE rows in `search.taxonomy`
- INSERT/UPDATE/DELETE rows in `search.classification_rules`
- CREATE new helper functions in a new schema (e.g., `taxonomy_admin.*`)
- CREATE new tables for audit logs, history, etc. in a new schema
- REFRESH materialized views after changes
- Query existing tables for display/validation

❌ **You CANNOT**:
- ALTER table structures
- DROP existing tables/functions/views
- UPDATE materialized views directly (use REFRESH instead)
- Modify any `items.*` schema objects

## 📋 Required Features

### 1. Taxonomy CRUD

**List View**:
- Display hierarchical tree of all taxonomy entries
- Show: code, name, parent_code, level, display_order, active status
- Filter by active/inactive
- Search by code or name
- Show product count per category (from `search.product_taxonomy_flags`)

**Create/Edit Form**:
- Code (auto-suggest format: `PARENT-CHILD`)
- Name (English, user-friendly)
- Parent Code (dropdown of existing categories)
- Level (auto-calculate based on parent)
- Display Order (numeric)
- Active (checkbox)
- Icon (optional)

**Delete Operation**:
- Check for dependencies (children categories, classification rules, products)
- Show warning if products are affected
- Offer cascade delete option for children
- Create audit log entry

**Validation Rules**:
- Code: Uppercase, alphanumeric + dashes only, unique
- Name: Required, max 100 chars
- Parent Code: Must exist in taxonomy table (FK validation)
- Level: Auto-calculate (parent level + 1, or 1 if no parent)
- Display Order: Positive integer

### 2. Classification Rules Management

**List View**:
- Show all classification rules
- Display: rule_name, taxonomy_code, flag_name, priority, active status
- Filter by taxonomy_code
- Filter by active/inactive

**Create/Edit Form**:
- Rule Name (descriptive, unique)
- Description (optional)
- Taxonomy Code (dropdown from taxonomy table)
- Flag Name (dropdown: luminaire, lamp, driver, accessory, indoor, outdoor, etc.)
- Priority (integer, higher = runs first)
- ETIM Group IDs (optional array)
- ETIM Class IDs (optional array)
- ETIM Feature Conditions (JSON editor)
- Text Pattern (regex, optional)
- Active (checkbox)

**Delete Operation**:
- Show which products will be affected (query product_taxonomy_flags)
- Require confirmation
- Create audit log entry

### 3. Bulk Operations

**Import/Export**:
- Export taxonomy to JSON/CSV
- Import taxonomy from JSON/CSV (with validation)
- Export classification rules to JSON

**Batch Updates**:
- Bulk activate/deactivate categories
- Bulk update display_order
- Bulk assign icon to categories

### 4. Audit & History

**Create audit log table** (`taxonomy_admin.audit_log`):
```sql
CREATE SCHEMA IF NOT EXISTS taxonomy_admin;

CREATE TABLE taxonomy_admin.audit_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    record_id TEXT NOT NULL,  -- code for taxonomy, rule_name for rules
    old_data JSONB,
    new_data JSONB,
    changed_by TEXT NOT NULL,  -- username or 'system'
    changed_at TIMESTAMP DEFAULT NOW()
);
```

**Audit Log View**:
- Show all changes with before/after values
- Filter by table, operation, date range, user
- Export audit log to CSV

### 5. Materialized View Management

**After any taxonomy/rule changes**:
- Show button: "Refresh Product Classifications"
- Execute: `REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;`
- Show progress indicator (can take 5-10 seconds)
- Display refresh timestamp and duration

### 6. Validation & Preview

**Before saving changes**:
- Validate all FK constraints
- Check for circular dependencies in taxonomy hierarchy
- Preview affected products (show count and sample)
- Warn about breaking changes

**Taxonomy Tree Validator**:
- Ensure no orphaned nodes
- Ensure no circular references (parent pointing to child)
- Ensure level consistency (parent.level + 1 = child.level)
- Warn about duplicate display_order at same level

## 🎨 UI/UX Requirements

### Layout

Use a clean, simple layout without authentication:
- Sidebar navigation (Dashboard, Taxonomy, Rules, Audit Log)
- Top bar with app title and theme toggle
- Responsive design (mobile-friendly)
- Dark mode support (via next-themes)

**No user profile/logout** since there's no authentication.

### Components

Use shadcn/ui components:
- **TreeView** - For hierarchical taxonomy display (use Accordion + nested structure)
- **DataTable** - For listing taxonomy/rules with sorting, filtering, pagination
- **Form** - For create/edit operations (with validation)
- **Dialog** - For confirmations and warnings
- **Toast** - For success/error notifications
- **Badge** - For status indicators (active/inactive, product count)
- **Command** - For search/command palette (optional but nice)

### Color Coding

- 🟢 Active categories - Green badge
- 🔴 Inactive categories - Red badge
- 🟡 Categories with warnings - Yellow badge
- 🔵 New/modified entries - Blue highlight

## 🔗 Supabase Client Pattern

**IMPORTANT**: Use the dual-client pattern from FOSSAPP:

**Client-side** (`lib/supabase.ts`):
```typescript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

**Server-side** (`lib/supabase-server.ts`):
```typescript
import { createClient } from '@supabase/supabase-js'

export const supabaseServer = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { persistSession: false } }
)
```

**Use server-side client for all mutations** (INSERT/UPDATE/DELETE).

## 📁 Suggested Project Structure

```
taxonomy-manager/
├── src/
│   ├── app/
│   │   ├── layout.tsx                 # Root layout (no auth provider)
│   │   ├── page.tsx                   # Dashboard/landing
│   │   ├── taxonomy/
│   │   │   ├── page.tsx              # Taxonomy list view
│   │   │   ├── [code]/page.tsx       # Edit taxonomy entry
│   │   │   └── new/page.tsx          # Create new taxonomy entry
│   │   ├── rules/
│   │   │   ├── page.tsx              # Classification rules list
│   │   │   ├── [id]/page.tsx         # Edit rule
│   │   │   └── new/page.tsx          # Create new rule
│   │   ├── audit/
│   │   │   └── page.tsx              # Audit log viewer
│   │   └── api/
│   │       ├── taxonomy/             # Taxonomy CRUD endpoints
│   │       └── rules/                # Rules CRUD endpoints
│   │
│   ├── components/
│   │   ├── ui/                        # shadcn/ui components
│   │   ├── taxonomy-tree.tsx          # Hierarchical tree view
│   │   ├── taxonomy-form.tsx          # Create/edit form
│   │   ├── rule-form.tsx              # Rule create/edit form
│   │   └── refresh-matview-button.tsx # Materialized view refresh
│   │
│   ├── lib/
│   │   ├── supabase.ts                # Client-side Supabase
│   │   ├── supabase-server.ts         # Server-side Supabase
│   │   ├── actions.ts                 # Server actions
│   │   └── validations.ts             # Zod schemas for validation
│   │
│   └── types/
│       ├── taxonomy.ts                # TypeScript interfaces
│       └── rules.ts                   # Rule interfaces
│
├── supabase/
│   └── migrations/
│       └── YYYYMMDD_create_admin_schema.sql  # Admin schema setup
│
├── .env.local                          # Environment variables
├── package.json
└── README.md
```

## 🔐 Security Considerations

1. **No Public Access**: This tool should ONLY be run locally (localhost:3003)
2. **Do NOT deploy publicly** without adding authentication
3. **Validation**: Server-side validation for all inputs (use Zod schemas)
4. **Audit Trail**: Log all changes with timestamp
5. **Read-only checks**: Verify permissions before any write operations

**Future Integration**: When integrated into FOSSAPP, wrap all routes with FOSSAPP's authentication middleware to check for admin role.

## 🧪 Testing Checklist

Before considering complete:

1. ✅ Can create new taxonomy category
2. ✅ Can edit existing category
3. ✅ Can delete category (with dependency check)
4. ✅ Can create classification rule
5. ✅ Can edit classification rule
6. ✅ Can delete rule (with warning)
7. ✅ Materialized view refresh works
8. ✅ Audit log captures all changes
9. ✅ Validation prevents invalid data
10. ✅ Tree view shows correct hierarchy
11. ✅ No modifications to FOSSAPP database structure
12. ✅ Dark mode works correctly

## 📦 Initial Setup Commands

```bash
# Navigate to tools directory
cd /home/sysadmin/tools/

# Create new Next.js app
npx create-next-app@latest taxonomy-manager --typescript --tailwind --app --use-npm

# Install dependencies
cd taxonomy-manager
npm install @supabase/supabase-js react-icons lucide-react zod

# Install shadcn/ui
npx shadcn@latest init

# Add commonly needed components
npx shadcn@latest add button card input label textarea select checkbox dialog toast badge table accordion separator scroll-area

# Create .env.local (copy values from FOSSAPP)
cp /home/sysadmin/nextjs/fossapp/.env.local .env.local
# Edit .env.local to remove NextAuth variables

# Run dev server
npm run dev  # Should start on port 3003
```

## 🎯 Success Criteria

The tool is complete when:
- ✅ Dimitri can manage taxonomy without SQL queries
- ✅ All changes are audited and reversible
- ✅ Product counts update correctly after changes
- ✅ No risk of breaking FOSSAPP database structure
- ✅ UI matches FOSSAPP style and UX patterns
- ✅ Can be integrated into FOSSAPP as a `/admin/taxonomy` route later

---

## 💡 Additional Notes

- Reference the FOSSAPP code for patterns: `/home/sysadmin/nextjs/fossapp/`
- The `search.taxonomy` table schema is well-defined - don't alter it
- Always refresh `product_taxonomy_flags` after taxonomy/rule changes
- Consider adding a "Preview Impact" feature before applying changes
- Make the tool mobile-responsive (admins might use tablets)
- **LOCAL ONLY**: Do not deploy this tool publicly without adding authentication

## 🔄 Future Integration into FOSSAPP

When ready to integrate:
1. Move routes to `/home/sysadmin/nextjs/fossapp/src/app/admin/taxonomy/`
2. Add authentication middleware to check for admin role
3. Update navigation to include admin section
4. Ensure all routes are protected by session check
5. Update audit log to capture user email from session

---

Good luck! 🚀

**Created**: 2025-11-22
**Location**: `/home/sysadmin/tools/taxonomy-manager/`
**FOSSAPP Reference**: `/home/sysadmin/nextjs/fossapp/`
