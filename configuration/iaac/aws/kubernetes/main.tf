# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-in28minutes-123
# AKIA4AHVNOD7OOO6T4KI
# arn:aws:s3:::terraform-backend-state-bussyadex42-123
# AKIAQRIH25L6N6CH34MJ

terraform {
  backend "s3" {
    bucket = "mybucket"
    key    = "path/to/my/key" 
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint #module.in28minutes-cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

module "bussyadex42-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "bussyadex42-cluster"
  cluster_version = "1.14"
  subnet_ids      = ["subnet-02cdd8da9556ba2ef", "subnet-0e5f34ce7408c50e1"]
  vpc_id          = aws_default_vpc.default.id

  node_group = [
    {
      instance_type = "t2.micro"
      max_capacity  = 5
      desired_capacity = 3
      min_capacity  = 3
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.bussyadex42-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.bussyadex42-cluster.cluster_id
}

resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}