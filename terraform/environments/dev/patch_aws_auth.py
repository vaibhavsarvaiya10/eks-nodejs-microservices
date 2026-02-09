#!/usr/bin/env python3
"""
Patch aws-auth ConfigMap using AWS SigV4 signed Kubernetes API requests
"""

import json
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

def get_kubernetes_api_endpoint(cluster_name, region):
    """Get the Kubernetes API endpoint from EKS cluster"""
    eks = boto3.client('eks', region_name=region)
    response = eks.describe_cluster(name=cluster_name)
    return response['cluster']['endpoint']

def get_ca_cert(cluster_name, region):
    """Get the cluster CA certificate"""
    eks = boto3.client('eks', region_name=region)
    response = eks.describe_cluster(name=cluster_name)
    import base64
    return base64.b64decode(response['cluster']['certificateAuthority']['data'])

def patch_aws_auth(cluster_name, region, user_arn, username, groups):
    """Patch aws-auth ConfigMap with IAM user"""
    
    endpoint = get_kubernetes_api_endpoint(cluster_name, region)
    ca_cert = get_ca_cert(cluster_name, region)
    
    # Write CA cert to temp file
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.crt', delete=False) as f:
        f.write(ca_cert.decode('utf-8'))
        ca_file = f.name
    
    # Build the ConfigMap patch
    map_users = [{
        "userarn": user_arn,
        "username": username,
        "groups": groups
    }]
    
    patch_body = {
        "data": {
            "mapUsers": "\n".join([
                f"- userarn: {u['userarn']}"
                f"\n  username: {u['username']}"
                f"\n  groups:"
                + "".join([f"\n    - {g}" for g in u['groups']])
                for u in map_users
            ])
        }
    }
    
    # Create AWS request
    url = f"{endpoint}/api/v1/namespaces/kube-system/configmaps/aws-auth"
    
    # First try to get it
    print(f"Checking if aws-auth exists...")
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Try PATCH request
    method = 'PATCH'
    headers = {
        'Content-Type': 'application/strategic-merge-patch+json'
    }
    
    request = AWSRequest(method=method, url=url, data=json.dumps(patch_body), headers=headers)
    SigV4Auth(credentials, 'eks', region).add_auth(request)
    
    print(f"Patching aws-auth ConfigMap...")
    response = requests.patch(
        url,
        json=patch_body,
        headers=dict(request.headers),
        verify=ca_file
    )
    
    print(f"Response status: {response.status_code}")
    print(f"Response: {response.text}")
    
    # Clean up
    import os
    os.unlink(ca_file)

if __name__ == '__main__':
    cluster_name = 'eks-dev-cluster'
    region = 'ap-south-1'
    user_arn = 'arn:aws:iam::***REMOVED***:user/terraform'
    username = 'terraform'
    groups = ['system:masters']
    
    try:
        patch_aws_auth(cluster_name, region, user_arn, username, groups)
        print("\nSuccess! aws-auth ConfigMap patched.")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
