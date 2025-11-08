output "notification_channel_id" {
  description = "Notification channel ID"
  value       = google_monitoring_notification_channel.email.id
}