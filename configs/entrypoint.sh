#!/bin/sh

nx_conf=/etc/nginx/nginx.conf

AWS_IAM='http://169.254.169.254/latest/dynamic/instance-identity/document'
AWS_FOLDER='/root/.aws'

region_config() {
  echo "[default]" > ${AWS_FOLDER}/config
  echo "region = $@" >> ${AWS_FOLDER}/config
}

mkdir -p ${AWS_FOLDER}
chmod 700 ${AWS_FOLDER}

if [[ "$REGION" != "" ]]; then
    region_config $REGION

# check if the region can be pulled from AWS IAM
elif wget -q -O- ${AWS_IAM} | grep -q 'region'; then
    REGION=$(wget -q -O- ${AWS_IAM} | grep 'region'|cut -d'"' -f4)
    region_config $REGION

else
    echo "No region detected"
    exit 1
fi

# fix the permissions
chmod 600 -R ${AWS_FOLDER}/config

# update the auth token
aws_cli_exec=$(aws ecr get-login --no-include-email)
auth=$(grep  X-Forwarded-User ${nx_conf} | awk '{print $4}'| uniq|tr -d "\n\r")
token=$(echo "${aws_cli_exec}" | awk '{print $6}')
auth_n=$(echo AWS:${token}  | base64 |tr -d "[:space:]")
reg_url=$(echo "${aws_cli_exec}" | awk '{print $7}')

sed -i "s|${auth%??}|${auth_n}|g" ${nx_conf}
sed -i "s|REGISTRY_URL|$reg_url|g" ${nx_conf}

/renew_token.sh &

exec "$@"

