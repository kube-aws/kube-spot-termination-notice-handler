FROM python:3-alpine

ARG KUBE_VERSION=1.13.7
ENV HOME=/srv
WORKDIR /srv

RUN apk add --no-cache curl ca-certificates && \
    pip --no-cache-dir --disable-pip-version-check --quiet install awscli
RUN curl -f -s -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

# Copy entrypoint.sh
COPY entrypoint.sh .
COPY handlers .

# Set permissions on the file.
RUN chmod +x entrypoint.sh

USER nobody

CMD ["/srv/entrypoint.sh"]
