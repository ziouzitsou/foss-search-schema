# Search Test App 🔍

Simple Next.js test app to verify the Foss SA search functionality before integrating into the main app.

## 🚀 Quick Start

The app is **already running** at:
**http://localhost:3001**

Just open your browser and navigate to http://localhost:3001

## 📋 Features Tested

### Search Functions
- ✅ `search.search_products()` - Main search with filters
- ✅ `search.get_search_statistics()` - System stats

### Filters Available
1. **Text Search** - Search by product description
2. **Location** - Indoor/Outdoor checkboxes
3. **Power Range** - Min/Max wattage (e.g., 5-20W)
4. **IP Rating** - Multiple selection (IP20, IP44, IP54, IP65, IP67)

### Product Display
Each product card shows:
- Product ID (FOSS_PID)
- Description
- Supplier & Class
- Price (if available)
- Boolean flags (Indoor, Outdoor, Ceiling, Wall, etc.)
- Key features (Power, Color Temp, IP Rating)

## 🧪 Test Scenarios

### Test 1: Load System Stats
Click **"Load System Stats"** to see:
- Total products indexed
- Indoor/Outdoor counts
- Filter entries
- Taxonomy nodes

### Test 2: Simple Text Search
1. Type "LED" in search box
2. Click Search
3. Should return products with LED in description

### Test 3: Power Filter
1. Set Power Min: 5
2. Set Power Max: 20
3. Click Search
4. Should return products with power between 5-20W

### Test 4: Combined Filters
1. Check "Indoor"
2. Set Power: 10-50W
3. Select IP Rating: IP20
4. Click Search
5. Should return indoor products with specified power and IP20

### Test 5: Outdoor + IP67
1. Check "Outdoor"
2. Select IP Rating: IP67
3. Click Search
4. Should return outdoor products with IP67 rating

## 📁 Project Structure

```
search-test-app/
├── app/
│   ├── layout.tsx          # Root layout
│   └── page.tsx            # Main search page (client component)
├── lib/
│   └── supabase.ts         # Supabase client
├── .env.local              # Environment variables
├── package.json
├── tsconfig.json
└── next.config.js
```

## 🛠️ Development

### Start/Stop Server

```bash
# Start (already running)
npm run dev

# Stop (if needed)
# Press Ctrl+C in the terminal running npm run dev
```

### Configuration

Supabase credentials are in `.env.local`:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## 🐛 Troubleshooting

### Server Not Running?
```bash
cd /home/sysadmin/tools/searchdb/search-test-app
npm run dev
```

### Port 3001 Already in Use?
Edit `package.json` and change `-p 3001` to another port like `-p 3002`

### Search Returns Empty?
1. Click "Load System Stats" to verify database connection
2. Check that stats show products (total_products > 0)
3. Try removing all filters and searching again

## ✅ What's Working

Based on our testing:
- ✅ Numeric filters (Power: 0.5W - 300W, 271 products)
- ✅ Color Temperature (1800K - 4000K, 6 products)
- ✅ Luminous Flux (40lm - 41,015lm, 693 products)
- ✅ IP Rating (6,251 products with ratings)
- ✅ Boolean flags (Indoor: 12,257, Outdoor: 819)
- ✅ Taxonomy tree (14 nodes)
- ✅ Combined complex filters

## 📝 Notes

- This is a **minimal test app** - intentionally simple for testing
- Runs on port **3001** (fossapp uses 8080)
- Uses the same Supabase database as the main app
- All 4 SQL files have been deployed and tested
- Search materialized views are refreshed and working

## 🎯 Next Steps

Once you verify everything works:
1. Test all filter combinations
2. Check product data displays correctly
3. Verify performance with different searches
4. If all good → integrate into main fossapp

---

**App is running at**: http://localhost:3001
