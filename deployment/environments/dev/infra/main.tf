terraform {
  backend "local" {}
}

provider "google" {
  project = "" // your GCP Project ID
  region  = "" // your preferred region, e.g., us-west1
  zone    = "" // your preferred zone, e.g., us-west1-a
}

module "infra" {
  source = "../../../modules/infra"

  network = {
    network    = "" // your GCP network
    subnetwork = "" // your GCP subnetwork
  }


  cloud_storage = {
    deployment_bucket = "" // your GCS bucket for deploy dataflow template
  }

  pubsublite = {
    beam_tutorial = {
      reservation = {
        throughput_capacity = 1
      }

      topic = {
        partition_config = {
          count = 1
          capacity = {
            publish_mib_per_sec   = 4
            subscribe_mib_per_sec = 4
          }
        }

        retention_config = {
          per_partition_bytes = 30 * 1024 * 1024 * 1024
        }
      }
    }
  }
}

output "infra" {
  value = module.infra
}
