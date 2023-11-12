terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.57.0" # Choose the version that best fits your needs
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
    }
  }
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

# Only one AWS provider should be declared.
provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "default" {}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

# Remove the version from the Kubernetes provider block.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "in28minutes-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.14"
  subnets         = data.aws_subnet_ids.subnets.ids # Use the subnets from the data source
  vpc_id          = aws_default_vpc.default.id

  node_groups = {
    ng1 = {
      name             = "ng1"
      instance_type    = "t2.micro"
      asg_max_size     = 5
      asg_desired_capacity = 3
      asg_min_size     = 3
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_id
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
