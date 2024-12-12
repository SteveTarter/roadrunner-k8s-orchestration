resource "kubernetes_deployment" "roadrunner_view_deployment" {
  metadata {
    name      = "roadrunner-view"
    namespace = var.roadrunner_namespace
    labels = {
      app = "roadrunner-view"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "roadrunner-view"
      }
    }

    template {
      metadata {
        labels = {
          app = "roadrunner-view"
        }
      }

      spec {
        image_pull_secrets {
          name = "dockerhub-secret"
        }

        container {
          name  = "roadrunner-view"
          image = "tarterware/roadrunner-view:latest"
          image_pull_policy = "Always"

          port {
            container_port = 3000
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = "roadrunner-view-config"
            }
          }
        }
      }
    }
  }
}
