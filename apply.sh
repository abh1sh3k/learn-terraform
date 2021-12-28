#!/bin/bash

RESOURCE_GROUP_NAME="Dummy_Resource"
STORAGE_ACCOUNT_NAME="dummy"
CUSTOMER_NAME=$1
VM_SIZE=$2

if [ $CUSTOMER_NAME == "common" ]; then
    cd common
else
    mkdir -p production/${CUSTOMER_NAME}
    sed -e "s/storage_rg/${RESOURCE_GROUP_NAME}/g; s/storage_name/${STORAGE_ACCOUNT_NAME}/g; s/storage_container_name/${CUSTOMER_NAME}-tfstatefiles/g; s/storage_key/${CUSTOMER_NAME}-terraform.tfstate/g; s/vm_customer_name/${CUSTOMER_NAME}/g; s/customer_vm_size/${VM_SIZE}/g" template/main.tf > production/${CUSTOMER_NAME}/main.tf
    cd production/${CUSTOMER_NAME}
fi

# Create blob container
az storage container create --name "${CUSTOMER_NAME}-tfstatefiles" --account-name $STORAGE_ACCOUNT_NAME

terraform init
terraform apply -auto-approve