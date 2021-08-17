# syntax = docker/dockerfile:1.2

FROM debian:buster

RUN apt-get update && apt-get install -y \
    autogen \
    automake \
    bash \
    bc \
    bison \
    build-essential \
    bzip2 \
    ca-certificates \
    ccache \
    chrpath \
    cpio \
    curl \
    diffstat \
    fakeroot \
    file \
    flex \
    gawk \
    git \
    gzip \
    kmod \
    libncursesw5-dev \
    libssl-dev \
    libtool \
    locales \
    lzop \
    make \
    multistrap \
    ncurses-dev \
    pkg-config \
    python \
    python3 \
    python3-pexpect \
    python3-pip \
    qemu-user-static \
    rsync \
    runit \
    socat \
    texinfo \
    u-boot-tools \
    unzip \
    vim \
    wget \
    xz-utils

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV debian_chroot debian_buster
RUN echo "PS1='\${debian_chroot}\\[\033[01;32m\\]@\\H\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> /etc/bash.bashrc
