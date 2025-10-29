FROM ubuntu:24.04

ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Berlin"

RUN apt-get update && apt-get install -y \
    sudo \
    software-properties-common \
    ssh \
    git \
    curl \
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
    verilator \
    gtkwave \
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
    libjpeg-dev

RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update

RUN pip install pyyaml --break-system-packages

RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list
RUN curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import
RUN chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg
RUN apt-get update && apt-get install -y sbt

# Zephyr SDK

ARG ZEPHYR_SDK_RELEASE=0.17.0

WORKDIR /opt/elements/

RUN wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xvf zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    rm zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz

WORKDIR /opt/elements/zephyr-sdk-${ZEPHYR_SDK_RELEASE}

RUN wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz && \
    wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xvf toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz && \
    rm toolchain_linux-x86_64_riscv64-zephyr-elf.tar.xz

# OSS Cad Suite

ARG OSS_CAD_SUITE_YEAR=2025
ARG OSS_CAD_SUITE_MONTH=10
ARG OSS_CAD_SUITE_DAY=08
ARG OSS_CAD_SUITE_DATE="${OSS_CAD_SUITE_YEAR}-${OSS_CAD_SUITE_MONTH}-${OSS_CAD_SUITE_DAY}"
ARG OSS_CAD_SUITE_STAMP="${OSS_CAD_SUITE_YEAR}${OSS_CAD_SUITE_MONTH}${OSS_CAD_SUITE_DAY}"

WORKDIR /opt/elements/

RUN wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz && \
    tar -xvf oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz && \
    rm oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz

# KLayout, OpenROAD flow scripts, xschem

ARG KLAYOUT_VERSION=0.30.4
ARG OPENROAD_FLOW_ORGA=The-OpenROAD-Project
ARG OPENROAD_FLOW_COMMIT=252042c9c294386a7a8594dc3465b542c0184c52
ARG XSCHEM_RELEASE=3.4.6

WORKDIR /opt/elements/

RUN wget https://www.klayout.org/downloads/Ubuntu-24/klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    sudo apt install -y ./klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    rm klayout_${KLAYOUT_VERSION}-1_amd64.deb

WORKDIR /opt/elements/tools

RUN git clone --progress --recursive https://github.com/${OPENROAD_FLOW_ORGA}/OpenROAD-flow-scripts.git && \
    cd OpenROAD-flow-scripts && \
    git checkout ${OPENROAD_FLOW_COMMIT} && \
    git submodule init && \
    git submodule update --recursive

WORKDIR /opt/elements/tools/OpenROAD-flow-scripts/

RUN ./tools/OpenROAD/etc/DependencyInstaller.sh -all
RUN ./build_openroad.sh --threads 16 --install-path /opt/elements/tools/
RUN rm -rf ./tools/OpenROAD && rm -rf ./tools/yosys && rm -rf .git

WORKDIR /opt/elements/tools/

RUN git clone https://github.com/StefanSchippers/xschem.git xschem-src && \
    cd xschem-src && \
    git checkout ${XSCHEM_RELEASE}

WORKDIR /opt/elements/tools/xschem-src/

RUN ./configure --prefix=/opt/elements/tools/ && make && sudo make install && make clean

# gdsfill

ARG GDSFILL_VERSION=0.1.3

RUN pip install gdsfill==${GDSFILL_VERSION} --break-system-packages

# Install klayout as Python package for IHP's DRC tool

ARG KLAYOUT_VERSION=0.30.4.post1

RUN pip install klayout==${KLAYOUT_VERSION} --break-system-packages

WORKDIR /opt/elements/
