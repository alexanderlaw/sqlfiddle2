#!/bin/bash

VSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
(
cd $VSDIR/..
vagrant ssh appdb1 -c "sudo sh -c \"rm -rf /vagrant/backups/appdb-data; mkdir -p /vagrant/backups/appdb-data & su postgres -c 'cd /vagrant/backups/appdb-data && pg_dump -s sqlfiddle >schema.sql && pg_dump -a sqlfiddle > data.sql'\""
)
