resource "kubernetes_deployment" "vllm" {
  metadata {
    name = "vllm-qwen"
    labels = {
      app = "vllm-qwen"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = "vllm-qwen"
      }
    }

    template {
      metadata {
        labels = {
          app = "vllm-qwen"
        }
      }

      spec {
        node_selector = {
          "kubernetes.azure.com/mode" = "user"
        }

        volume {
          name = "dshm"

          empty_dir {
            medium     = "Memory"
            size_limit = "1Gi"
          }
        }

        container {
          name  = "vllm"
          image = "${var.dockerhub_username}/${var.image_name}:${var.image_tag}"

          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }

          port {
            container_port = var.container_port
          }

          env {
            name  = "VLLM_CPU_KVCACHE_SPACE"
            value = "2"
          }

          env {
            name  = "VLLM_CPU_OMP_THREADS_BIND"
            value = "auto"
          }

          resources {
            requests = {
              cpu    = "1"
              memory = "4Gi"
            }
            limits = {
              cpu    = "3"
              memory = "8Gi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.container_port
            }
            initial_delay_seconds = 60
            period_seconds        = 15
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.container_port
            }
            initial_delay_seconds = 90
            period_seconds        = 30
          }
        }
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster_node_pool.user]
}

resource "kubernetes_service" "vllm" {
  metadata {
    name = "vllm-qwen"
  }

  spec {
    type = "ClusterIP" # traffic enters via the Application Gateway Ingress instead of a public LB

    selector = {
      app = "vllm-qwen"
    }

    port {
      port        = 80
      target_port = var.container_port
    }
  }
}

resource "kubernetes_ingress_v1" "vllm" {
  metadata {
    name = "vllm-qwen"
    annotations = merge({
      "kubernetes.io/ingress.class"                   = "azure/application-gateway"
      "appgw.ingress.kubernetes.io/health-probe-path" = "/health"
      "appgw.ingress.kubernetes.io/request-timeout"   = "120"
      }, var.enable_tls ? {
      "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
      "appgw.ingress.kubernetes.io/ssl-redirect" = "true"
    } : {})
  }

  spec {
    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []

      content {
        hosts       = ["${var.appgw_dns_label}.${var.location}.cloudapp.azure.com"]
        secret_name = "vllm-qwen-tls"
      }
    }

    rule {
      host = "${var.appgw_dns_label}.${var.location}.cloudapp.azure.com"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.vllm.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubectl_manifest.letsencrypt_issuer]
}
