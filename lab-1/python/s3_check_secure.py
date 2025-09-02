#!/usr/bin/env python3
import boto3
import sys
import botocore

def check_encryption(s3_client, bucket):
    try:
        enc = s3_client.get_bucket_encryption(Bucket=bucket)
        rules = enc.get("ServerSideEncryptionConfiguration", {}).get("Rules", [])
        if rules:
            print(f"[OK] Bucket {bucket} has server-side encryption configured: {rules}")
        else:
            print(f"[WARN] Bucket {bucket} has no SSE rules.")
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'ServerSideEncryptionConfigurationNotFoundError':
            print(f"[FAIL] Bucket {bucket} has no server-side encryption configured.")
        else:
            print("[ERROR] Could not get encryption info:", e)
            raise

def check_public_access_block(s3_client, bucket):
    try:
        pab = s3_client.get_public_access_block(Bucket=bucket)
        config = pab['PublicAccessBlockConfiguration']
        print(f"[OK] PublicAccessBlock for {bucket}: {config}")
        if not all([config.get('BlockPublicAcls'), config.get('BlockPublicPolicy'),
                    config.get('IgnorePublicAcls'), config.get('RestrictPublicBuckets')]):
            print("[WARN] Not all public access block settings are enabled.")
    except botocore.exceptions.ClientError as e:
        print("[ERROR] Could not get public access block:", e)
        raise

def s3_roundtrip_test(s3_client, bucket):
    key = "lab-test-object.txt"
    body = b"hello from s3_check_secure"
    try:
        s3_client.put_object(Bucket=bucket, Key=key, Body=body)
        print(f"[OK] Uploaded test object {key} to {bucket}")
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        content = obj['Body'].read()
        if content == body:
            print("[OK] Downloaded content matches uploaded content")
        else:
            print("[FAIL] Content mismatch")
        s3_client.delete_object(Bucket=bucket, Key=key)
        print("[OK] Cleaned up test object")
    except Exception as e:
        print("[ERROR] S3 roundtrip failed:", e)
        raise

def main():
    if len(sys.argv) != 2:
        print("Usage: python s3_check_secure.py <bucket-name>")
        sys.exit(2)
    bucket = sys.argv[1]
    s3 = boto3.client("s3")
    check_encryption(s3, bucket)
    check_public_access_block(s3, bucket)
    s3_roundtrip_test(s3, bucket)

if __name__ == "__main__":
    main()
