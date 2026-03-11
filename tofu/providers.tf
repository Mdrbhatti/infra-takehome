provider "docker" {}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}
