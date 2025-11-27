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
    display_name = "Error rate > ${var.error_rate_threshold * 100}% for 5 minutes"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.namespace_name=\"api\"",
        "metric.type=\"prometheus.googleapis.com/http_server_requests_seconds_count/counter\"",
        "metric.labels.status=monitoring.regex.full_match(\"5.*\")"
      ])

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold
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
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.namespace_name=\"api\"",
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
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.container_name=\"gateway\"",
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
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "resource.labels.container_name=\"session-service\"",
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
# Alert 6: Cost Calculation Errors (Business Critical)
# =============================================================================
resource "google_monitoring_alert_policy" "cost_calculation_errors" {
  count        = var.enable_alerts && var.enable_prometheus_alerts ? 1 : 0
  project      = var.project_id
  display_name = "Cost Calculation Errors - Data Integrity"
  combiner     = "OR"

  conditions {
    display_name = "Any cost calculation error"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"k8s_container\"",
        "metric.type=\"prometheus.googleapis.com/ev_cost_calculation_errors_total/counter\""
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
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      ## Cost Calculation Error Alert

      **Severity**: Critical
      **Impact**: Users may see incorrect charging costs

      ### Immediate Actions:
      1. Check logs for stack traces
      2. Review recent sessions with errors
      3. Verify VAT calculation logic
      4. Check for edge cases (null values, division by zero)

      ### Data Validation:
      ```sql
      SELECT * FROM charging_sessions
      WHERE total_cost_with_vat IS NULL
         OR total_cost_with_vat < 0
      ORDER BY created_at DESC
      LIMIT 100;
      ```
    EOT
    mime_type = "text/markdown"
  }

  user_labels = {
    severity    = "critical"
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
