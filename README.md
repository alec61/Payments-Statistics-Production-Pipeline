# Payments-Statistics-Production-Pipeline
## Python | R | SQL Integration for Quarterly Statistical Production
---
## Overview
Complete statistical production framework for Payments Statistics team. Three complementary components:

- Python: Data ingestion, validation, aggregation
- SQL: Multi-dimensional analysis, quality gates, production readiness
- R: Time-series forecasting, statistical decomposition

Used for quarterly/semi-annual payments statistics production with rigorous quality assurance.

---
### 1. Prerequisites

```bash
# Python 3.9+
pip install pandas numpy scipy sqlalchemy pyarrow

# R 4.0+
R -e "install.packages(c('data.table', 'forecast'))"

# PostgreSQL 12+
psql --version
```

### 2. Execute Pipeline

```bash
# Step 1: Python - Validate and aggregate
python3 << 'EOF'
from payments_processor import PaymentsStatisticsProcessor
processor = PaymentsStatisticsProcessor('payment_transaction_data.parquet')
quality = processor.assess_data_quality()
print("Quality:", quality)
processor.export_statistical_output('payment_statistics.csv')
EOF

# Step 2: SQL - Multi-dimensional aggregation & quality validation
psql payments_db -f payments_statistical_production_gate.sql

# Step 3: R - Time-series analysis & forecasting
Rscript payments_analysis.R
```
---
## Component Details

### **Python: Transaction Validation & Aggregation**

**File**: `payments_processor.py`

**What it does**:
- Reads parquet transaction data
- Validates: nulls, negatives, duplicates, missing currency codes, invalid settlement times
- Aggregates by date/payment_method/currency
- Calculates: sum, mean, std, median, percentiles, settlement metrics
- Detects anomalies (Z-score > 3)
- Exports staging CSV for SQL layer

**Key methods**:
```python
assess_data_quality()          # Quality gate 1
aggregate_payment_statistics() # Multi-dimensional aggregates
detect_payment_anomalies()     # Outlier detection (scipy)
calculate_settlement_indicators() # Settlement SLA metrics
export_statistical_output()    # Output for R/SQL
```

**Output**: `payment_statistics.csv`

---

### SQL: Production Quality Gates & Dimensional Analysis

**File**: `payments_statistical_production_gate.sql`

**What it does**:
- Loads Python aggregates
- Creates multi-dimensional analytics (country × method × currency × cross_border)
- Calculates statistical quality indicators:
  - Coefficient of variation (volatility)
  - Data completeness % (coverage validation)
  - Variance from 12-month average (trend detection)
  - Cross-border integration metrics
- Assigns production quality status:
  - `PRODUCTION_READY` (completeness ≥95%, variation ≤0.5)
  - `REVIEW_REQUIRED` (completeness ≥85%, variation ≤0.7)
  - `DATA_QUALITY_CONCERN` (below thresholds)

**Key metrics**:
- `reporting_completeness_pct` - Days reported vs. expected
- `coefficient_of_variation` - Relative variability
- `variance_from_12m_avg_pct` - Deviation from historical average
- `statistical_significance` - Anomaly classification

**Output**: Dashboard-ready quality assessment
---
### **R: Time-Series Analysis & Forecasting**

**File**: `payments_analysis.R`

**What it does**:
- Loads Python's CSV output
- Aggregates daily payment volumes by payment method
- Computes time-series components:
  - 30-day moving average (trend)
  - Year-over-year growth % (seasonality)
  - 90-day rolling volatility (risk)
- Detects anomalies (Z-score > 2.5 by payment method)
- Quality validation: null volumes, zero transactions, extreme settlements
- Produces statistical quality report

**Key outputs**:
- `daily_stats`: Volume, trend, growth, volatility by date/method
- `quality_flags`: Null counts, zero transactions, P95 settlement breaches

**Output**: 
- `payment_statistics_output.csv`
- `payment_data_quality_report.csv`
---
## Data Flow

```
Payment Transactions (Parquet)
    ↓
Python: Validate + Aggregate
    ↓ (payment_statistics.csv)
SQL: Multi-dimensional Analysis + Quality Gates
    ↓ (production_quality_status)
R: Time-Series Forecasting + Quality Checks
    ↓
Quarterly Production Output
```
---

## Quality Assurance

### 3-Layer Validation

1. **Python Layer** (Application-level)
   - Nulls, negatives, duplicates
   - Transaction-level anomalies (Z-score > 3)
   - Pre-database screening

2. **SQL Layer** (Database-level)
   - Data completeness (days reported %)
   - Coefficient of variation (volatility bounds)
   - Variance from historical baseline
   - Production readiness gates

3. **R Layer** (Statistical-level)
   - Distribution validation
   - Seasonal pattern detection
   - Forecast accuracy (MAPE)

**Production gate**: Data must be PRODUCTION_READY before quarterly dissemination

---

## Output Examples

### **Python Quality Report**
```python
{
    'missing_amounts': 0,
    'negative_amounts': 0,
    'duplicate_transactions': 12,
    'missing_currency_codes': 0
}
```

### **SQL Production Status**
```
reporting_month | payment_method | ncb_country | status
2026-06-30      | SEPA_Credit    | DE          | PRODUCTION_READY
2026-06-30      | Card_Scheme    | IT          | REVIEW_REQUIRED
2026-06-30      | Wire_Transfer  | FR          | DATA_QUALITY_CONCERN
```

### **R Time-Series Output**
```
payment_date | payment_method | daily_volume | ma_30day | yoy_growth | volatility
2026-06-30   | SEPA_Credit    | 450,000,000  | 445M     | +8.2%      | 0.125
2026-06-29   | SEPA_Credit    | 440,000,000  | 444M     | +8.1%      | 0.124
```

---

## File Structure

```
payments-statistics/
├── payments_processor.py                      # Python: ETL & validation
├── payments_analysis.R                        # R: Time-series analysis
├── payments_statistical_production_gate.sql   # SQL: Quality gates
├── README.md                                  # This file

```
