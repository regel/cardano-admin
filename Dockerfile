FROM debian:stable-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    gnupg2 \
    lsb-release \
    software-properties-common \
 && apt-get autoremove -y

# static cardano binaries
RUN curl -s https://update-cardano-mainnet.iohk.io/cardano-node-releases/cardano-node-1.35.4-linux.tar.gz | tar -xz -C /opt

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - \
  && apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  && apt-get -y update && apt-get install -y vault \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt"

# update permissions & change user to not run as root
WORKDIR /app

COPY ./scripts /app

RUN chgrp -R 0 /app && chmod -R g=u /app
USER 1001

