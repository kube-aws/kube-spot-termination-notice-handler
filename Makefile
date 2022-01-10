NAME    := mattermost/kube-spot-termination-notice-handler
TAG     := 1.21.0
CHECKSUM=$(shell cat * | md5 | cut -c1-8)

.PHONY: build-image
build-image:
	docker build -t ${NAME} .

.PHONY: all
all:
	@$(MAKE) build-image
	@$(MAKE) scan
	@$(MAKE) push

.PHONY: push
push:
	@echo "The CHECKSUM of all files in this folder is ${CHECKSUM}."
	@echo "Pushing to Docker Hub..."
	docker tag ${NAME} ${NAME}:${TAG}
	docker tag ${NAME} ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:latest

.PHONY: push-tag
push-tag:
	@echo "The CHECKSUM of all files in this folder is ${CHECKSUM}."
	@echo "Pushing to Docker Hub..."
	docker tag ${NAME} ${NAME}:${TAG}
	docker tag ${NAME} ${NAME}:${TAG}_${CHECKSUM}
	docker push ${NAME}:${TAG}_${CHECKSUM}

.PHONY: scan
scan:
	docker scan ${NAME}

.PHONY: deps
deps:
	sudo apt update && sudo apt install hub git
	GO111MODULE=on go get k8s.io/release/cmd/release-notes

# Cut a release
.PHONY: release
release:
	@echo Cut a release
	bash ./scripts/release.sh
