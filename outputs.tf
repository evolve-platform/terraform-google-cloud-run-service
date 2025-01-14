

output "service_name" {
  value = google_cloud_run_v2_service.primary.name
}


output "service_url" {
  value = google_cloud_run_v2_service.primary.uri
}

output "name" {
  value = google_cloud_run_v2_service.primary.name
}


output "service_account" {
  value = var.service_account
}
