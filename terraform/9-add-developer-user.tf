resource "aws_iam_user" "developer" {
  name = "developer"
}

resource "aws_iam_policy" "developer_eks" {

  name = "AmazonEKSDeveloperPolicy"

  policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        }
    ]
  }
  POLICY  
}

resource "aws_iam_user_policy_attachment" "developer_eks" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_eks.arn
}


resource "aws_eks_access_entry" "developer" {
  cluster_name      = aws_eks_cluster.eks.name
  principal_arn     = aws_iam_user.developer.arn
  kubernetes_groups = ["my-viewer"]
}



/*

after applying this changes check:- 

1. Generate Access Key & Secret for developer in AWS Console.
2. Configure CLI with aws configure --profile developer.
3. Verify profile with aws sts get-caller-identity --profile developer.
4. Connect to EKS with aws eks update-kubeconfig --region us-east-2 --name staging-demo --profile developer.
5. Check current context with kubectl config view --minify.
6. Test access with kubectl auth can-i get pods.
7. Check admin privileges with kubectl auth can-i "*" "*".


*/