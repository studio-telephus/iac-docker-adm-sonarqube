module "container_adm_sonarqube" {
  source    = "github.com/studio-telephus/terraform-lxd-instance.git?ref=1.0.3"
  name      = "container-adm-sonarqube"
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
  exec_enabled = true
  exec         = "/mnt/install.sh"
  environment = {
    RANDOM_STRING         = "1d9f2318-1f2d-4864-90b3-463a37801fff"
    POSTGRES_PASSWORD     = var.sonar_postgres_password
    SONAR_OWNER_PASSWORD  = var.sonar_owner_password
    SONAR_USER_PASSWORD   = var.sonar_user_password
    SERVER_KEY_PASSPHRASE = var.platformrsa_key_passphrase
  }
}
