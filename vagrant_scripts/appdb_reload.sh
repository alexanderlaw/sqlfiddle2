#!/bin/bash

VSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
(
cd $VSDIR/..
vagrant destroy appdb1 -f
cp backups/appdb-data/* src/main/resources/db/sqlfiddle/
vagrant up appdb1
if [ X"$1" != X"--no-password-reset" ]; then
vagrant ssh appdb1 -c "sudo sh -c \"su postgres -c \\\"echo UPDATE hosts SET admin_password=\\'password\\' | psql sqlfiddle\\\"\""
fi
)
