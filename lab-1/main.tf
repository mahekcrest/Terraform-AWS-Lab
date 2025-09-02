# --- Networking (VPC, Subnet, IGW, Route Table) ---
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "lab-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "lab-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "lab-public-rt" }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Security Group (HTTP open, SSH optional) ---
resource "aws_security_group" "lab_sg" {
  name        = "lab-sg"
  description = "Allow HTTP; SSH optional via ssh_cidr; allow all outbound"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_cidr) > 0 ? [1] : []
    content {
      description = "SSH from configured CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.ssh_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lab-sg" }
}

# --- S3 bucket with encryption + block public access ---
resource "aws_s3_bucket" "lab_bucket" {
  bucket        = var.bucket_name
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = { Name = "lab-bucket" }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.lab_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- IAM role for EC2 (least privilege: S3 access to this bucket + SSM) ---
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "lab-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Allow EC2 instance to call S3 on only this bucket + SSM operations
resource "aws_iam_policy" "ec2_s3_limited" {
  name        = "lab-ec2-s3-limited"
  description = "Allow S3 operations on the lab bucket and SSM for session manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.lab_bucket.arn,
          "${aws_s3_bucket.lab_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus",
          "ssm:UpdateInstanceInformation",
          "ssm:DescribeInstanceProperties"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceProperties",
          "ssm:GetInventory",
          "ssm:ListInventoryEntries"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_limited.arn
}

# Attach AWS managed policy for SSM Agent to function fully (Session Manager etc)
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "lab-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


# Generate a new SSH key pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Upload the public key to AWS
resource "aws_key_pair" "ec2_key" {
  key_name   = var.ec2_key_name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save private key locally as PEM file
resource "local_file" "pem_key" {
  content          = tls_private_key.ec2_key.private_key_pem
  filename         = "${path.module}/${var.ec2_key_file}"
  file_permission  = "0400"
}



# --- EC2 instance with user-data to run HTTP server ---
resource "aws_instance" "lab_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Amazon Linux 2 has SSM agent pre-installed; ensure it's running
              systemctl enable --now amazon-ssm-agent || true
              # install python3 and start basic HTTP server
              amazon-linux-extras enable python3.8
              yum install -y python3
              echo "Hello from Secure AWS Lab EC2 instance!" > /home/ec2-user/index.html
              nohup python3 -m http.server 80 --directory /home/ec2-user > /home/ec2-user/server.log 2>&1 &
              EOF

  tags = { Name = var.ec2_name }
}

# AMI data
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- Optional: small CloudWatch alarm for instance status check failures (helps detect down instances) ---
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name          = "${aws_instance.lab_ec2.id}-status-check-failed"
  alarm_description   = "Alarm when EC2 status check fails"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  dimensions = {
    InstanceId = aws_instance.lab_ec2.id
  }
  treat_missing_data = "notBreaching"
}