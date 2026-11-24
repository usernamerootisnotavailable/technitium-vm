FROM almalinux:10

# Tell systemd it is running inside Docker so it skips host-only setup.
ENV container=docker

# The test image intentionally contains only the systemd harness and DHCP test
# client. Roles install Podman, Technitium dependencies, and nginx.
# hadolint ignore=DL3041
RUN dnf -y install \
      bind-utils \
      dhcpcd \
      dnf-plugins-core \
      gzip \
      iproute \
      jq \
      openssh-server \
      openssl \
      policycoreutils-python-utils \
      procps-ng \
      python3 \
      sudo \
      systemd \
      tar \
      unzip \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN useradd --create-home --shell /bin/bash ansible \
    && printf 'ansible ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/ansible \
    && chmod 0440 /etc/sudoers.d/ansible \
    && install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh \
    && ssh-keygen -A \
    && systemctl enable sshd

COPY entrypoint.sh /usr/local/sbin/technitium-host-entrypoint
RUN chmod 0755 /usr/local/sbin/technitium-host-entrypoint

STOPSIGNAL SIGRTMIN+3
EXPOSE 22
ENTRYPOINT ["/usr/local/sbin/technitium-host-entrypoint"]
CMD ["/usr/sbin/init"]
