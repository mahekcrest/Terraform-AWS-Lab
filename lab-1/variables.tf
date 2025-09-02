variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name (optional if using SSM)"
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH (recommend your IP/32). If empty, SSH will be disabled and SSM is used."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Unique S3 bucket name"
  type        = string
}

variable "ec2_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "lab-ec2"
}

variable "ec2_key_name" {
  description = "Key pair name for EC2"
  type        = string
  default     = "lab-key"
}

variable "ec2_key_file" {
  description = "PEM filename to save locally"
  type        = string
  default     = "lab-key.pem"
}
