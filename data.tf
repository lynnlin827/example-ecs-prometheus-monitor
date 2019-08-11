data "aws_ssm_parameter" "ecs_instance_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id"
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    sid     = ""
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
