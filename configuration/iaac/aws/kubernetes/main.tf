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
    // Add other providers here if necessary
  }
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
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
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0" # Specify the module version that is compatible with your inputs

  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.21" # Use a supported version
  vpc_id          = aws_default_vpc.default.id
  subnets         = data.aws_subnet_ids.subnets.ids

  node_groups = {
    ng1 = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 3

      instance_type = "t2.micro"
      # Other required node group configurations...
    }
  }

  # Include other module configurations as necessary
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
