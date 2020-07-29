FROM debian:stretch

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get install -y \
    autogen \
    automake \
    bash \
    bc \
    build-essential \
    bzip2 \
    ca-certificates \
    chrpath \
    cpio \
    curl \
    diffstat \
    fakeroot \
    file \
    gawk \
    gcc-multilib \
    git \
    gzip \
    kmod \
    libncursesw5-dev \
    libtool \
    locales \
    lzop \
    make \
    multistrap \
    ncurses-dev \
    python3-pexpect \
    python3-pip \
    xterm \
    libsdl1.2-dev \
    pkg-config \
    python \
    python3 \
    qemu-user-static \
    rsync \
    runit \
    socat \
    texinfo \
    u-boot-tools \
    unzip \
    xterm \
    libsdl1.2-dev \
    vim \
    wget \
    xz-utils \
    libgmp10-dev:i386 \
    libgc-dev \
    libgc-dev:i386

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
