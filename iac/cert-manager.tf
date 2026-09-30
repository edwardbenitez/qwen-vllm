resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.15.3"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Uses kubectl_manifest (not kubernetes_manifest) to avoid a plan-time CRD chicken-and-egg dependency.
resource "kubectl_manifest" "letsencrypt_issuer" {
  count = var.enable_tls ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "azure/application-gateway"
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]

  lifecycle {
    precondition {
      condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.letsencrypt_email)) && !endswith(lower(var.letsencrypt_email), "example.com")
      error_message = "Set a valid, non-example.com email in letsencrypt_email before enabling TLS."
    }
  }
}
