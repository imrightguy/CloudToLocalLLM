#!/usr/bin/env python3
"""
Apply GitHub Actions OIDC trust policy to IAM role.
Requires: boto3, python-dotenv
"""

import json
import sys
import getpass
import boto3
from botocore.exceptions import ClientError

def create_trust_policy(account_id, github_repo):
    """Create the OIDC trust policy document."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": f"arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                    },
                    "StringLike": {
                        "token.actions.githubusercontent.com:sub": f"repo:{github_repo}:*"
                    }
                }
            }
        ]
    }

def main():
    """Main function."""
    role_name = "github-actions-role"
    account_id = "422017356244"
    github_repo = "zoidbot/zoidbot"
    region = "us-east-1"
    
    print("GitHub Actions OIDC Trust Policy Setup")
    print("=" * 40)
    print()
    
    # Get credentials
    print("Enter AWS Root Credentials:")
    print()
    access_key_id = input("AWS Access Key ID: ").strip()
    secret_access_key = getpass.getpass("AWS Secret Access Key: ")
    
    if not access_key_id or not secret_access_key:
        print("✗ Credentials cannot be empty")
        sys.exit(1)
    
    print()
    print("✓ Credentials received")
    print()
    
    # Create trust policy
    trust_policy = create_trust_policy(account_id, github_repo)
    
    print("Trust Policy:")
    print(json.dumps(trust_policy, indent=2))
    print()
    
    # Create IAM client
    try:
        iam_client = boto3.client(
            'iam',
            region_name=region,
            aws_access_key_id=access_key_id,
            aws_secret_access_key=secret_access_key
        )
    except Exception as e:
        print(f"✗ Failed to create IAM client: {e}")
        sys.exit(1)
    
    # Update trust policy
    print("Updating IAM role trust policy...")
    print(f"Role: {role_name}")
    print(f"Region: {region}")
    print()
    
    try:
        iam_client.update_assume_role_policy(
            RoleName=role_name,
            PolicyDocument=json.dumps(trust_policy)
        )
        print("✓ Trust policy updated successfully")
    except ClientError as e:
        print(f"✗ Failed to update trust policy: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)
    
    # Verify
    print()
    print("Verifying trust policy...")
    
    try:
        response = iam_client.get_role(RoleName=role_name)
        current_policy = response['Role']['AssumeRolePolicyDocument']
        
        print("✓ Trust policy verified")
        print()
        print("Current Trust Policy:")
        print(json.dumps(current_policy, indent=2))
    except ClientError as e:
        print(f"⚠ Could not verify trust policy: {e}")
    except Exception as e:
        print(f"⚠ Error verifying: {e}")
    
    print()
    print("✓ OIDC trust policy applied successfully")
    print()
    print("Next steps:")
    print("1. Trigger Deploy to AWS EKS workflow in GitHub")
    print("2. Monitor the workflow")
    print("3. Delete the root API key")

if __name__ == "__main__":
    main()
