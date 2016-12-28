#!/bin/bash
set -e

apt-get --yes install maven npm nodejs-legacy

npm install -g grunt-cli

cd /vagrant
mvn -B clean install
npm install

cd target/sqlfiddle/bin
./create-openidm-rc.sh
cp openidm /etc/init.d/
update-rc.d openidm defaults
