locals {
  region = var.region
  enable_route_53          = true
  is_route53_private_zone = false
  # change to a valid domain name you created a route53 zone
  # aws route53 create-hosted-zone --name example.com --caller-reference "$(date)"
  domain_name      = var.domain_name
  # route53_zone_arn = try(data.aws_route53_zone.this.arn, "")

}
