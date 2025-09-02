# Secure AWS Lab with Terraform and Python Verification

## Overview
The goal of this lab is to demonstrate **Infrastructure as Code (IaC)** best practices, secure resource provisioning, and automated compliance checks.

In this project, we provisioned a secure AWS lab environment that includes:
- **EC2 Instance** running a simple HTTP server
- **S3 Bucket** with enforced server-side encryption
- **Security Group** rules restricted to specific CIDR blocks
- Optional access using **AWS Systems Manager (SSM)** instead of SSH key pair
- Automated **Python script** to verify S3 encryption compliance

---

## Prerequisites
- AWS CLI configured with credentials that have permissions to create EC2, S3, IAM, and related resources:
  ```bash
  aws configure
  ```
- Terraform installed ([Download Terraform](https://developer.hashicorp.com/terraform/downloads))
- Python 3.x installed

---

## Deployment Steps

### 1. Initialize and Apply Terraform
From the `terraform` folder, run:
```bash
terraform init
terraform apply -var="key_pair_name=YOUR_KEY" -var="ssh_cidr=YOUR.IP.32" -var="bucket_name=unique-bucket-name"
```

If you don't want to provide a key pair and prefer to use SSM for access, set:
```bash
-var="key_pair_name="
```

---

### 2. Test the HTTP Server
After the infrastructure is created, run:
```bash
curl $(terraform output -raw ec2_http_url)
```
Expected output:
```
Hello from Secure AWS Lab EC2 instance!
```

---

### 3. Run Python Security Verification
Install required Python packages:
```bash
pip install boto3
```
Run the S3 encryption compliance check:
```bash
python python/s3_check_secure.py $(terraform -chdir=terraform output -raw s3_bucket_name)
```

---

### 4. Cleanup
To delete all created resources:
```bash
terraform -chdir=terraform destroy -auto-approve
```

---

## Project Structure
```
.
├── terraform/
│   ├── main.tf              # AWS infrastructure definition
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   └── provider.tf          # AWS provider configuration
├── python/
│   └── s3_check_secure.py   # Python script to verify S3 encryption
└── README.md
```

---

## Security Considerations
- **Least privilege** IAM policies are used for resource creation.
- **S3 bucket encryption** enforced at creation.
- **Security Groups** restricted to specified IP ranges.
- **Optional SSM** access eliminates the need for SSH key distribution.
- Terraform state should be stored securely (e.g., S3 with encryption + DynamoDB locking).

---

## Architecture Diagram
```
+-------------------------+
| AWS Cloud               |
|                         |
|  +------------------+   |
|  | EC2 Instance     |   |
|  | - HTTP Server    |   |
|  +--------+---------+   |
|           |             |
|      Security Group     |
|       (CIDR limited)    |
|                         |
|  +------------------+   |
|  | S3 Bucket        |   |
|  | - Encrypted      |   |
|  +------------------+   |
|                         |
+-------------------------+
```

---
