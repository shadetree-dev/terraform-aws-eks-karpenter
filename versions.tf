terraform {
    required_version = "~> 1.9.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.72"
        }
        helm = {
            source = "hashicorp/helm"
            version = "~> 2.12"
        }
        kubernetes = {
            source = "hashicorp/kubernetes"
            version = "~> 2.20"
        }
    }
}