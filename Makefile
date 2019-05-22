AWS_REGION?=ap-southeast-2
STACK_NAME?=SmartCheckDemo
IMAGE_REPO_NAME=smart-check-demo
PASSWORD=password
ACTIVATION_CODE=
EC2_KEY_PATH=

.PHONY: validate
validate:
	@echo Validating template
	@aws cloudformation validate-template \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	> /dev/null

.PHONY: create-stack
create-stack:
	@echo Spinning up demo cluster...
	@aws cloudformation --region ${AWS_REGION} create-stack \
	--stack-name ${STACK_NAME} \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	--parameters file://vars.json \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND > \
	/dev/null

	@aws cloudformation --region ${AWS_REGION} wait stack-create-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: check-key-provided
check-key-provided:
	@if [ -z ${EC2_KEY_PATH} ]; \
	then echo Error: The EC2_KEY_PATH variable must be defined; \
	exit 1; \
	fi;

.PHONY: get-config
get-config:
# get GetKubeConfigCommand output: https://github.com/heptio/aws-quickstart/blob/master/README.md
	@make check-key-provided

	@echo Extracting IP addresses...
	@ BASTION_PUBLIC_IP="$(shell aws cloudformation --region ${AWS_REGION} describe-stacks \
	--stack-name=${STACK_NAME} \
	--query 'Stacks[0].Outputs[?OutputKey==`BastionHostPublicIp`].OutputValue' --output text)"; \
	echo Bastion IP is $$BASTION_PUBLIC_IP; \
	MASTER_PRIVATE_IP="$(shell aws cloudformation --region ${AWS_REGION} describe-stacks \
	--stack-name=${STACK_NAME} \
	--query 'Stacks[0].Outputs[?OutputKey==`MasterPrivateIp`].OutputValue' --output text)"; \
	echo Master private IP is $$MASTER_PRIVATE_IP; \
	mkdir ${HOME}/.kube/ &>/dev/null; \
	KUBE_CFG_DIR=${HOME}/.kube/config; \
	echo Downloading Kube config file from Master node and storing it locally in $$KUBE_CFG_DIR; \
	CMD=echo scp -oStrictHostKeyChecking=no -i ${EC2_KEY_PATH} -o ProxyCommand="ssh -oStrictHostKeyChecking=no -i ${EC2_KEY_PATH} ubuntu@$$BASTION_PUBLIC_IP nc %h %p" ubuntu@$$MASTER_PRIVATE_IP:~/kubeconfig ${HOME}/.kube/config &>/dev/null;

	@sleep 10

.PHONY: setup-tiller
setup-tiller:
	@echo Setting up Tiller

	@kubectl create serviceaccount \
	--namespace kube-system \
	tiller \
	> /dev/null

	@kubectl create clusterrolebinding tiller-cluster-role \
	--clusterrole=cluster-admin \
	--serviceaccount=kube-system:tiller \
	> /dev/null

	@helm init --service-account tiller \
	> /dev/null

	@echo Sleeping for 60 seconds to allow the Tiller pod to spin up
	@sleep 60

.PHONY: install-smart-check
install-smart-check:
	@echo Installing smart-check chart
	@if [ -z ${ACTIVATION_CODE} ]; \
	then helm install \
	--name deepsecurity-smartcheck \
	--set auth.masterPassword=${PASSWORD} \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
	> /dev/null; \
	else helm install \
	--name deepsecurity-smartcheck \
	--set auth.masterPassword=${PASSWORD} \
	--set activationCode=${ACTIVATION_CODE} \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
	> /dev/null; \
	fi;

.PHONY: create-image-repo
create-image-repo:
	@echo Creating demo image repository
	@aws ecr create-repository --region ${AWS_REGION} --repository-name ${IMAGE_REPO_NAME} > /dev/null

.PHONY: delete-image-repo
delete-image-repo:
	@echo Deleting demo image repository
	@aws --region ${AWS_REGION} ecr delete-repository --repository-name ${IMAGE_REPO_NAME} --force > /dev/null

.PHONY: upload-images
upload-images:
	@echo Logging into demo image registry
	@ECR_LOGIN="$(shell aws ecr get-login --no-include-email --region ${AWS_REGION})"; \
	eval $$ECR_LOGIN > /dev/null; \
	echo Downloading buamod/eicar; \
	docker pull buamod/eicar > /dev/null; \
	EICAR_HASH="$(shell docker image ls | grep buamod/eicar | awk '{print $$3}')"; \
	echo Downloading vulnerables/web-dvwa ; \
	docker pull vulnerables/web-dvwa  > /dev/null; \
	DVWA_HASH="$(shell docker image ls | grep vulnerables/web-dvwa | awk '{print $$3}')"; \
	IMAGE_REPO_URI="$(shell aws ecr describe-repositories --output text --query 'repositories[?repositoryName==`${IMAGE_REPO_NAME}`][repositoryUri]')"; \
	sleep 5; \
	echo Tagging images; \
	docker tag $$EICAR_HASH $$IMAGE_REPO_URI:vulnerable; \
	docker tag $$DVWA_HASH $$IMAGE_REPO_URI:infected; \
	echo Uploading buamod/eicar \(vulnerable\) to demo repository; \
	docker push $$IMAGE_REPO_URI:vulnerable > /dev/null; \
	echo Uploading vulnerables/web-dvwa \(infected\) to demo repository; \
	docker push $$IMAGE_REPO_URI:infected > /dev/null;

.PHONY: get-smart-check-details
get-smart-check-details:
	@echo ----------------------------------------------------------------------------------------------------------------

	@ SMARTCHECK_URL="$(shell kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"; \
	echo Smart Check URI: https://$$SMARTCHECK_URL:443/

	@ SC_USERNAME="$(shell kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Username: $$SC_USERNAME

	@ SC_PASSWORD="$(shell kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Password: $$SC_PASSWORD

	@echo ECR Region: ${AWS_REGION}

	@ REGISTRY_ID="$(shell aws ecr describe-repositories --output text --query 'repositories[?repositoryName==`${IMAGE_REPO_NAME}`][registryId]')"; \
	echo ECR Reigstry ID: $$REGISTRY_ID

	@echo ----------------------------------------------------------------------------------------------------------------

.PHONY: start-demo
start-demo: | check-key-provided validate create-image-repo create-stack get-config setup-tiller install-smart-check upload-images get-smart-check-details

.PHONY: update-stack
update-stack:
	@echo Updating demo cluster
	@aws cloudformation --region ${AWS_REGION} update-stack \
	--stack-name ${STACK_NAME} \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	--parameters file://vars.json \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	> /dev/null

	@echo Waiting for demo cluster update to be complete
	@aws cloudformation --region ${AWS_REGION} wait stack-update-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: delete-stack
delete-stack:
	@echo Spinning down demo cluster...
	@aws cloudformation --region ${AWS_REGION} delete-stack --stack-name ${STACK_NAME} \
	> /dev/null

	@aws cloudformation --region ${AWS_REGION} wait stack-delete-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: stop-demo
stop-demo: | delete-image-repo delete-stack
