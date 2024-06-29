output "public_subnet_ids" {
  value = [ for s in aws_subnet.public: s.id ]
}

output "private_subnet_ids" {
  value = [ for s in aws_subnet.private: s.id ]
}

output "cluster_sg_id" {
  value = aws_security_group.cluster.id
}

output "worker_sg_id" {
  value = aws_security_group.worker.id
}