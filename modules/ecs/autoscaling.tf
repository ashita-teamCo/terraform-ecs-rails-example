resource "aws_appautoscaling_target" "batch" {
  min_capacity = var.asc_batch_min_count
  max_capacity = var.asc_batch_max_count
  resource_id = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.batch.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "batch" {
  name = "autoscaling_batch"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.batch.resource_id
  scalable_dimension = aws_appautoscaling_target.batch.scalable_dimension
  service_namespace = aws_appautoscaling_target.batch.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.asc_batch_target
  }
}

resource "aws_appautoscaling_target" "app" {
  min_capacity = var.asc_app_min_count
  max_capacity = var.asc_app_max_count
  resource_id = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "app" {
  name = "autoscaling_app"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.asc_app_target
  }
}
