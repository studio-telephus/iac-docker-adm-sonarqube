locals {
  name              = "sonarqube"
  docker_image_name = "tel-${var.env}-${local.name}"
  container_name    = "container-${var.env}-${local.name}"
  fqdn              = "sonarqube.docker.${var.env}.acme.corp"
  sonarqube_address = "https://${local.fqdn}/sonarqube"
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

resource "docker_volume" "sonarqube_data" {
  name = "volume-${var.env}-sonarqube-data"
}

resource "docker_container" "sonarqube" {
  name     = local.container_name
  image    = docker_image.sonarqube.image_id
  restart  = "unless-stopped"
  hostname = local.container_name
  shm_size = 1024

  networks_advanced {
    name         = "${var.env}-docker"
    ipv4_address = "10.10.0.125"
  }

  env = [
    "RANDOM_STRING=acb53b5e-6a57-4e81-a983-2cde076ce6d4"
  ]

  volumes {
    volume_name    = docker_volume.sonarqube_data.name
    container_path = "/sonarqube-data"
    read_only      = false
  }

  volumes {
    container_path = "/opt/sonarqube/data"
    volume_name = "sonar-data"
  }
  volumes {
    container_path = "/opt/sonarqube/extensions"
    volume_name = "sonar-extensions"
  }
}
