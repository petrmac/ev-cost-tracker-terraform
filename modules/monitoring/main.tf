# Create notification channel for alerts
resource "google_monitoring_notification_channel" "email" {
  display_name = "EV Tracker Alert Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_email
  }

  user_labels = {
    environment = terraform.workspace
  }
}

# =============================================================================
# HTTPS Uptime Checks - API endpoints
# Checks every 5 minutes from multiple regions, validates SSL certificate
# =============================================================================
resource "google_monitoring_uptime_check_config" "api_https" {
  for_each = var.enable_alerts ? toset(var.api_domains) : toset([])

  project      = var.project_id
  display_name = "HTTPS Uptime - ${each.value}"
  timeout      = "10s"
  period       = "300s" # 5 minutes

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value
    }
  }

  checker_type = "STATIC_IP_CHECKERS"
}

# Alert: API endpoint down (fires after 2 consecutive failures = 10 min)
resource "google_monitoring_alert_policy" "api_uptime" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "CRITICAL: API Endpoint Down"
  combiner     = "OR"
  severity     = "CRITICAL"

  dynamic "conditions" {
    for_each = var.api_domains
    content {
      display_name = "${conditions.value} is unreachable"

      condition_threshold {
        filter = join(" AND ", [
          "resource.type=\"uptime_url\"",
          "resource.labels.host=\"${conditions.value}\"",
          "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\"",
        ])
        comparison      = "COMPARISON_GT"
        threshold_value = 1
        duration        = "600s" # 10 minutes (2 check failures)

        aggregations {
          alignment_period     = "300s"
          per_series_aligner   = "ALIGN_NEXT_OLDER"
          cross_series_reducer = "REDUCE_COUNT_FALSE"
          group_by_fields      = ["resource.label.host"]
        }

        trigger {
          count = 1
        }
      }
    }
  }

  alert_strategy {
    auto_close = "1800s" # Auto-resolve after 30 minutes
  }

  notification_channels = [
    google_monitoring_notification_channel.email.name,
  ]

  documentation {
    content   = <<-EOT
## API Endpoint Unreachable

**Severity:** CRITICAL
**Impact:** Users cannot access the application

### Investigation Steps
1. Check certificate status:
   ```
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod get managedcertificates -n api
   ```
2. Check ingress:
   ```
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod describe ingress ev-tracker-ingress -n api
   ```
3. Check gateway pods:
   ```
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod get pods -n api
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod logs -n api deployment/gateway --tail=50
   ```

### Common Causes
- SSL certificate expired or provisioning failed
- Gateway pods crashed or not ready
- GKE ingress misconfiguration
- DNS resolution failure
    EOT
    mime_type = "text/markdown"
  }
}

# Alert: SSL certificate expiring soon (14 days before expiry)
resource "google_monitoring_alert_policy" "ssl_cert_expiry" {
  count        = var.enable_alerts ? 1 : 0
  project      = var.project_id
  display_name = "WARNING: SSL Certificate Expiring Soon"
  combiner     = "OR"
  severity     = "WARNING"

  dynamic "conditions" {
    for_each = var.api_domains
    content {
      display_name = "SSL cert for ${conditions.value} expires within 14 days"

      condition_threshold {
        filter = join(" AND ", [
          "resource.type=\"uptime_url\"",
          "resource.labels.host=\"${conditions.value}\"",
          "metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\"",
        ])
        comparison      = "COMPARISON_LT"
        threshold_value = 14 # days
        duration        = "600s"

        aggregations {
          alignment_period     = "1200s"
          per_series_aligner   = "ALIGN_MEAN"
          cross_series_reducer = "REDUCE_MIN"
          group_by_fields      = ["resource.label.host"]
        }

        trigger {
          count = 1
        }
      }
    }
  }

  alert_strategy {
    auto_close = "86400s" # Auto-resolve after 24 hours
  }

  notification_channels = [
    google_monitoring_notification_channel.email.name,
  ]

  documentation {
    content   = <<-EOT
## SSL Certificate Expiring Soon

**Severity:** WARNING
**Impact:** If not renewed, users will see browser security warnings and API calls will fail

### Investigation Steps
1. Check ManagedCertificate status:
   ```
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod describe managedcertificate ev-tracker-api-certificate -n api
   ```
2. If status is `ProvisioningFailedPermanently`, delete and let Flux recreate:
   ```
   kubectl --context gke_ev-cost-tracker_europe-west1_ev-tracker-gke-prod delete managedcertificate ev-tracker-api-certificate -n api
   ```
3. Verify DNS points to GKE static IP:
   ```
   dig +short api.evtracker.cz A
   dig +short api.evtracker.online A
   dig +short api.evtracker.cloud A
   ```

### Common Causes
- Google Managed Certificate auto-renewal failed (FailedNotVisible)
- DNS records changed or Cloudflare proxy enabled (blocks HTTP validation)
- Ingress misconfiguration preventing ACME challenge
    EOT
    mime_type = "text/markdown"
  }
}

# Budget alert
resource "google_billing_budget" "monthly" {
  count = var.billing_account != "" ? 1 : 0

  billing_account = var.billing_account
  display_name    = "EV Tracker Monthly Budget - ${terraform.workspace}"

  budget_filter {
    projects               = ["projects/${var.project_id}"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.2
    spend_basis      = "FORECASTED_SPEND"
  }
}