# Quick Start Guide - Search Schema Implementation

## Overview
This guide will walk you through implementing the search infrastructure for your Foss SA luminaires database in **30 minutes**.

---

## Prerequisites

✅ Supabase project with existing `items` and `etim` schemas  
✅ PostgreSQL access (via Supabase SQL Editor or psql)  
✅ 14,889 products already loaded in `items.product_info`  
✅ Basic understanding of SQL  

---

## Step 1: Create Schema (5 minutes)

### Via Supabase SQL Editor

1. Open your Supabase project
2. Go to **SQL Editor**
3. Open file: `sql/01-create-search-schema.sql`
4. Click **Run**

### Via psql Command Line

```bash
psql -h your-project.supabase.co \
     -U postgres \
     -d postgres \
     -f sql/01-create-search-schema.sql
```

**Expected Output:**
```
Search schema created successfully!
Tables created:
  - search.taxonomy
  - search.classification_rules
  - search.filter_definitions

Next steps:
  1. Run 02-populate-example-data.sql...
```

---

## Step 2: Populate Example Data (5 minutes)

**Important:** Before running, you MUST update ETIM Feature IDs in this file to match your actual database.

### Find Your ETIM Feature IDs

Run this query to find correct IDs for common features:

```sql
-- Find power feature
SELECT "FEATUREID", "FEATUREDESC" 
FROM etim.feature 
WHERE "FEATUREDESC" ILIKE '%power%'
  OR "FEATUREDESC" ILIKE '%ισχύ%'
LIMIT 10;

-- Find IP rating feature
SELECT "FEATUREID", "FEATUREDESC" 
FROM etim.feature 
WHERE "FEATUREDESC" ILIKE '%IP%'
  OR "FEATUREDESC" ILIKE '%protection%'
LIMIT 10;

-- Find dimmable feature
SELECT "FEATUREID", "FEATUREDESC" 
FROM etim.feature 
WHERE "FEATUREDESC" ILIKE '%dimm%'
LIMIT 10;
```

### Update the SQL File

Open `sql/02-populate-example-data.sql` and replace placeholder IDs:

```sql
-- BEFORE (line ~200)
'EF000001', 'EU570001',  -- ⚠️ Replace with actual ETIM codes

-- AFTER (your actual codes)
'EF026454', 'EU570001',  -- ✅ Real power feature ID from your DB
```

### Run the File

```sql
-- Via Supabase SQL Editor
-- Open file: sql/02-populate-example-data.sql
-- Click Run

-- Or via psql
psql -h your-project.supabase.co -U postgres -d postgres \
     -f sql/02-populate-example-data.sql
```

**Expected Output:**
```
Example data populated successfully!
Statistics:
  - Taxonomy nodes: 24
  - Classification rules: 11
  - Filter definitions: 12

Important: You must update ETIM Feature IDs...
```

---

## Step 3: Create Materialized Views (10 minutes)

This step processes all your products and creates the search indexes. **It may take 5-10 minutes** depending on your data volume.

```sql
-- Via Supabase SQL Editor
-- Open file: sql/03-create-materialized-views.sql
-- Click Run

-- Or via psql
psql -h your-project.supabase.co -U postgres -d postgres \
     -f sql/03-create-materialized-views.sql
```

**Expected Output:**
```
Starting materialized view refresh...
This may take several minutes...

  ✓ product_taxonomy_flags - success (took 00:02:30)
  ✓ product_filter_index - success (took 00:03:15)
  ✓ filter_facets - success (took 00:00:45)
  ✓ taxonomy_product_counts - success (took 00:00:30)

Total refresh time: 00:07:00

Statistics:
  - Products with taxonomy: 14,889
  - Filter index entries: 125,432
  - Available facets: 12
  - Taxonomy nodes with products: 18
```

---

## Step 4: Create Search Functions (2 minutes)

```sql
-- Via Supabase SQL Editor
-- Open file: sql/04-create-search-functions.sql
-- Click Run

-- Or via psql
psql -h your-project.supabase.co -U postgres -d postgres \
     -f sql/04-create-search-functions.sql
```

**Expected Output:**
```
Search functions created successfully!

Available functions:
  - search.search_products() - Main search API
  - search.get_product_details() - Product detail page
  ...
```

---

## Step 5: Test Your Search (5 minutes)

### Test 1: Simple Text Search

```sql
SELECT 
    foss_pid,
    description_short,
    supplier_name,
    price,
    relevance_score
FROM search.search_products(
    p_query := 'LED',
    p_limit := 10
);
```

### Test 2: Boolean Filters

```sql
SELECT 
    foss_pid,
    description_short,
    flags->>'indoor' as is_indoor,
    flags->>'recessed' as is_recessed
FROM search.search_products(
    p_indoor := true,
    p_recessed := true,
    p_limit := 10
);
```

### Test 3: Numeric Range Filter

```sql
SELECT 
    foss_pid,
    description_short,
    price,
    key_features
FROM search.search_products(
    p_power_min := 15,
    p_power_max := 25,
    p_limit := 10
);
```

### Test 4: Combined Search

```sql
SELECT 
    foss_pid,
    description_short,
    supplier_name,
    price
FROM search.search_products(
    p_query := 'outdoor',
    p_outdoor := true,
    p_ip_ratings := ARRAY['IP65', 'IP67'],
    p_dimmable := true,
    p_limit := 20
);
```

### Test 5: Get Facets

```sql
SELECT 
    filter_key,
    label_el,
    filter_type,
    facet_data
FROM search.get_available_facets();
```

### Test 6: Get Statistics

```sql
SELECT * FROM search.get_search_statistics();
```

---

## Step 6: Verify Installation

Run this comprehensive verification query:

```sql
-- Verification script
DO $$
DECLARE
    schema_exists BOOLEAN;
    tables_count INTEGER;
    views_count INTEGER;
    functions_count INTEGER;
    taxonomy_count INTEGER;
    rules_count INTEGER;
    products_indexed INTEGER;
BEGIN
    -- Check schema
    SELECT EXISTS (
        SELECT 1 FROM information_schema.schemata 
        WHERE schema_name = 'search'
    ) INTO schema_exists;
    
    -- Count tables
    SELECT COUNT(*) INTO tables_count
    FROM information_schema.tables
    WHERE table_schema = 'search'
      AND table_type = 'BASE TABLE';
    
    -- Count views
    SELECT COUNT(*) INTO views_count
    FROM pg_matviews
    WHERE schemaname = 'search';
    
    -- Count functions
    SELECT COUNT(*) INTO functions_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'search';
    
    -- Count data
    SELECT COUNT(*) INTO taxonomy_count FROM search.taxonomy WHERE active = true;
    SELECT COUNT(*) INTO rules_count FROM search.classification_rules WHERE active = true;
    SELECT COUNT(*) INTO products_indexed FROM search.product_taxonomy_flags;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'SEARCH SCHEMA VERIFICATION';
    RAISE NOTICE '==============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Schema exists: %', CASE WHEN schema_exists THEN '✓ YES' ELSE '✗ NO' END;
    RAISE NOTICE 'Tables created: % (expected: 3)', tables_count;
    RAISE NOTICE 'Materialized views: % (expected: 4)', views_count;
    RAISE NOTICE 'Functions created: % (expected: 6+)', functions_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Configuration data:';
    RAISE NOTICE '  - Taxonomy nodes: %', taxonomy_count;
    RAISE NOTICE '  - Classification rules: %', rules_count;
    RAISE NOTICE '  - Products indexed: %', products_indexed;
    RAISE NOTICE '';
    
    IF schema_exists AND tables_count = 3 AND views_count = 4 AND products_indexed > 0 THEN
        RAISE NOTICE '✅ Installation SUCCESSFUL!';
        RAISE NOTICE '';
        RAISE NOTICE 'Ready to integrate with Next.js application.';
    ELSE
        RAISE NOTICE '⚠️  Installation INCOMPLETE!';
        RAISE NOTICE '';
        RAISE NOTICE 'Please review the steps above.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
END $$;
```

---

## Troubleshooting

### Problem: Materialized view refresh is slow

**Solution:** This is normal for the first run. Subsequent refreshes will be faster.

```sql
-- Check progress
SELECT 
    schemaname,
    matviewname,
    last_refresh_time
FROM pg_matviews
WHERE schemaname = 'search';
```

### Problem: No products in taxonomy flags

**Cause:** Classification rules didn't match your products.

**Solution:** Check your ETIM group/class IDs:

```sql
-- See what ETIM groups your products have
SELECT DISTINCT "group", group_name, COUNT(*)
FROM items.product_info
GROUP BY "group", group_name
ORDER BY COUNT(*) DESC;

-- Update classification rules with correct group IDs
UPDATE search.classification_rules
SET etim_group_ids = ARRAY['YOUR_ACTUAL_GROUP_ID']
WHERE rule_name = 'indoor_luminaires';

-- Refresh views
SELECT * FROM search.refresh_all_views(false);
```

### Problem: Filter definitions not working

**Cause:** Wrong ETIM feature IDs.

**Solution:** Find and update correct feature IDs:

```sql
-- List all your features to find correct IDs
SELECT DISTINCT 
    f->>'FEATUREID' as feature_id,
    f->>'feature_name' as feature_name,
    COUNT(*) as product_count
FROM items.product_info pi,
     jsonb_array_elements(pi.features) f
GROUP BY f->>'FEATUREID', f->>'feature_name'
ORDER BY product_count DESC
LIMIT 50;

-- Update filter definitions
UPDATE search.filter_definitions
SET etim_feature_id = 'YOUR_CORRECT_FEATURE_ID'
WHERE filter_key = 'power';
```

---

## Maintenance

### Daily: After Catalog Import

```sql
-- Refresh all views (concurrent = doesn't block reads)
SELECT * FROM search.refresh_all_views(concurrent := true);
```

### Weekly: Check Performance

```sql
-- View refresh times
SELECT 
    matviewname,
    last_refresh_time,
    now() - last_refresh_time as age
FROM pg_matviews
WHERE schemaname = 'search';

-- Index health
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used
FROM pg_stat_user_indexes
WHERE schemaname = 'search'
ORDER BY idx_scan DESC;
```

### Monthly: Analyze and Vacuum

```sql
-- Update query planner statistics
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;

-- Reclaim space (optional)
VACUUM ANALYZE search.product_taxonomy_flags;
```

---

## Next Steps

1. ✅ **Schema installed and tested**
2. 🚀 **Integrate with Next.js** - See `search-schema-complete-guide.md` section on "Next.js Integration"
3. 🎨 **Build UI components** - See example React components in the guide
4. 📊 **Add analytics** - Track which filters users use most
5. 🌐 **Add Greek/English toggle** - Use label_el/label_en fields

---

## Support

If you run into issues:

1. Check the troubleshooting section above
2. Review your ETIM feature IDs
3. Verify your classification rules match your products
4. Check materialized view refresh logs
5. Test individual functions with simple queries first

---

## Success Criteria

✅ All 4 SQL files executed without errors  
✅ `search.product_taxonomy_flags` has ~14,889 rows  
✅ `search.product_filter_index` has 100,000+ rows  
✅ Test queries return results  
✅ Verification script shows "Installation SUCCESSFUL"  

**You're ready to build your Next.js search UI!** 🎉
