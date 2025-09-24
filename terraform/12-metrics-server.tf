resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_node_group.general]
}


/*

metrics-server collects CPU and memory metrics from Kubernetes nodes and pods.
It’s required for Horizontal Pod Autoscaling (HPA).
Helm installs it in the kube-system namespace (system components namespace).
values contains custom configuration for metrics-server.
depends_on ensures it only installs after EKS nodes are ready.

*/


