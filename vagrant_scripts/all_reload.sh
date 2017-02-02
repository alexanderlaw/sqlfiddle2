#!/bin/bash

VSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
(
cd $VSDIR/..
vagrant destroy -f
rm -rf .vagrant
vagrant_scripts/appdb_reload.sh
vagrant up
)
