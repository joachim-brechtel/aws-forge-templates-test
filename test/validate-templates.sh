#!/bin/bash

TEMPLATE_FOLDER=${1:-"../templates"}
FAILED_TEMPLATES=()

for filename in ${TEMPLATE_FOLDER}/*.yaml; do
    ./validate-template.sh $(basename "${filename}")
    if [ "$?" -ne 0 ]; then
        FAILED_TEMPLATES+=${filename}
    fi
done

if [ ${#FAILED_TEMPLATES[@]} -gt 0 ]; then
    echo -e "\nFailed templates:"
    for template in "${FAILED_TEMPLATES[@]}"; do
        echo "${template}"
    done
    exit 1
fi
