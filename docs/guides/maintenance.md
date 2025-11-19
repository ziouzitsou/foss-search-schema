# Maintenance & Operations Guide

**Purpose**: Daily, weekly, and monthly maintenance operations for the Foss SA product search system
**Target Audience**: Database administrators, DevOps engineers
**Last Updated**: November 19, 2025

---

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Weekly Maintenance](#weekly-maintenance)
3. [Monthly Tasks](#monthly-tasks)
4. [Monitoring & Statistics](#monitoring--statistics)
5. [Performance Optimization](#performance-optimization)
6. [Troubleshooting](#troubleshooting)
7. [Schema Updates](#schema-updates)
8. [Backup & Recovery](#backup--recovery)
9. [Data Quality Checks](#data-quality-checks)

---

## Daily Operations

### 1. Refresh Materialized Views (After Catalog Import)

**When to run**: After every BMECat catalog import completes

**Complete refresh sequence** (run in this exact order):

```sql
-- 1. Existing FOSSAPP views (already in your workflow)
REFRESH MATERIALIZED VIEW items.product_info;                    -- 5.2s - Base product data
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_features_mv; -- 7.6s - ETIM features
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_categories_mv;
REFRESH MATERIALIZED VIEW items.gcfv_mapping;
REFRESH MATERIALIZED VIEW items.product_feature_group_mapping;

-- 2. Search schema views (NEW - add to your workflow)
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;         -- 2-3s - Category flags
REFRESH MATERIALIZED VIEW search.product_filter_index;           -- 3-5s - Filter values
REFRESH MATERIALIZED VIEW search.filter_facets;                  -- 1s - UI counts

-- 3. Update query planner statistics
ANALYZE items.product_info;
ANALYZE items.product_features_mv;
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;
```

**Total time**: ~20-23 seconds (was ~14 seconds before search schema)

**Automation script**:

```bash
#!/bin/bash
# /home/sysadmin/fossdb/utils/refresh_search_views.sh

echo "Starting materialized view refresh..."

psql $DATABASE_URL <<EOF
-- Existing views
REFRESH MATERIALIZED VIEW items.product_info;
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_features_mv;
REFRESH MATERIALIZED VIEW CONCURRENTLY items.product_categories_mv;
REFRESH MATERIALIZED VIEW items.gcfv_mapping;
REFRESH MATERIALIZED VIEW items.product_feature_group_mapping;

-- Search schema views
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW search.product_filter_index;
REFRESH MATERIALIZED VIEW search.filter_facets;

-- Update statistics
ANALYZE items.product_info;
ANALYZE items.product_features_mv;
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
ANALYZE search.filter_facets;

-- Verify counts
SELECT
    'product_taxonomy_flags' as view_name,
    COUNT(*) as row_count
FROM search.product_taxonomy_flags
UNION ALL
SELECT
    'product_filter_index',
    COUNT(*)
FROM search.product_filter_index
UNION ALL
SELECT
    'filter_facets',
    COUNT(*)
FROM search.filter_facets;
EOF

echo "Refresh complete!"
```

**Add to cron** (example: daily at 2 AM after catalog import):

```bash
0 2 * * * /home/sysadmin/fossdb/utils/refresh_search_views.sh >> /var/log/search_refresh.log 2>&1
```

### 2. Check System Statistics

**Run after each refresh** to verify data integrity:

```sql
SELECT * FROM search.get_search_statistics();
```

**Expected output**:

```
metric_name                    | metric_value | description
-------------------------------|--------------|----------------------------------
total_products                 | 14889        | Products in product_info
taxonomy_flagged_products      | 14889        | Products with taxonomy flags
filter_indexed_products        | 14889        | Products in filter index
total_filter_index_entries     | 125000+      | Total feature values indexed
total_filter_facets            | 12+          | Available filter options
avg_features_per_product       | 8.4          | Average ETIM features per product
taxonomy_nodes                 | 30+          | Total taxonomy categories
classification_rules           | 35+          | Active classification rules
```

**Alert if**:
- `taxonomy_flagged_products` < `total_products` (missing classifications)
- `filter_indexed_products` < `total_products` (missing filter data)
- Any count = 0 (view refresh failed)

---

## Weekly Maintenance

### 1. Performance Review

**Check query performance** (run on Monday mornings):

```sql
-- Average search query time (last 7 days)
SELECT
    date_trunc('day', created_at) as day,
    AVG(query_time_ms) as avg_time_ms,
    MAX(query_time_ms) as max_time_ms,
    COUNT(*) as query_count
FROM search.query_log  -- If you implement query logging
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY date_trunc('day', created_at)
ORDER BY day DESC;

-- Slow queries (>500ms)
SELECT
    query_text,
    query_time_ms,
    created_at
FROM search.query_log
WHERE query_time_ms > 500
    AND created_at > NOW() - INTERVAL '7 days'
ORDER BY query_time_ms DESC
LIMIT 20;
```

**Performance benchmarks**:
- ✅ Boolean filter queries: <50ms
- ✅ Text search: <200ms
- ✅ Dynamic facets: <100ms
- ✅ Product count: <50ms
- ⚠️ Alert if: Any query consistently >500ms

### 2. Index Health Check

**Check for bloated indexes**:

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan as times_used,
    idx_tup_read as tuples_read
FROM pg_stat_user_indexes
WHERE schemaname = 'search'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Rebuild indexes if needed** (rarely required):

```sql
-- Only run if index_scan is very low or indexes are corrupted
REINDEX TABLE search.product_taxonomy_flags;
REINDEX TABLE search.product_filter_index;
```

### 3. Check for Missing Classifications

**Products without taxonomy assignments**:

```sql
SELECT
    pi.foss_pid,
    pi.description_short,
    pi."group" as etim_group,
    pi.class as etim_class
FROM items.product_info pi
LEFT JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE ptf.product_id IS NULL
LIMIT 20;
```

**If found**:
1. Check if ETIM group/class exists in classification rules
2. Add new rule if needed (see [Schema Updates](#schema-updates))
3. Refresh materialized views

---

## Monthly Tasks

### 1. Review Classification Rules

**Check rule effectiveness**:

```sql
-- How many products does each rule classify?
SELECT
    cr.rule_name,
    cr.taxonomy_code,
    cr.active,
    COUNT(DISTINCT ptf.product_id) as products_classified
FROM search.classification_rules cr
LEFT JOIN search.product_taxonomy_flags ptf
    ON cr.taxonomy_code = ANY(ptf.taxonomy_path)
WHERE cr.active = true
GROUP BY cr.rule_name, cr.taxonomy_code, cr.active
ORDER BY products_classified DESC;
```

**Identify unused rules** (classify 0 products):

```sql
SELECT
    rule_name,
    taxonomy_code,
    description,
    created_at
FROM search.classification_rules
WHERE rule_name NOT IN (
    SELECT DISTINCT unnest(taxonomy_path)
    FROM search.product_taxonomy_flags
)
AND active = true;
```

**Action**: Deactivate unused rules or update their criteria

### 2. Review Filter Definitions

**Check which filters are actually used**:

```sql
-- Filters with data
SELECT
    fd.filter_key,
    fd.label,
    fd.category,
    COUNT(DISTINCT pfi.product_id) as products_with_filter
FROM search.filter_definitions fd
LEFT JOIN search.product_filter_index pfi
    ON fd.filter_key = pfi.filter_key
GROUP BY fd.filter_key, fd.label, fd.category
ORDER BY products_with_filter DESC;
```

**Filters with no data** (candidates for removal):

```sql
SELECT
    fd.filter_key,
    fd.label,
    fd.category,
    fd.created_at
FROM search.filter_definitions fd
WHERE fd.filter_key NOT IN (
    SELECT DISTINCT filter_key
    FROM search.product_filter_index
);
```

### 3. Database Size Monitoring

**Check schema size growth**:

```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) -
                   pg_relation_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE schemaname = 'search'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Expected sizes** (14,889 products):
- `product_taxonomy_flags`: ~2-5 MB
- `product_filter_index`: ~15-25 MB
- `filter_facets`: <1 MB

**Alert if**: Any table >100 MB (investigate data issues)

---

## Monitoring & Statistics

### 1. Real-Time System Health

**Quick health check** (run anytime):

```sql
-- System health dashboard
WITH stats AS (
    SELECT * FROM search.get_search_statistics()
)
SELECT
    metric_name,
    metric_value,
    CASE
        WHEN metric_name = 'total_products' AND metric_value::int < 14000 THEN '⚠️ LOW'
        WHEN metric_name = 'taxonomy_flagged_products' AND metric_value::int < 14000 THEN '⚠️ LOW'
        WHEN metric_name = 'filter_indexed_products' AND metric_value::int < 14000 THEN '⚠️ LOW'
        WHEN metric_name = 'total_filter_index_entries' AND metric_value::int < 100000 THEN '⚠️ LOW'
        ELSE '✅ OK'
    END as status
FROM stats
ORDER BY
    CASE metric_name
        WHEN 'total_products' THEN 1
        WHEN 'taxonomy_flagged_products' THEN 2
        WHEN 'filter_indexed_products' THEN 3
        ELSE 99
    END;
```

### 2. Query Performance Metrics

**Measure actual query times**:

```sql
-- Test search performance
EXPLAIN ANALYZE
SELECT * FROM search.search_products_with_filters(
    p_query := 'LED',
    p_indoor := true,
    p_limit := 24
);
```

**Look for**:
- `Execution Time`: Should be <200ms
- `Planning Time`: Should be <10ms
- `Seq Scan` on large tables: BAD (means missing index)
- `Index Scan` or `Bitmap Index Scan`: GOOD

### 3. Facet Calculation Speed

**Test dynamic facets**:

```sql
EXPLAIN ANALYZE
SELECT * FROM search.get_dynamic_facets(
    p_taxonomy_codes := ARRAY['LUMINAIRE-INDOOR-CEILING'],
    p_indoor := true
);
```

**Expected**: <100ms execution time

---

## Performance Optimization

### 1. Optimize Materialized View Refresh

**Use CONCURRENTLY for zero-downtime** (where supported):

```sql
-- Instead of:
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;

-- Use (requires unique index):
CREATE UNIQUE INDEX IF NOT EXISTS idx_ptf_product_id
ON search.product_taxonomy_flags(product_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY search.product_taxonomy_flags;
```

**Trade-off**: CONCURRENTLY is slower but allows queries during refresh

### 2. Add Missing Indexes

**If searches are slow, check for missing indexes**:

```sql
-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used
FROM pg_stat_user_indexes
WHERE schemaname = 'search'
    AND idx_scan < 10  -- Rarely used
ORDER BY idx_scan;
```

**Add indexes for common filters**:

```sql
-- Example: If filtering by supplier is slow
CREATE INDEX IF NOT EXISTS idx_ptf_supplier_name
ON search.product_taxonomy_flags(supplier_name);

-- Example: If outdoor filter is slow
CREATE INDEX IF NOT EXISTS idx_ptf_outdoor
ON search.product_taxonomy_flags(outdoor)
WHERE outdoor = true;  -- Partial index (faster)
```

### 3. Vacuum and Analyze

**Run weekly** (automatically scheduled by PostgreSQL, but can run manually):

```sql
-- Vacuum to reclaim space
VACUUM ANALYZE search.product_taxonomy_flags;
VACUUM ANALYZE search.product_filter_index;
VACUUM ANALYZE search.filter_facets;

-- Full vacuum (requires table lock, run during maintenance window)
VACUUM FULL search.product_taxonomy_flags;  -- Only if table is heavily bloated
```

---

## Troubleshooting

### Problem 1: No Products in Search Results

**Symptom**: All searches return 0 products

**Diagnosis**:

```sql
-- Check if views are populated
SELECT COUNT(*) FROM search.product_taxonomy_flags;  -- Should be 14,889
SELECT COUNT(*) FROM search.product_filter_index;    -- Should be 125,000+

-- Check if product_info has data
SELECT COUNT(*) FROM items.product_info;  -- Should be 14,889
```

**Solution**:

```sql
-- Refresh views if empty
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW search.product_filter_index;
```

### Problem 2: Slow Searches (>500ms)

**Symptom**: Queries take longer than expected

**Diagnosis**:

```sql
-- Check if indexes exist
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'search'
    AND tablename = 'product_taxonomy_flags';

-- Check if statistics are up to date
SELECT
    schemaname,
    tablename,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'search';
```

**Solution**:

```sql
-- Update statistics
ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;

-- Rebuild indexes if needed
REINDEX TABLE search.product_taxonomy_flags;
```

### Problem 3: Filter Counts Are Wrong

**Symptom**: Filter UI shows incorrect product counts

**Diagnosis**:

```sql
-- Check facets materialized view
SELECT * FROM search.filter_facets LIMIT 10;

-- Compare with real-time count
SELECT
    filter_key,
    filter_value,
    COUNT(*) as actual_count
FROM search.product_filter_index
WHERE filter_key = 'ip'  -- Replace with your filter
GROUP BY filter_key, filter_value
ORDER BY actual_count DESC;
```

**Solution**:

```sql
-- Refresh facets view
REFRESH MATERIALIZED VIEW search.filter_facets;
```

### Problem 4: Products Missing from Categories

**Symptom**: Products don't appear in expected taxonomy categories

**Diagnosis**:

```sql
-- Check product's ETIM classification
SELECT
    pi.foss_pid,
    pi.description_short,
    pi."group" as etim_group,
    pi.class as etim_class,
    ptf.taxonomy_path
FROM items.product_info pi
LEFT JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE pi.foss_pid = 'YOUR_PRODUCT_ID';

-- Check if classification rule exists for this ETIM group/class
SELECT *
FROM search.classification_rules
WHERE 'YOUR_ETIM_GROUP' = ANY(etim_group_ids)
    OR 'YOUR_ETIM_CLASS' = ANY(etim_class_ids);
```

**Solution**: Add classification rule (see [Schema Updates](#schema-updates))

### Problem 5: Memory Issues During Refresh

**Symptom**: Materialized view refresh fails with out-of-memory error

**Solution**:

```sql
-- Increase work_mem for session
SET work_mem = '256MB';
REFRESH MATERIALIZED VIEW search.product_filter_index;
RESET work_mem;

-- Or configure in postgresql.conf permanently
-- work_mem = 256MB
```

---

## Schema Updates

### Adding a New Taxonomy Category

**Example**: Add "LUMINAIRE-OUTDOOR-GARDEN" category

**Step 1: Add to taxonomy table**

```sql
INSERT INTO search.taxonomy (code, parent_code, label, level, display_order, active)
VALUES
    ('LUMINAIRE-OUTDOOR-GARDEN', 'LUMINAIRE-OUTDOOR', 'Garden', 3, 10, true);
```

**Step 2: Add classification rule**

```sql
INSERT INTO search.classification_rules
(rule_name, taxonomy_code, flag_name, etim_class_ids, priority, active, description)
VALUES
(
    'outdoor_garden',
    'LUMINAIRE-OUTDOOR-GARDEN',
    'garden',
    ARRAY['EC001234', 'EC005678'],  -- Replace with actual ETIM classes
    70,
    true,
    'Garden and outdoor decorative luminaires'
);
```

**Step 3: Refresh and verify**

```sql
-- Refresh views
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW search.taxonomy_product_counts;

-- Verify products were classified
SELECT COUNT(*)
FROM search.product_taxonomy_flags
WHERE 'LUMINAIRE-OUTDOOR-GARDEN' = ANY(taxonomy_path);
```

### Adding a New Filter

**Example**: Add "Beam Angle" filter

**Step 1: Check ETIM feature ID**

```sql
SELECT "FEATUREID", "FEATUREDESC", "UNIT"
FROM etim.feature
WHERE "FEATUREDESC" ILIKE '%beam%angle%'
    OR "FEATUREDESC" ILIKE '%γωνία%';
```

**Step 2: Add filter definition**

```sql
INSERT INTO search.filter_definitions
(filter_key, label, category, etim_feature_id, value_type, sort_order, active)
VALUES
(
    'beam_angle',
    'Beam Angle',
    'light_engine',
    'EF001234',  -- Replace with actual ETIM ID
    'range',     -- or 'multi_select', 'boolean'
    60,
    true
);
```

**Step 3: Refresh and verify**

```sql
-- Refresh filter index
REFRESH MATERIALIZED VIEW search.product_filter_index;
REFRESH MATERIALIZED VIEW search.filter_facets;

-- Verify data exists
SELECT
    filter_key,
    numeric_value,
    COUNT(*) as product_count
FROM search.product_filter_index
WHERE filter_key = 'beam_angle'
GROUP BY filter_key, numeric_value
ORDER BY numeric_value;
```

### Modifying Classification Rules

**Example**: Change which ETIM classes map to DRIVERS category

**Step 1: View current rule**

```sql
SELECT *
FROM search.classification_rules
WHERE taxonomy_code = 'DRIVER';
```

**Step 2: Update rule**

```sql
UPDATE search.classification_rules
SET etim_class_ids = ARRAY['EC002710', 'EC001234']  -- Add new class
WHERE taxonomy_code = 'DRIVER';
```

**Step 3: Refresh and compare**

```sql
-- Before count
SELECT COUNT(*) FROM search.product_taxonomy_flags
WHERE 'DRIVER' = ANY(taxonomy_path);

-- Refresh
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;

-- After count (should be different)
SELECT COUNT(*) FROM search.product_taxonomy_flags
WHERE 'DRIVER' = ANY(taxonomy_path);
```

---

## Backup & Recovery

### 1. Schema Backup

**Export search schema** (structure + data):

```bash
# Full schema dump (structure + data)
pg_dump $DATABASE_URL \
    --schema=search \
    --file=/home/sysadmin/backups/search_schema_$(date +%Y%m%d).sql

# Structure only (for version control)
pg_dump $DATABASE_URL \
    --schema=search \
    --schema-only \
    --file=/home/sysadmin/tools/searchdb/sql/schema_backup.sql
```

**Commit schema changes to git**:

```bash
cd /home/sysadmin/tools/searchdb
git add sql/
git commit -m "backup: Search schema structure $(date +%Y-%m-%d)"
git push
```

### 2. Configuration Backup

**Export configuration tables**:

```bash
psql $DATABASE_URL <<EOF > /home/sysadmin/backups/search_config_$(date +%Y%m%d).sql
-- Taxonomy
COPY (SELECT * FROM search.taxonomy ORDER BY code) TO STDOUT WITH (FORMAT CSV, HEADER);

-- Classification rules
COPY (SELECT * FROM search.classification_rules ORDER BY priority, rule_name) TO STDOUT WITH (FORMAT CSV, HEADER);

-- Filter definitions
COPY (SELECT * FROM search.filter_definitions ORDER BY category, sort_order) TO STDOUT WITH (FORMAT CSV, HEADER);
EOF
```

### 3. Restore from Backup

**Restore full schema**:

```bash
# WARNING: This will drop and recreate the search schema
psql $DATABASE_URL < /home/sysadmin/backups/search_schema_20251119.sql
```

**Restore configuration only**:

```sql
-- Restore taxonomy
TRUNCATE search.taxonomy CASCADE;
COPY search.taxonomy FROM '/path/to/taxonomy_backup.csv' CSV HEADER;

-- Restore classification rules
TRUNCATE search.classification_rules CASCADE;
COPY search.classification_rules FROM '/path/to/rules_backup.csv' CSV HEADER;

-- Restore filter definitions
TRUNCATE search.filter_definitions CASCADE;
COPY search.filter_definitions FROM '/path/to/filters_backup.csv' CSV HEADER;

-- Refresh materialized views
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW search.product_filter_index;
REFRESH MATERIALIZED VIEW search.filter_facets;
```

### 4. Disaster Recovery

**Complete search schema rebuild** (if corrupted):

```bash
# 1. Drop existing schema
psql $DATABASE_URL -c "DROP SCHEMA IF EXISTS search CASCADE;"

# 2. Recreate from SQL files (in order)
cd /home/sysadmin/tools/searchdb/sql
psql $DATABASE_URL < 01-create-search-schema.sql
psql $DATABASE_URL < 02-populate-taxonomy.sql
psql $DATABASE_URL < 03-populate-classification-rules.sql
psql $DATABASE_URL < 04-populate-filter-definitions.sql
psql $DATABASE_URL < 05-create-product-taxonomy-flags.sql
psql $DATABASE_URL < 06-create-filter-index.sql
psql $DATABASE_URL < 07-create-filter-facets.sql
psql $DATABASE_URL < 08-add-dynamic-filter-search.sql
psql $DATABASE_URL < 09-add-dynamic-facets.sql

# 3. Verify
psql $DATABASE_URL -c "SELECT * FROM search.get_search_statistics();"
```

**Expected recovery time**: 10-15 minutes (includes materialized view refresh)

---

## Data Quality Checks

### 1. Check for Duplicate Products

**Should never happen** (product_id is unique), but verify:

```sql
SELECT
    product_id,
    COUNT(*) as duplicate_count
FROM search.product_taxonomy_flags
GROUP BY product_id
HAVING COUNT(*) > 1;
```

**Expected**: 0 rows

### 2. Check for Products Without Categories

**Products that don't match any classification rule**:

```sql
SELECT
    pi.foss_pid,
    pi.description_short,
    pi."group" as etim_group,
    pi.class as etim_class
FROM items.product_info pi
LEFT JOIN search.product_taxonomy_flags ptf ON pi.product_id = ptf.product_id
WHERE ptf.taxonomy_path IS NULL
    OR array_length(ptf.taxonomy_path, 1) = 0;
```

**Expected**: 0 rows (all products should have at least one category)

**If found**: Add classification rules for missing ETIM groups/classes

### 3. Check for Invalid Filter Values

**Filters with NULL or empty values** (data quality issue):

```sql
SELECT
    filter_key,
    COUNT(*) as null_value_count
FROM search.product_filter_index
WHERE (alphanumeric_value IS NULL OR alphanumeric_value = '')
    AND (numeric_value IS NULL)
    AND (boolean_value IS NULL)
GROUP BY filter_key
ORDER BY null_value_count DESC;
```

**Expected**: 0 rows (all filters should have valid values)

### 4. Check ETIM Feature Coverage

**How many products have each ETIM feature**:

```sql
SELECT
    fd.filter_key,
    fd.label,
    fd.etim_feature_id,
    COUNT(DISTINCT pfi.product_id) as product_count,
    ROUND(COUNT(DISTINCT pfi.product_id)::numeric / 14889 * 100, 2) as coverage_percent
FROM search.filter_definitions fd
LEFT JOIN search.product_filter_index pfi
    ON fd.filter_key = pfi.filter_key
GROUP BY fd.filter_key, fd.label, fd.etim_feature_id
ORDER BY coverage_percent DESC;
```

**Alert if**: Coverage drops below 50% for major filters (power, CCT, IP rating)

### 5. Check for Orphaned Records

**Filter index entries for non-existent products**:

```sql
SELECT
    pfi.product_id,
    COUNT(*) as filter_count
FROM search.product_filter_index pfi
LEFT JOIN items.product_info pi ON pfi.product_id = pi.product_id
WHERE pi.product_id IS NULL
GROUP BY pfi.product_id;
```

**Expected**: 0 rows

**If found**: Run cleanup:

```sql
DELETE FROM search.product_filter_index
WHERE product_id NOT IN (SELECT product_id FROM items.product_info);
```

---

## Maintenance Checklist

### Daily (Automated)
- [ ] Refresh materialized views after catalog import
- [ ] Run get_search_statistics() to verify counts
- [ ] Check for errors in application logs

### Weekly (Manual - 15 minutes)
- [ ] Review query performance metrics
- [ ] Check for slow queries (>500ms)
- [ ] Verify index health
- [ ] Check for missing product classifications
- [ ] Review database size growth

### Monthly (Manual - 30 minutes)
- [ ] Review classification rule effectiveness
- [ ] Check for unused filter definitions
- [ ] Analyze data quality (duplicates, nulls, orphans)
- [ ] Review ETIM feature coverage
- [ ] Export schema and configuration backups
- [ ] Test disaster recovery procedure (in staging)

### Quarterly (Manual - 1 hour)
- [ ] Full database vacuum and analyze
- [ ] Review and optimize slow queries
- [ ] Update documentation with schema changes
- [ ] Review and archive old performance logs
- [ ] Conduct load testing

---

## Emergency Contacts

**Database Issues**:
- Supabase Dashboard: https://supabase.com/dashboard
- Check logs: Database → Logs → Postgres Logs

**Application Issues**:
- Search test app: http://localhost:3001
- Check logs: `search-test-app/` directory

**Git Repository**:
- GitHub: (your repository URL)
- Local: `/home/sysadmin/tools/searchdb/`

---

**Last Updated**: November 19, 2025
**Maintained by**: Database Administrator
**Review Schedule**: Monthly

---

## Quick Reference Commands

```bash
# Daily refresh
psql $DATABASE_URL < /home/sysadmin/fossdb/utils/refresh_search_views.sh

# Check statistics
psql $DATABASE_URL -c "SELECT * FROM search.get_search_statistics();"

# Backup configuration
pg_dump $DATABASE_URL --schema=search --schema-only > schema_backup.sql

# Test search performance
psql $DATABASE_URL -c "EXPLAIN ANALYZE SELECT * FROM search.search_products_with_filters(p_query := 'LED', p_limit := 24);"

# Check view freshness
psql $DATABASE_URL -c "SELECT schemaname, matviewname, last_refresh FROM pg_matviews WHERE schemaname = 'search';"
```
