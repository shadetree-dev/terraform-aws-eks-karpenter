locals {
    cluster_name = var.cluster_name != "" ? var.cluster_name : "shadetree-dev-cluster-${formatdate(YYYMMDD, timestamp())}"

    k8s_version = "1.31"

    # A list of ARNs that should have admin access to the cluster and ancillary resources
    admin_arns = [

    ]

    helm_repos = {
        cert_manager = {
            version = "1.16.1"
        },
        metrics_server = {
            version = "3.12.2"
        }
        karpenter = {
            version = "1.1.0"
        }
    }

    # Merge any optional / passed in tags with defaults we want to set
   tags = merge(var.tags, 
   {
        source-example = "shadetree.dev"
   }) 
}