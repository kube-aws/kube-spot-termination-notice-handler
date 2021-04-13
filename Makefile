NAME    := kubeaws/kube-spot-termination-notice-handler
TAG     := 1.21.0
CHECKSUM=$(shell cat * | md5 | cut -c1-8)

build:
	docker build -t ${NAME} .
all:
	@$(MAKE) build
	@$(MAKE) scan
	@$(MAKE) push
push:
	@echo "The CHECKSUM of all files in this folder is ${CHECKSUM}."
	@echo "Pushing to Docker Hub..."
	docker tag ${NAME} ${NAME}:${TAG}
	docker tag ${NAME} ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:latest
push-tag:
	@echo "The CHECKSUM of all files in this folder is ${CHECKSUM}."
	@echo "Pushing to Docker Hub..."
	docker tag ${NAME} ${NAME}:${TAG}
	docker tag ${NAME} ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:${TAG}_${CHECKSUM}
scan:
	docker scan ${NAME}
