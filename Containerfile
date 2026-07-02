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
    swig \
    cmake \
    libftdi1-dev \
    libusb-1.0-0-dev \
    texinfo \
    python3.12 \
    python3.12-dev \
    python3-pip \
    python3-psutil \
    libpython3.12 \
    virtualenv \
    openjdk-17-jdk-headless \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libtinfo6 \
    libtbb-dev \
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
    apt-transport-https \
    coreutils \
    python3 \
    clang \
    libboost-dev \
    capnproto \
    libcapnp-dev \
    libgtest-dev \
    libspdlog-dev \
    libfmt-dev \
    libboost-iostreams-dev \
    zlib1g-dev \
    libreadline-dev \
    libedit-dev \
    libbsd-dev \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages
RUN pip install --no-cache-dir pyyaml uv "pybind11>=3.0.0" cxxheaderparser click setuptools wheel --break-system-packages

# Zephyr SDK - download, extract, and cleanup in single layer
ARG ZEPHYR_SDK_RELEASE=1.0.1

WORKDIR /opt/elements/

RUN wget -q https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    wget -q -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xJf zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz && \
    rm zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64_minimal.tar.xz

WORKDIR /opt/elements/zephyr-sdk-${ZEPHYR_SDK_RELEASE}

RUN mkdir -p gnu && \
    wget -q https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/toolchain_gnu_linux-x86_64_riscv64-zephyr-elf.tar.xz && \
    wget -q -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing && \
    tar xJf toolchain_gnu_linux-x86_64_riscv64-zephyr-elf.tar.xz -C gnu && \
    rm toolchain_gnu_linux-x86_64_riscv64-zephyr-elf.tar.xz

# OpenROAD xschem
ARG XSCHEM_RELEASE=3.4.6

WORKDIR /opt/elements/tools/

# Build xschem and cleanup source
RUN git clone --depth 1 --branch ${XSCHEM_RELEASE} https://github.com/StefanSchippers/xschem.git xschem-src && \
    cd xschem-src && \
    ./configure --prefix=/opt/elements/tools/ && \
    make && \
    make install && \
    cd .. && \
    rm -rf xschem-src

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
ARG OPENROAD_FLOW_COMMIT=8ecb57a0a7f5278d4ebbabf02851e5cd1eea7ecb

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

# Yosys with pyosys support for LibreLane
ARG YOSYS_VERSION=0.62
ARG PYOSYS_DESTDIR=/usr/local/lib/python3.12/dist-packages

WORKDIR /opt/elements/tools/

RUN rm -rf yosys
RUN git clone --depth 1 --recurse-submodules --branch v${YOSYS_VERSION} https://github.com/YosysHQ/yosys.git yosys && \
    cd yosys && \
    make \
        CC=clang CXX=clang++ \
        PRETTY=0 \
        ENABLE_READLINE=0 \
        ENABLE_EDITLINE=1 \
        ENABLE_YOSYS=1 \
        ENABLE_PYOSYS=1 \
        PYOSYS_USE_UV=0 \
        PYTHON_EXECUTABLE=/usr/bin/python3.12 \
        PYTHON_DESTDIR=${PYOSYS_DESTDIR} \
        TCL_INCLUDE=/usr/include/tcl8.6 \
        TCL_LIBS=-ltcl8.6 \
        PREFIX=/usr/local \
        -j$(nproc) && \
    make \
        ENABLE_PYOSYS=1 \
        PYTHON_DESTDIR=${PYOSYS_DESTDIR} \
        PREFIX=/usr/local \
        install && \
    python3 ./setup.py dist_info -o ${PYOSYS_DESTDIR} && \
    cd .. && \
    rm -rf yosys

# Magic VLSI layout tool for LibreLane
ARG MAGIC_VERSION=8.3.617

RUN git clone --depth 1 --branch ${MAGIC_VERSION} https://github.com/RTimothyEdwards/magic.git magic-src && \
    cd magic-src && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf magic-src

WORKDIR /opt/elements/tools/bin

ARG OPENVAF_VERSION=23_5_0

RUN wget -q https://openva.fra1.cdn.digitaloceanspaces.com/openvaf_${OPENVAF_VERSION}_linux_amd64.tar.gz && \
    tar xf openvaf_${OPENVAF_VERSION}_linux_amd64.tar.gz && \
    rm openvaf_${OPENVAF_VERSION}_linux_amd64.tar.gz

WORKDIR /opt/elements/tools/

# OpenOCD - aesc fork with SPI flash controller support
ARG OPENOCD_REPO=https://github.com/aesc-silicon/elements-openocd.git
ARG OPENOCD_BRANCH=WIP/dnltz/SPI-flash-controller

RUN git clone --recursive --branch ${OPENOCD_BRANCH} ${OPENOCD_REPO} openocd-src && \
    cd openocd-src && \
    ./bootstrap && \
    ./configure --prefix=/usr/local --enable-internal-jimtcl && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf openocd-src

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
    g++ \
    binutils \
    python3.12 \
    python3.12-dev \
    python3-pip \
    python3-psutil \
    python3-tk \
    python3-click \
    libpython3.12 \
    openjdk-17-jdk-headless \
    verilator \
    gtkwave \
    flashrom \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libtinfo6 \
    libtbb-dev \
    libncurses6 \
    ngspice \
    ninja-build \
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
    libopengl0 \
    libxpm4 \
    libjpeg-turbo8 \
    libssl3 \
    libyaml-0-2 \
    libyaml-cpp0.8 \
    libftdi1-2 \
    libusb-1.0-0 \
    libfl2 \
    libbz2-1.0 \
    libffi8 \
    libgomp1 \
    libglu1-mesa \
    libpcre2-8-0 \
    libreadline8 \
    libcapnp-dev \
    libspdlog-dev \
    libfmt-dev \
    zlib1g \
    unzip \
    tzdata \
    xterm \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && ln -s /usr/sbin/flashrom /usr/local/bin/flashrom

# Copy built artifacts from builder stage
COPY --from=builder /opt/elements /opt/elements
COPY --from=builder /opt/or-tools /opt/or-tools
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/share /usr/local/share
COPY --from=builder /usr/local/lib /usr/local/lib

RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/scalasbt-release.gpg --import && \
    chmod 644 /etc/apt/trusted.gpg.d/scalasbt-release.gpg && \
    apt-get update && apt-get install -y --no-install-recommends sbt && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/elements/

# Install KLayout
ARG KLAYOUT_VERSION=0.30.6

RUN wget -q https://www.klayout.org/downloads/Ubuntu-24/klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    apt-get update && apt-get install -y --no-install-recommends ./klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    rm klayout_${KLAYOUT_VERSION}-1_amd64.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Renode
ARG RENODE_VERSION=1.16.1

RUN wget -q https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode_${RENODE_VERSION}_amd64.deb && \
    apt-get update && apt-get install -y ./renode_${RENODE_VERSION}_amd64.deb && \
    rm renode_${RENODE_VERSION}_amd64.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python packages
ARG KLAYOUT_PY_VERSION=0.30.6
ARG COCOTB_VERSION=2.0.1
ARG PYTEST_VERSION=9.0.2
ARG CIEL_VERSION=2.4.0
ARG LIBRELANE_VERSION=3.0.2

RUN pip install --no-cache-dir \
    uv \
    klayout==${KLAYOUT_PY_VERSION} \
    cocotb==${COCOTB_VERSION} \
    pytest==${PYTEST_VERSION} \
    ciel==${CIEL_VERSION} \
    librelane==${LIBRELANE_VERSION} \
    west \
    docopt \
    jsonschema \
    pyelftools \
    pykwalify \
    packaging \
    intelhex \
    pyserial \
    --break-system-packages

# Install EDA packages via Cargo (Rust).
# Append more tools to CARGO_PACKAGES using the "<crate>@<version>" syntax,
# e.g. "gdsfill@0.1.8 othertool@1.2.3".
ARG CARGO_PACKAGES="gdsfill@0.1.8"

RUN export RUSTUP_HOME=/tmp/rustup && \
    export CARGO_HOME=/tmp/cargo && \
    export PATH="$CARGO_HOME/bin:$PATH" && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path && \
    cargo install ${CARGO_PACKAGES} --root /usr/local && \
    rm -rf "$RUSTUP_HOME" "$CARGO_HOME"

WORKDIR /opt/elements/
