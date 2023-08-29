locals {
  output_google_bigquery_table_meta = [
    google_bigquery_table.demo1,
    google_bigquery_table.demo2,
  ]

  output_google_pubsublite_meta = {
    beam_tutorial = {
      reservation_id  = google_pubsub_lite_reservation.beam_tutorial.id
      topic_id        = google_pubsub_lite_topic.beam_tutorial.id
      subscription_id = google_pubsub_lite_subscription.beam_tutorial.id
    }
  }
}

output "google_project" {
  value = {
    number     = data.google_project.default.number
    project_id = data.google_project.default.project_id
    region     = data.google_client_config.default.region
    zone       = data.google_client_config.default.zone
  }
}

output "google_network" {
  value = {
    network    = var.network.network
    subnetwork = var.network.subnetwork
  }
}

output "google_bigquery" {
  value = {
    dataset_id = google_bigquery_dataset.beam_tutorial.dataset_id
    tables = {
      for table in local.output_google_bigquery_table_meta :
      table.table_id => ({
        table_id = format("%s:%s.%s", table.project, table.dataset_id, table.table_id)
      })
    }
  }
}

output "google_pubsublite" {
  value = local.output_google_pubsublite_meta
}

output "google_service_account" {
  value = data.google_service_account.default.email
}

output "google_storage_bucket" {
  value = {
    deployment_bucket = data.google_storage_bucket.deployment.name
  }
}
