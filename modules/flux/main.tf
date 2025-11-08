terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

# Create flux-system namespace
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes        = [metadata[0].labels]
    create_before_destroy = true
  }
}

# Create sops-age secret if age key is provided
resource "kubernetes_secret" "sops_age" {
  count = var.age_key != "" ? 1 : 0

  metadata {
    name      = "sops-age"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    "age.agekey" = var.age_key
  }

  type = "Opaque"
}

# Create flux-system secret for git repository access
resource "kubernetes_secret" "flux_system" {
  metadata {
    name      = "flux-system"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    "identity"     = var.git_ssh_key
    "identity.pub" = var.git_ssh_key_pub
    "known_hosts"  = var.known_hosts
  }

  type = "Opaque"
}

# Install Flux using Helm with wait=false to skip pre-install checks
resource "helm_release" "flux" {
  name       = "flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  namespace  = kubernetes_namespace.flux_system.metadata[0].name
  version    = "2.16.3"

  # Skip waiting for deployment to be ready
  wait = false

  # Force recreation if needed
  replace = true

  set {
    name  = "imageAutomationController.create"
    value = "true"
  }

  set {
    name  = "imageReflectionController.create"
    value = "true"
  }

  # Install CRDs
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Set high priority for Flux pods to ensure they get scheduled
  set {
    name  = "priorityClassName"
    value = "critical"
  }

  # Resource limits for GKE Autopilot compatibility
  set {
    name  = "helmController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "helmController.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "sourceController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "sourceController.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "kustomizeController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "kustomizeController.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "notificationController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "notificationController.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "imageReflectionController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "imageReflectionController.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "imageAutomationController.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "imageAutomationController.resources.requests.memory"
    value = "64Mi"
  }

  depends_on = [kubernetes_namespace.flux_system]
}

# Create GitRepository source
resource "kubectl_manifest" "git_repository" {
  yaml_body = <<-YAML
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: 5m0s
      ref:
        branch: ${var.github_branch}
      secretRef:
        name: flux-system
      url: ssh://git@github.com/${var.github_owner}/${var.github_repository}
  YAML

  depends_on = [helm_release.flux]
}

# Create Kustomization for cluster sync
resource "kubectl_manifest" "flux_kustomization" {
  yaml_body = <<-YAML
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: 10m0s
      path: ./clusters/${var.cluster_name}
      prune: true
      sourceRef:
        kind: GitRepository
        name: flux-system
      decryption:
        provider: sops
        secretRef:
          name: sops-age
  YAML

  depends_on = [
    kubectl_manifest.git_repository,
    kubernetes_secret.sops_age
  ]
}