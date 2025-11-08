output "zone_ids" {
  description = "Cloudflare zone IDs for each domain"
  value       = { for k, v in data.cloudflare_zone.zones : k => v.id }
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    root = { for k, v in cloudflare_record.root : k => v.hostname }
    www  = { for k, v in cloudflare_record.www : k => v.hostname }
    api  = { for k, v in cloudflare_record.api : k => v.hostname }
  }
}

output "nameservers" {
  description = "Cloudflare nameservers for each domain"
  value       = { for k, v in data.cloudflare_zone.zones : k => v.name_servers }
}