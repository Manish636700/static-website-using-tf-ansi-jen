#!/bin/bash

set -e
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


echo -e "${GREEN} Terrform setup Script to Deploy static Website"

# Step 1: Get AWS Credentials and Bucket Name

read -p "Enter Aws Access Key: " AWS_ACCESS_KEY
read -p "Enter Aws Secret Key: " AWS_SECRET_KEY
read -p "Enter the Bucket name:" BUCKET_NAME
#Apply defaults

AWS_ACCESS_KEY=${AWS_ACCESS_KEY:-AKIARHFT66P3I5XIBO57}
AWS_SECRET_KEY=${AWS_SECRET_KEY:-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}
JOB_NAME=${JOB_NAME:-auto-deploy}


# Step 2 : Install Terraform if not available

if ! command -v terraform &> /dev/null; then
	echo -e "${GREEN} Installing Terraform"
	sudo apt update -y
	sudo apt install -y unzip curl
	curl -fsSL https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -o terraform.zip
	unzip terraform.zip
	sudo mv terraform /usr/local/bin/
	rm terraform.zip
fi

# Step 3 : Install Ansible if not available

if ! command -v ansible &> /dev/null; then
	echo -e "${GREEN} Installing Ansible.......${NC}"
	sudo apt update -y
	sudo apt install -y software-properties-common
	sudo add-apt-repository --yes --update ppa:ansible/ansible
	sudo apt install -y ansible
fi

# Step 4 : Export AWS credentials for Terraform

export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"

# Step 5 : Validate and update main.tf


cd ./Terraform
terraform destroy -target=aws_instance.example -auto-approve \
  -var="public_key_path=$(realpath manish-key.pub)" \
  -var="key_name=manish-key"
cd ..


KEY_NAME="manish-key"
TF_DIR="./Terraform"
KEY_PATH="$TF_DIR/$KEY_NAME"
KEY_FILE1="$HOME/$KEY_NAME.pem"

echo "Deleting existing AWS key pair (if exists)..."
aws ec2 delete-key-pair --key-name "$KEY_NAME" 2>/dev/null || true
rm -f "$KEY_PATH" "$KEY_PATH.pub" "$KEY_FILE1"

# Step: "Generating ssh key.."

mkdir -p "$TF_DIR"
ssh-keygen -t rsa -b 2048 -f "$KEY_PATH" -N "" -q

ABS_KEY_PATH="$(realpath "$KEY_PATH.pub")"


#Step: move to terraform Directory
cd "$TF_DIR"
terraform destroy -target=aws_instance.example -auto-approve \
  -var="public_key_path=$ABS_KEY_PATH" \
  -var="key_name=$KEY_NAME"


# Step: init $ Apply terraform....."
echo "initializing Terraform...."
terraform init -input=false

echo "Applying Terrafrom ..."
terraform apply -auto-approve \
        -var="public_key_path=$ABS_KEY_PATH" \
        -var="key_name=$KEY_NAME"


# step: GET PUBlic IP

PUBLIC_IP=$(terraform output -raw public_ip)
cd ..
#Step: Copy pem to root

KEY_FILE1="$HOME/$KEY_NAME.pem"

cp "$KEY_PATH" "$KEY_FILE1"
chmod 400 "$KEY_FILE1"



EC2_HOST=$PUBLIC_IP
PEM_PATH=$KEY_FILE1
EC2_USER="ubuntu"


echo "ssh -i \"$PEM_PATH\" $EC2_USER@$EC2_HOST"

echo ""
echo "✅ EC2 Instance Created!"
echo "🔑 Key File     : $KEY_FILE"
echo "🌐 Public IP    : $PUBLIC_IP"
echo "👤 EC2 Username : $EC2_USER"
echo "📁 PEM Path     : $PEM_PATH"



# Wait for EC2 to be ready before uploading Jenkinsfile
echo "Waiting for EC2 instance ($PUBLIC_IP) to become SSH-ready..."

until ssh -i ./Terraform/manish-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes ubuntu@$PUBLIC_IP 'echo SSH Ready' 2>/dev/null; do
    echo "Still waiting for SSH..."
    sleep 5
done


echo "Using EC2_HOST: $PUBLIC_IP"
scp -i ./Terraform/manish-key -o StrictHostKeyChecking=no ./Jenkinsfile ubuntu@$EC2_HOST:/home/ubuntu/


if [ ! -f main.tf ]; then
	echo -e "${RED} ❌ main.tf not found in the current directory"
	exit 1
fi

echo -e "${GREEN} updating bucket name in main.tf"
sed -i "s|bucket *= *\"[^\"]*\"|bucket = \"$BUCKET_NAME\"|" main.tf
sed -i "s|access_key *= *\"[^\"]*\"|access_key=\"$AWS_ACCESS_KEY\"|" main.tf
sed -i "s|secret_key *= *\"[^\"]*\"|secret_key=\"$AWS_SECRET_KEY\"|" main.tf

# Step 6 : Run Terraform

echo -e "${GREEN} Running Terraform to Deploy S3 bucket "
terraform init
terraform apply -lock=false -auto-approve

# step 7 : Run Ansible Playbook to Install Jenkins
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY" > jenkins_env_vars.env
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY" >> jenkins_env_vars.env
echo "S3_BUCKET=$BUCKET_NAME" >> jenkins_env_vars.env
echo "AWS_DEFAULT_REGION = us-east-1" >> jenkins_env_vars.env

echo "[jenkins]" > hosts.ini
echo "$EC2_HOST ansible_user=$EC2_USER ansible_ssh_private_key_file=$PEM_PATH" >> hosts.ini

echo -e "${GREEN} Running Ansible Playbook to Install Jenkins..........${NC}"

ansible-playbook -i hosts.ini AWS_config.yml -e "aws_access_key=$AWS_ACCESS_KEY aws_access_key $AWS_SECRET_KEY"
ansible-playbook -i hosts.ini jenkins_setup.yml -e "job_name=$JOB_NAME" 
# Step 8 : Display Website URL


echo -e "${GREEN} Deployment complete!"
echo -e "${GREEN} Youur Jenkins url is : http://$EC2_HOST:8080 ${NC}"
echo -e "${GREEN} Your website url is : http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"


URL="http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"

if command -v open &> /dev/null; then
    # macOS
    open "$URL"
elif command -v xdg-open &> /dev/null; then
    # Linux
    xdg-open "$URL"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash or Cygwin)
    start "$URL"
elif [[ "$OSTYPE" == "win32" ]]; then
    # Native Windows
    cmd.exe /C start "" "$URL"
else
    echo "Could not detect OS to auto-open browser"
fi

