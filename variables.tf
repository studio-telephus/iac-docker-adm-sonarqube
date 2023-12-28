variable "sonar_owner_password" {
  type      = string
  sensitive = true
}

variable "sonar_user_password" {
  type      = string
  sensitive = true
}

variable "sonar_postgres_password" {
  type      = string
  sensitive = true
}

variable "platformrsa_keystore_storepass" {
  type      = string
  sensitive = true
}
