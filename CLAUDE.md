# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository Overview

This is a **documentation-only repository** containing a complete implementation guide for building a high-performance product search system for the Foss SA luminaires database. The repository contains no executable code - only comprehensive documentation, SQL schemas, and integration examples.

**Target System**: Supabase (PostgreSQL) database with Next.js frontend
**Source Data**: items.product_info (materialized view filtering items.catalog by selected catalogs)
**Current Products**: 14,889+ lighting products with 1.38M ETIM features
**Production App**: FOSSAPP at https://app.titancnc.eu

---

## Documentation Structure

The repository contains three interconnected documentation files that should be read in order:

### 1. INDEX.md (Start Here)
- **Purpose**: Package overview and quick navigation
- **Read when**: First time exploring the repository
- **Contains**: File descriptions, implementation checklist, critical warnings

### 2. QUICKSTART.md (Implementation Guide)
- **Purpose**: 30-minute step-by-step implementation guide
- **Read when**: Ready to implement the search schema
- **Contains**: SQL execution order, test queries, troubleshooting, verification scripts
- **Key sections**:
  - Step-by-step SQL file execution (4 files)
  - ETIM Feature ID mapping instructions (CRITICAL)
  - Verification queries
  - Maintenance operations

### 3. search-schema-complete-guide.md (Reference)
- **Purpose**: Complete technical reference and architecture documentation
- **Read when**: Need to understand design decisions or customize implementation
- **Contains**: Full schema definitions, architecture diagrams, Next.js integration code
- **Key sections**:
  - Section 2: Architecture Overview
  - Section 3: Schema Definition (all SQL)
  - Section 5: Next.js Integration (TypeScript examples)
  - Section 7: Query Examples
  - Section 8: Maintenance & Operations

---

## Architecture Overview

This search system implements a **three-tier search architecture**:

```
1. GUIDED FINDER → Boolean flags (indoor/outdoor/recessed/etc.)
2. SMART TEXT SEARCH → Full-text + ETIM feature matching
3. TECHNICAL FILTERS → Numeric ranges (power, lumens) + alphanumeric (IP rating)
```

### Database Architecture

**Existing Database Structure (NEVER MODIFIED)**:
```
items.catalog (BASE TABLE - source of truth, all imported products)
    ↓ (filtered by selected catalogs)
items.product_info (EXISTING MATERIALIZED VIEW - 14,889 products)
    ↓ (dependent views)
items.product_features_mv (EXISTING MATERIALIZED VIEW)
items.product_categories_mv (EXISTING MATERIALIZED VIEW)
```

**New Search Schema (search.*)**:

The implementation creates a new isolated `search` schema that **reads from** existing views:

**Configuration Tables** (populated once, rarely changed):
- `taxonomy` - Hierarchical product categories
- `classification_rules` - Rules for auto-classification
- `filter_definitions` - Available filters for UI

**Materialized Views** (refreshed after catalog imports, reads from items.product_info):
- `product_taxonomy_flags` - Boolean flags per product (indoor, outdoor, recessed, etc.)
- `product_filter_index` - Flattened feature index (power, IP rating, color temp, etc.)
- `filter_facets` - Aggregated counts for filter UI
- `taxonomy_product_counts` - Product counts per category

**Key Design Principles**:
- Boolean flags for instant filtering (no JSON parsing)
- Materialized views for performance (sub-200ms queries)
- Configuration-driven (no hardcoded business logic)
- ETIM-based classification (standardized taxonomy)
- **Non-invasive**: Only reads existing data, never modifies base tables or existing mat views

---

## Critical Implementation Notes

### ⚠️ BEFORE Running SQL Files

**YOU MUST UPDATE ETIM FEATURE IDs** - The example SQL uses placeholder ETIM codes that won't match your actual database.

**How to find correct IDs**:
```sql
-- Find power feature
SELECT "FEATUREID", "FEATUREDESC"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%power%' OR "FEATUREDESC" ILIKE '%ισχύ%'
LIMIT 10;

-- Find IP rating feature
SELECT "FEATUREID", "FEATUREDESC"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%IP%' OR "FEATUREDESC" ILIKE '%protection%'
LIMIT 10;
```

**Then update placeholders in SQL files** with your real ETIM codes before execution.

### SQL File Execution Order (CRITICAL)

The documentation references **4 SQL files** that don't exist in this repo. When implementing:

1. `01-create-search-schema.sql` - Creates search schema and tables
2. `02-populate-example-data.sql` - Populates taxonomy and rules (UPDATE ETIM IDs HERE!)
3. `03-create-materialized-views.sql` - Creates mat views (takes 5-10 min)
4. `04-create-search-functions.sql` - Creates search functions

These files must be created by extracting SQL from `search-schema-complete-guide.md` sections 3-7.

---

## Common Tasks

### View Documentation
```bash
# Read in order:
cat INDEX.md
cat QUICKSTART.md
cat search-schema-complete-guide.md

# Or open in browser/editor for better formatting
```

### Extract SQL for Implementation

The SQL code is embedded in `search-schema-complete-guide.md`. To extract:

1. Open `search-schema-complete-guide.md`
2. Find "Schema Definition" section (starts ~line 98)
3. Copy SQL blocks for each table/view/function
4. Create the 4 SQL files referenced in QUICKSTART.md
5. **Update ETIM Feature IDs** before running

### Verify Installation (After SQL Execution)

Run the comprehensive verification script from QUICKSTART.md:262-330. Expected output:
```
✅ Installation SUCCESSFUL!
- Products indexed: 14,889
- Filter index entries: 125,000+
- Available facets: 12+
```

### Refresh Materialized Views (Daily Maintenance)

**Complete Refresh Sequence (after BMEcat catalog import)**:

```sql
-- 1. Existing views (already in your workflow, ~14 seconds total)
REFRESH MATERIALIZED VIEW items.product_info;                    -- 5.2s
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_features_mv; -- 7.6s
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_categories_mv;
REFRESH MATERIALIZED VIEW items.gcfv_mapping;
REFRESH MATERIALIZED VIEW items.product_feature_group_mapping;

-- 2. NEW: Search schema views (adds ~6-9 seconds)
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;         -- 2-3s
REFRESH MATERIALIZED VIEW search.product_filter_index;           -- 3-5s
REFRESH MATERIALIZED VIEW search.filter_facets;                  -- 1s

-- 3. Update statistics (recommended)
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;
```

**Total refresh time**: ~20-23 seconds (was ~14 seconds before search schema)

---

## Integration with FOSSAPP

This search schema is designed to integrate with the existing FOSSAPP Next.js application at `/home/sysadmin/nextjs/fossapp/`.

**Integration points**:
- Database: Same Supabase instance (new `search` schema)
- API Routes: Create new `/api/search/` endpoints (examples in complete guide)
- Components: SearchBar, FilterPanel, ProductGrid (examples provided)

**Example API route location**: `/home/sysadmin/nextjs/fossapp/src/app/api/search/route.ts`

See `search-schema-complete-guide.md` Section 5 for complete Next.js integration code.

---

## Performance Expectations

After implementation:
- **Boolean filter queries**: <50ms (instant)
- **Text search**: <200ms
- **Facet calculation**: <100ms
- **Materialized view refresh**: 5-10 minutes (first time), faster subsequently

---

## Troubleshooting Guide

### Problem: No products in taxonomy flags
**Cause**: Classification rules don't match ETIM groups
**Solution**: Query your actual ETIM groups and update `classification_rules` table

### Problem: Filters not working
**Cause**: Wrong ETIM feature IDs in `filter_definitions`
**Solution**: Query `etim.feature` table and update feature IDs

### Problem: Slow searches
**Cause**: Views not refreshed or missing indexes
**Solution**:
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags;
ANALYZE search.product_taxonomy_flags;
```

See QUICKSTART.md "Troubleshooting" section (lines 334-396) for complete guide.

---

## Related Projects

This search schema is part of the larger Foss SA ecosystem:

- **FOSSAPP**: `/home/sysadmin/nextjs/fossapp/` - Production Next.js app
- **ETIM MCP**: Built-in MCP server for ETIM classification queries
- **Supabase MCP**: Built-in MCP server for database operations
- **Database Utils**: `/home/sysadmin/fossdb/utils/` - Maintenance scripts

---

## Key Concepts

### ETIM Classification System
ETIM (Electro-Technical Information Model) is an international product classification standard. The search schema maps ETIM technical classifications to user-friendly taxonomy.

**Key ETIM tables** (existing in database):
- `etim.feature` - Technical features (power, IP rating, etc.)
- `etim.value` - Allowed values for features
- `etim.unit` - Measurement units

### Materialized Views
Pre-computed views that cache query results for performance. Must be refreshed when source data changes (after catalog imports).

### Classification Rules
Configuration-driven logic that automatically assigns products to categories and sets boolean flags based on ETIM properties.

---

## Classification System: The Bridge from ETIM to Human Categories

### Overview: The Translation Layer

The core purpose of this search system is to act as a **translation bridge**:
- **FROM**: ETIM technical taxonomy (groups like EG000027, classes like EC002710, features like EF009471)
- **TO**: Human-friendly categories that end users can understand (Luminaires, Accessories, Drivers, Ceiling-mounted, etc.)

### Historical Context

**Obsolete System**: `items.category_switches`
- Original bridge table mapping ETIM codes to human categories
- Used `switch_type` field to control matching logic:
  - `"etim_group"` - Match entire ETIM group
  - `"etim_class"` - Match specific ETIM class
  - `"etim_feature"` - Match products with specific feature
  - `"combined"` - Match group + class + feature
  - `"text_pattern"` - Match description text
- **Status**: Reference only for ETIM codes used in the past (unverified)
- **Not used in production**: Historical data only

**Current System**: `search.classification_rules`
- New translation layer built from scratch
- Same concept, different implementation
- More flexible: supports multiple groups/classes per rule, priority-based matching
- **Configuration-driven**: Add/remove rows to control which products appear in which categories

### The Classification Challenge: Overlapping ETIM Groups

**Problem**: Some ETIM groups contain multiple product types that need separate human categories.

**Example - EG000030 Group**:
- Contains BOTH drivers AND accessories
- **DRIVERS**: Specific subset (class EC002710)
- **ACCESSORIES**: Everything else in EG000030 that's NOT drivers

**Current Issue (2025-01-13)**:
```sql
-- Current classification_rules setup:
ACCESSORIES: etim_group_ids = ['EG000030'], etim_class_ids = null  -- Matches ENTIRE group!
DRIVERS: etim_group_ids = ['EG000030'], etim_class_ids = ['EC002710']  -- Matches subset

-- Result: Driver products get BOTH taxonomy codes (incorrect)
```

**Solution Approaches**:

1. **Explicit Class Lists (Recommended)**:
   - Query all classes in EG000030
   - Manually list accessory classes (excluding EC002710)
   - Clear, explicit, easy to verify
   - Requires manual maintenance when new classes appear

2. **Exclusion Logic (Future Enhancement)**:
   - Add `excluded_etim_class_ids` column to `classification_rules`
   - ACCESSORIES: `etim_group_ids = ['EG000030']`, `excluded_etim_class_ids = ['EC002710']`
   - Auto-includes new accessories, more maintainable
   - Requires modifying classification function

### How Classification Rules Work

**Add a row** to `search.classification_rules`:
- Products matching the ETIM criteria will appear under that human category
- Multiple products can match multiple categories (multi-category products)

**Remove a row**:
- Products no longer appear in that category

**Priority system** (lower number = higher priority):
- Controls order of rule application
- Used for hierarchical classification (parent → child categories)
- Example: LUMINAIRE (priority 10) → CEILING (priority 30) → RECESSED (priority 60)

### Verification Workflow

1. **Update classification rules** in database (add/remove/modify rows)
2. **Refresh materialized view**: `REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;`
3. **View in UI**: The Node.js app (`search-test-app`) provides visual verification of results
4. **Iterate**: Adjust rules based on what you see, repeat

The **search-test-app** is your visual tool to verify that the ETIM→Human translation is working as expected.

### Human-Friendly Hierarchical Classification (CRITICAL INSIGHT)

**Key Principle**: Don't map ETIM codes directly to UI categories. Create a **human-friendly hierarchical structure** that makes sense to end users who have no knowledge of ETIM.

**Example - ACCESSORIES Category Structure**:
```
ACCESSORIES (parent - EG000030 group EXCLUDING EC002710 drivers)
├── ACCESSORY-TRACKS
│   ├── ACCESSORY-TRACKS-PROFILES (EC000101, EC000293, EC004966)
│   └── ACCESSORY-TRACKS-SPARES (EC002707)
├── ACCESSORY-OPTICS
│   ├── ACCESSORY-OPTICS-LENS (TBD - map ETIM classes)
│   └── ACCESSORY-OPTICS-REFLECTOR (TBD - map ETIM classes)
├── ACCESSORY-ELECTRICAL
│   ├── ACCESSORY-ELECTRICAL-BOXES (EC000414, EC004291)
│   ├── ACCESSORY-ELECTRICAL-CABLES (EC002327)
│   └── ACCESSORY-ELECTRICAL-CONNECTORS (TBD - map ETIM classes)
└── ACCESSORY-MECHANICAL
    ├── ACCESSORY-MECHANICAL-MOUNTING-BOXES (EC002472)
    └── ACCESSORY-MECHANICAL-MOUNTING-KITS (EC002557, EC002768)
```

**Why This Matters**:
- Light engineers don't know ETIM codes (EG000030, EC002710)
- They think in terms of "Tracks → Profiles" or "Electrical → Boxes"
- The taxonomy must match their mental model, not ETIM's technical structure
- Classification rules map ETIM codes → Human categories
- UI shows human categories with proper hierarchy

**Implementation Approach**:
1. Work with domain expert (light engineer) to define human categories
2. Create taxonomy hierarchy in `search.taxonomy` table
3. Map ETIM classes to human categories in `search.classification_rules`
4. Verify in UI - if it doesn't make sense to the engineer, refine it

---

## Hybrid Classification Approach: ETIM + Text Matching

### Overview

The search system uses a **hybrid classification strategy** combining ETIM codes and text pattern matching:

- **ETIM-based rules**: For structural product categories (LUMINAIRE, ACCESSORIES, DRIVERS, LAMPS, MISC)
- **Text pattern rules**: For functional characteristics (indoor/outdoor, dimmable, smart control, etc.)

This approach leverages the strengths of both methods:
- ETIM provides reliable, standardized product categorization
- Text patterns catch supplier-provided descriptive attributes not always available in ETIM features

### Current Implementation (Verified 2025-01-15)

#### 1. Root Category Rules (ETIM-Based)

**Database Status**: 14,889 total products across 8 ETIM groups

| Taxonomy Code | Classification Method | ETIM Mapping | Products | Status |
|---------------|----------------------|--------------|----------|--------|
| **LUMINAIRE** | ETIM Group | `EG000027` | 13,336 | ✅ Working |
| **ACCESSORIES** | ETIM Class List | 35 specific classes from `EG000030` (excluding `EC002710`) | 1,411 | ✅ Working |
| **DRIVERS** | ETIM Class | `EC002710` only | 83 | ✅ Working |
| **LAMPS** | ETIM Class List | `EC000996`, `EC001959` | 50 | ✅ Working |
| **MISC** | ETIM Class List | `EC001582`, `EC001511`, `EC001698`, `EC002337`, `EC000142` | 9 | ✅ Working |

**Key Insight - ACCESSORIES vs DRIVERS**:
Both come from the same ETIM group (`EG000030 - Accessories for lighting`), but are split based on class:
- **DRIVERS**: Only products in class `EC002710` (LED driver)
- **ACCESSORIES**: All other classes in `EG000030` (explicit list of 35 classes)

This prevents products from appearing in both categories and provides clean separation.

**EG000030 Class Breakdown** (1,494 total products):
```
EC002557 - Mechanical accessories/spare parts (543 products)
EC002558 - Light technical accessories/spare parts (221 products)
EC002556 - Electrical accessories/spare parts (211 products)
EC000293 - Support profile light-line system (190 products)
EC002710 - LED driver (83 products) → Goes to DRIVERS category
EC004966 - Profile for light ribbon/-hose/-strip (65 products)
EC000533 - Lighting control system component (60 products)
EC000101 - Light-track (59 products)
EC000061 - Light pole (44 products)
... (35 classes total)
```

#### 2. Functional Flag Rules (Text Pattern-Based)

**Indoor/Outdoor Detection**:
```sql
-- Indoor rule
{
  "rule_name": "indoor_detection",
  "flag_name": "indoor",
  "text_pattern": "indoor|interior|internal",  -- Case-insensitive regex
  "etim_group_ids": NULL,
  "etim_class_ids": NULL
}

-- Outdoor rule
{
  "rule_name": "outdoor_detection",
  "flag_name": "outdoor",
  "text_pattern": "outdoor|exterior|external|garden",
  "etim_group_ids": NULL,
  "etim_class_ids": NULL
}
```

**How It Works**:
- Searches BOTH `description_short` AND `description_long` fields
- Uses PostgreSQL regex operator `~*` (case-insensitive)
- Products can have BOTH flags if descriptions contain both keywords
- Example: "Indoor/Outdoor LED" → `indoor=TRUE`, `outdoor=TRUE`

**Why Text Patterns for Indoor/Outdoor**:
- ETIM does not have dedicated "indoor" or "outdoor" group/class classifications
- Suppliers typically include this information in product descriptions
- More reliable than trying to infer from IP ratings or other technical features
- Allows products designed for both environments to be properly flagged

#### 3. Mounting Type Rules (ETIM Class-Based)

**Ceiling Luminaires** (`LUMINAIRE-INDOOR-CEILING`):
```sql
{
  "rule_name": "ceiling_luminaires",
  "flag_name": "ceiling",
  "etim_class_ids": ["EC001744", "EC002892"],  -- Specific ceiling classes
  "priority": 30
}
```

**Floor Luminaires** (`LUMINAIRE-INDOOR-FLOOR`):
```sql
{
  "rule_name": "floor_luminaires",
  "flag_name": "floor",
  "etim_class_ids": ["EC000758", "EC000301", "EC000300", "EC002892", "EC000481"],
  "priority": 30
}
```

**Wall Luminaires** (`LUMINAIRE-INDOOR-WALL`):
```sql
{
  "rule_name": "wall_luminaires",
  "flag_name": "wall",
  "etim_class_ids": ["EC001744", "EC002892", "EC000481"],
  "priority": 30
}
```

### When to Use ETIM vs Text Patterns

**Use ETIM codes when**:
- Information is structural/categorical (product type, mounting method)
- ETIM classification is reliable and consistent
- You need exact, unambiguous product grouping
- Example: LUMINAIRE, DRIVERS, track systems, specific mounting types

**Use text patterns when**:
- Information is descriptive/functional (usage context, features)
- ETIM doesn't provide specific classification
- Suppliers consistently include keywords in descriptions
- Example: indoor/outdoor, dimmable, smart control, decorative

**Avoid text patterns when**:
- Keywords are unreliable or missing in descriptions
- Different languages/suppliers use different terminology
- ETIM provides a standardized alternative
- False positives are likely (e.g., "light" matching too broadly)

### Verification Query

Check how products are being classified:

```sql
-- See which rules match a specific product
SELECT
    pi.foss_pid,
    pi.description_short,
    pi."group" as etim_group,
    pi.class as etim_class,
    ptf.taxonomy_path,
    ptf.indoor,
    ptf.outdoor,
    ptf.ceiling,
    ptf.wall,
    ptf.floor
FROM items.product_info pi
LEFT JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE pi.foss_pid = 'YOUR_PRODUCT_ID';

-- See distribution of indoor/outdoor flags
SELECT
    indoor,
    outdoor,
    COUNT(*) as product_count
FROM search.product_taxonomy_flags
GROUP BY indoor, outdoor
ORDER BY COUNT(*) DESC;
```

### Adding New Classification Rules

**Example: Add "Smart Control" flag using text pattern**:

```sql
INSERT INTO search.classification_rules
(rule_name, flag_name, text_pattern, priority, active, description)
VALUES
(
    'smart_control_detection',
    'smart_control',
    'smart|wifi|bluetooth|zigbee|app.?control',
    40,
    true,
    'Products with smart control features'
);

-- Then refresh the materialized view
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
```

**Example: Add subcategory using ETIM class**:

```sql
-- First, verify the ETIM class exists and has products
SELECT class, class_name, COUNT(*)
FROM items.product_info
WHERE class = 'EC002706'  -- LED strip lights
GROUP BY class, class_name;

-- Then add the rule
INSERT INTO search.classification_rules
(rule_name, taxonomy_code, flag_name, etim_class_ids, priority, active, description)
VALUES
(
    'special_strips',
    'LUMINAIRE-SPECIAL-STRIP',
    'led_strip',
    ARRAY['EC002706'],
    70,
    true,
    'LED strip lights'
);

REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
```

### Best Practices

1. **Always verify ETIM codes exist in your database** before creating rules
2. **Use explicit class lists** instead of entire groups when you need subset filtering
3. **Test text patterns** on actual product descriptions to avoid false positives
4. **Set appropriate priorities** - lower values = higher priority, applied first
5. **Document your reasoning** in the rule's description field
6. **Refresh materialized views** after any rule changes
7. **Verify in the UI** (search-test-app) to ensure results make sense to users

### Troubleshooting

**Products not appearing in expected category**:
1. Check if product's ETIM group/class matches rule criteria
2. Run verification query to see which rules matched
3. Check if `active = true` on the rule
4. Ensure materialized view was refreshed after rule changes

**Products appearing in wrong categories**:
1. Check for overlapping ETIM class lists
2. Verify priority ordering (lower = applied first)
3. Look for overly broad text patterns
4. Check if product descriptions contain unexpected keywords

**Indoor/outdoor flags missing**:
1. Check product descriptions for keywords
2. Verify text pattern regex is correct
3. Check both `description_short` and `description_long` fields
4. Consider if product descriptions are in Greek (add Greek keywords to pattern)

---

## Documentation Best Practices

When working with this repository:

1. **Always read INDEX.md first** - Provides context and navigation
2. **Follow QUICKSTART.md sequentially** - Don't skip steps
3. **Use complete guide as reference** - Don't memorize, look up as needed
4. **Update ETIM IDs before implementation** - Most common failure point
5. **Test with verification queries** - Ensure each step succeeded

---

## Notes for Claude Code

- This is **documentation only** - no code to run directly
- SQL must be extracted and executed in Supabase SQL Editor
- Always verify ETIM Feature IDs match the target database before using SQL
- The 4 SQL files referenced don't exist - must be created from guide
- When asked about implementation, refer to QUICKSTART.md first
- When asked about architecture/design, refer to search-schema-complete-guide.md
- Integration examples are for reference - actual paths may differ in FOSSAPP

---

## Support Resources

- **ETIM Documentation**: https://www.etim-international.com/
- **Supabase Docs**: https://supabase.com/docs
- **FOSSAPP Home**: `/home/sysadmin/CLAUDE.md` - Overall project structure
- **Troubleshooting**: QUICKSTART.md lines 334-396

---

**Last Updated**: 2025-11-03
**Repository Purpose**: Documentation for search schema implementation
**Target Database**: Supabase PostgreSQL (14,889+ products)
**Implementation Time**: 30 minutes (quickstart) to 2-3 hours (full customization)
