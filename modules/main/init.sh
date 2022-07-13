cd ../network && terraform init && cd ../main
cd ../alb && terraform init && cd ../main
cd ../rds && terraform init && cd ../main
cd ../elasticsearch && terraform init && cd ../main
cd ../elasti_cache && terraform init && cd ../main
cd ../cloud_front && terraform init && cd ../main
cd ../ecs && terraform init && cd ../main
cd ../s3 && terraform init && cd ../main

terraform init
