.PHONY: vendor

default: clean

aws-region ?= us-east-1

hosted-zone ?= Z2R1NCP8IR4TFQ

clean:
	@echo "Cleaning vendor and artifacts"
	rm -rf vendor/ *.zip __pycache__

vendor: requirements.txt 
	pip install -r requirements.txt --target ./vendor

zip-deps: vendor
	cd vendor && zip -r9 ../cleanup.zip *

package: zip-deps
	zip -g cleanup.zip cleanup.py

create-lambda: package
		aws lambda create-function  --function-name cleaner-lambda --zip-file fileb://cleanup.zip --runtime  python3.6 --handler cleanup.handler --role "arn:aws:iam::$(aws-account):role/$(aws-role)" --environment Variables="{CLEANUP_AWS_ACCOUNT=$(aws-account),CLEANUP_AWS_REGION=$(aws-region),CLEANUP_TASKCAT_ONLY=True,HOSTED_ZONE_ID=$(hosted-zone)}" --timeout 30

update-lambda: package
		aws lambda update-function-code  --function-name cleaner-lambda --zip-file fileb://cleanup.zip

delete-lambda:
		aws lambda delete-function --function-name cleaner-lambda

