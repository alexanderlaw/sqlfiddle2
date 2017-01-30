#!/bin/bash
set -e

# initialize the sqlfiddle central database, which has all sqlfiddle-specific data structures
su postgres -c "createdb -E UTF8 sqlfiddle"
su postgres -c "psql sqlfiddle < /vagrant/src/main/resources/db/sqlfiddle/schema.sql"
su postgres -c "psql sqlfiddle < /vagrant/src/main/resources/db/sqlfiddle/data.sql"

# initialize the openidm repository
su postgres -c "psql < /vagrant/src/main/resources/db/openidm/createuser.pgsql"
su postgres -c "echo 'set role openidm;' | cat - /vagrant/src/main/resources/db/openidm/openidm.pgsql | psql openidm"
