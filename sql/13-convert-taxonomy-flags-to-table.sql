-- =====================================================================
-- File: 13-convert-taxonomy-flags-to-table.sql
-- Purpose: Convert product_taxonomy_flags from matview to table with
--          batch rebuild function for 2.2M+ product scale
-- =====================================================================
-- The matview CROSS JOIN approach (2.2M products x 56 rules = 123M pairs)
-- never completes at scale. This replaces it with:
--   1. A regular table (same schema, same indexes)
--   2. A rebuild function that splits by rule type (class/group/text/feature)
--      using efficient JOINs instead of CROSS JOIN
--
-- All existing RPC functions and frontend code continue working unchanged
-- since they reference the table by name (works for both matviews and tables).
-- =====================================================================

-- Step 1: Drop the matview (and any dependent objects)
DROP MATERIALIZED VIEW IF EXISTS search.product_taxonomy_flags CASCADE;

-- Step 2: Create the regular table with identical schema
CREATE TABLE search.product_taxonomy_flags (
    product_id UUID PRIMARY KEY,
    foss_pid TEXT,
    taxonomy_path TEXT[],
    -- Root category flags
    luminaire BOOLEAN DEFAULT FALSE,
    lamp BOOLEAN DEFAULT FALSE,
    driver BOOLEAN DEFAULT FALSE,
    accessory BOOLEAN DEFAULT FALSE,
    -- Environment flags
    indoor BOOLEAN DEFAULT FALSE,
    outdoor BOOLEAN DEFAULT FALSE,
    submersible BOOLEAN DEFAULT FALSE,
    trimless BOOLEAN DEFAULT FALSE,
    cut_shape_round BOOLEAN DEFAULT FALSE,
    cut_shape_rectangular BOOLEAN DEFAULT FALSE,
    -- Mounting location
    ceiling BOOLEAN DEFAULT FALSE,
    wall BOOLEAN DEFAULT FALSE,
    floor BOOLEAN DEFAULT FALSE,
    -- Installation type
    recessed BOOLEAN DEFAULT FALSE,
    surface_mounted BOOLEAN DEFAULT FALSE,
    suspended BOOLEAN DEFAULT FALSE,
    -- Specific combinations
    ceiling_recessed BOOLEAN DEFAULT FALSE,
    ceiling_surface BOOLEAN DEFAULT FALSE,
    ceiling_suspended BOOLEAN DEFAULT FALSE,
    wall_recessed BOOLEAN DEFAULT FALSE,
    wall_surface BOOLEAN DEFAULT FALSE,
    floor_recessed BOOLEAN DEFAULT FALSE,
    floor_surface BOOLEAN DEFAULT FALSE,
    -- Decorative
    decorative_table BOOLEAN DEFAULT FALSE,
    decorative_pendant BOOLEAN DEFAULT FALSE,
    decorative_floor BOOLEAN DEFAULT FALSE,
    -- Special types
    led_strip BOOLEAN DEFAULT FALSE,
    track_system BOOLEAN DEFAULT FALSE,
    batten BOOLEAN DEFAULT FALSE,
    pole_mounted BOOLEAN DEFAULT FALSE,
    -- Driver types
    constant_current BOOLEAN DEFAULT FALSE,
    constant_voltage BOOLEAN DEFAULT FALSE,
    driver_accessory BOOLEAN DEFAULT FALSE,
    -- Lamp types
    filament BOOLEAN DEFAULT FALSE,
    led_module BOOLEAN DEFAULT FALSE,
    -- Additional
    dimmable BOOLEAN DEFAULT FALSE,
    accessory_track BOOLEAN DEFAULT FALSE,
    accessory_strip BOOLEAN DEFAULT FALSE,
    accessory_pole BOOLEAN DEFAULT FALSE,
    accessory_optics BOOLEAN DEFAULT FALSE,
    accessory_electrical BOOLEAN DEFAULT FALSE,
    accessory_mechanical BOOLEAN DEFAULT FALSE,
    track_profile BOOLEAN DEFAULT FALSE,
    track_spare BOOLEAN DEFAULT FALSE,
    optics_lens BOOLEAN DEFAULT FALSE,
    electrical_boxes BOOLEAN DEFAULT FALSE,
    electrical_connectors BOOLEAN DEFAULT FALSE,
    mechanical_kits BOOLEAN DEFAULT FALSE,
    -- Computed columns
    decorative BOOLEAN DEFAULT FALSE,
    special BOOLEAN DEFAULT FALSE
);

-- Step 3: Create indexes (matching original matview + extras)
CREATE INDEX idx_ptf_foss_pid ON search.product_taxonomy_flags(foss_pid);
CREATE INDEX idx_ptf_taxonomy_path ON search.product_taxonomy_flags USING GIN(taxonomy_path);

-- Root category partial indexes
CREATE INDEX idx_ptf_luminaire ON search.product_taxonomy_flags(luminaire) WHERE luminaire = true;
CREATE INDEX idx_ptf_lamp ON search.product_taxonomy_flags(lamp) WHERE lamp = true;
CREATE INDEX idx_ptf_driver ON search.product_taxonomy_flags(driver) WHERE driver = true;
CREATE INDEX idx_ptf_accessory ON search.product_taxonomy_flags(accessory) WHERE accessory = true;

-- Environment partial indexes
CREATE INDEX idx_ptf_indoor ON search.product_taxonomy_flags(indoor) WHERE indoor = true;
CREATE INDEX idx_ptf_outdoor ON search.product_taxonomy_flags(outdoor) WHERE outdoor = true;
CREATE INDEX idx_ptf_submersible ON search.product_taxonomy_flags(submersible) WHERE submersible = true;

-- Installation type partial indexes
CREATE INDEX idx_ptf_recessed ON search.product_taxonomy_flags(recessed) WHERE recessed = true;
CREATE INDEX idx_ptf_surface_mounted ON search.product_taxonomy_flags(surface_mounted) WHERE surface_mounted = true;

-- Step 4: Grant permissions
GRANT SELECT ON search.product_taxonomy_flags TO authenticated, service_role, anon;

-- NOTE: The rebuild logic lives in the bash script:
--   supabase/db-maintenance/rebuild-search-tables.sh
--
-- It runs each step as a separate psql connection/transaction,
-- preventing resource exhaustion at 2.2M+ product scale.
-- The PL/pgSQL function approach was abandoned because:
--   1. A single transaction holding 17M+ staging rows overwhelms shared buffers
--   2. PL/pgSQL evaluate_feature_condition() calls are too slow (22M calls)
--   3. No progress visibility during execution
--
-- Usage:
--   ./rebuild-search-tables.sh --taxonomy-only  # ~16 min for 2.2M products
--   ./rebuild-search-tables.sh --filter-only    # filter index only
--   ./rebuild-search-tables.sh                  # both
