provider "docker" {}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-${var.k3d_cluster_name}"
}
