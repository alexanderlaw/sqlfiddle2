#!/bin/bash
set -e

# initialize the sqlfiddle central database, which has all sqlfiddle-specific data structures
createdb -U postgres -E UTF8 sqlfiddle
psql -U postgres sqlfiddle < /vagrant/src/main/resources/db/sqlfiddle/schema.sql
psql -U postgres sqlfiddle < /vagrant/src/main/resources/db/sqlfiddle/data.sql

# initialize the openidm repository
psql -U postgres < /vagrant/src/main/resources/db/openidm/createuser.pgsql
psql -U openidm < /vagrant/src/main/resources/db/openidm/openidm.pgsql
