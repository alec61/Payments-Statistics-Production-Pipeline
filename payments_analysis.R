# R: Payments Statistics Analysis
# Payments statistics production and market infrastructure monitoring
library(data.table)
library(forecast)
# Load payment flows data
payments_flows <- fread("payment_statistics.csv")

# Aggregate daily payment volumes and settlement metrics
daily_stats <- payments_flows[, .(
  daily_volume = sum(transaction_amount),
  settlement_value = sum(settlement_amount),
  transaction_count = .N,
  avg_settlement_time = mean(settlement_time),
  cross_border_volume = sum(cross_border_amount)
), by = .(payment_date, payment_method)]

# Time series analysis on payment trends
daily_stats[, `:=`(
  ma_30day = frollmean(daily_volume, 30),
  yoy_growth = (daily_volume / shift(daily_volume, 365) - 1) * 100,
  volatility = frollapply(daily_volume, 90, sd)
), by = payment_method]

# Detect anomalies in payment flows
daily_stats[, z_score := scale(daily_volume), by = payment_method]
daily_stats[, anomaly := abs(z_score) > 2.5]

# Quality checks for payment data
quality_flags <- daily_stats[, .(
  null_volumes = sum(is.na(daily_volume)),
  zero_transactions = sum(transaction_count == 0),
  extreme_settlement = sum(avg_settlement_time > quantile(avg_settlement_time, 0.95, na.rm = TRUE))
), by = payment_method]

# Export for statistical outputs
fwrite(daily_stats, "payment_statistics_output.csv")
fwrite(quality_flags, "payment_data_quality_report.csv")
```
## Dependencies
```
data.table
forecast
```
## Usage
```bash
Rscript payments_analysis.R
```
## Outputs

- `payment_statistics_output.csv` - Daily statistics with moving averages, growth rates, volatility
- `payment_data_quality_report.csv` - Quality flags by payment method
