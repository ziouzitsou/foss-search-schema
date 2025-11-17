-- =====================================================================
-- 01-create-search-schema.sql
-- =====================================================================
-- Creates the search schema and configuration tables
-- Run this first before any other files
-- =====================================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS search;

COMMENT ON SCHEMA search IS
'Product search and discovery layer. Provides fast boolean flags, faceted search,
and hierarchical taxonomy for the Foss SA luminaires catalog.';

-- =====================================================================
-- 1. TAXONOMY TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS search.taxonomy (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    parent_code TEXT REFERENCES search.taxonomy(code),
    level INTEGER NOT NULL,
    name_el TEXT NOT NULL,
    name_en TEXT NOT NULL,
    description_el TEXT,
    description_en TEXT,
    icon TEXT,
    display_order INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT true,
    full_path TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_taxonomy_code ON search.taxonomy(code);
CREATE INDEX IF NOT EXISTS idx_taxonomy_parent ON search.taxonomy(parent_code);
CREATE INDEX IF NOT EXISTS idx_taxonomy_active ON search.taxonomy(active) WHERE active = true;

COMMENT ON TABLE search.taxonomy IS
'Hierarchical product taxonomy for navigation. Maps business-friendly categories
to technical ETIM classifications via classification_rules.';

-- =====================================================================
-- 2. CLASSIFICATION RULES TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS search.classification_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    description TEXT,
    taxonomy_code TEXT REFERENCES search.taxonomy(code),
    flag_name TEXT,
    priority INTEGER DEFAULT 100,

    -- Rule conditions (ONE of these must be specified)
    etim_group_ids TEXT[],
    etim_class_ids TEXT[],
    etim_feature_conditions JSONB,
    text_pattern TEXT,

    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_classification_rules_active
    ON search.classification_rules(active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_classification_rules_taxonomy
    ON search.classification_rules(taxonomy_code);

COMMENT ON TABLE search.classification_rules IS
'Configuration-driven rules for product classification. Applied to populate product_taxonomy_flags.';

-- =====================================================================
-- 3. FILTER DEFINITIONS TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS search.filter_definitions (
    id SERIAL PRIMARY KEY,
    filter_key TEXT UNIQUE NOT NULL,
    filter_type TEXT NOT NULL CHECK (filter_type IN ('numeric_range', 'alphanumeric', 'boolean')),

    -- Display names
    label_el TEXT NOT NULL,
    label_en TEXT NOT NULL,

    -- ETIM mapping
    etim_feature_id TEXT NOT NULL,
    etim_unit_id TEXT,

    -- UI configuration
    display_order INTEGER DEFAULT 0,
    ui_component TEXT,
    ui_config JSONB,

    -- Taxonomy restrictions (optional)
    applicable_taxonomy_codes TEXT[],

    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_filter_definitions_active
    ON search.filter_definitions(active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_filter_definitions_feature
    ON search.filter_definitions(etim_feature_id);

COMMENT ON TABLE search.filter_definitions IS
'Defines available filters for faceted search. Controls UI rendering and
maps to ETIM features via product_filter_index materialized view.';

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Search schema created successfully!';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  ✓ search.taxonomy';
    RAISE NOTICE '  ✓ search.classification_rules';
    RAISE NOTICE '  ✓ search.filter_definitions';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Run 02-populate-example-data.sql to add configuration data';
    RAISE NOTICE '  2. Run 03-create-materialized-views.sql to build indexes';
    RAISE NOTICE '  3. Run 04-create-search-functions.sql to create search API';
    RAISE NOTICE '';
    RAISE NOTICE '======================================================================';
END $$;
