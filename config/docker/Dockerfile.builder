# ============================================================================
# Builder Dockerfile for CloudToLocalLLM
# Contains tools to build Flutter, Node.js, and sync artifacts
# ============================================================================
FROM fedora:40

USER root

RUN dnf -y update && \
    dnf -y install \
      git \
      nodejs \
      npm \
      java-devel \
      clang \
      cmake \
      ninja-build \
      pkg-config \
      gtk3-devel \
      unzip \
      which \
      curl \
      && dnf clean all

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

RUN useradd -u 1000 -m -s /bin/bash cloudtolocalllm

USER cloudtolocalllm
WORKDIR /home/cloudtolocalllm

RUN git clone https://github.com/flutter/flutter.git -b stable
ENV PATH="/home/cloudtolocalllm/flutter/bin:$PATH"
RUN flutter config --no-analytics
RUN flutter doctor

WORKDIR /app

COPY --chown=cloudtolocalllm:cloudtolocalllm scripts/build-and-sync.sh /usr/local/bin/build-and-sync.sh
RUN chmod +x /usr/local/bin/build-and-sync.sh

CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
