ARG BASE_IMAGE
FROM $BASE_IMAGE AS build

FROM debian:11

RUN apt-get update && apt-get install -yq \
  qemu-utils \
  dosfstools \
  parted \
  kpartx \
  mtools \
  shim-signed shim-unsigned

COPY grub.cfg /mkimage.grub.cfg

ARG BASE_IMAGE
RUN echo "Cache bust value (base image tag): ${BASE_IMAGE}"

COPY --from=build / /mkimage
COPY mkimage.sh /
RUN chmod +x /mkimage.sh
RUN /mkimage.sh