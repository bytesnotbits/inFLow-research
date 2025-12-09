# inFlow Inventory Data Analysis Tool - Product Definition

## Project Overview
A Flutter web application for importing, parsing, and analyzing historical inventory transaction data exported from inFlow Inventory (XLSX/CSV formats) after migration to a new inventory system. The tool provides researchers and analysts with easy access to legacy data for historical analysis and transaction research.

---

## 1. Core Requirements

### 1.1 File Import Capabilities
- **Supported Formats:**
  - XLSX (Excel spreadsheet files)
  - CSV (comma-separated values)
  - Support multiple files in a single session
  - Batch import capability (import 5-50+ files at once)
  - Ability to import and parse all the exported files from inFlow (3 folders, 317 files, 398mb)

- **File Handling:**
  - Drag-and-drop file upload interface
  - Traditional file picker (browse and select)
  - File size validation (the max file size in the database is just over 32mb 'inFlow_SalesOrder.csv')
  - Progress indication during upload
  - Clear error messages for invalid/corrupted files

### 1.2 Data Parsing & Detection
- **Automatic Detection:**
  - Detect file structure and headers automatically
  - Identify data types in columns (dates, numbers, text, currency)
  - Handle varying date formats (MM/DD/YYYY, DD/MM/YYYY, ISO 8601, 5/11/2020 1:29:41 PM -05:00, etc.)
  - Currency detection and normalization (we are not worried about transaction costs)

- **Flexible Parsing:**
  - Manual header row specification (if auto-detection fails)
  - Skip/ignore header rows parameter
  - Handle non-standard layouts
  - Deal with empty rows/columns
  - Support for special characters in data

### 1.3 Data Transformation & Cleaning
- **Standardization:**
  - Date normalization to ISO 8601 format
  - Currency standardization (preserve original, store normalized)
  - Trim whitespace from text fields
  - Consistent case handling (optional)

- **Data Enhancement:**
  - Add import metadata (source filename, import date/time)
  - Add row sequence numbers for tracking
  - Generate unique record IDs if not present
  - Add data validation flags

---

## 2. Data Model & Storage

### 2.1 In-Memory Storage
- **Session Data:**
  - Store parsed data in memory during session
  - Support concurrent datasets from multiple files
  - Efficient data structures for querying

- **Data Structure:**
  - Each imported file maintains its metadata
  - Column mappings and transformations tracked
  - Original vs. normalized data preserved
  - Row-level validation status

### 2.2 Persistence Options (Phase 2)
- **Local Storage:**
  - IndexedDB for offline capability
  - CSV export of analyzed data
  - JSON export of complete datasets with metadata
  - Bookmark/snapshot functionality for analysis sessions

---

## 3. User Interface Components

### 3.1 Main Navigation
- **Dashboard/Landing Page:**
  - Quick start section (drop zone for files)
  - Recent files list
  - Quick statistics overview
  - Documentation/help access

- **Navigation Tabs/Menu:**
  - Import/Upload section
  - Data Explorer
  - Analysis & Reporting
  - Settings/Configuration
  - Help & Documentation

### 3.2 Import Interface
- **Upload Zone:**
  - Large drag-and-drop area
  - File picker button
  - Show selected files before import
  - Clear/remove individual files option
  - "Start Analysis" button

- **Upload Progress:**
  - Progress bar per file
  - Overall progress
  - Cancel option
  - Estimated time remaining

### 3.3 Data Explorer Interface
- **File List View:**
  - List of imported datasets
  - Row counts, column counts, date ranges
  - File details (name, size, import date)
  - Quick action buttons (view, export, delete)

- **Data Preview Table:**
  - Sortable columns
  - Scrollable view (virtual scrolling for large datasets)
  - Row count display
  - Column type indicators
  - Filtering by column values
  - Search functionality

- **Column Inspector:**
  - Show all columns for a dataset
  - Data type for each column
  - Sample values (first 5 rows)
  - Null/empty count
  - Unique value count
  - Data range (min/max for numbers and dates)

### 3.4 Analysis & Reporting
- **Transaction Search:**
  - Multi-field search
  - Date range filtering
  - Transaction type filtering
  - Amount range filtering
  - Combine multiple filters
  - Here is a real-life example of a question that needed to be answered and which required referencing multiple files to do so:
    - We needed to know where reel number 2F1124 was dispersed to. We had to reference '5953DP INV_Product_TransactionHistory.csv' to see what sales order it was dispersed on. Then we had to reference 'inFlow_SalesOrder.csv' to find the sale order and see who the customer was and the date of the sales order.

- **Basic Analytics:**
  - Transaction count by type
  - Transaction volume by date (timeline chart)
  - Top items/SKUs by transaction count
  - Amount distribution statistics
  - Movement trends over time

- **Export Results:**
  - Export filtered/analyzed data as CSV
  - Export as JSON
  - Print-friendly views
  - Custom report generation

---

## 4. Feature Set - Phased Approach

### Phase 1: MVP (Critical for Launch)
- ✅ File upload (XLSX & CSV)
- ✅ Automatic file parsing and detection
- ✅ Basic data transformation (date/currency normalization)
- ✅ Data preview in table format
- ✅ Column inspection and data type detection
- ✅ Single dataset analysis at a time
- ✅ Basic search and filtering
- ✅ CSV export of analyzed data

### Phase 2: Enhanced Functionality (1-2 weeks post-launch)
- Multi-dataset comparison
- More sophisticated filtering (regex, complex queries)
- Basic charting/visualization
- Saved analysis sessions (browser storage)
- Advanced statistics (percentiles, distributions)
- Custom field mapping (for non-standard exports)

### Phase 3: Advanced Analytics (Later iterations)
- Inventory movement analysis
- Trend detection and forecasting
- Data quality scoring
- Duplicate detection
- Historical comparisons between periods
- Report scheduling/generation

---

## 5. Technical Considerations
  - inFlow did not have a way to track Cable Reel numbers. So we used the Sublocation field to track each individual reel number.

### 5.1 File Format Specifications
**Questions to Research:**
- What columns typically appear in inFlow inventory exports? Below is a tab-separated list. It is extensive but not comprehensive. This is just from 'inFlow_SalesOrder.csv'.
OrderNumber	InventoryStatus	PaymentStatus	Customer	ContactName	Phone	Email	BillingAddress1	BillingAddress2	BillingCity	BillingState	BillingCountry	BillingPostalCode	BillingAddressRemarks	ShipToCompanyName	ShippingAddress1	ShippingAddress2	ShippingCity	ShippingState	ShippingCountry	ShippingPostalCode	ShippingAddressRemarks	ShippingTrackingNumber	ShippingCarrier	CurrencyCode	ExchangeRate	NonCustomerCost	OrderDate	OrderRemarks	Freight	InvoicedDate	DueDate	DatePaid	AmountPaid	RequestedShipDate	PONumber	SalesRep	Location	PricingScheme	PaymentTerms	PaymentMethod	TaxingScheme	Tax1Rate	Tax2Rate	CalculateTax2OnTax1	Tax1Name	Tax2Name	Tax1OnShipping	Tax2OnShipping	SO #	ProductName	ProductSKU	ProductDescription	ProductQuantity	ProductQuantityUoM	ProductUnitPrice	ProductDiscount	ProductSubtotal	ProductSerials	SpecialTaxRate	NeedsConfirmation	ConfirmerTeamMember	AssignedToTeamMember	IsQuote	IsCancelled

- Are there standard transaction types (Purchase, Sales, Adjustment, etc.)? [yes]
- What's the maximum file size you typically export? [33mb]
- Do different export types (transactions, inventory, sales) have different schemas? [yes. the column headers are the key to understanding the data the file contains. I can breakdown each file schema if you need.]
- What date/currency formats does inFlow use? [5/11/2020 1:29:41 PM -05:00. We'd want to break this down to just a simple date and time (5/20/2020 and 13:29)]

### 5.2 Flutter Web Implementation
- Use `file_picker` package for file selection
- Use `excel` package for XLSX parsing
- Use `csv` package for CSV parsing
- State management: Provider or Riverpod
- Table visualization: Use DataTable or custom virtualized list
- Charts: FL Chart or similar
- Local storage: Hive or shared_preferences

### 5.3 Performance Considerations
- Virtual scrolling for large tables (>10k rows)
- Lazy loading of large datasets
- Debounced search/filtering
- Memory optimization for large files
- Responsive design for various screen sizes

### 5.4 Data Validation & Error Handling
- Graceful error messages for malformed files
- Validation rules per data type
- User feedback on data quality issues
- Recovery from partial import failures
- Logging and error reporting

---

## 6. User Workflows

### Workflow 1: Import & Quick Analysis
1. User lands on app
2. Drags one or more XLSX/CSV files into drop zone
3. App detects file types and shows preview of detected structure
4. User reviews detected headers and confirms parsing settings
5. App parses all files and shows statistics
6. User can immediately search/filter the data
7. User exports results as needed

### Workflow 2: Batch Import & Comparison
1. User imports multiple files from different time periods
2. App shows summary of all datasets (file count, total rows)
3. User switches between datasets or performs cross-dataset analysis
4. User filters by date range across all files
5. User exports consolidated or individual results

### Workflow 3: Historical Research
1. User imports historical dataset
2. Uses column inspector to understand data structure
3. Searches for specific transactions by multiple criteria
4. Filters results by date range
5. Exports filtered results for further analysis (Excel, etc.)

---

## 7. User Personas & Use Cases

### Persona 1: Inventory Manager
- **Need:** Quickly look up historical transactions for specific items
- **Task:** Find all sales of SKU "X" in Q3 2024
- **Success:** Can find and export data within 2 minutes

### Persona 2: Data Analyst
- **Need:** Analyze trends and patterns in historical data
- **Task:** Identify top-moving items and compare periods
- **Success:** Can create custom reports and export for analysis tools

### Persona 3: Accountant
- **Need:** Reconcile historical records with new system
- **Task:** Verify transaction counts and amounts match
- **Success:** Can compare datasets and identify discrepancies

---

## 8. Success Metrics (MVP)

- Users can import XLSX/CSV files without errors
- Data is parsed correctly 95% of the time (auto-detection)
- Users can filter and search across 50k+ row datasets with <2s response
- Export functionality works for all data types
- App remains responsive on standard laptops (Chrome, Firefox, Safari, Edge)
- Users can complete basic research task in <5 minutes

---

## 9. Known Questions & Decisions Needed

### Before Development:
1. **Sample Data:** Can you provide 2-3 sample export files from inFlow so we can understand the exact format?
2. **File Structure:** Are there multiple export types (Transactions, Inventory, Sales)? Do they have different schemas?
3. **Scale:** What's the largest single file you need to import? Typical number of files per session?
4. **Browser Support:** Which browsers need to be supported (Chrome, Firefox, Safari, Edge)? [primarily chrome]
5. **Offline Use:** Does the app need to work offline, or is internet required? [no]
6. **User Authentication:** Multiple users or single-user application? [single]
7. **Data Sensitivity:** Are the data files sensitive/confidential? Any privacy/security concerns? [not private, but should not be publically available. access to employees only]

---

## 10. Development Roadmap

### Pre-Development (This Week)
- [ ] Collect sample files from inFlow exports
- [ ] Document exact data schemas and formats
- [ ] Finalize UI/UX mockups
- [ ] Decide on Flutter Web framework (Riverpod vs Provider)
- [ ] Set up project structure

### Development Phase 1 (Week 1-2)
- [ ] Project setup and dependencies
- [ ] File upload and parsing logic
- [ ] Data model and storage
- [ ] Basic table UI with data preview
- [ ] Column inspector

### Development Phase 2 (Week 2-3)
- [ ] Search and filtering
- [ ] Basic analytics and statistics
- [ ] Export functionality
- [ ] Error handling and validation

### Development Phase 3 (Week 3-4)
- [ ] UI refinement and polish
- [ ] Performance optimization
- [ ] Testing and bug fixes
- [ ] Documentation and help content

---


## 11. Data Models & Relationships

### 11.1 Data Models

- **Product**
  - `sku` (String): Unique product code (matches ProductSKU/SKU/ProductName)
  - `name` (String): Product name/description
  - `category` (String)
  - `isActive` (Bool)
  - `defaultUnitPrice` (Decimal)
  - `vendor` (String)
  - `uom` (String)
  - ...other fields from ProductDetails

- **SalesOrderLine**
  - `orderNumber` (String)
  - `customer` (String)
  - `orderDate` (DateTime)
  - `productSku` (String)
  - `productName` (String)
  - `quantity` (Decimal)
  - `unitPrice` (Decimal)
  - `location` (String)
  - ...other fields from SalesOrder

- **PurchaseOrderLine**
  - `orderNumber` (String)
  - `vendor` (String)
  - `orderDate` (DateTime)
  - `productSku` (String)
  - `productName` (String)
  - `quantity` (Decimal)
  - `unitPrice` (Decimal)
  - `location` (String)
  - ...other fields from PurchaseOrder

- **InventoryTransaction**
  - `transactionType` (String)
  - `date` (DateTime)
  - `location` (String)
  - `sublocation` (String) // Dual-purpose: shelf or reel
  - `orderNumber` (String)
  - `quantity` (Decimal)
  - `qtyBefore` (Decimal)
  - `qtyAfter` (Decimal)

- **SublocationUsage (Derived/Helper)**
  - `sublocation` (String)
  - `usageType` (Enum: 'Shelf', 'Reel', 'Unknown')
  - `relatedProductSku` (String)
  - `notes` (String)

### 11.2 Relationships

- `productSku`/`sku`/`productName` are interchangeable join keys across all models.
- `orderNumber` links SalesOrderLine, PurchaseOrderLine, and InventoryTransaction.
- `sublocation` is context-dependent; for certain products/transactions, it’s a reel, otherwise a shelf.

---

## 12. UI/UX Flow for Dual-Purpose Sublocation & File Relationships

### 12.1 Import & Data Mapping
- Drag-and-drop or select files for import.
- Auto-detect file type and schema; allow user to confirm/override mappings.
- Show summary of imported files and detected columns.

### 12.2 Data Explorer
- Tabbed or sidebar navigation for:
  - Sales Orders
  - Purchase Orders
  - Inventory Transactions
  - Products
- Each tab shows a filterable, sortable table.
- Clicking a row shows details and related records (e.g., all transactions for a product).

### 12.3 Sublocation Insights
- In Inventory Transactions, display a “Sublocation Usage” column.
- Allow filtering by usage type (Shelf vs. Reel).
- Provide a toggle or filter to show only reel-tracked items (based on product type/category or transaction type).
- Tooltip or info icon explains dual-purpose nature of Sublocation.

### 12.4 Cross-File Search
- Global search bar: search by SKU, ProductName, OrderNumber, Sublocation.
- When searching for a reel number, show all related transactions and sales orders, with links to customer and product details.

### 12.5 Data Relationships Visualization
- When viewing a product or order, show related transactions, sales, and purchases in linked panels or tabs.
- For a given sublocation (reel), show its movement history and current status.

### 12.6 Export & Reporting
- Export filtered data as CSV/JSON.
- Print-friendly views for research and reporting.

---

## 13. File Format Template

### Expected XLSX Columns (Example - adjust based on actual inFlow exports)
```
Date | Transaction Type | SKU | Description | Quantity | Unit Price | Amount | Location | Notes
```

### Expected CSV Headers (Example)
```
date,transaction_type,sku,description,quantity,unit_price,amount,location,notes
```

---

## 14. Success Criteria Checklist

- [ ] Users can upload XLSX and CSV files
- [ ] Files are parsed automatically with >90% accuracy
- [ ] Data displays in sortable, filterable table
- [ ] Users can search across all columns
- [ ] Column inspector shows data types and statistics
- [ ] Results can be exported as CSV/JSON
- [ ] App handles files with 100k+ rows smoothly
- [ ] Responsive design works on desktop/tablet
- [ ] All error scenarios have user-friendly messages
- [ ] Documentation/help is clear and accessible
