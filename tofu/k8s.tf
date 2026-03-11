resource "terraform_data" "k3d_cluster" {
  input = {
    name  = var.k3d_cluster_name
    image = "rancher/k3s:${var.k3s_version}"
  }

  provisioner "local-exec" {
    command = "k3d cluster create ${self.input.name} --image ${self.input.image} --servers 1 --agents 0 -p '8080:80@loadbalancer'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.input.name}"
  }
}


resource "terraform_data" "k3d_ready" {
  depends_on = [terraform_data.k3d_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      timeout 60 sh -c 'until kubectl cluster-info --context k3d-${var.k3d_cluster_name}; do echo "Waiting for k3d cluster..."; sleep 2; done' || {
        echo "Failed: k3d cluster not ready after 60 seconds"
        exit 1
      }
      echo "k3d cluster is ready!"
    EOT
  }
}
