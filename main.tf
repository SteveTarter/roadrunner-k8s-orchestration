terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.75.0" # Pinning version to ensure compatibility and avoid breaking changes in future versions
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0" # Use the latest version supported
    }
    helm = {
      source = "hashicorp/helm"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

# Configure AWS provider
provider "aws" {
  region = var.region
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path # Parameterized path for kubeconfig
    config_context = var.cluster_name
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path # Parameterized path for kubeconfig
  config_context = var.cluster_name
}

provider "kubectl" {
  config_path = var.kubeconfig_path # Parameterized path for kubeconfig
  config_context = var.cluster_name
}

# Define the namespace to be used for Roadrunner
resource "kubernetes_namespace" "roadrunner_namespace" {
  # Creates a dedicated namespace for the Roadrunner application to organize resources and enforce separation within the Kubernetes cluster.
  metadata {
    name = var.roadrunner_namespace
  }
}

# Install redis only on minikube.  MemoryDB will be used on EKS.  For now, that's hand-generated.
module "redis" {
  source = "./modules/redis"
  count  = terraform.workspace == "minikube" ? 1 : 0

# This module sets up a Redis instance to share datas between Roadrunner instances.

  roadrunner_namespace           = var.roadrunner_namespace
}

# Conditional null_resource for dependency
resource "null_resource" "redis_ready" {
  count = terraform.workspace == "minikube" ? 1 : 0
}

# Determine the redis host based on the workspace.
locals {
  redis_host = terraform.workspace == "minikube" && length(module.redis) > 0 ? module.redis[0].redis_host : var.aws_memorydb_host
}

module "prometheus" {
  source = "./modules/prometheus"
}

module "roadrunner" {
  source = "./modules/roadrunner"

  # This module sets up the core infrastructure for the Roadrunner application, including networking, IAM roles, and Kubernetes resources.

  cluster_name                   = var.cluster_name
  roadrunner_namespace           = var.roadrunner_namespace
  mapbox_api_key                 = var.mapbox_api_key
  spring_mail_username           = var.spring_mail_username
  spring_mail_password           = var.spring_mail_password
  auth0_api_client_id            = var.auth0_api_client_id
  auth0_api_client_secret        = var.auth0_api_client_secret
  auth0_api_scope                = var.auth0_api_scope
  auth0_api_issuer_url           = var.auth0_api_issuer_url
  auth0_api_audience             = var.auth0_api_audience
  auth0_api_rest_url_base        = var.auth0_api_rest_url_base
  tarterware_cert_arn            = var.tarterware_cert_arn
  redis_host                     = local.redis_host
  prometheus_release_name        = module.prometheus.prometheus_release_name

  depends_on = [null_resource.redis_ready]
}

module "roadrunner_view" {
  source = "./modules/roadrunner_view"

  # This module configures the frontend for the Roadrunner application and relies on the `roadrunner` module to provide backend services and infrastructure. The dependency ensures that the backend is fully set up before the frontend configuration is applied.

  roadrunner_namespace                 = var.roadrunner_namespace
  roadrunner_rest_url_base             = var.roadrunner_rest_url_base
  roadrunner_view_url_base             = var.roadrunner_view_url_base
  mapbox_api_key                       = var.mapbox_api_key
  auth0_api_issuer_url                 = var.auth0_api_issuer_url
  auth0_api_domain                     = var.auth0_api_domain
  roadrunner_view_auth0_client_id      = var.roadrunner_view_auth0_client_id
  roadrunner_view_auth0_client_secret  = var.roadrunner_view_auth0_client_secret
  tarterware_cert_arn                  = var.tarterware_cert_arn
  tarterware_api_audience              = var.tarterware_api_audience

  depends_on = [module.roadrunner]
}
