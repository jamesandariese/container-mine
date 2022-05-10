FROM debian:11

RUN apt-get -q update
RUN apt-get install --no-install-recommends -yq linux-image-cloud-amd64
RUN apt-get install --no-install-recommends -yq systemd-sysv
RUN apt-get install --no-install-recommends -yq iproute2
RUN apt-get install --no-install-recommends -yq iputils-ping
RUN apt-get install --no-install-recommends -yq bash
RUN apt-get install --no-install-recommends -yq neovim
RUN apt-get install --no-install-recommends -yq strace
RUN apt-get install --no-install-recommends -yq less
RUN apt-get install --no-install-recommends -yq dbus-user-session
RUN apt-get install --no-install-recommends -yq hyperv-daemons
RUN apt-get install --no-install-recommends -yq openssh-server openssh-client
RUN mkdir -p /root/.ssh
COPY root_authorized_keys /root/.ssh/authorized_keys
RUN chown -R root:root /root
RUN chmod 600 /root/.ssh/authorized_keys
RUN mkdir -p /etc/systemd/network
COPY 99-dhcp.network /etc/systemd/network/
RUN echo '/dev/sda1 / auto defaults 0 1' > /etc/fstab
RUN systemctl enable systemd-networkd
RUN systemctl enable systemd-resolved
RUN systemctl enable ssh
RUN systemctl enable dbus
RUN systemctl enable getty@ttyS0

RUN printf '%s\n' root root | passwd
