#!/bin/bash

set -e

pgver=$1
locale=$2
if [ ! -z $locale ]; then
    locale-gen $locale
    localectl set-locale LANG=$locale
    export LANG=$locale
fi
# create a 512mb swapfile
dd if=/dev/zero of=/swapfile1 bs=1024 count=524288
chown root:root /swapfile1
chmod 0600 /swapfile1
mkswap /swapfile1
swapon /swapfile1
echo "/swapfile1 none swap sw 0 0" >> /etc/fstab

echo "deb http://repo.postgrespro.ru/pgpro-9.6/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/postgrespro.list
wget --quiet -O - http://repo.postgrespro.ru/pgpro-9.6/keys/GPG-KEY-POSTGRESPRO | apt-key add -
apt-get --yes update
apt-get --yes upgrade
apt-get --yes install postgrespro-$pgver postgrespro-contrib-$pgver

pg_dropcluster --stop $pgver main
echo "listen_addresses = '*'" >> /etc/postgresql-common/createcluster.conf
echo "max_connections = 500" >> /etc/postgresql-common/createcluster.conf

pg_createcluster --start $pgver main -- --auth-local=trust
echo "host    all             all             10.0.0.14/32            md5" >> /etc/postgresql/$pgver/main/pg_hba.conf
echo "host    all             all             10.0.0.24/32            md5" >> /etc/postgresql/$pgver/main/pg_hba.conf
service postgresql reload

echo "alter user postgres with password 'password';" | psql -U postgres
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# initialize the template database, used by fiddle databases running in this env
psql -U postgres postgres < /vagrant/src/main/resources/db/postgresql/initial_setup.sql
psql -U postgres db_template < /vagrant/src/main/resources/db/postgresql/db_template.sql
