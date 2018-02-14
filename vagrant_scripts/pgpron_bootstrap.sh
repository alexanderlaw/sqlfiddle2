#!/bin/bash

set -e

pgver_full=$1
pgver=${pgver_full%%-*}
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

echo "deb http://repo.postgrespro.ru/pgpro-$pgver_full-beta/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/postgrespro.list
wget --quiet -O - http://repo.postgrespro.ru/pgpro-$pgver-beta/keys/GPG-KEY-POSTGRESPRO | apt-key add -
apt-get --yes update
apt-get --yes upgrade

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get --yes install unzip iptables-persistent
apt-get --yes install postgrespro-$pgver postgrespro-contrib-$pgver || apt-get --yes install postgrespro-std-$pgver postgrespro-std-$pgver-contrib

echo "host    all             all             10.0.0.14/32            md5" >> /var/lib/pgpro/std-$pgver/data/pg_hba.conf
echo "host    all             all             10.0.0.14/32            @authmethodhost@" >> /opt/pgpro/std-$pgver/share/pg_hba.conf.sample

echo "listen_addresses = '*'" >> /var/lib/pgpro/std-$pgver/data/postgresql.conf
systemctl restart postgrespro-std-10.service

su - postgres -c "psql -c \"alter user postgres with password 'password';\""
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# initialize the template database, used by fiddle databases running in this env
su - postgres -c "psql postgres < /vagrant/src/main/resources/db/postgresql/initial_setup.sql"
su - postgres -c "psql db_template < /vagrant/src/main/resources/db/postgresql/db_template.sql"

# Load demo database
wget -nv https://edu.postgrespro.ru/demo_small.zip -O /tmp/demo_small.zip
unzip /tmp/demo_small.zip -d /tmp/
# Rename demo database to demo_bookings
sed -e 's/^\(DROP DATABASE\|CREATE DATABASE\) demo\b/\1 demo_bookings/' -i /tmp/demo_small.sql
sed -e 's/^\(\\connect\) demo\b/\1 demo_bookings\nset role admin;/' -i /tmp/demo_small.sql
# Load database as user "admin" to set him as owner of all the objects
su - postgres -c "psql -c \"CREATE ROLE admin WITH NOLOGIN SUPERUSER\""
su - postgres -c "psql </tmp/demo_small.sql"
rm /tmp/demo_small.zip /tmp/demo_small.sql

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
