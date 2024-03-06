locals {
  name              = "sonarqube"
  docker_image_name = "tel-${var.env}-${local.name}"
  container_name    = "container-${var.env}-${local.name}"
}

resource "docker_image" "sonarqube" {
  name         = local.docker_image_name
  keep_locally = false
  build {
    context = path.module
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

resource "docker_volume" "sonarqube_logs" {
  name = "volume-${var.env}-sonarqube-logs"
}

resource "docker_volume" "sonarqube_extensions" {
  name = "volume-${var.env}-sonarqube-extensions"
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
    "SONAR_WEB_CONTEXT=/sonarqube",
    "RANDOM_STRING=acb53b5e-6a57-4e81-a983-2cde076ce6d4"
  ]

  volumes {
    volume_name    = docker_volume.sonarqube_data.name
    container_path = "/opt/sonarqube/data"
  }

  volumes {
    volume_name    = docker_volume.sonarqube_logs.name
    container_path = "/opt/sonarqube/logs"
  }

  volumes {
    volume_name    = docker_volume.sonarqube_extensions.name
    container_path = "/opt/sonarqube/extensions"
  }
}
