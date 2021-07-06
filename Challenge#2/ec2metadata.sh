#!/bin/bash
sudo yum install jq -y
region_name=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region`
echo "region name is $region_name"

