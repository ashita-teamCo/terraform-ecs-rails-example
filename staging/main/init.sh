#!/bin/bash

cd ../../modules/main && terraform init && cd ../../staging/main

terraform init
if [ -z "$(terraform workspace list | grep test)" ]; then terraform workspace new test; fi
terraform workspace select default
