resource "aws_ecr_repository" "this" {
  name = "example_project"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "nginx" {
  name = "nginx"

  image_scanning_configuration {
    scan_on_push = true
  }
}
