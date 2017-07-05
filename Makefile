KUBE_VERSION ?= 1.6.4
VERSION ?= 0.9.1
REPOSITORY ?= mumoshu/kube-spot-termination-notice-handler
TAG ?= $(KUBE_VERSION)-$(VERSION)
IMAGE ?= $(REPOSITORY):$(TAG)
ALIAS ?= $(REPOSITORY):$(KUBE_VERSION)
BUILD_ROOT ?= build/$(TAG)
DOCKERFILE ?= $(BUILD_ROOT)/Dockerfile
ENTRYPOINT ?= $(BUILD_ROOT)/entrypoint.sh
DOCKER_CACHE ?= docker-cache

cross-build:
	for v in 1.6.4 1.7.0; do\
	  KUBE_VERSION=$$v sh -c 'echo Building am image targeting k8s $$KUBECTL_VERSION';\
	  KUBE_VERSION=$$v make build ;\
	done

cross-push:
	for v in 1.6.4 1.7.0; do\
	  KUBE_VERSION=$$v sh -c 'echo Pushing an image targeting k8s $$KUBECTL_VERSION';\
	  KUBE_VERSION=$$v make publish ;\
	done

clean-all:
	for v in 1.6.4 1.7.0; do\
	  KUBE_VERSION=$$v sh -c 'echo Cleaning assets targeting k8s $$KUBECTL_VERSION';\
	  KUBE_VERSION=$$v make clean ;\
	done

.PHONY: build
build: $(DOCKERFILE) $(ENTRYPOINT)
	cd $(BUILD_ROOT) && docker build -t $(IMAGE) . && docker tag $(IMAGE) $(ALIAS)

publish:
	docker push $(IMAGE) && docker push $(ALIAS)

clean:
	rm -Rf $(BUILD_ROOT)

$(DOCKERFILE): $(BUILD_ROOT)
	sed 's/%%KUBE_VERSION%%/'"$(KUBE_VERSION)"'/g;' Dockerfile.template > $(DOCKERFILE)

$(ENTRYPOINT): $(BUILD_ROOT)
	cp entrypoint.sh $(ENTRYPOINT)

$(BUILD_ROOT):
	mkdir -p $(BUILD_ROOT)

travis-env:
	travis env set DOCKER_EMAIL $(DOCKER_EMAIL)
	travis env set DOCKER_USERNAME $(DOCKER_USERNAME)
	travis env set DOCKER_PASSWORD $(DOCKER_PASSWORD)

test:
	@echo There are no tests available for now. Skipping

save-docker-cache: $(DOCKER_CACHE)
	docker save $(IMAGE) $(shell docker history -q $(IMAGE) | tail -n +2 | grep -v \<missing\> | tr '\n' ' ') > $(DOCKER_CACHE)/image-$(KUBE_VERSION).tar
	ls -lah $(DOCKER_CACHE)

load-docker-cache: $(DOCKER_CACHE)
	if [ -e $(DOCKER_CACHE)/image-$(KUBE_VERSION).tar ]; then docker load < $(DOCKER_CACHE)/image-$(KUBE_VERSION).tar; fi

$(DOCKER_CACHE):
	mkdir -p $(DOCKER_CACHE)
