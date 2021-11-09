FROM registry.redhat.io/ubi8/ubi

ARG SNOWBALL_IP
ARG SNOWBALL_MANIFEST
ARG SNOWBALL_UNLOCK_CODE

ARG RHCOS_VER
ENV RHCOS_VER=${RHCOS_VER:-'4.8.14'}

ARG OCP_VER
ENV OCP_VER=${OCP_VER:-'4.8.16'}


# Might work with aws but untested
ENV PLATFORM='metal'

# Might be able to remove the ca-bundle arg is the trust bundle updates correctly
ENV S3="aws --profile snowballEdge --region snow  --endpoint https://${SNOWBALL_IP}:8443 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt s3"
ENV EC2="aws --profile snowballEdge --region snow --endpoint https://${SNOWBALL_IP}:8243 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt ec2"
ARG BUCKET

ENV IGN_CONFIGS='/home/danclark/openshift_clusters/snow/'
ENV IGN_BASE='/home/danclark/openshift_clusters/install-config.yaml'

ENV BOOTSTRAP_IMG='/opt/data/rhcos_4_6_8_bootstrap.img'
ENV MASTER_IMG='/opt/data/rhcos_4_6_8_master.img'

ENV MIRROR_BASE='https://mirror.openshift.com/pub/openshift-v4/x86_64'
ENV RHCOS_BASE_URL='https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/'

COPY sbe.crt /etc/pki/ca-trust/source/anchors/sbe.crt
COPY deploy_dns.sh /usr/local/bin
COPY deploy_load_balancer.sh /usr/local/bin
COPY deploy_registry.sh /usr/local/bin
COPY deploy_sbe.sh /usr/local/bin

# Install Dependencies
RUN true \
  && dnf -y update \
  && dnf -y install jq util-linux \
  && dnf clean all \
  && rm -rf /usr/share/doc /usr/share/doc-base \
    /usr/share/man /usr/share/locale /usr/share/zoneinfo \
  && true

# Install AWS SBE CLI
RUN true \
  cd /opt/ \
  curl -q -O http://snowball-client.s3-website-us-west-2.amazonaws.com/snowball-client-linux.tar.gz \
  tar -xzf snowball-client-linux.tar.gz \
  rm -f snowball-client-linux.tar.gz \
  T=$(ls -1 | grep snow) \
  ln -sf $T snowball-client-linux \
  update-ca-trust \
  update-ca-trust extract

# Install latest Butane binary to modify machineConfigs
RUN curl -o /usr/bin/butane -O https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane \
  && chmod +x /usr/bin/butane

# Install coreos-installer
RUN true \
  cd /usr/local/bin \
  curl -q -o coreos-installer $MIRROR_BASE/clients/coreos-installer/latest/coreos-installer_amd64 \
  chmod +x ./coreos-installer

# Install openshift-install / oc / kubectl
RUN true \
  curl -q -O $MIRROR_BASE/clients/ocp/$OCP_VER/openshift-client-linux-${OCP_VER}.tar.gz \
  curl -q -O $MIRROR_BASE/clients/ocp/$OCP_VER/openshift-install-linux-${OCP_VER}.tar.gz \
  tar -xzf openshift-client-linux-${OCP_VER}.tar.gz \
  tar -xzf openshift-install-linux-${OCP_VER}.tar.gz \
  rm -f README.md \
  mv oc kubectl openshift-install /usr/local/bin/ \
  chmod +x /usr/local/bin/oc /usr/local/bin/kubectl /usr/local/bin/openshift-install \
  restorecon -v /usr/local/bin/oc /usr/local/bin/kubectl /usr/local/bin/openshift-install

#WORKDIR /home/$OSCAP_USERNAME

# clean the build dir in case the user is also building SSG locally
#RUN rm -rf $OSCAP_DIR/build/*

#WORKDIR /home/$OSCAP_USERNAME/$OSCAP_DIR/build

#CMD true \
#  && cmake -DPYTHON_EXECUTABLE=/usr/bin/python3 -G Ninja .. \
#  && ninja -j $BUILD_JOBS \
#  && ctest --output-on-failure -j $BUILD_JOBS \
#  && true

