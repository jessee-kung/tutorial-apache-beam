resource "google_bigquery_dataset" "beam_tutorial" {
  dataset_id = "beam_tutorial"
  location   = data.google_client_config.default.region
}

resource "google_bigquery_table" "demo1" {
  depends_on = [
    google_bigquery_dataset.beam_tutorial
  ]

  deletion_protection = false

  dataset_id = google_bigquery_dataset.beam_tutorial.dataset_id
  table_id   = "demo1"
  schema     = file("${path.module}/resource/bigquery/demo1.json")

  time_partitioning {
    type          = "DAY"
    field         = "event_time"
    expiration_ms = 7 * 86400 * 1000
  }
}

resource "google_bigquery_table" "demo2" {
  depends_on = [
    google_bigquery_dataset.beam_tutorial
  ]

  deletion_protection = false

  dataset_id = google_bigquery_dataset.beam_tutorial.dataset_id
  table_id   = "demo2"
  schema     = file("${path.module}/resource/bigquery/demo2.json")

  time_partitioning {
    type          = "DAY"
    field         = "processing_time"
    expiration_ms = 7 * 86400 * 1000
  }
}
