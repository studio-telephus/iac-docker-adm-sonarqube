module "container_sonarqube" {
  source    = "github.com/studio-telephus/tel-iac-modules-lxd.git//instance?ref=develop"
  name      = "container-sonarqube"
  image     = "images:debian/bookworm"
  profiles  = ["limits", "fs-dir", "nw-adm"]
  autostart = true
  nic = {
    name = "eth0"
    properties = {
      nictype        = "bridged"
      parent         = "adm-network"
      "ipv4.address" = "10.0.10.125"
    }
  }
  mount_dirs = [
    "${path.cwd}/filesystem-shared-ca-certificates",
    "${path.cwd}/filesystem",
  ]
  exec = {
    enabled    = true
    entrypoint = "/mnt/install.sh"
    environment = {
      RANDOM_STRING       = "1d9f2318-1f2d-4864-90b3-463a37801fff"
      SONAR_JDBC_PASSWORD = var.sonar_jdbc_password
    }
  }
}
