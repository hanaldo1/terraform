output "cluster_arn" {
  value = aws_eks_cluster.common.arn
}

output "cluster_name" {
  value = aws_eks_cluster.common.name
}