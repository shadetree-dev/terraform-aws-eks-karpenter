provider "aws" {
    region = var.region
    profile = var.sso_profile
    dynamic "assume_role" {
        for_each = var.sso_profile != null ? [] : [1]
        content {
            role_arn = provider::aws::arn_builder("aws", "iam", "", var.account_id, "role/your-terraform-role")
        }
    }
}

# Need to have ECR token generated from us-east-1
provider "aws" {
    region = "us-east-1"
    alias = "ecr"
    profile = var.sso_profile
    dynamic "assume_role" {
        for_each = var.sso_profile != null ? [] : [1]
        content {
            role_arn = provider::aws::arn_builder("aws", "iam", "", var.account_id, "role/your-terraform-role")
        }
    }
}