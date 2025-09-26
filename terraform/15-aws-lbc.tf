data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

  }
}


resource "aws_iam_role" "aws_lbc" {
  name               = "${aws_eks_cluster.eks.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}


resource "aws_iam_policy" "aws_lbc" {
  policy = file("./iam/AWSLoadBalancerController.json")
  name   = aws_iam_role.aws_lbc.name
}


resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}



resource "helm_release" "aws_lbc" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set = [{
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "vpcId"
      value = aws_vpc.main.id
  }]
  depends_on = [helm_release.cluster_autoscaler]
}


// terraform apply 
// kubectl get pods -n kube-system
// kubectl apply -f lb-demo
// kubectl get svc -n lb-demo  
// get the external ip 
// in aws check the load balancer tab it will show provisioning
// we used network load balancer (it's a layer 4 load balancer and faster the alb and cheaper also)
// also in scheme you can see it's internet facing so anyone can access it
// also don't use internet facing for internal services and dashboards and prometheus and grafana 

// get the pod ip just to prove that target group is using this ip address

// kubectl get pods -o wide -n lb-demo


// you can use curl to hit the load balancer

// curl -i http:// <whatever you got from kubectl get svc -n lb-demo in external ip>:8080/about

// kubectl delete ns lb-demo


// the aws load balancer controller ships by default with alb ingress class

// kubectl get ingressclass



# now with plain-ingress

// in plain-ingress folder:-

// kubectl apply -f plain-ingress

// get the ingresses in our namespace :- 

// kubectl get ing -n plain-ingress

// in load balancer tab in aws you can see it uses load balancer type as application means it understands HTTP and can route traffic based on the HTTP path or a verb such as GET,POST 

// and scheme is internet facing

// target it pod ip address  as it is cluster ip and node port because node port uses instance mode not ip mode


// send live traffic

// curl -i --header "Host: myapp.kunal.cloud" http:// <the address you'll get from kubectl get ing -n plain-ingress>/about

// it is ingress we don't need to use port 8080 that we used with load balancer


// kubectl delete ns plain-ingress



# now with ssl-ingress:- 

# use aws certificate manager to generate the certificate with domain
# myapp.kunal.cloud and route53 to register that domain



# kubectl apply -f ssl-ingress
# kubectl get ing -n ssl-ingress


# now create a dns record:- 

# go to route53 -> hosted zones -> your domain

# click create record 

# give record name myapp 

# and record type CNAME


# and copy the address from the output of this command kubectl get ing -n ssl-ingress

# and paste it in value section 

# and click create records


# and in terminal 

# dig myapp.kunal.cloud


# or in browser 

# https://myapp.kunal.cloud/about

# and check the valid certificate in browser



/*


notes:- 

you’re setting up the AWS Load Balancer Controller (AWS LBC) for your EKS cluster using Terraform. Let’s break down each resource step by step, what it does, and how the flow works:


1. IAM Role Trust Policy (Pod Identity Assume Role)


data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

This creates an assume role policy (trust relationship).

It says:

Who can assume this role? → Any EKS pod running under the pods.eks.amazonaws.com service principal (this is the new EKS Pod Identity mechanism).

What actions can they perform? → sts:AssumeRole (to assume the IAM role) and sts:TagSession (for tagging temporary sessions).

👉 This is required because AWS LBC (running as a pod in your cluster) needs AWS API permissions to create/manage LoadBalancers.




2. IAM Role for AWS LBC

resource "aws_iam_role" "aws_lbc" {
  name               = "${aws_eks_cluster.eks.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}



Creates an IAM Role named your-cluster-name-aws-lbc.

Attaches the trust policy we defined above.

This role will later be bound to the AWS LBC pod via Pod Identity.




3. IAM Policy for AWS LBC


resource "aws_iam_policy" "aws_lbc" {
  policy = file("./iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}



Loads a JSON file containing AWS LBC permissions (AWSLoadBalancerController.json).

This JSON policy typically includes permissions like:

elasticloadbalancing:* (create ALB/NLB, listeners, target groups, etc.)

ec2:Describe* (to discover VPC subnets/security groups)

iam:CreateServiceLinkedRole (if needed for ELB)

👉 Without this policy, the LBC pod cannot interact with AWS resources.




4. Attach IAM Policy to IAM Role



resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}



Grants the IAM Role (aws_lbc) all the permissions defined in the JSON policy.

Now, any pod assuming this role will have AWS permissions to manage load balancers.



5. Pod Identity Association


resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}


Critical piece (EKS Pod Identity):

Associates the IAM Role (aws_lbc) with the Kubernetes Service Account aws-load-balancer-controller in the kube-system namespace.

Effect: When the AWS LBC pod runs under this service account, it automatically assumes the IAM role with proper permissions.

No need to use IRSA (IAM Roles for Service Accounts) with OIDC anymore — this is the newer pod identity method.






6. Helm Release: Deploy AWS Load Balancer Controller


resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [helm_release.cluster_autoscaler]
}




Deploys the AWS LBC Helm chart into your EKS cluster.

Key configurations:

clusterName → Tells LBC which EKS cluster it’s running in.

serviceAccount.name → Matches the one used in aws_eks_pod_identity_association, so it can assume the IAM role.

vpcId → Tells LBC which VPC to provision ALBs/NLBs in.

The controller runs in the kube-system namespace.

depends_on ensures that the Cluster Autoscaler Helm release is installed before this one (deployment ordering).






End-to-End Flow

Terraform creates IAM Role + Policy for AWS LBC.

Pod Identity Association links this IAM Role to the aws-load-balancer-controller Service Account.

Helm deploys the AWS LBC pod in kube-system, under that service account.

When the LBC pod starts:

It uses Pod Identity to assume the IAM Role (aws_lbc).

It gets permissions from the attached policy (AWSLoadBalancerController.json).

Now, when you create Kubernetes resources like:



kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  annotations:
    kubernetes.io/ingress.class: alb





AWS LBC will provision and manage ALBs/NLBs in your AWS account.

✅ In short:
This Terraform setup gives the AWS Load Balancer Controller just enough IAM permissions via Pod Identity and deploys it with Helm so your Kubernetes Ingresses/Services can automatically create/manage AWS Load Balancers.






Q2) so this runs for every pod in my eks cluster on every node ?


No, the AWS Load Balancer Controller (LBC) does not run for every pod on every node in your EKS cluster.


1. Where does AWS LBC run?

It’s deployed as a Kubernetes Deployment in the kube-system namespace.

This means it runs only a few pods (usually 1–2 replicas, depending on your Helm values).

These pods are the controller — they watch Kubernetes resources (Ingress, Service of type LoadBalancer, etc.) and decide when to create/update/delete AWS load balancers.







2. What about my application pods?

Your application pods (running in your own namespaces) do not get these IAM permissions.

They don’t talk directly to AWS APIs.

Instead, they just expose themselves using Service or Ingress objects.

The controller pod sees those objects and provisions AWS LBs on their behalf.




3. How does it get IAM permissions?

Only the LBC pods’ service account (aws-load-balancer-controller in kube-system) is associated with the IAM Role (aws_lbc).

That link is made by your Terraform resource:



resource "aws_eks_pod_identity_association" "aws_lbc" {
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}





Q 3) no no what i mean is this aws lbc will manage alb or nlb when i deploy that right ?
but i want to ask in iam role we have given the permission somethig called pods.eks.amazonaws.com . so this only means for every pod right as a pod identity ?




1. What AWS Load Balancer Controller (LBC) does

Yes ✅ — the AWS LBC pod (running in your cluster) is responsible for creating and managing ALBs/NLBs when you define Kubernetes resources like:

Ingress (for ALBs)

Service of type LoadBalancer (for NLBs, if configured)

It does not run on every pod. It’s a single controller (Deployment in kube-system), usually 1–2 replicas, watching for Ingress/Service objects and reconciling AWS resources.

2. What pods.eks.amazonaws.com means

In the IAM Role trust policy, you had this:



principals {
  type        = "Service"
  identifiers = ["pods.eks.amazonaws.com"]
}


This doesn’t mean every pod in the cluster automatically gets that role.

Instead, it’s tied to EKS Pod Identity → AWS allows only certain pods (via a ServiceAccount you explicitly bind) to assume the role.

3. Pod Identity Association

You linked the IAM Role to the specific Service Account:


resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}



That means:

Only pods in kube-system namespace using the ServiceAccount aws-load-balancer-controller can assume this role.

Regular application pods in your other namespaces won’t have this permission.



4. ✅ To summarize

pods.eks.amazonaws.com = tells AWS “this IAM Role can be assumed by EKS pods (via Pod Identity)”.

But the scope is restricted by your Pod Identity Association.

So not all pods get this role — only the LBC pods running with the bound ServiceAccount can use it.

Other pods (your app pods) will just run normally and won’t have IAM permissions unless you explicitly bind them with another pod identity.


👉 Think of it like this:

EC2/EKS worker nodes → have a node IAM role.

Pods with Pod Identity → can assume specific IAM roles, but only if you explicitly associate them with a service account.





Q 4) okay so we linked the service account of aws load balancer controller in that whatever pod we have only that pod will get the permission and similarly when we created cluster autoscaler over there we did the same thing of pod identity add on and in cluster-autoscaler service account in kube-system will get the permission 


Exactly ✅ you’ve got it right!

Let me restate in your words and expand a bit for clarity:

🔑 The Pattern

Create IAM Role with the required AWS permissions (e.g., manage ALBs for LBC, manage scaling for Cluster Autoscaler).

Trust Policy uses pods.eks.amazonaws.com so that pods (via Pod Identity) can assume it.

Associate IAM Role with a specific Kubernetes ServiceAccount using aws_eks_pod_identity_association.

Only the pods running with that ServiceAccount inside your cluster can use the IAM Role → no other pods can.

🟦 Example: AWS Load Balancer Controller

ServiceAccount: aws-load-balancer-controller in kube-system.

IAM Role: eks-clustername-aws-lbc.

Pod Identity: maps that role to only this ServiceAccount.

✅ Result: only the LBC pods can create/manage ALBs/NLBs.

🟩 Example: Cluster Autoscaler

ServiceAccount: cluster-autoscaler in kube-system.

IAM Role: eks-clustername-cluster-autoscaler.

Pod Identity: maps that role to only this ServiceAccount.

✅ Result: only the Cluster Autoscaler pods can scale your node groups.

🔒 Security benefit

You’re applying least privilege:

LBC can only touch load balancers & related resources.

Cluster Autoscaler can only scale node groups.

Your app pods don’t get any AWS IAM permissions unless you explicitly configure them.






*/