.PHONY: vendor

default: clean

clean:
	@echo "Cleaning vendor and artifacts"
	rm -rf vendor/ *.zip __pycache__

vendor: requirements.txt 
	pip install -r requirements.txt --target ./vendor

zip-deps: vendor
	cd vendor && zip -r9 ../cleanup.zip *

package: zip-deps
	zip -g cleanup.zip cleanup.py

upload: package
		aws lambda create-function  --function-name cleaner-lambda --zip-file fileb://cleanup.zip --runtime  python3.6 --handler cleanup.cleanup --role "arn:aws:iam::$(aws-account):role/$(aws-role)"

update: package
		aws lambda update-function-code  --function-name cleaner-lambda --zip-file fileb://cleanup.zip

delete-lambda:
		aws lambda delete-function --function-name cleaner-lambda

