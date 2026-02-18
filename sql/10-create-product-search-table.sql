-- =====================================================================
-- 10-create-product-search-table.sql
-- =====================================================================
-- Creates the denormalized search.product_search wide table.
-- Replaces the EAV product_filter_index (21.7M rows) with a single
-- row per product (~2.2M rows) containing all filterable values as
-- direct columns.
--
-- This table is populated by rebuild-product-search.sh, NOT by this
-- migration. This file only creates the structure and indexes.
-- =====================================================================

-- Drop if exists (for re-running)
DROP TABLE IF EXISTS search.product_search CASCADE;

-- =====================================================================
-- WIDE TABLE: One row per product with ALL filterable values
-- =====================================================================
CREATE TABLE search.product_search (
    -- Core identity
    product_id      UUID PRIMARY KEY,
    foss_pid        TEXT NOT NULL,

    -- Descriptions
    description_short TEXT,
    description_long  TEXT,

    -- Catalog/supplier
    supplier_name   TEXT,
    catalog_id      INTEGER,
    class_name      TEXT,
    family          TEXT,

    -- Price (extracted from JSONB)
    price           NUMERIC,

    -- Image URL (MD01 thumbnail, extracted from multimedia JSONB)
    image_url       TEXT,

    -- Taxonomy (from product_taxonomy_flags)
    taxonomy_path   TEXT[],

    -- ─── Boolean flags (from product_taxonomy_flags) ───
    -- Root categories
    luminaire       BOOLEAN DEFAULT FALSE,
    lamp            BOOLEAN DEFAULT FALSE,
    driver          BOOLEAN DEFAULT FALSE,
    accessory       BOOLEAN DEFAULT FALSE,

    -- Location
    indoor          BOOLEAN DEFAULT FALSE,
    outdoor         BOOLEAN DEFAULT FALSE,
    submersible     BOOLEAN DEFAULT FALSE,

    -- Options
    trimless        BOOLEAN DEFAULT FALSE,
    cut_shape_round BOOLEAN DEFAULT FALSE,
    cut_shape_rectangular BOOLEAN DEFAULT FALSE,

    -- Mounting
    ceiling         BOOLEAN DEFAULT FALSE,
    wall            BOOLEAN DEFAULT FALSE,
    floor           BOOLEAN DEFAULT FALSE,
    recessed        BOOLEAN DEFAULT FALSE,
    surface_mounted BOOLEAN DEFAULT FALSE,
    suspended       BOOLEAN DEFAULT FALSE,

    -- Combined mounting
    ceiling_recessed  BOOLEAN DEFAULT FALSE,
    ceiling_surface   BOOLEAN DEFAULT FALSE,
    ceiling_suspended BOOLEAN DEFAULT FALSE,
    wall_recessed     BOOLEAN DEFAULT FALSE,
    wall_surface      BOOLEAN DEFAULT FALSE,
    floor_recessed    BOOLEAN DEFAULT FALSE,
    floor_surface     BOOLEAN DEFAULT FALSE,

    -- Decorative
    decorative_table   BOOLEAN DEFAULT FALSE,
    decorative_pendant BOOLEAN DEFAULT FALSE,
    decorative_floor   BOOLEAN DEFAULT FALSE,
    decorative         BOOLEAN DEFAULT FALSE,

    -- Miscellaneous
    misc            BOOLEAN DEFAULT FALSE,

    -- Special types
    led_strip       BOOLEAN DEFAULT FALSE,
    track_system    BOOLEAN DEFAULT FALSE,
    batten          BOOLEAN DEFAULT FALSE,
    pole_mounted    BOOLEAN DEFAULT FALSE,
    special         BOOLEAN DEFAULT FALSE,

    -- Driver subtypes
    constant_current  BOOLEAN DEFAULT FALSE,
    constant_voltage  BOOLEAN DEFAULT FALSE,
    driver_accessory  BOOLEAN DEFAULT FALSE,

    -- Lamp subtypes
    filament        BOOLEAN DEFAULT FALSE,
    led_module      BOOLEAN DEFAULT FALSE,

    -- Dimmable (from taxonomy flag OR ETIM feature)
    dimmable        BOOLEAN DEFAULT FALSE,

    -- Accessory subtypes
    accessory_track       BOOLEAN DEFAULT FALSE,
    accessory_strip       BOOLEAN DEFAULT FALSE,
    accessory_pole        BOOLEAN DEFAULT FALSE,
    accessory_optics      BOOLEAN DEFAULT FALSE,
    accessory_electrical  BOOLEAN DEFAULT FALSE,
    accessory_mechanical  BOOLEAN DEFAULT FALSE,

    -- Accessory detail types
    track_profile          BOOLEAN DEFAULT FALSE,
    track_spare            BOOLEAN DEFAULT FALSE,
    optics_lens            BOOLEAN DEFAULT FALSE,
    electrical_boxes       BOOLEAN DEFAULT FALSE,
    electrical_connectors  BOOLEAN DEFAULT FALSE,
    mechanical_kits        BOOLEAN DEFAULT FALSE,

    -- ─── ETIM feature columns (direct values, NO EAV) ───
    -- These columns are populated data-driven from filter_definitions
    -- where etim_feature_id starts with 'EF'

    -- Electricals
    voltage             NUMERIC,   -- EF005127 (range)
    light_source        TEXT,      -- EF002423 (categorical)
    protection_class    TEXT,      -- EF000004 (categorical, filter_key = 'class')

    -- Design
    ip_rating           TEXT,      -- EF003118 (categorical, filter_key = 'ip')
    finishing_colour    TEXT,      -- EF000136 (categorical)

    -- Light
    light_distribution  TEXT,      -- EF004283 (categorical)
    cct                 NUMERIC,   -- EF009346 (range)
    cri                 TEXT,      -- EF000442 (categorical)
    lumens_output       NUMERIC,   -- EF018714 (range)
    beam_angle_type     TEXT,      -- EF008157 (categorical)

    -- ─── Full-text search ───
    fts                 TSVECTOR
);

-- =====================================================================
-- INDEXES
-- =====================================================================

-- Taxonomy: GIN on array for containment queries (taxonomy_path && ARRAY['LUMINAIRE'])
CREATE INDEX idx_ps_taxonomy_path ON search.product_search USING GIN (taxonomy_path);

-- Boolean flags: Partial indexes (only index TRUE rows - much smaller)
CREATE INDEX idx_ps_luminaire ON search.product_search (product_id) WHERE luminaire = TRUE;
CREATE INDEX idx_ps_indoor ON search.product_search (product_id) WHERE indoor = TRUE;
CREATE INDEX idx_ps_outdoor ON search.product_search (product_id) WHERE outdoor = TRUE;
CREATE INDEX idx_ps_ceiling ON search.product_search (product_id) WHERE ceiling = TRUE;
CREATE INDEX idx_ps_wall ON search.product_search (product_id) WHERE wall = TRUE;
CREATE INDEX idx_ps_floor ON search.product_search (product_id) WHERE floor = TRUE;
CREATE INDEX idx_ps_recessed ON search.product_search (product_id) WHERE recessed = TRUE;
CREATE INDEX idx_ps_surface_mounted ON search.product_search (product_id) WHERE surface_mounted = TRUE;
CREATE INDEX idx_ps_suspended ON search.product_search (product_id) WHERE suspended = TRUE;
CREATE INDEX idx_ps_dimmable ON search.product_search (product_id) WHERE dimmable = TRUE;
CREATE INDEX idx_ps_trimless ON search.product_search (product_id) WHERE trimless = TRUE;
CREATE INDEX idx_ps_submersible ON search.product_search (product_id) WHERE submersible = TRUE;
CREATE INDEX idx_ps_misc ON search.product_search (foss_pid) WHERE misc = TRUE;

-- Root category partial indexes on foss_pid (for ORDER BY foss_pid + LIMIT optimization)
CREATE INDEX idx_ps_luminaire_foss_pid ON search.product_search (foss_pid) WHERE luminaire = TRUE;
CREATE INDEX idx_ps_accessory ON search.product_search (foss_pid) WHERE accessory = TRUE;
CREATE INDEX idx_ps_driver ON search.product_search (foss_pid) WHERE driver = TRUE;
CREATE INDEX idx_ps_lamp ON search.product_search (foss_pid) WHERE lamp = TRUE;

-- Composite partial indexes for multi-boolean filter combinations
CREATE INDEX idx_ps_luminaire_indoor_outdoor ON search.product_search (foss_pid)
    WHERE luminaire = TRUE AND indoor = TRUE AND outdoor = TRUE;
CREATE INDEX idx_ps_luminaire_outdoor ON search.product_search (foss_pid)
    WHERE luminaire = TRUE AND outdoor = TRUE;

-- Categorical columns (B-tree for equality/IN queries)
CREATE INDEX idx_ps_ip_rating ON search.product_search (ip_rating) WHERE ip_rating IS NOT NULL;
CREATE INDEX idx_ps_finishing_colour ON search.product_search (finishing_colour) WHERE finishing_colour IS NOT NULL;
CREATE INDEX idx_ps_light_source ON search.product_search (light_source) WHERE light_source IS NOT NULL;
CREATE INDEX idx_ps_light_distribution ON search.product_search (light_distribution) WHERE light_distribution IS NOT NULL;
CREATE INDEX idx_ps_beam_angle_type ON search.product_search (beam_angle_type) WHERE beam_angle_type IS NOT NULL;
CREATE INDEX idx_ps_cri ON search.product_search (cri) WHERE cri IS NOT NULL;
CREATE INDEX idx_ps_protection_class ON search.product_search (protection_class) WHERE protection_class IS NOT NULL;
CREATE INDEX idx_ps_voltage ON search.product_search (voltage) WHERE voltage IS NOT NULL;

-- Numeric range columns (B-tree for range queries)
CREATE INDEX idx_ps_cct ON search.product_search (cct) WHERE cct IS NOT NULL;
CREATE INDEX idx_ps_lumens_output ON search.product_search (lumens_output) WHERE lumens_output IS NOT NULL;
CREATE INDEX idx_ps_price ON search.product_search (price) WHERE price IS NOT NULL;

-- Supplier (for facets and filtering)
CREATE INDEX idx_ps_supplier ON search.product_search (supplier_name);

-- Full-text search
CREATE INDEX idx_ps_fts ON search.product_search USING GIN (fts);

-- Composite: supplier + taxonomy (common combined filter)
CREATE INDEX idx_ps_supplier_taxonomy ON search.product_search USING GIN (supplier_name, taxonomy_path);

-- =====================================================================
-- PERMISSIONS
-- =====================================================================
GRANT SELECT ON search.product_search TO authenticated, service_role, anon;

-- =====================================================================
-- COMMENTS
-- =====================================================================
COMMENT ON TABLE search.product_search IS
'Denormalized wide table for fast product search and faceted filtering.
One row per product (~2.2M rows) with all filterable values as direct columns.
Replaces the EAV product_filter_index (21.7M rows) for massive performance gain.
Populated by rebuild-product-search.sh using data-driven approach from filter_definitions.';

-- =====================================================================
-- SUCCESS
-- =====================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE 'search.product_search table created successfully!';
    RAISE NOTICE '=======================================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run rebuild-product-search.sh to populate with data.';
    RAISE NOTICE '';
END $$;
