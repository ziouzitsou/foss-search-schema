-- =====================================================
-- File: 01-create-search-schema.sql
-- Purpose: Create search schema, tables, and helper functions
-- Database: Foss SA Supabase (English only)
-- =====================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS search;

-- =====================================================
-- 1. search.taxonomy (Configuration Table)
-- =====================================================

CREATE TABLE search.taxonomy (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,                    -- e.g., 'LUM_CEIL_REC'
    parent_code TEXT REFERENCES search.taxonomy(code),
    level INTEGER NOT NULL,                       -- 0=root, 1=category, 2=subcategory, 3=type
    name TEXT NOT NULL,                           -- English name
    description TEXT,                             -- English description
    icon TEXT,                                    -- Icon identifier
    display_order INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT true,
    full_path TEXT[],                             -- Computed: ['LUM', 'CEIL', 'REC']
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_taxonomy_code ON search.taxonomy(code);
CREATE INDEX idx_taxonomy_parent ON search.taxonomy(parent_code);
CREATE INDEX idx_taxonomy_active ON search.taxonomy(active) WHERE active = true;

COMMENT ON TABLE search.taxonomy IS
'Hierarchical product taxonomy for navigation. Maps business-friendly categories
to technical ETIM classifications via classification_rules. English only.';

COMMENT ON COLUMN search.taxonomy.code IS 'Unique taxonomy code (e.g., LUM_CEIL_REC for Luminaires > Ceiling > Recessed)';
COMMENT ON COLUMN search.taxonomy.level IS '0=root, 1=main category, 2=subcategory, 3=type';
COMMENT ON COLUMN search.taxonomy.full_path IS 'Array of codes from root to current node';

-- =====================================================
-- 2. search.classification_rules (Configuration Table)
-- =====================================================

CREATE TABLE search.classification_rules (
    id SERIAL PRIMARY KEY,
    rule_name TEXT UNIQUE NOT NULL,
    description TEXT,
    taxonomy_code TEXT REFERENCES search.taxonomy(code),
    flag_name TEXT,                               -- e.g., 'indoor', 'recessed', 'dimmable'
    priority INTEGER DEFAULT 100,                 -- Lower = higher priority (applied first)

    -- Rule conditions (ONE or MORE of these can be specified)
    etim_group_ids TEXT[],                        -- Match ETIM groups (e.g., ['EG000027'])
    etim_class_ids TEXT[],                        -- Match ETIM classes (e.g., ['EC002710'])
    etim_feature_conditions JSONB,                -- Feature-based rules
    text_pattern TEXT,                            -- Regex pattern for descriptions (case-insensitive)

    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_classification_rules_active ON search.classification_rules(active) WHERE active = true;
CREATE INDEX idx_classification_rules_taxonomy ON search.classification_rules(taxonomy_code);
CREATE INDEX idx_classification_rules_priority ON search.classification_rules(priority);

COMMENT ON TABLE search.classification_rules IS
'Configuration-driven rules for product classification. Applied to populate product_taxonomy_flags.';

COMMENT ON COLUMN search.classification_rules.priority IS
'Lower number = higher priority. Used to resolve conflicts (e.g., drivers override accessories).';

COMMENT ON COLUMN search.classification_rules.etim_group_ids IS
'Match products where items.product_info.group IN (etim_group_ids). Example: [''EG000027''] for luminaires.';

COMMENT ON COLUMN search.classification_rules.etim_class_ids IS
'Match products where items.product_info.class IN (etim_class_ids). Example: [''EC002710''] for drivers.';

COMMENT ON COLUMN search.classification_rules.etim_feature_conditions IS
'JSONB conditions for feature matching. Example: {"EF006760": {"operator": "exists"}} for recessed mounting.';

COMMENT ON COLUMN search.classification_rules.text_pattern IS
'Case-insensitive regex pattern applied to description_short and description_long. Example: "indoor|interior|internal"';

-- =====================================================
-- 3. search.filter_definitions (Configuration Table)
-- =====================================================

CREATE TABLE search.filter_definitions (
    id SERIAL PRIMARY KEY,
    filter_key TEXT UNIQUE NOT NULL,              -- e.g., 'power', 'ip_rating', 'color_temp'
    filter_type TEXT NOT NULL,                    -- 'numeric_range', 'alphanumeric', 'boolean'

    -- Display name (English only)
    label TEXT NOT NULL,                          -- e.g., 'Power', 'IP Rating', 'Dimmable'

    -- ETIM mapping
    etim_feature_id TEXT NOT NULL,                -- References etim.feature.FEATUREID
    etim_unit_id TEXT,                            -- For numeric filters (references etim.unit.UNITID)

    -- UI configuration
    display_order INTEGER DEFAULT 0,
    ui_component TEXT,                            -- 'slider', 'checkbox', 'dropdown', 'multiselect'
    ui_config JSONB,                              -- Component-specific config

    -- Taxonomy restrictions (optional)
    applicable_taxonomy_codes TEXT[],             -- Show only for these categories (NULL = all)

    -- Metadata
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_filter_definitions_active ON search.filter_definitions(active) WHERE active = true;
CREATE INDEX idx_filter_definitions_feature ON search.filter_definitions(etim_feature_id);

COMMENT ON TABLE search.filter_definitions IS
'Defines available filters for faceted search. Controls UI rendering and
maps to ETIM features via product_filter_index materialized view.';

COMMENT ON COLUMN search.filter_definitions.filter_type IS
'numeric_range: for continuous values (power, temperature); alphanumeric: for discrete values (IP rating); boolean: for yes/no features (dimmable)';

COMMENT ON COLUMN search.filter_definitions.ui_config IS
'JSON configuration for UI component. Example: {"min": 0, "max": 300, "step": 5, "unit": "W"} for power slider';

COMMENT ON COLUMN search.filter_definitions.applicable_taxonomy_codes IS
'Optional filter to show only for specific categories. Example: [''LUM_OUT''] for outdoor-only filters like IP rating';

-- =====================================================
-- 4. Helper Functions
-- =====================================================

-- Function: Evaluate feature conditions in classification rules
CREATE OR REPLACE FUNCTION search.evaluate_feature_condition(
    feature JSONB,
    condition JSONB
) RETURNS BOOLEAN AS $$
DECLARE
    feature_id TEXT;
    operator TEXT;
    expected_value TEXT;
BEGIN
    -- Extract feature ID from condition keys
    feature_id := (SELECT jsonb_object_keys(condition) LIMIT 1);

    -- Check if this is the feature we're looking for
    -- FIXED: Use uppercase FEATUREID to match actual data structure
    IF (feature->>'FEATUREID') != feature_id THEN
        RETURN false;
    END IF;

    -- Get operator and value from condition
    operator := condition->feature_id->>'operator';
    expected_value := condition->feature_id->>'value';

    -- Evaluate based on operator
    CASE operator
        WHEN 'exists' THEN
            -- Feature simply exists (any value)
            RETURN true;
        WHEN 'equals' THEN
            -- Check alphanumeric or boolean value
            RETURN (feature->>'fvalueC' = expected_value
                    OR (feature->>'fvalueB')::TEXT = expected_value);
        WHEN 'contains' THEN
            -- Text contains substring (case-insensitive)
            RETURN (feature->>'fvalueC_desc' ILIKE '%' || expected_value || '%');
        WHEN 'greater_than' THEN
            -- Numeric comparison
            RETURN (feature->>'fvalueN')::NUMERIC > expected_value::NUMERIC;
        WHEN 'less_than' THEN
            -- Numeric comparison
            RETURN (feature->>'fvalueN')::NUMERIC < expected_value::NUMERIC;
        WHEN 'in_range' THEN
            -- Numeric range
            RETURN (feature->>'fvalueN')::NUMERIC BETWEEN
                (condition->feature_id->>'min')::NUMERIC AND
                (condition->feature_id->>'max')::NUMERIC;
        ELSE
            RETURN false;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION search.evaluate_feature_condition IS
'Evaluates whether a product feature matches a condition from classification_rules.
Operators: exists, equals, contains, greater_than, less_than, in_range';

-- Function: Build histogram for numeric filter facets
CREATE OR REPLACE FUNCTION search.build_histogram(
    value_array NUMERIC[],  -- FIXED: Renamed from 'values' (reserved keyword in PostgreSQL)
    bucket_count INTEGER DEFAULT 10
) RETURNS JSONB AS $$
DECLARE
    min_val NUMERIC;
    max_val NUMERIC;
    bucket_width NUMERIC;
    histogram JSONB := '[]'::JSONB;
    bucket_start NUMERIC;
    bucket_end NUMERIC;
    bucket_label TEXT;
    count INTEGER;
BEGIN
    -- Get min and max values
    min_val := (SELECT MIN(v) FROM unnest(value_array) v);
    max_val := (SELECT MAX(v) FROM unnest(value_array) v);

    -- Avoid division by zero
    IF min_val = max_val THEN
        RETURN jsonb_build_array(
            jsonb_build_object(
                'range', min_val::TEXT,
                'min', min_val,
                'max', max_val,
                'count', array_length(value_array, 1)
            )
        );
    END IF;

    -- Calculate bucket width
    bucket_width := (max_val - min_val) / bucket_count;

    -- Build histogram buckets
    FOR i IN 0..(bucket_count - 1) LOOP
        bucket_start := min_val + (i * bucket_width);
        bucket_end := bucket_start + bucket_width;
        bucket_label := bucket_start::TEXT || '-' || bucket_end::TEXT;

        -- Count values in this bucket
        SELECT COUNT(*) INTO count
        FROM unnest(value_array) v
        WHERE v >= bucket_start AND v < bucket_end;

        -- Add to histogram
        histogram := histogram || jsonb_build_object(
            'range', bucket_label,
            'min', bucket_start,
            'max', bucket_end,
            'count', count
        );
    END LOOP;

    RETURN histogram;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION search.build_histogram IS
'Builds histogram for numeric filters (e.g., power distribution).
Returns JSONB array of buckets with range, min, max, and count.';

-- =====================================================
-- Verification
-- =====================================================

-- Verify schema creation
DO $$
BEGIN
    RAISE NOTICE 'Search schema created successfully!';
    RAISE NOTICE 'Tables: taxonomy, classification_rules, filter_definitions';
    RAISE NOTICE 'Functions: evaluate_feature_condition, build_histogram';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 02-populate-taxonomy.sql';
END $$;
