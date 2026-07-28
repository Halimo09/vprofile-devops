login:
	bash scripts/login-ecr.sh

build:
	bash scripts/build-all.sh

push:
	bash scripts/push-all.sh

deploy:
	bash scripts/deploy.sh

clean:
	bash scripts/clean.sh
