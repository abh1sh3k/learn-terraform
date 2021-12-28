#!/bin/bash

CUSTOMER_NAME=$1

if [ $CUSTOMER_NAME == "common" ]; then
    cd common
else
    cd production/${CUSTOMER_NAME}
fi
terraform destroy -auto-approve