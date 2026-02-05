# Multi-stage build to reduce final image size
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Berlin"

# Install build dependencies in a single layer with cleanup
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    software-properties-common \
    ssh \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    time \
    libtool-bin \
    autotools-dev \
    automake \
    pkg-config \
    libyaml-dev \
    libssl-dev \
    gdb \
    ninja-build \
    flex \
    bison \
    libfl-dev \
    cmake \
    libftdi1-dev \
    python3.12 \
    python3.12-dev \
    python3-pip \
    python3-psutil \
    libpython3.12 \
    virtualenv \
    openjdk-11-jdk-headless \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libtinfo6 \
    libncurses6 \
    ngspice \
    libx11-dev \
    libxrender-dev \
    libx11-xcb-dev \
    libcairo2-dev \
    tcl8.6-dev \
    tk8.6-dev \
    libxpm-dev \
    libjpeg-dev \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages
RUN pip install --no-cache-dir pyyaml --break-system-packages

# Zephyr SDK - download, extract, and cleanup in single layer
ARG ZEPHYR_SDK_RELEASE=0.17.0

WORKDIR /opt/elements/

RUN wget -q https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    wget -q -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xJf zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    rm zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz

WORKDIR /opt/elements/zephyr-sdk-${ZEPHYR_SDK_RELEASE}

RUN wget -q https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz && \
    wget -q -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xJf toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz && \
    rm toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz

# OSS Cad Suite
ARG OSS_CAD_SUITE_YEAR=2026
ARG OSS_CAD_SUITE_MONTH=01
ARG OSS_CAD_SUITE_DAY=23
ARG OSS_CAD_SUITE_DATE="${OSS_CAD_SUITE_YEAR}-${OSS_CAD_SUITE_MONTH}-${OSS_CAD_SUITE_DAY}"
ARG OSS_CAD_SUITE_STAMP="${OSS_CAD_SUITE_YEAR}${OSS_CAD_SUITE_MONTH}${OSS_CAD_SUITE_DAY}"

WORKDIR /opt/elements/

RUN wget -q https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz && \
    tar -xzf oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz && \
    rm oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz

# OpenROAD flow scripts, xschem
ARG OPENROAD_FLOW_ORGA=The-OpenROAD-Project
ARG OPENROAD_FLOW_COMMIT=cc3eba7744b76ebe4c864d20a735e07bd7d357c6
ARG XSCHEM_RELEASE=3.4.6

WORKDIR /opt/elements/tools

# Clone with shallow history and cleanup .git
RUN git clone --depth 1 --branch ${OPENROAD_FLOW_COMMIT} --recursive https://github.com/${OPENROAD_FLOW_ORGA}/OpenROAD-flow-scripts.git || \
    (git clone --recursive https://github.com/${OPENROAD_FLOW_ORGA}/OpenROAD-flow-scripts.git && \
     cd OpenROAD-flow-scripts && \
     git checkout ${OPENROAD_FLOW_COMMIT} && \
     git submodule update --recursive --depth 1)

WORKDIR /opt/elements/tools/OpenROAD-flow-scripts/

# Build and cleanup in single layer
RUN ./tools/OpenROAD/etc/DependencyInstaller.sh -all && \
    ./build_openroad.sh --threads 16 --install-path /opt/elements/tools/ && \
    rm -rf ./tools/OpenROAD ./tools/yosys .git /tmp/* /var/tmp/* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/elements/tools/

# Build xschem and cleanup source
RUN git clone --depth 1 --branch ${XSCHEM_RELEASE} https://github.com/StefanSchippers/xschem.git xschem-src && \
    cd xschem-src && \
    ./configure --prefix=/opt/elements/tools/ && \
    make && \
    make install && \
    cd .. && \
    rm -rf xschem-src

# Final stage - copy only what's needed
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Berlin"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    time \
    make \
    python3.12 \
    python3.12-dev \
    python3-pip \
    python3-psutil \
    libpython3.12 \
    python3-click \
    openjdk-11-jre-headless \
    verilator \
    gtkwave \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libtinfo6 \
    libncurses6 \
    ngspice \
    libx11-6 \
    libxrender1 \
    libx11-xcb1 \
    libcairo2 \
    tcl8.6 \
    tk8.6 \
    tcllib \
    tcl-tclreadline \
    qt5-image-formats-plugins \
    libqt5core5a \
    libqt5gui5 \
    libqt5widgets5 \
    libqt5charts5 \
    libqt5printsupport5 \
    libxpm4 \
    libjpeg-turbo8 \
    libssl3 \
    libyaml-0-2 \
    libyaml-cpp0.8 \
    libftdi1-2 \
    libfl2 \
    libbz2-1.0 \
    libffi8 \
    libgomp1 \
    libpcre2-8-0 \
    libreadline8 \
    zlib1g \
    unzip \
    tzdata \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy built artifacts from builder stage
COPY --from=builder /opt/elements /opt/elements
COPY --from=builder /opt/or-tools /opt/or-tools
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import && \
    chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg && \
    apt-get update && apt-get install -y --no-install-recommends sbt && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/elements/

# Install KLayout
ARG KLAYOUT_VERSION=0.30.4

RUN wget -q https://www.klayout.org/downloads/Ubuntu-24/klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    rm klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages
ARG GDSFILL_VERSION=0.1.3
ARG KLAYOUT_PY_VERSION=0.30.4.post1

RUN pip install --no-cache-dir \
    gdsfill==${GDSFILL_VERSION} \
    klayout==${KLAYOUT_PY_VERSION} \
    --break-system-packages

WORKDIR /opt/elements/
