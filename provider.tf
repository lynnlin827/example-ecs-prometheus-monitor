provider "aws" {
  region              = "ap-northeast-1"
  allowed_account_ids = ["${var.account}"]
}
