# Create a new EKS cluster with the public AWS module
module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "~> 20.31.6"

    tags = local.tags

    # The configmap/aws-auth is deprecated and should be moved away from
    # API also helps prevent cluster lockout because you can assign access via UI/API if needed
    authentication_mode = "API"
    enable_cluster_creator_admin_permissions = true

    # EKS supported Kubernetes version, recommended to use recent minor versions
    cluster_version = local.k8s_version

    cluster_name = local.cluster_name
    # YOU SHOULD MAKE YOUR CLUSTERS PRIVATE IF POSSIBLE!
    # Otherwise make sure you have strong IAM controls with MFA
    # And consider setting cluster_endpoint_public_access_cidrs
    cluster_endpoint_public_access = true

    create_cluster_security_group = true
    cluster_security_group_name = "${local.cluster_name}-cluster-sg"
    # Preference to avoid long UID suffixed on the above SG
    cluster_security_group_use_name_prefix = false

    create_node_security_group = true
    node_security_group_name = "${local.cluster_name}-node-sg"
    # Preference to avoid long UID suffixed on the above SG
    node_security_group_use_name_prefix = true
    # IMPORTANT: Add tags for Karpenter discovery
    node_security_group_tags = merge(local.tags, {
        "karpenter.sh/discovery" = local.cluster_name
    })

    # Create basic managed node group for kube-system stuff and anything we do NOT want on Karpenter
    eks_managed_node_groups = {
        default = {
            # Substring in case we exceed 37 characters
            name = substr("${local.cluster_name}-default-ng", 0, 37)
            # Preference to avoid long UID suffixed on the above node group name
            use_name_prefix = false

            # Use Bottlerocket since it is lightweight and updated often
            ami_type = "BOTTLEROCKET_x86_x64"
            use_latest_ami_release_version = true
            instance_types = var.instance_types

            launch_template_name = "${local.cluster_name}-default-lt"
            update_launch_template_default_version = true
            launch_template_tags = {
                "CLUSTER" = local.cluster_name
                "AMI_TYPE" = "BOTTLEROCKET_x86_x64"
            }

            # Configure the EBS volumes for our nodes
            block_device_mappings = {
                # Boot volume
                xvda = {
                    device_name = "/dev/xvda"
                    ebs = {
                        volume_size = 5
                        volume_type = "gp3"
                        encrypted = true
                        delete_on_termination = true
                    }
                }
                # Data volume
                xvdb = {
                    device_name = "/dev/xvdb"
                    ebs = {
                        volume_size = 20
                        volume_type = "gp3"
                        iops = 5000
                        throughput = 300
                        encrypted = true
                        delete_on_termination = true
                    }
                }
            }

            # Set some defaults on how many nodes we want for min/max
            # You may see some failed pods of kube-system stuff if you do not have at least 3
            min_size = 3
            desired_size = 3
            max_size = 5

            create_iam_role = true
            iam_role_name = "${local.cluster_name}-NodeRole"
            iam_role_use_name_prefix = false
            iam_role_attach_cni_policy = true
            vpc_cni_enable_ipv4 = true

            # Make sure we have SSM and EBS policies
            iam_role_additional_policies = {
                AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
                AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
            }
        }
    }

    cloudwatch_log_group_retention_in_days = var.cloudwatch_retention_days
    cloudwatch_log_group_class = "STANDARD"
    # Default does not log all types
    # This will increase cost, but can be useful, so set your preferences accordingly
    cluster_enabled_log_types = [
        "audit", 
        "api", 
        "authenticator", 
        "controllerManager", 
        "scheduler"
    ]
}

# CREATE THIS BEFORE THE BLUEPRINTS ADDONS
# That way you can manage and update CRDs as part of the helm chart
module "karpenter_nodepool" {
    source = "./modules/karpenter-nodepool"
}

# Addons supported by EKS Blueprints, which set up useful resources, especially for Karpenter
module "eks_blueprints_addons" {
    source = "aws-ia/eks-blueprints-addons/aws"
    version = "~> 1.17"

    # Required configuration for the specific cluster to manage addons
    oidc_provider_arn = module.eks.oidc_provider_arn
    cluster_name = module.eks.cluster_name
    cluster_version = module.eks.cluster_version
    cluster_endpoint = module.eks.cluster_endpoint

    eks_addons = {
        coredns = {
            most_recent = true
            cleanup_on_fail = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
        },
        kube-proxy = {
            most_recent = true
            cleanup_on_fail = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
        },
        vpc-cni = {
            most_recent = true
            cleanup_on_fail = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
        },
        aws-ebs-csi-driver = {
            most_recent = true
            cleanup_on_fail = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
        },
        eks-pod-identity-agent = {
            most_recent = true
            cleanup_on_fail = true
            resolve_conflicts_on_create = "OVERWRITE"
            resolve_conflicts_on_update = "OVERWRITE"
        }
    }

    enable_cert_manager = true
    cert_manager = {
        chart_version = local.helm_repos["cert_manager"].version
        iam_role_name = "cert-manager-${module.eks.cluster_name}"
        iam_policy_name = "cert-manager-${module.eks.cluster_name}"
        tags = local.tags
    }

    metrics_server = {
        chart_version = local.helm_repos["metrics_server"].version
        iam_role_name = "metrics-server-${module.eks.cluster_name}"
        iam_policy_name = "metrics-server-${module.eks.cluster_name}"
        tags = local.tags
    }

    karpenter = {
        force_update = true
        chart_version = local.helm_repo_values["karpenter"].version
        repository_username = data.aws_ecrpublic_authorization_token.token.user_name
        repository_password = data.aws_ecrpublic_authorization_token.token.password

        create_iam_role = true
        iam_role_name = "${module.eks.cluster_name}-KarpenterControllerRole"
        iam_role_use_name_prefix = false
        iam_policy_name = "${module.eks.cluster_name}-KarpenterControllerPolicy"
        iam_policy_use_name_prefix = false
        tags = local.tags
    }

    karpenter_node = {
        create_node_iam_role = true
        iam_role_name = "${module.eks.cluster_name}-KarpenterNodeRole"
        iam_role_use_name_prefix = false
        iam_policy_name = "${module.eks.cluster_name}-KarpenterNodePolicy"
        iam_policy_use_name_prefix = false
        # Make sure we have SSM and EBS policies
        iam_role_additional_policies = {
            AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
            AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        }
    }

    enable_metrics_server = true
}

# Make sure the Karpenter nodes can be joined to the control plane and have the right permissions
resource "aws_eks_access_entry" "karpenter" {
    depends_on = [
        module.eks_blueprints_addons
    ]
    cluster_name = module.eks.cluster_name
    principal_arn = provider::aws::arn_build("aws", "iam", "", var.account_id, "role/${module.eks.cluster_name}-KarpenterNodeRole")
    type = "EC2_LINUX"
}