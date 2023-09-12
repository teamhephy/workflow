#!/bin/sh

set -e
set -x

rm -rf /tmp/oci-pull
mkdir /tmp/oci-pull

flux pull artifact \
  oci://ghcr.io/kingdonb/sites/workflow:testing \
  --output /tmp/oci-pull && \
  rsync --delete -rlv /tmp/oci-pull/site/ /usr/share/nginx/html

rm -rf /tmp/oci-pull
