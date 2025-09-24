# sets up a secure, role-based access control system that allows a user called "manager" to safely administer your EKS cluster.



# Get current AWS account ID for reference
data "aws_caller_identity" "current" {}



# Creates the main EKS admin role that will have EKS management permissions
resource "aws_iam_role" "eks_admin" {
  name               = "${local.env}-${local.eks_name}-eks-admin"
  assume_role_policy = <<POLICY
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"   
      }
    }
  ]
}
POLICY
}


# It defines what the EKS admin role can actually do (EKS permissions)
resource "aws_iam_policy" "eks_admin" {
  name = "AmazonEKSAdminPolicy"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        }
    ]
}
POLICY
}


# Attaches the EKS permissions policy to the EKS admin role
resource "aws_iam_role_policy_attachment" "eks_admin" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = aws_iam_policy.eks_admin.arn
}


# Creates the manager user who will assume the EKS admin role
resource "aws_iam_user" "manager" {
  name = "manager"
}


# Gives the manager user permission to assume the EKS admin role
resource "aws_iam_policy" "eks_assume_admin" {
  name = "AmazonEKSAssumeAdminPolicy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "${aws_iam_role.eks_admin.arn}"
        }
    ]
}
POLICY
}


# Attaches the assume role policy to the manager user
resource "aws_iam_user_policy_attachment" "manager" {
  user       = aws_iam_user.manager.name
  policy_arn = aws_iam_policy.eks_assume_admin.arn
}

# Maps the AWS IAM role to a Kubernetes group for cluster access
resource "aws_eks_access_entry" "manager" {
  cluster_name      = aws_eks_cluster.eks.name
  principal_arn     = aws_iam_role.eks_admin.arn
  kubernetes_groups = ["my-admin"]
}


/*


# EKS IAM Role-Based Access Setup:- 

## Overview
• **STS (Security Token Service)**: AWS service providing temporary credentials (temporary ID card generator)
• **Assume Role**: Temporarily take on identity and permissions of another role
• **Resource Scoping**: `"Resource": "${aws_iam_role.eks_admin.arn}"` restricts access to only this specific role
• **EKS Access Entry**: Maps AWS IAM role to Kubernetes group for cluster access

## Setup Steps:- 

### 1. After Terraform Apply
• Go to IAM → manager user → generate access key and secret access key

### 2. Initial Cluster Access (Admin User):- 

• Switch to the user who created the EKS cluster
• Update kubeconfig: `aws eks update-kubeconfig --region us-east-2 --name staging-demo`
• Apply admin role: `kubectl apply -f adminRole`

### 3. Configure Manager Profile:- 

• Set up manager credentials: `aws configure --profile manager`
• Enter the generated access key and secret access key

### 4. Assume Role Command:- 

aws sts assume-role \
  --role-arn arn:aws:iam::<account_id>:role/staging-demo-eks-admin \
  --role-session-name manager-session \
  --profile manager


### 5. Create AWS Config Profile
• Edit `~/.aws/config`:

[profile manager]
region = us-east-1
output = json

[profile eks-admin]
role_arn = arn:aws:iam::424432388155:role/staging-demo-eks-admin
source_profile = manager
role_session_name = manager-session


### 6. Update Kubeconfig with Role Profile
• `aws eks update-kubeconfig --region us-east-2 --name staging-demo --profile eks-admin`

### 7. Test Access
• Check pods: `kubectl get pods`
• Verify admin permissions: `kubectl auth can-i "*" "*"`

## Important Notes
• **Security**: Temporary credentials expire automatically (typically 1 hour)
• **Cleanup**: Manually delete access keys before `terraform destroy` to avoid deletion issues
• **Account ID**: Manager uses your AWS account ID in the role ARN (no separate entry needed)



*/