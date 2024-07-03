resource "null_resource" "get-kubeconfig" {

  depends_on = [aws_eks_node_group.node-groups, aws_eks_cluster.main]

  provisioner "local-exec" {
    command = <<EOF
aws eks update-kubeconfig --name "${var.env}-eks"
EOF
  }

}

data "http" "metric-server" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

data "kubectl_file_documents" "metric-server" {
  content = data.http.metric-server.body
}

resource "kubectl_manifest" "metric-server" {
  depends_on = [null_resource.get-kubeconfig]

  count     = length(data.kubectl_file_documents.metric-server.documents)
  yaml_body = data.kubectl_file_documents.metric-server.documents[count.index]
}

data "kubectl_file_documents" "cluster-autoscaler" {
  content = "${path.module}/cluster-autoscale.yaml"
}

resource "kubectl_manifest" "cluster-autoscaler" {
  depends_on = [null_resource.get-kubeconfig]

  count     = length(data.kubectl_file_documents.cluster-autoscaler.documents)
  yaml_body = templatefile(data.kubectl_file_documents.cluster-autoscaler.documents[count.index], {
    IAM_ROLE     = aws_iam_role.eks-cluster-autoscaler.arn
    CLUSTER_NAME = aws_eks_cluster.main.name
  })
}

