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

resource "terraform_data" "apps" {
  depends_on = [terraform_data.argocd, kubernetes_secret.postgrest_credentials]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ArgoCD to be ready..."
      timeout 300 sh -c 'until kubectl wait --for=condition=available --timeout=30s deployment/argocd-server -n argocd 2>/dev/null; do echo "Waiting for argocd-server..."; sleep 2; done' || {
        echo "Failed: ArgoCD not ready after 300 seconds"
        exit 1
      }
      echo "ArgoCD is ready, applying apps..."
      kubectl apply -f ${path.module}/../argocd/apps/apps.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ${path.module}/../argocd/apps/apps.yaml --ignore-not-found"
  }
}
