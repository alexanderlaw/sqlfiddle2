#!/bin/bash
set -e

# create a 512mb swapfile
dd if=/dev/zero of=/swapfile1 bs=1024 count=524288
chown root:root /swapfile1
chmod 0600 /swapfile1
mkswap /swapfile1
swapon /swapfile1
echo "/swapfile1 none swap sw 0 0" >> /etc/fstab


export OPENIDM_OPTS="-Xms1024m -Xmx1280m"
export JAVA_OPTS="-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.port=9010 \
-Dcom.sun.management.jmxremote.local.only=true \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false"

echo "export OPENIDM_OPTS=\"${OPENIDM_OPTS}\"" >> /etc/profile
echo "export JAVA_OPTS=\"${JAVA_OPTS}\"" >> /etc/profile

echo "10.0.0.14 openidm1" >> /etc/hosts
echo "10.0.0.24 openidm2" >> /etc/hosts
echo "10.0.0.16 OPENIDM_REPO_HOST" >> /etc/hosts
echo "10.0.0.16 SQLFIDDLE_HOST" >> /etc/hosts
echo "10.0.0.95 POSTGRESQL95_HOST" >> /etc/hosts
echo "10.0.0.96 POSTGRESQL96_HOST" >> /etc/hosts
echo "10.0.0.196 POSTGRESPRO96_HOST" >> /etc/hosts

apt-get --yes update
apt-get --yes upgrade

apt-get --yes install openjdk-8-jdk varnish

cp /vagrant/src/main/resources/varnish/default.vcl /etc/varnish
