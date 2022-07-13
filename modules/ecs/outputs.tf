output "clusters" {
  value = aws_ecs_cluster.this
}

output "task_def_app" {
  value = data.template_file.task_definitions_app.rendered
}

output "task_def_batch" {
  value = data.template_file.task_definitions_batch.rendered
}

output "alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.batch_task_count.alarm_name
  ]
}

output "event_role" {
  value = aws_iam_role.ecs_events
}
