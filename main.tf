locals {
  name              = "sonarqube"
  docker_image_name = "tel-${var.env}-${local.name}"
  container_name    = "container-${var.env}-${local.name}"
  fqdn              = "sonarqube.docker.${var.env}.acme.corp"
  sonarqube_address    = "https://${local.fqdn}/sonarqube"
}

resource "docker_image" "sonarqube" {
  name         = local.docker_image_name
  keep_locally = false
  build {
    context = path.module
    build_args = {
      _SERVER_KEY_PASSPHRASE = module.bw_sonarqube_pk_passphrase.data.password
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      filesha1("${path.module}/Dockerfile")
    ]))
  }
}

resource "docker_volume" "nexus_data" {
  name = "volume-${var.env}-nexus-data"
}

resource "docker_container" "sonarqube" {
  name  = local.container_name
  image = docker_image.sonarqube.image_id
  restart  = "unless-stopped"
  hostname = local.container_name
  shm_size = 1024

  networks_advanced {
    name         = "${var.env}-docker"
    ipv4_address = "10.10.0.125"
  }

  env = [
    "RANDOM_STRING=1d9f2318-1f2d-4864-90b3-463a37801fff"
  ]

  volumes {
    volume_name    = docker_volume.nexus_data.name
    container_path = "/nexus-data"
    read_only      = false
  }
}
