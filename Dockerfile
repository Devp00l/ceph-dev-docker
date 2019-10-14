FROM opensuse/tumbleweed
LABEL maintainer="rimarques@suse.com"

# Install all zypper dependencies
#RUN zypper -n ar https://download.opensuse.org/repositories/filesystems:/ceph:/nautilus/openSUSE_Tumbleweed/filesystems:ceph:nautilus.repo
RUN zypper --gpg-auto-import-keys ref
RUN zypper -n dup

#from current main repository Dockerfile
RUN zypper -n install \
        iproute2 net-tools-deprecated zsh lttng-ust-devel babeltrace-devel \
        bash vim tmux git aaa_base ccache wget jq google-opensans-fonts psmisc \
        python python3-pip \
        python-devel python3-devel \
        python3-bcrypt \
        python3-CherryPy \
        python3-Cython \
        python3-Jinja2 \
        python3-pecan \
        python3-PrettyTable \
        python3-PyJWT \
        python3-pylint \
        python3-pyOpenSSL \
        python3-requests \
        python3-Routes \
        attr,
        python3-Werkzeug

# temporary fix for error regarding version of tempora
RUN pip3 install tempora==1.8 backports.functools_lru_cache

RUN zypper -n install \
        librados2 \
        gcc7 gcc7-c++ libstdc++6-devel-gcc7 \
        libxmlsec1-1 libxmlsec1-nss1 libxmlsec1-openssl1 xmlsec1-devel \
        xmlsec1-openssl-devel hostname npm

# Install google chrome
RUN wget https://dl.google.com/linux/linux_signing_key.pub
RUN rpm --import linux_signing_key.pub
RUN zypper ar http://dl.google.com/linux/chrome/rpm/stable/x86_64 google
RUN zypper -n in google-chrome-stable
ENV CHROME_BIN /usr/bin/google-chrome

#Shells
RUN wget -O /root/.zshrc "https://git.grml.org/?p=grml-etc-core.git;a=blob_plain;f=etc/zsh/zshrc;hb=HEAD"
RUN echo "source /scripts/zshrc" >> /root/.zshrc
RUN echo "source /scripts/bashrc" > /etc/bash.bashrc

ENV CEPH_ROOT /ceph
ENV BUILD_DIR /ceph/build

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

VOLUME ["/ceph"]

CMD /bin/bash
