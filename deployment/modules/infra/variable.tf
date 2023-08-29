variable "network" {
  type = object({
    network    = string
    subnetwork = string
  })
}

variable "cloud_storage" {
  type = object({
    deployment_bucket = string
  })
}

variable "pubsublite" {
  type = map(object({
    reservation = object({
      throughput_capacity = number
    })

    topic = object({
      partition_config = object({
        count = number
        capacity = object({
          publish_mib_per_sec   = number
          subscribe_mib_per_sec = number
        })
      })

      retention_config = object({
        per_partition_bytes = number
      })
    })
  }))
}
