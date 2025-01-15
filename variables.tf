variable cluster_name {
    description = "The name for your EKS cluster."
    type = string
    default = ""
}

variable "region" {
    description = "The AWS region where you are deploying resources."
    type = string
    default = "us-west-2"
}

variable "account_id" {
    description = "The 12 digit AWS account ID where resources should be deployed."
    type = string
    default = ""
}

variable "tags" {
    description = "A map of tag key/value pairs for AWS tags."
    type = map(string)
    default = {}
}

variable "sso_profile" {
    description = "Optional parameter for running locally with AWS SSO profile."
    type = string
    default = null
}

variable "instance_types" {
    description = "The instance families and sizes to use for managed EKS node groups"
    type = list(string)
    default = [
        # Intel first for 7th generation; cheaper than AMD
        "m7i.large",
        "m7i.xlarge",
        "m7a.large",
        "m7a.xlarge",
        # AMD first for 6th generation; cheaper than Intel
        "m6a.large",
        "m6a.xlarge",
        "m6i.large",
        "m6i.xlarge"
    ]
}

variable "cloudwatch_retention_days" {
    description = "The number of days to retain CloudWatch Logs."
    type = number
    default = 7
    validation {
      condition = var.cloudwatch_retention_days >= 7 && var.cloudwatch_retention_days <= 90
      error_message = "Retention days must be between 7 and 90."
    }
}