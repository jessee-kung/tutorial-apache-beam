resource "google_pubsub_lite_reservation" "beam_tutorial" {
  name                = "beam_tutorial"
  project             = data.google_project.default.project_id
  throughput_capacity = var.pubsublite.beam_tutorial.reservation.throughput_capacity
  region              = data.google_client_config.default.region
}

resource "google_pubsub_lite_topic" "beam_tutorial" {
  depends_on = [
    google_pubsub_lite_reservation.beam_tutorial
  ]

  name    = "beam_tutorial"
  project = data.google_project.default.project_id
  region  = data.google_client_config.default.region
  zone    = data.google_client_config.default.zone

  reservation_config {
    throughput_reservation = google_pubsub_lite_reservation.beam_tutorial.name
  }

  partition_config {
    count = var.pubsublite.beam_tutorial.topic.partition_config.count
    capacity {
      publish_mib_per_sec   = var.pubsublite.beam_tutorial.topic.partition_config.capacity.publish_mib_per_sec
      subscribe_mib_per_sec = var.pubsublite.beam_tutorial.topic.partition_config.capacity.subscribe_mib_per_sec
    }
  }

  retention_config {
    per_partition_bytes = var.pubsublite.beam_tutorial.topic.retention_config.per_partition_bytes
  }
}

resource "google_pubsub_lite_subscription" "beam_tutorial" {
  depends_on = [
    google_pubsub_lite_topic.beam_tutorial
  ]

  topic = google_pubsub_lite_topic.beam_tutorial.name
  name  = "beam_tutorial"

  region = data.google_client_config.default.region
  zone   = data.google_client_config.default.zone

  delivery_config {
    delivery_requirement = "DELIVER_IMMEDIATELY"
  }
}
