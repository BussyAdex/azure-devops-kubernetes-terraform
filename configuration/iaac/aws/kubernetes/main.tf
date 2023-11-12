terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.57.0"  
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10.0" 
    }
  }
  backend "s3" {
    bucket = "terraform-backend-state-bussyadex42-123"
    key    = "kubernetes-dev.tfstate" 
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

module "bussyadex42-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.19.1"  

  cluster_name    = "bussyadex42-cluster"
  cluster_version = "1.21"  
  vpc_id          = aws_default_vpc.default.id
  subnet_ids      = data.aws_subnet_ids.subnets.ids  

  worker_groups = [
    {
      name          = "worker-group-1"
      instance_type = "t2.micro"
      asg_max_size  = 5
      asg_min_size  = 3
      
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
