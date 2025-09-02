output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.lab_ec2.public_ip
}

output "ec2_http_url" {
  description = "HTTP URL to test the instance"
  value       = "http://${aws_instance.lab_ec2.public_ip}"
}

output "s3_bucket_name" {
  description = "S3 bucket name created for the lab"
  value       = aws_s3_bucket.lab_bucket.bucket
}
