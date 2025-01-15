variable "helm_repo" {
    description = "The Helm repository configuration for any Karpenter assets."
    type = map(any)
    default = {
        repository = "oci://public.ecr.aws/karpenter"
        version = "1.1.0"
    }
}

variable "cluster_name" {
    description = "The name of the EKS cluster."
    type = string
}

variable "nodepool_name" {
    description = "The name to assign to the Karpenter Nodepool."
    type = string
    default = "default"
}

variable "karpenter_node_role" {
    description = "The Karpenter node IAM role name (not ARN)."
    type = string
}

variable "capacity_type" {
    description = "On-demand, spot, or both."
    type = list(string)
    default = [
        "spot",
        "on-demand"
    ]
}

variable "instance_category" {
    description = "The instance families (m, c, etc.) Karpenter can choose from."
    type = list(string)
    default = [
        "m",
        "c"
    ]
}

variable "instance_cpu" {
    description = "The number of cores for instances Karpenter can choose."
    type = list(string)
    default = [
        "4",
        "8",
        "16",
        "32"
    ]
}

variable "max_pods" {
    description = "The maximum number of pods allowed on a Karpenter node."
    type = string
    default = "50"
}

variable "vpc_name" {
    description = "The name of the VPC where Karpenter nodes will be launched."
    type = string
}