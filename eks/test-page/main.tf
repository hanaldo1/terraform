resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_pod" "echo" {
  metadata {
    name = "echo"
    namespace = kubernetes_namespace.test.metadata[0].name
    labels = {
      "app": "echo"
    }
  }

  spec {
    container {
      name = "echo"
      image = "hashicorp/http-echo"
      args = [ "-text=\"hello world\"" ]

      port {
        protocol = "TCP"
        container_port = 5678
      }
    }
  }
}

resource "kubernetes_service" "echo" {
  metadata {
    name = "echo"
    namespace = kubernetes_namespace.test.metadata[0].name
  }

  spec {
    selector = {
      "app": "echo"
    }

    type = "ClusterIP"
    port {
      protocol = "TCP"
      port = 5678
      target_port = 5678
    }
  }
}