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

apt-get --yes update
#apt-get --yes upgrade

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get --yes install ssl-cert
apt-get --yes install unzip iptables-persistent


apt-get --yes install gcc make flex bison perl zlib1g-dev libreadline-dev libsystemd-dev libxml2-dev libossp-uuid-dev

cd /home/vagrant
tar fax src/postgres*.tgz
chown -R vagrant:vagrant postgres*/
(
cd postgres*/
su vagrant -c "./configure --with-systemd --with-libxml --with-uuid=ossp && make && make -C contrib"
make install
make install -C contrib
)
adduser --system --quiet --group --gecos "PostgreSQL administrator" --shell /bin/bash postgres
chown -R postgres:postgres /usr/local/pgsql
export BINDIR=/usr/local/pgsql/bin
export PATH=$BINDIR:$PATH
export PGDATA=/usr/local/pgsql/data

echo "PATH=\$PATH:/usr/local/pgsql/bin" >/etc/profile.d/posgres-bin-path.sh

cat << EOF >> /lib/systemd/system//postgresql.service
[Unit]
Description=PostgreSQL database server
Documentation=man:postgres(1)

[Service]
Type=notify
User=postgres
ExecStart=$BINDIR/postgres -D $PGDATA
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo "host    all             all             10.0.0.14/32            md5" >> /usr/local/pgsql/share/pg_hba.conf.sample
echo "listen_addresses = '*'" >> /usr/local/pgsql/share/postgresql.conf.sample
echo "max_connections = 500" >> /usr/local/pgsql/share/postgresql.conf.sample

sudo -u postgres $BINDIR/initdb --auth-local=peer --auth-host=md5 -D $PGDATA

systemctl enable postgresql
systemctl start postgresql

su postgres -lc "psql -c \"alter user postgres with password 'password';\""
iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# initialize the template database, used by fiddle databases running in this env
su postgres -lc "psql postgres < /vagrant/src/main/resources/db/postgresql/initial_setup.sql"
su postgres -lc "psql db_template < /vagrant/src/main/resources/db/postgresql/db_template.sql"

# Load demo database
wget -nv https://edu.postgrespro.ru/demo_small.zip -O /tmp/demo_small.zip
unzip /tmp/demo_small.zip -d /tmp/
# Rename demo database to demo_bookings
sed -e 's/^\(DROP DATABASE\|CREATE DATABASE\) demo\b/\1 demo_bookings/' -i /tmp/demo_small.sql
sed -e 's/^\(\\connect\) demo\b/\1 demo_bookings\nset role admin;/' -i /tmp/demo_small.sql
# Load database as user "admin" to set him as owner of all the objects
su postgres -lc "psql -c \"CREATE ROLE admin WITH NOLOGIN SUPERUSER\""
su postgres -lc "psql </tmp/demo_small.sql"
rm /tmp/demo_small.zip /tmp/demo_small.sql

# Load json_test database
(cd /tmp
wget -nv http://oc.postgrespro.ru/index.php/s/MM2kmGri125U4UF/download -O json_test.zip
unzip json_test.zip -d json_test
sed -e 's/^\(\\connect json_test\)\b/\1\nset role admin;/' -i json_test/json_test-db.sql
su postgres -lc "psql </tmp/json_test/json_test-db.sql"
rm -rf json_test.zip json_test
)

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
