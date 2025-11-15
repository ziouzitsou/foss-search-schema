-- =====================================================================
-- Step 1: Create Missing Search Schema Tables
-- =====================================================================
-- Purpose: Create product_filter_index and filter_facets for luminaire filtering
-- Database: FOSSAPP Supabase
-- Date: 2025-01-15
-- Scope: Luminaires (ETIM group EG000027) from active catalogs ONLY

-- =====================================================================
-- Table: search.product_filter_index
-- Purpose: Flattened ETIM feature index for fast filtering
-- =====================================================================

CREATE TABLE IF NOT EXISTS search.product_filter_index (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL,
  filter_key TEXT NOT NULL,
  numeric_value NUMERIC,
  alphanumeric_value TEXT,
  boolean_value BOOLEAN,
  source_feature_id TEXT,  -- ETIM feature ID for traceability
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT fk_product FOREIGN KEY (product_id)
    REFERENCES items.product(id) ON DELETE CASCADE,
  CONSTRAINT fk_filter_definition FOREIGN KEY (filter_key)
    REFERENCES search.filter_definitions(filter_key) ON DELETE CASCADE,

  -- At least one value must be present
  CONSTRAINT chk_has_value CHECK (
    numeric_value IS NOT NULL OR
    alphanumeric_value IS NOT NULL OR
    boolean_value IS NOT NULL
  )
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_filter_index_product_id
  ON search.product_filter_index(product_id);
CREATE INDEX IF NOT EXISTS idx_product_filter_index_filter_key
  ON search.product_filter_index(filter_key);
CREATE INDEX IF NOT EXISTS idx_product_filter_index_numeric_value
  ON search.product_filter_index(numeric_value) WHERE numeric_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_product_filter_index_alphanumeric_value
  ON search.product_filter_index(alphanumeric_value) WHERE alphanumeric_value IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_product_filter_index_boolean_value
  ON search.product_filter_index(boolean_value) WHERE boolean_value IS NOT NULL;

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_product_filter_index_key_product
  ON search.product_filter_index(filter_key, product_id);
CREATE INDEX IF NOT EXISTS idx_product_filter_index_key_alpha
  ON search.product_filter_index(filter_key, alphanumeric_value)
  WHERE alphanumeric_value IS NOT NULL;

COMMENT ON TABLE search.product_filter_index IS
  'Flattened index of ETIM features for fast product filtering (luminaires from active catalogs only)';
COMMENT ON COLUMN search.product_filter_index.filter_key IS
  'References search.filter_definitions.filter_key';
COMMENT ON COLUMN search.product_filter_index.source_feature_id IS
  'ETIM feature ID (e.g., EF009346 for CCT) for data lineage';

-- =====================================================================
-- Materialized View: search.filter_facets
-- Purpose: Pre-calculated filter value counts for UI
-- =====================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS search.filter_facets AS
WITH
-- Multi-select filters (categorical values)
multi_select_facets AS (
  SELECT
    fd.filter_key,
    fd.label as filter_label,
    CASE
      WHEN fd.ui_config->>'filter_category' IS NOT NULL
      THEN fd.ui_config->>'filter_category'
      ELSE 'other'
    END as filter_category,
    pfi.alphanumeric_value as filter_value,
    COUNT(DISTINCT pfi.product_id) as product_count,
    MIN(pfi.numeric_value) as min_numeric_value,
    MAX(pfi.numeric_value) as max_numeric_value
  FROM search.filter_definitions fd
  JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
  WHERE fd.filter_type = 'multi-select'
    AND fd.active = true
    AND pfi.alphanumeric_value IS NOT NULL
  GROUP BY fd.filter_key, fd.label, fd.ui_config->>'filter_category', pfi.alphanumeric_value
),
-- Range filters (numeric min/max)
range_facets AS (
  SELECT
    fd.filter_key,
    fd.label as filter_label,
    CASE
      WHEN fd.ui_config->>'filter_category' IS NOT NULL
      THEN fd.ui_config->>'filter_category'
      ELSE 'other'
    END as filter_category,
    'range:' || MIN(pfi.numeric_value)::text || '-' || MAX(pfi.numeric_value)::text as filter_value,
    COUNT(DISTINCT pfi.product_id) as product_count,
    MIN(pfi.numeric_value) as min_numeric_value,
    MAX(pfi.numeric_value) as max_numeric_value
  FROM search.filter_definitions fd
  JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
  WHERE fd.filter_type = 'range'
    AND fd.active = true
    AND pfi.numeric_value IS NOT NULL
  GROUP BY fd.filter_key, fd.label, fd.ui_config->>'filter_category'
),
-- Boolean filters
boolean_facets AS (
  SELECT
    fd.filter_key,
    fd.label as filter_label,
    CASE
      WHEN fd.ui_config->>'filter_category' IS NOT NULL
      THEN fd.ui_config->>'filter_category'
      ELSE 'other'
    END as filter_category,
    CASE pfi.boolean_value WHEN true THEN 'Yes' ELSE 'No' END as filter_value,
    COUNT(DISTINCT pfi.product_id) as product_count,
    NULL::numeric as min_numeric_value,
    NULL::numeric as max_numeric_value
  FROM search.filter_definitions fd
  JOIN search.product_filter_index pfi ON pfi.filter_key = fd.filter_key
  WHERE fd.filter_type = 'boolean'
    AND fd.active = true
    AND pfi.boolean_value IS NOT NULL
  GROUP BY fd.filter_key, fd.label, fd.ui_config->>'filter_category', pfi.boolean_value
)
-- Combine all facet types
SELECT * FROM multi_select_facets
UNION ALL
SELECT * FROM range_facets
UNION ALL
SELECT * FROM boolean_facets
ORDER BY filter_category, filter_key, product_count DESC;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_filter_facets_filter_key
  ON search.filter_facets(filter_key);
CREATE INDEX IF NOT EXISTS idx_filter_facets_category
  ON search.filter_facets(filter_category);
CREATE INDEX IF NOT EXISTS idx_filter_facets_key_value
  ON search.filter_facets(filter_key, filter_value);

COMMENT ON MATERIALIZED VIEW search.filter_facets IS
  'Pre-calculated filter value counts for UI faceted search (refreshed after catalog imports)';

-- =====================================================================
-- Completion Message
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Search schema tables created successfully!';
  RAISE NOTICE '   - search.product_filter_index (table)';
  RAISE NOTICE '   - search.filter_facets (materialized view)';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '   1. Run 02-populate-filter-definitions.sql';
  RAISE NOTICE '   2. Run 03-populate-filter-index.sql';
  RAISE NOTICE '   3. REFRESH MATERIALIZED VIEW search.filter_facets;';
END $$;
