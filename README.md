# Trend Micro Smart Check Demo

Spin up test environment in order to trial Trend Micro's Smart Check product. The script creates the following:
* An EKS Cluster
* AWS ECR
* Two demo vulnerable Docker images
* Smart Check

## Pre Requisites

1. Register for a 30-day [trial licence](https://go2.trendmicro.com/geoip/trial-168).
2. Set up your [AWS profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html).
3. Create an [EC2 key](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and download it to your machine.
4. Install [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) - `sudo snap install aws-cli --classic`
5. Install [Docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/).
6. Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - `sudo snap install kubectl --classic`
7. Install [Helm](https://helm.sh/docs/using_helm/#installing-helm) - `sudo snap install helm --classic`
8. Configure Docker to run [without `sudo`](https://docs.docker.com/install/linux/linux-postinstall/)

## Demo
1. Set `AWS_PROFILE`:

	```
	export AWS_PROFILE=<profile_name>
	```

2. Configure `vars.json`.

3. Start demo: 
	```
	make start-demo EC2_KEY_PATH=</path/to/EC2/key> REGISTRY_NAME=<registry_name> ACTIVATION_CODE=<activation_code> STACK_NAME=<stack_name> REGION=<aws_region> PASSWORD=<password>
	```

	* Mandatory argument: 
		* `EC2_KEY_PATH`
	* Optional arguments: 
		* `STACK_NAME` - Default: `SmartCheckDemo`
		* `REGISTRY_NAME` - Default: `smart-check-demo`
		* `REGION` - Default: `ap-southeast-2`
		* `PASSWORD` - Default: `password`
		* `ACTIVATION_CODE` - Default: `<NONE>`

4. Set up Smart Check:
	1. Browse to the provided Smart Check URI.
	2. Authenticate with the provided username and password.
	3. Set a registry name and description.
	5. Set `Region` to `ap-southeast-2`, unless you specified a different region when running `make`.
	6. Input the provided ECR `Registry ID`.
	7. Set `Authentication Mode` to `Instance Role`.
	8. Click **Next** to get started.

5. When you're done, stop the demo:
	```
	make stop-demo
	```

**Note 1**: The Load Balancer can take a few minutes to intialise. If you cannot access the Smart Check URI after the script finishes running, continue refreshing your browser. 

**Note 2**: Sometimes the CloudFormation template fails to remove all resources. If this occurs, you'll need to manually delete the Load Balancer and VPC created by the demo.

## Example

```
$ make start-demo EC2_KEY_PATH=~/.ssh/DemoKey STACK_NAME=SmartCheckDemo2
Validating template
Creating demo registry
Spinning up demo cluster...
make[1]: Entering directory '/home/demo/smartcheck'
make[1]: Leaving directory '/home/demo/smartcheck'
Extracting IP addresses...
Bastion IP is 54.42.43.19
Master private IP is 10.0.31.10
Downloading Kube config file from Master node and storing it locally in /home/demo/.kube/config
Warning: Permanently added '54.206.40.17' (ECDSA) to the list of known hosts.
Warning: Permanently added '10.0.31.10' (ECDSA) to the list of known hosts.
kubeconfig                                                                                                                                                                                                                                100% 5402    98.7KB/s   00:00    
Setting up Tiller
Sleeping for 60 seconds to allow the Tiller pod to spin up
Installing smart-check chart
Logging into demo registry
Downloading buamod/eicar
Downloading vulnerables/web-dvwa
Tagging images
Uploading buamod/eicar (vulnerable) to demo registry
Uploading vulnerables/web-dvwa (infected) to demo registry
----------------------------------------------------------------------------------------------------------------
Smart Check URI: https://ae23478324a5c4111e9bb20028e2219c2f-75936593.ap-southeast-2.elb.amazonaws.com:443/
Smart Check Username: administrator
Smart Check Password: ke7982(2j3@#7
ECR Reigstry ID: 856284940264
----------------------------------------------------------------------------------------------------------------
```