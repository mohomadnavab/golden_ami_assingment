############################################
# LOCAL TIMESTAMP (FOR UNIQUE NAMING)
############################################

locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

############################################
# COMPONENTS (FIXED)
############################################

resource "aws_imagebuilder_component" "iis" {
  name     = "install-iis-${local.timestamp}"
  platform = "Windows"
  version  = "1.0.0"
  data     = file("${path.module}/../components/install-iis.yml")
}

resource "aws_imagebuilder_component" "dotnet" {
  name     = "install-dotnet-${local.timestamp}"
  platform = "Windows"
  version  = "1.0.0"
  data     = file("${path.module}/../components/install-dotnet.yml")
}

resource "aws_imagebuilder_component" "hardening" {
  name     = "hardening-${local.timestamp}"
  platform = "Windows"
  version  = "1.0.0"
  data     = file("${path.module}/../components/hardening.yml")
}

resource "aws_imagebuilder_component" "patch" {
  name     = "patching-${local.timestamp}"
  platform = "Windows"
  version  = "1.0.0"
  data     = file("${path.module}/../components/patch.yml")
}

resource "aws_imagebuilder_component" "validate" {
  name     = "validate-${local.timestamp}"
  platform = "Windows"
  version  = "1.0.0"
  data     = file("${path.module}/../components/validate.yml")
}

############################################
# IMAGE RECIPE (FIXED)
############################################

resource "aws_imagebuilder_image_recipe" "this" {
  name         = "golden-ami-recipe-${local.timestamp}"
  version      = "1.0.0"
  parent_image = data.aws_ami.windows.id

  block_device_mapping {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ami.arn
    }
  }

  component { component_arn = aws_imagebuilder_component.iis.arn }
  component { component_arn = aws_imagebuilder_component.dotnet.arn }
  component { component_arn = aws_imagebuilder_component.hardening.arn }
  component { component_arn = aws_imagebuilder_component.patch.arn }
  component { component_arn = aws_imagebuilder_component.validate.arn }
}

############################################
# INFRA CONFIG (OK)
############################################

resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                          = "golden-ami-infra-${local.timestamp}"
  instance_profile_name         = aws_iam_instance_profile.this.name
  instance_types                = ["t3.medium"]

  subnet_id                     = data.aws_subnets.default.ids[0]
  security_group_ids            = [data.aws_security_group.default.id]

  terminate_instance_on_failure = true

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.logs.bucket
    }
  }
}

############################################
# DISTRIBUTION CONFIG (CRITICAL FIX APPLIED)
############################################

resource "aws_imagebuilder_distribution_configuration" "this" {
  name = "golden-ami-dist-${local.timestamp}"

  dynamic "distribution" {
    for_each = toset([data.aws_region.current.name])

    content {
      region = distribution.value

      ami_distribution_configuration {
        name       = "golden-ami-{{ imagebuilder:buildDate }}"
        kms_key_id = aws_kms_key.ami.arn
      }
    }
  }
}

############################################
# PIPELINE (FINAL)
############################################

resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = "golden-ami-pipeline-${local.timestamp}"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn

  status = "ENABLED"
}