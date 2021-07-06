In This 3 tier architechture I am creating a VPC with 2 subnets in each AZ for HA.  
The First Layer contains the load balancer  to route traffic to webserver placed in private subnet and 
The Second Lyaer Contains the Web server attached to lb with an Auto Scalling Group and nginx ami baked in , where in launch configuration i am start the service so that ec2 machines are able to serve the request .
Also i am using a RDS mysql instance for the backend , placed in the private subnet to talk to our applicaiton and the password of the same is encrypted via KMS KEY.
Variables are placed in variable.tf file and Output are placed in outputs.tf file.
