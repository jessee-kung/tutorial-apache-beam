data "google_client_config" "default" {
  provider = google
}

data "google_project" "default" {
  provider = google
}

data "google_service_account" "default" {
  depends_on = [
    data.google_project.default
  ]
  account_id = format("%d-compute@developer.gserviceaccount.com", data.google_project.default.number)
}

data "google_storage_bucket" "deployment" {
  name = var.cloud_storage.deployment_bucket
}