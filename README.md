# Foss SA Product Search System

**Status**: ✅ Production-Ready (v2.5)
**Running at**: http://localhost:3001
**Database**: Supabase PostgreSQL (56K+ products)
**Last Updated**: 2025-11-19

---

## 🎯 What This Is

A **complete, working product search system** for the Foss SA lighting catalog with:

- ✅ **Next.js 15.5.6** test application with production-quality components
- ✅ **Delta Light-style filters** (Electricals, Design, Light Engine)
- ✅ **Dynamic facets** with context-aware counts
- ✅ **Real-time auto-search** (no search button needed)
- ✅ **Hierarchical taxonomy navigation** with 3-level categories
- ✅ **20 SQL files** implementing complete search schema
- ✅ **7 RPC functions** deployed to Supabase

This is **NOT a concept** - it's a fully functional application you can run right now.

---

## 🚀 Quick Start

### Run the Test App (Fastest Way to See It Work)

```bash
cd /home/dimitris/foss/searchdb/search-test-app
npm run dev
# Opens at http://localhost:3001
```

**What you'll see:**
- 3-column layout: Categories (left) + Technical Filters (middle) + Location/Options (right)
- Real-time search as you select filters
- Dynamic product counts updating based on your selections
- Responsive product grid with images and ETIM features

### Database Setup (If Starting Fresh)

```bash
cd /home/dimitris/foss/searchdb/sql

# Execute files in order (00 → 14)
# See sql/README.md for detailed instructions
```

---

## 📁 Project Structure

```
searchdb/
├── README.md                    ← You are here
├── QUICKSTART.md                ← 30-min implementation guide
├── CLAUDE.md                    ← Instructions for Claude Code
│
├── search-test-app/             ← 🌟 THE REFERENCE IMPLEMENTATION
│   ├── app/page.tsx             592 lines - main search interface
│   ├── components/
│   │   ├── FilterPanel.tsx      319 lines - Delta Light filters
│   │   ├── FacetedCategoryNavigation.tsx  342 lines
│   │   ├── ActiveFilters.tsx    207 lines
│   │   └── filters/             Boolean, MultiSelect, Range components
│   └── README.md                Component architecture guide
│
├── sql/                         ← Database implementation (16 files)
│   ├── README.md                Execution guide for all SQL files
│   ├── 00-drop-search-schema.sql
│   ├── 01-create-search-schema.sql
│   ├── 02-populate-taxonomy.sql
│   ├── ...
│   └── 09-add-dynamic-facets.sql
│
└── docs/                        ← Comprehensive documentation
    ├── architecture/
    │   ├── overview.md          System architecture and design
    │   └── ui-components.md     Component documentation
    ├── guides/
    │   ├── fossapp-integration.md
    │   ├── delta-light-filters.md
    │   ├── dynamic-facets.md
    │   └── maintenance.md
    ├── reference/
    │   ├── search-schema-complete-guide.md
    │   ├── sql-functions.md
    │   └── filter-types.md
    └── archive/                 Historical docs (dated)
```

---

## 🏗️ Architecture Overview

### Three-Tier Search System

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE (Next.js)                 │
│  3-Column Layout: Categories + Tech Filters + Location      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              DATABASE FUNCTIONS (Supabase RPC)              │
│  - search_products_with_filters()                           │
│  - get_dynamic_facets()                                     │
│  - get_filter_facets_with_context()                         │
│  - count_products_with_filters()                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│           MATERIALIZED VIEWS (Pre-computed Data)            │
│  - search.product_taxonomy_flags (Boolean filters)          │
│  - search.product_filter_index (Technical features)         │
│  - search.filter_facets (Filter options & counts)           │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
items.catalog (56K+ products)
    ↓ (filtered by active catalogs)
items.product_info (14,889 products)
    ↓ (classification rules applied)
search.product_taxonomy_flags (Boolean flags: indoor, outdoor, etc.)
    ↓ (ETIM features flattened)
search.product_filter_index (Technical specs: power, IP rating, etc.)
    ↓ (aggregated)
search.filter_facets (Filter UI options with counts)
```

---

## 🎨 Key Features

### 1. Hierarchical Taxonomy Navigation
- **Root Categories**: Luminaires, Lamps, Drivers, Accessories
- **Subcategories**: Ceiling, Wall, Floor, Decorative, Special
- **Installation Types**: Recessed, Surface, Suspended
- **ETIM-based**: Maps technical ETIM codes to user-friendly categories

### 2. Delta Light-Style Technical Filters
- **Electricals**: Voltage, Dimmable, Protection Class
- **Design**: IP Rating, Finishing Colour
- **Light Engine**: CCT, CRI, Power, Lumens, Beam Angle
- **Smart UI**: Color swatches, icons, presets

### 3. Dynamic Facets
- **Context-aware**: Filter counts update based on current selections
- **Real-time**: Instant updates as you add/remove filters
- **Performance**: Sub-100ms facet calculation

### 4. Boolean Location Filters
- Indoor/Outdoor detection (text pattern matching)
- Submersible
- Trimless
- Cut Shape (Round/Rectangular)

### 5. Auto-Search
- No search button needed
- Debounced for performance (300ms)
- Instant visual feedback

---

## 📊 Current Status (Nov 19, 2025)

### Implementation Timeline

| Phase | Date | What Was Built | Status |
|-------|------|----------------|--------|
| **Phase 1** | Nov 3-8 | Initial schema, taxonomy, classification | ✅ Complete |
| **Phase 2** | Nov 8-12 | Multi-taxonomy filtering, SQL functions | ✅ Complete |
| **Phase 3** | Nov 12-15 | Delta Light filters, ETIM mapping | ✅ Complete |
| **Phase 4** | Nov 15-19 | Dynamic facets, context-aware counts | ✅ Complete |
| **Phase 5** | TBD | FOSSAPP integration | 🔜 Ready to start |

### Database Statistics

```
✅ Total Products: 14,889
✅ Luminaires: 13,336
✅ Lamps: 50
✅ Drivers: 83
✅ Accessories: 1,411

✅ Classification Rules: 35+
✅ Taxonomy Nodes: 30+
✅ Filter Definitions: 8 (Phase 1 filters)
✅ Filter Index Entries: 125,000+
```

### Performance Metrics

```
✅ Boolean filter queries: <50ms
✅ Text search: <200ms
✅ Facet calculation: <100ms
✅ Product count: <50ms
✅ Materialized view refresh: 5-8 minutes
```

---

## 📚 Documentation Guide

### For First-Time Users

1. **Start Here**: Read this README
2. **Quick Implementation**: [QUICKSTART.md](./QUICKSTART.md) (30 minutes)
3. **Run the App**: `cd search-test-app && npm run dev`
4. **Explore UI**: Open http://localhost:3001

### For Understanding the System

1. **Architecture**: [docs/architecture/overview.md](./docs/architecture/overview.md)
2. **UI Components**: [docs/architecture/ui-components.md](./docs/architecture/ui-components.md)
3. **Database Schema**: [docs/reference/search-schema-complete-guide.md](./docs/reference/search-schema-complete-guide.md)

### For Integration

1. **FOSSAPP Integration**: [docs/guides/fossapp-integration.md](./docs/guides/fossapp-integration.md)
2. **SQL Functions Reference**: [docs/reference/sql-functions.md](./docs/reference/sql-functions.md)
3. **Filter Types Guide**: [docs/reference/filter-types.md](./docs/reference/filter-types.md)

### For Advanced Topics

1. **Delta Light Filters**: [docs/guides/delta-light-filters.md](./docs/guides/delta-light-filters.md)
2. **Dynamic Facets**: [docs/guides/dynamic-facets.md](./docs/guides/dynamic-facets.md)
3. **Maintenance Operations**: [docs/guides/maintenance.md](./docs/guides/maintenance.md)

---

## 🔧 Common Tasks

### Start Development Server
```bash
cd search-test-app
npm run dev
# http://localhost:3001
```

### Refresh Materialized Views (After Catalog Import)
```bash
# In Supabase SQL Editor:
REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;
REFRESH MATERIALIZED VIEW search.product_filter_index;
REFRESH MATERIALIZED VIEW search.filter_facets;

ANALYZE search.product_taxonomy_flags;
ANALYZE search.product_filter_index;
```

### Check System Statistics
```sql
SELECT * FROM search.get_search_statistics();
```

### Test Search Function
```sql
SELECT * FROM search.search_products_with_filters(
  p_query := 'LED',
  p_indoor := true,
  p_limit := 20
);
```

---

## 🎯 Next Steps

### For FOSSAPP Integration
1. Review [docs/guides/fossapp-integration.md](./docs/guides/fossapp-integration.md)
2. Copy server actions from guide
3. Create API routes in FOSSAPP
4. Build UI components using search-test-app as reference
5. Test with production data

### For Customization
1. Add new taxonomy categories in `search.taxonomy`
2. Add classification rules in `search.classification_rules`
3. Add filter definitions in `search.filter_definitions`
4. Refresh materialized views
5. Test in search-test-app

### For Maintenance
1. Add search view refresh to your daily catalog import routine
2. Monitor query performance
3. Review and update classification rules as product data evolves

---

## 🐛 Troubleshooting

### App won't start
```bash
cd search-test-app
npm install
npm run dev
```

### No products showing
- Check if materialized views are populated: `SELECT COUNT(*) FROM search.product_taxonomy_flags;`
- If zero, run: `REFRESH MATERIALIZED VIEW search.product_taxonomy_flags;`

### Filters not working
- Check filter definitions exist: `SELECT * FROM search.filter_definitions;`
- Check dynamic facets function: `SELECT * FROM search.get_dynamic_facets(NULL, NULL, NULL);`

### Slow queries
- Run ANALYZE on materialized views
- Check indexes: `\d+ search.product_taxonomy_flags`

For more: See [docs/guides/maintenance.md](./docs/guides/maintenance.md)

---

## 🤝 Related Projects

- **FOSSAPP**: `/home/dimitris/foss/fossapp/` - Production Next.js app
- **Database Utils**: `/home/dimitris/foss/supabase/db-maintenance/` - Maintenance scripts
- **ETIM MCP**: Built-in MCP server for ETIM queries
- **Supabase MCP**: Built-in MCP server for database operations

---

## 📄 Version History

- **v2.5** (Nov 19, 2025): Dynamic facets, context-aware counts
- **v2.0** (Nov 15, 2025): Delta Light filters, ETIM mapping
- **v1.5** (Nov 12, 2025): Multi-taxonomy filtering
- **v1.0** (Nov 8, 2025): Initial schema and taxonomy

See full history: `git log --oneline`

---

## 🏷️ Git Tags

- `v2.5-pre-docs-reorganization` - State before major docs reorganization (Nov 19, 2025)

---

## 📞 Support

- **Troubleshooting**: See docs/guides/maintenance.md
- **Architecture Questions**: See docs/architecture/overview.md
- **Integration Help**: See docs/guides/fossapp-integration.md
- **Bug Reports**: Check git history and recent commits

---

**Built with**: Next.js 15.5.6, Supabase, PostgreSQL, TypeScript, Tailwind CSS
**Maintained by**: Dimitri (Foss SA)
**Last Major Update**: November 19, 2025
