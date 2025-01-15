# Required for 
data "aws_ecrpublic_authorization_token" "token" {
    provider = aws.ecr
}