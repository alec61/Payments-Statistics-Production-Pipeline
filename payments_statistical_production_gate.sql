-- SQL: PAYMENTS STATISTICS PRODUCTION QUALITY & DIMENSIONAL AGGREGATION
-- Statistical layer: Multi-dimensional aggregates, variance reconciliation, accuracy metrics
-- Supports quarterly production with statistical rigor and data completeness validation
WITH transaction_universe AS (
    SELECT 
        payment_date,
        DATE_TRUNC('month', payment_date)::DATE as reporting_month,
        payment_method,
        currency,
        ncb_country_code,
        transaction_amount,
        settlement_time,
        is_cross_border,
        data_source,
        COUNT(*) as transaction_count,
        SUM(transaction_amount) as aggregate_value
    FROM raw_payment_transactions
    WHERE payment_date >= DATE_TRUNC('quarter', CURRENT_DATE - INTERVAL '12 months')
    GROUP BY payment_date, reporting_month, payment_method, currency, ncb_country_code, 
             is_cross_border, data_source
),

dimensional_aggregates AS (
    SELECT 
        reporting_month,
        payment_method,
        currency,
        ncb_country_code,
        is_cross_border,
        COUNT(DISTINCT payment_date) as reporting_days,
        SUM(transaction_count) as total_transactions,
        SUM(aggregate_value) as total_value_eur,
        ROUND(AVG(aggregate_value), 2) as mean_transaction_size,
        ROUND(STDDEV_POP(aggregate_value), 2) as stddev_transaction_size,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY aggregate_value), 2) as median_value,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY aggregate_value), 2) as p95_value,
        ROUND(SUM(settlement_time) / NULLIF(SUM(transaction_count), 0), 2) as mean_settlement_hours,
        ROUND(STDDEV_POP(settlement_time), 2) as settlement_time_stddev,
        COUNT(*) as dimension_records
    FROM transaction_universe
    GROUP BY reporting_month, payment_method, currency, ncb_country_code, is_cross_border
),

aggregate_reconciliation AS (
    SELECT 
        da.reporting_month,
        da.payment_method,
        da.currency,
        da.ncb_country_code,
        da.is_cross_border,
        da.total_value_eur,
        da.total_transactions,
        -- Variance analysis: compare current month to 12-month average
        LAG(da.total_value_eur) OVER (
            PARTITION BY da.payment_method, da.currency, da.ncb_country_code, da.is_cross_border
            ORDER BY da.reporting_month
        ) as prev_month_value,
        ROUND(
            100.0 * (da.total_value_eur - AVG(da.total_value_eur) OVER (
                PARTITION BY da.payment_method, da.currency, da.ncb_country_code, da.is_cross_border
                ORDER BY da.reporting_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
            )) / NULLIF(AVG(da.total_value_eur) OVER (
                PARTITION BY da.payment_method, da.currency, da.ncb_country_code, da.is_cross_border
                ORDER BY da.reporting_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
            ), 0),
            2
        ) as variance_from_12m_avg_pct,
        da.mean_settlement_hours,
        da.p95_value,
        CASE 
            WHEN da.dimension_records < 20 THEN 'LOW_COVERAGE'
            WHEN da.dimension_records < 50 THEN 'PARTIAL_COVERAGE'
            ELSE 'FULL_COVERAGE'
        END as data_coverage_status
    FROM dimensional_aggregates da
),

statistical_quality_indicators AS (
    SELECT 
        ar.reporting_month,
        ar.payment_method,
        ar.ncb_country_code,
        SUM(ar.total_value_eur) as country_method_total,
        COUNT(DISTINCT ar.currency) as currency_diversity,
        COUNT(DISTINCT ar.is_cross_border) as flow_type_diversity,
        ROUND(
            100.0 * SUM(CASE WHEN ar.is_cross_border THEN ar.total_value_eur ELSE 0 END) 
            / NULLIF(SUM(ar.total_value_eur), 0),
            2
        ) as cross_border_share_pct,
        -- Coefficient of variation (relative variability)
        ROUND(
            STDDEV_POP(ar.total_value_eur) / NULLIF(AVG(ar.total_value_eur), 0),
            3
        ) as coefficient_of_variation,
        -- Data completeness: days reported vs expected
        ROUND(
            100.0 * AVG(ar.reporting_days) / 
            NULLIF((EXTRACT(DAY FROM (MAKE_DATE(
                EXTRACT(YEAR FROM ar.reporting_month)::INT, 
                EXTRACT(MONTH FROM ar.reporting_month)::INT + 1, 1) - INTERVAL '1 day'))::INT), 0),
            2
        ) as reporting_completeness_pct,
        COUNT(DISTINCT ar.data_coverage_status) as coverage_distribution,
        ROUND(AVG(ar.mean_settlement_hours), 2) as avg_settlement_all_currencies,
        -- Statistical significance flag
        CASE 
            WHEN ABS(ROUND(
                100.0 * (SUM(ar.total_value_eur) - AVG(SUM(ar.total_value_eur)) OVER (
                    PARTITION BY ar.payment_method, ar.ncb_country_code
                )) / NULLIF(AVG(SUM(ar.total_value_eur)) OVER (
                    PARTITION BY ar.payment_method, ar.ncb_country_code
                ), 0),
                2
            )) > 20 THEN 'SIGNIFICANT_VARIANCE'
            ELSE 'WITHIN_NORMAL_RANGE'
        END as statistical_significance
    FROM aggregate_reconciliation ar
    GROUP BY ar.reporting_month, ar.payment_method, ar.ncb_country_code
)

SELECT 
    reporting_month,
    payment_method,
    ncb_country_code,
    country_method_total,
    currency_diversity,
    flow_type_diversity,
    cross_border_share_pct,
    coefficient_of_variation,
    reporting_completeness_pct,
    avg_settlement_all_currencies,
    statistical_significance,
    CASE 
        WHEN reporting_completeness_pct >= 95 AND coefficient_of_variation <= 0.5 
            THEN 'PRODUCTION_READY'
        WHEN reporting_completeness_pct >= 85 AND coefficient_of_variation <= 0.7 
            THEN 'REVIEW_REQUIRED'
        ELSE 'DATA_QUALITY_CONCERN'
    END as production_quality_status
FROM statistical_quality_indicators
ORDER BY reporting_month DESC, statistical_significance DESC, ncb_country_code;
