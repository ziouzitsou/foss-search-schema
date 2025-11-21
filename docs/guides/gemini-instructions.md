# Gemini Instructions

This document provides a concise overview of the `searchdb` project, serving as a quick reference for the Gemini AI agent.

---

## Repository Overview

This repository contains a **complete, working product search system** for the Foss SA lighting catalog. It is currently in **v2.5 Production-Ready** status (November 19, 2025).

**Running App**: http://localhost:3001 (Next.js 15.5.6)
**Target Database**: Supabase PostgreSQL (14,889+ products)

## Key Information

### Project Purpose
The primary purpose is to provide a robust, high-performance, and configurable product search system. It translates ETIM technical classifications into human-friendly categories, supporting advanced filtering and dynamic facets for an optimal user experience.

### Technology Stack
*   **Frontend:** Next.js 15.5.6 (React) application (`search-test-app/`). Utilizes Radix UI and Tailwind CSS for a modern, accessible UI.
*   **Backend/Database:** Supabase PostgreSQL. The system is designed to be non-invasive, creating a new `search` schema that reads from existing `items` schema views.
*   **Tooling:** NPM for package management.

### Key Features
*   **Three-tier search architecture:** Guided finder, Smart text search, and Technical filters.
*   **Delta Light-style filters:** 18 implemented filters.
*   **Dynamic facets:** Context-aware filter counts.
*   **Hierarchical taxonomy navigation:** ETIM-based classification mapped to user-friendly categories.
*   **Hybrid Classification:** Uses both ETIM-based rules for structural categories and text pattern-based rules for functional characteristics (e.g., indoor/outdoor).
*   **Materialized Views:** Used extensively for performance optimization, ensuring sub-200ms query times.

### My Role (Gemini AI Agent)
My role in this project is to act as a **reviewer, analyst, and tester**. I will collaborate with the "Claude Code" agent, whose instructions are detailed in `CLAUDE.md`.

### Project Structure (Key Directories)
*   `search-test-app/`: The Next.js frontend application.
    *   `app/`: Application pages.
    *   `components/`: Reusable React components (e.g., `FilterPanel`, `FacetedCategoryNavigation`).
    *   `lib/`: Supabase client and utility functions.
*   `sql/`: Contains all SQL migration scripts for the Supabase PostgreSQL database. These are numbered and designed to be executed in order.
*   `docs/`: Comprehensive project documentation, including architecture, implementation guides, and reference material.
    *   `docs/guides/gemini-instructions.md` (this file): Specific instructions and context for the Gemini agent.

### Getting Started & Critical Notes

1.  **Start the Frontend App**:
    ```bash
    cd search-test-app && npm run dev
    ```
    The application will run on `http://localhost:3001`.

2.  **SQL Execution Order (Critical)**: The SQL files in `sql/` must be executed in numerical order. Refer to `sql/README.md` for precise instructions.

3.  **ETIM Feature IDs (CRITICAL)**: Before running SQL files that populate example data or define filters (e.g., `02-populate-example-data.sql`, `02-populate-filter-definitions.sql`, `03-populate-classification-rules.sql`), you **MUST UPDATE PLACEHOLDER ETIM FEATURE IDs** to match the actual IDs in the target Supabase PostgreSQL database. Examples for finding these IDs are in `CLAUDE.md`.

4.  **Verification**: After SQL execution, verify the installation and functionality using the provided verification scripts (e.g., in `QUICKSTART.md`).

5.  **Materialized View Refresh**: Remember that materialized views (`search.product_taxonomy_flags`, `search.product_filter_index`, `search.filter_facets`) need to be refreshed after any data imports or configuration changes to reflect updates.

---

This document will be updated as new insights or changes occur.