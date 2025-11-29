# GCP Cloud Monitoring Alert Policies for EV Cost Tracker
# These alerts ensure rapid detection and response to service issues

# =============================================================================
# Alert 1: High Error Rate
# =============================================================================
resource "google_monitoring_alert_policy" "high_error_rate" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "High Error Rate - API"
  combiner     = "OR"

  conditions {
    display_name = "5xx errors > 5 per minute for 5 minutes"

    condition_threshold {
      # NOTE: Prometheus histogram metrics use /histogram suffix
      # ALIGN_COUNT counts the number of observations in the histogram
      filter = join(" AND ", [
        "resource.type=\"prometheus_target\"",
        "resource.labels.namespace=\"api\"",
        "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\"",
        "metric.labels.status=monitoring.regex.full_match(\"5.*\")"
      ])

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_COUNT"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## High Error Rate Alert

      **Severity**: Critical
      **SLO Target**: 99.9% availability

      ### Investigation Steps:
      1. Check Cloud Trace for failing requests
      2. Review logs: `resource.labels.namespace_name="api" AND severity>=ERROR`
      3. Check circuit breaker state in Service Health dashboard
      4. Verify database connectivity
      5. Check Redis health

      ### Quick Actions:
      ```bash
      # Check pod status
      kubectl get pods -n api

      # Check recent logs
      kubectl logs -n api -l app=gateway --tail=100
      kubectl logs -n api -l app=session-service --tail=100
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "critical"
    service     = "api"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 2: High Latency
# =============================================================================
resource "google_monitoring_alert_policy" "high_latency" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "High P95 Latency - API"
  combiner     = "OR"

  conditions {
    display_name = "P95 latency > ${var.latency_threshold_seconds}s for 5 minutes"

    condition_threshold {
      # NOTE: Prometheus metrics from PodMonitoring use resource.type="prometheus_target"
      filter = join(" AND ", [
        "resource.type=\"prometheus_target\"",
        "resource.labels.namespace=\"api\"",
        "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds/histogram\""
      ])

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_seconds
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## High Latency Alert

      **Severity**: Warning
      **SLO Target**: P95 < 500ms

      ### Investigation Steps:
      1. Check database slow queries
      2. Review Redis latency in dashboard
      3. Check GC pressure (JVM Memory)
      4. Review trace spans for slow operations

      ### Common Causes:
      - Unindexed database queries
      - Redis connection pool exhaustion
      - External API timeouts (Stripe, OAuth)
      - High GC activity
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "api"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 3: Circuit Breaker Open
# =============================================================================
resource "google_monitoring_alert_policy" "circuit_breaker_open" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Circuit Breaker Open - Session Service"
  combiner     = "OR"

  conditions {
    display_name = "Circuit breaker is open"

    condition_threshold {
      # NOTE: Prometheus metrics from PodMonitoring use resource.type="prometheus_target"
      filter = join(" AND ", [
        "resource.type=\"prometheus_target\"",
        "metric.labels.service=\"gateway\"",
        "metric.type=\"prometheus.googleapis.com/resilience4j_circuitbreaker_state/gauge\"",
        "metric.labels.state=\"open\""
      ])

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.5
      duration        = "60s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Circuit Breaker Open Alert

      **Severity**: Critical
      **Impact**: Session service unavailable, gateway returning fallback responses

      ### Immediate Actions:
      1. Check session-service pod health
      2. Review session-service logs
      3. Check database connectivity
      4. Verify Redis is accessible

      ### Expected Behavior:
      - Circuit will auto-recover after 10s (waitDurationInOpenState)
      - 3 test requests in half-open state
      - If 2/3 succeed, circuit closes

      ```bash
      kubectl get pods -n api -l app=session-service
      kubectl logs -n api -l app=session-service --tail=100
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "critical"
    service     = "gateway"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 4: Database Connection Pool Exhaustion
# =============================================================================
resource "google_monitoring_alert_policy" "db_pool_exhausted" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Database Connection Pool Near Exhaustion"
  combiner     = "OR"

  conditions {
    display_name = "Active DB connections >= 4 (max 5)"

    condition_threshold {
      # NOTE: Prometheus metrics from PodMonitoring use resource.type="prometheus_target"
      filter = join(" AND ", [
        "resource.type=\"prometheus_target\"",
        "metric.labels.service=\"session-service\"",
        "metric.type=\"prometheus.googleapis.com/hikaricp_connections_active/gauge\""
      ])

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 3
      duration        = "180s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Database Connection Pool Alert

      **Severity**: Warning
      **Config**: Max pool size = 5

      ### Investigation:
      1. Check for long-running transactions
      2. Review slow queries
      3. Check for connection leaks

      ### SQL Diagnostics:
      ```sql
      -- Active connections
      SELECT * FROM pg_stat_activity WHERE state = 'active';

      -- Long-running queries
      SELECT * FROM pg_stat_activity
      WHERE state = 'active'
      AND query_start < now() - interval '30 seconds';
      ```

      ### Actions:
      - Consider increasing pool size if traffic increased
      - Look for missing @Transactional annotations
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "session-service"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 5: Pod Restarts
# =============================================================================
resource "google_monitoring_alert_policy" "pod_restarts" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "High Pod Restart Rate"
  combiner     = "OR"

  conditions {
    display_name = "Pod restarts > ${var.pod_restart_threshold} in 1 hour"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.namespace_name=\"api\"",
        "metric.type=\"kubernetes.io/container/restart_count\""
      ])

      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.container_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.pod_restart_threshold
      duration        = "0s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      ## Pod Restart Alert

      **Severity**: Warning
      **Impact**: Service instability, potential data loss during restart

      ### Investigation:
      1. Check pod events for OOMKilled, CrashLoopBackOff
      2. Review container logs before restart
      3. Check memory usage trends
      4. Review recent deployments

      ```bash
      # Check pod events
      kubectl describe pod -n api -l app=<service>

      # Check previous container logs
      kubectl logs -n api -l app=<service> --previous
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "api"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 6: Cost Calculation Slow (Business Critical)
# =============================================================================
resource "google_monitoring_alert_policy" "cost_calculation_slow" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cost Calculation Slow - Performance"
  combiner     = "OR"

  conditions {
    display_name = "P95 cost calculation > 1s"

    condition_threshold {
      # Monitor cost calculation duration histogram
      filter = join(" AND ", [
        "resource.type=\"prometheus_target\"",
        "metric.type=\"prometheus.googleapis.com/ev_cost_cost_calculation_duration_seconds/histogram\""
      ])

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 1.0
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Cost Calculation Slow Alert

      **Severity**: Warning
      **Impact**: Users may experience slow session creation

      ### Investigation Steps:
      1. Check database query performance
      2. Review concurrent session creation rate
      3. Check for missing indexes
      4. Review VAT calculation complexity

      ### Quick Checks:
      ```bash
      # Check session-service logs for slow queries
      kubectl logs -n api -l app=session-service --tail=100 | grep -i slow
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "session-service"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 7: Memory Usage High
# =============================================================================
resource "google_monitoring_alert_policy" "high_memory" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "High Memory Usage"
  combiner     = "OR"

  conditions {
    display_name = "Memory usage > ${var.memory_threshold_bytes / 1000000}MB"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.namespace_name=\"api\"",
        "metric.type=\"kubernetes.io/container/memory/used_bytes\""
      ])

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.container_name"]
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.memory_threshold_bytes
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## High Memory Usage Alert

      **Severity**: Warning
      **Impact**: Pod may be OOMKilled

      ### Investigation:
      1. Check JVM heap usage
      2. Review for memory leaks
      3. Check for large cached data
      4. Review recent code changes

      ### Actions:
      - Consider increasing memory limits
      - Review heap dump if needed
      - Check GC logs
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "api"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 8: Cloud SQL Memory Usage High
# =============================================================================
resource "google_monitoring_alert_policy" "cloudsql_high_memory" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cloud SQL High Memory Usage"
  combiner     = "OR"

  conditions {
    display_name = "Memory usage > 85%"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloudsql_database\"",
        "metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
      ])

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High Memory Usage Alert

      **Severity**: Warning
      **Impact**: Database may become slow or unresponsive

      ### Investigation Steps:
      1. Check for memory-intensive queries
      2. Review connection count
      3. Check for missing indexes causing full table scans
      4. Review recent schema changes

      ### SQL Diagnostics:
      ```sql
      -- Check active queries
      SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
      FROM pg_stat_activity
      WHERE state != 'idle'
      ORDER BY duration DESC;

      -- Check table sizes
      SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
      FROM pg_catalog.pg_statio_user_tables
      ORDER BY pg_total_relation_size(relid) DESC;
      ```

      ### Actions:
      - Consider scaling up the Cloud SQL instance
      - Optimize memory-intensive queries
      - Add appropriate indexes
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "cloudsql"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 9: Cloud SQL CPU Usage High
# =============================================================================
resource "google_monitoring_alert_policy" "cloudsql_high_cpu" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cloud SQL High CPU Usage"
  combiner     = "OR"

  conditions {
    display_name = "CPU usage > 80% for 10 minutes"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloudsql_database\"",
        "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      ])

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "600s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High CPU Usage Alert

      **Severity**: Warning
      **Impact**: Query performance degradation

      ### Investigation Steps:
      1. Identify slow/expensive queries
      2. Check for missing indexes
      3. Review query execution plans
      4. Check for lock contention

      ### SQL Diagnostics:
      ```sql
      -- Find slow queries (requires pg_stat_statements extension)
      SELECT query, calls, total_exec_time, mean_exec_time, rows
      FROM pg_stat_statements
      ORDER BY total_exec_time DESC
      LIMIT 10;

      -- Check for sequential scans
      SELECT relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch
      FROM pg_stat_user_tables
      WHERE seq_scan > 0
      ORDER BY seq_tup_read DESC;
      ```

      ### Actions:
      - Add missing indexes
      - Optimize expensive queries
      - Consider scaling up CPU
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "cloudsql"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 10: Cloud SQL Connection Count High
# =============================================================================
resource "google_monitoring_alert_policy" "cloudsql_high_connections" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cloud SQL High Connection Count"
  combiner     = "OR"

  conditions {
    display_name = "Connections > 80% of max"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloudsql_database\"",
        "metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\""
      ])

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      # Default max_connections for small Cloud SQL is ~100
      # Alert when approaching limit
      comparison      = "COMPARISON_GT"
      threshold_value = 80
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High Connection Count Alert

      **Severity**: Warning
      **Impact**: New connections may be rejected

      ### Investigation Steps:
      1. Check for connection leaks in application
      2. Review connection pool settings
      3. Identify clients holding connections

      ### SQL Diagnostics:
      ```sql
      -- Check connections by state
      SELECT state, count(*)
      FROM pg_stat_activity
      GROUP BY state;

      -- Check connections by application
      SELECT application_name, count(*)
      FROM pg_stat_activity
      GROUP BY application_name;

      -- Check idle connections
      SELECT pid, usename, application_name, state, query_start
      FROM pg_stat_activity
      WHERE state = 'idle'
      ORDER BY query_start;
      ```

      ### Actions:
      - Review HikariCP pool size settings
      - Check for connection leaks
      - Consider increasing max_connections (requires restart)
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "cloudsql"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 11: Cloud SQL Deadlocks Detected
# =============================================================================
resource "google_monitoring_alert_policy" "cloudsql_deadlocks" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cloud SQL Deadlocks Detected"
  combiner     = "OR"

  conditions {
    display_name = "Any deadlock detected"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloudsql_database\"",
        "metric.type=\"cloudsql.googleapis.com/database/postgresql/deadlock_count\""
      ])

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL Deadlock Alert

      **Severity**: Critical
      **Impact**: Transactions are being rolled back due to deadlocks

      ### Investigation Steps:
      1. Check PostgreSQL logs for deadlock details
      2. Review transaction isolation levels
      3. Identify conflicting queries
      4. Review locking order in code

      ### SQL Diagnostics:
      ```sql
      -- Check for current locks
      SELECT blocked_locks.pid AS blocked_pid,
             blocked_activity.usename AS blocked_user,
             blocking_locks.pid AS blocking_pid,
             blocking_activity.usename AS blocking_user,
             blocked_activity.query AS blocked_query,
             blocking_activity.query AS blocking_query
      FROM pg_catalog.pg_locks blocked_locks
      JOIN pg_catalog.pg_stat_activity blocked_activity
        ON blocked_activity.pid = blocked_locks.pid
      JOIN pg_catalog.pg_locks blocking_locks
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.pid != blocked_locks.pid
      JOIN pg_catalog.pg_stat_activity blocking_activity
        ON blocking_activity.pid = blocking_locks.pid
      WHERE NOT blocked_locks.granted;
      ```

      ### Common Causes:
      - Concurrent updates to same rows in different order
      - Long-running transactions holding locks
      - Missing indexes causing table locks

      ### Actions:
      - Review transaction boundaries
      - Ensure consistent locking order
      - Consider shorter transactions
      - Add appropriate indexes
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "critical"
    service     = "cloudsql"
    environment = terraform.workspace
  }
}

# =============================================================================
# Alert 12: Cloud SQL Disk Usage High
# =============================================================================
resource "google_monitoring_alert_policy" "cloudsql_high_disk" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cloud SQL High Disk Usage"
  combiner     = "OR"

  conditions {
    display_name = "Disk usage > 80%"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloudsql_database\"",
        "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
      ])

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      duration        = "300s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High Disk Usage Alert

      **Severity**: Warning
      **Impact**: Database may run out of disk space

      ### Investigation Steps:
      1. Check table sizes
      2. Review WAL/transaction log size
      3. Check for bloated tables needing VACUUM
      4. Review data retention policies

      ### SQL Diagnostics:
      ```sql
      -- Check database size
      SELECT pg_size_pretty(pg_database_size(current_database()));

      -- Check table sizes
      SELECT schemaname, relname,
             pg_size_pretty(pg_total_relation_size(relid)) AS total_size
      FROM pg_catalog.pg_statio_user_tables
      ORDER BY pg_total_relation_size(relid) DESC
      LIMIT 20;

      -- Check for bloat (dead tuples)
      SELECT relname, n_dead_tup, n_live_tup,
             round(n_dead_tup * 100.0 / nullif(n_live_tup, 0), 2) AS dead_pct
      FROM pg_stat_user_tables
      WHERE n_dead_tup > 1000
      ORDER BY n_dead_tup DESC;
      ```

      ### Actions:
      - Run VACUUM ANALYZE on bloated tables
      - Archive or delete old data
      - Increase disk size in Cloud SQL
      - Enable automatic storage increase
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "warning"
    service     = "cloudsql"
    environment = terraform.workspace
  }
}
