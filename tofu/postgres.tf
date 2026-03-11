resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "postgres" {
  name  = "postgres-infra-takehome"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=app",
  ]

  ports {
    internal = 5432
    external = var.postgres_port
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  restart = "unless-stopped"
}

resource "docker_volume" "postgres_data" {
  name = "postgres-infra-takehome-data"
}

provider "postgresql" {
  host     = "localhost"
  port     = var.postgres_port
  username = "postgres"
  password = var.postgres_password
  sslmode  = "disable"
}

resource "terraform_data" "postgres_ready" {
  depends_on = [docker_container.postgres]

  provisioner "local-exec" {
    command = <<-EOT
      timeout 60 sh -c 'until pg_isready -h localhost -p ${var.postgres_port} -U postgres; do echo "Waiting for postgres..."; sleep 2; done' || {
        echo "Failed: Postgres not ready after 60 seconds"
        exit 1
      }
      echo "Postgres is ready!"
    EOT
  }
}

resource "postgresql_database" "postgrest" {
  name       = "postgrest"
  depends_on = [terraform_data.postgres_ready, terraform_data.k3d_ready]
}

# Generate random password for postgrest superuser
resource "random_password" "postgrest_superuser" {
  length  = 32
  special = false
}

# Create superuser role in postgrest database
resource "postgresql_role" "postgrest_superuser" {
  name       = "postgrest_superuser"
  password   = random_password.postgrest_superuser.result
  login      = true
  superuser  = true
  depends_on = [postgresql_database.postgrest, terraform_data.postgres_ready]
}

# Kubernetes namespace for postgrest
resource "kubernetes_namespace" "postgrest" {
  metadata {
    name = "postgrest"
  }

  depends_on = [terraform_data.k3d_ready]
}

# Kubernetes secret with postgrest credentials
resource "kubernetes_secret" "postgrest_credentials" {
  metadata {
    name      = "postgrest-credentials"
    namespace = kubernetes_namespace.postgrest.metadata[0].name
  }

  data = {
    username = "postgrest_superuser"
    password = random_password.postgrest_superuser.result
    database = "postgrest"
    host     = "host.docker.internal"
    port     = tostring(var.postgres_port)
  }

  depends_on = [postgresql_role.postgrest_superuser]
}

