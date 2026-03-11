resource "terraform_data" "argocd" {
  depends_on = [terraform_data.k3d_ready]

  input = {
    context_name = "k3d-${var.k3d_cluster_name}"
  }

  provisioner "local-exec" {
    command = "kubectl create namespace argocd && kubectl apply --server-side -k ${path.module}/../argocd/argocd/"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete namespace argocd --ignore-not-found"
  }
}
