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