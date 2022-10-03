#! /bin/bash
aws --region=us-east-1 ssm get-parameters --names "vault_passwd" --query "Parameters[*].{Value:Value}" --output text