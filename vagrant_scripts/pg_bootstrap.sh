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

echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get --yes update
apt-get --yes upgrade

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get --yes install postgresql-$pgver postgresql-contrib-$pgver iptables-persistent

pg_dropcluster --stop $pgver main
echo "listen_addresses = '*'" >> /etc/postgresql-common/createcluster.conf
echo "max_connections = 500" >> /etc/postgresql-common/createcluster.conf

pg_createcluster --start $pgver main
echo "host    all             all             10.0.0.14/32            md5" >> /etc/postgresql/$pgver/main/pg_hba.conf
echo "host    all             all             10.0.0.14/32            @authmethodhost@" >> /usr/share/postgresql/$pgver/pg_hba.conf.sample
echo "host    all             all             10.0.0.24/32            md5" >> /etc/postgresql/$pgver/main/pg_hba.conf
service postgresql reload

su postgres -c "psql -c \"alter user postgres with password 'password';\""
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# initialize the template database, used by fiddle databases running in this env
su postgres -c "psql postgres < /vagrant/src/main/resources/db/postgresql/initial_setup.sql"
su postgres -c "psql db_template < /vagrant/src/main/resources/db/postgresql/db_template.sql"

# Install pgmanager service
cp /vagrant/src/main/resources/db/postgresql/pgmanager/com.postgrespro.PGManager.conf /etc/dbus-1/system.d/
cp /vagrant/src/main/resources/db/postgresql/pgmanager/com.postgrespro.PGManager.service /usr/share/dbus-1/system-services/
mkdir /opt/pgmanager
cp /vagrant/src/main/resources/db/postgresql/pgmanager/pgmanager.py /opt/pgmanager/
systemctl daemon-reload

# Disable outbound network connections
iptables -t filter -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t filter -A OUTPUT -m state --state NEW -m owner --uid-owner root -j ACCEPT
iptables -t filter -A OUTPUT -m state --state NEW -o lo -j ACCEPT
iptables -t filter -A OUTPUT -m state --state NEW -j LOG --log-level warning \
  --log-prefix "Outbound connection blocked: " --log-uid
iptables -t filter -A OUTPUT -m state --state NEW -j DROP
netfilter-persistent save

# Reset ubuntu and vagrant password
getent passwd ubuntu && passwd -d ubuntu
getent passwd vagrant && passwd -d vagrant
