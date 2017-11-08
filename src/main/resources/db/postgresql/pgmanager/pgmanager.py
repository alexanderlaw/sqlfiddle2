#! /usr/bin/env python3

# D-Bus Server -- System Bus

from gi.repository import GLib
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
import json
import os
import crypt
import subprocess
import signal
import re
import random
import socket

class System_DBus(dbus.service.Object):

    def __init__(self):
        bus_name = dbus.service.BusName('com.postgrespro.PGManager', bus=dbus.SystemBus())
        dbus.service.Object.__init__(self, bus_name, '/com/postgrespro/PGManager')

    def generatePassword(self):
        length = 10
        chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return ''.join(random.choice(chars) for _ in range(length))

    def getFreePort(self):
        port = 0
        numTries = 10
        while numTries > 0:
            numTries -= 1
            port = random.randint(40000, 49999)
            tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                tcp.bind(('', port))
                break
            except OSError:
                if numTries == 0:
                    raise Exception("Could not choose a port number.")
            finally:
                tcp.close()
        return port

    @dbus.service.method('com.postgrespro.PGManager')
    def CreateCluster(self, username):
        username = str(username)
        version_output = ''
        try:
            version_output = subprocess.check_output(
                "perl -e \"use PgCommon; print join('\n', get_versions())\"",
                stderr=subprocess.STDOUT, shell=True)
        except subprocess.CalledProcessError as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({
                "error": ('get_versions failed: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace')))});
        pg_version = version_output.decode('utf-8').split('\n')[0]

        program_path = ''
        try:
            program_path = subprocess.check_output(
                "perl -e \"use PgCommon; print get_program_path '', '%s';\"" % pg_version,
                stderr=subprocess.STDOUT, shell=True)
        except subprocess.CalledProcessError as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({
                "error": ('get_program_path failed: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace')))});

        program_path = program_path.decode('utf-8')
        if program_path == '':
            return json.JSONEncoder(ensure_ascii=False).encode({
                "error": ('unable to get program path for postgres version: %s' % (pg_version))});

        password = self.generatePassword()
        encPass = crypt.crypt(password,"22")
        try:
            subprocess.check_output(
                ['/usr/sbin/useradd', username, '-m', '-p', '"' + encPass + '"'],
                stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({
                "error": ('useradd failed: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace')))});


        port_number = 0
        postgres_password = self.generatePassword()
        try:
            passfile = os.path.expanduser("~%s/.postgres.pass" % username)
            with open(passfile, "w") as fpass: fpass.write(postgres_password)

            port_number = self.getFreePort()
        except Exception as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({"error": ('preparation failed: %s' % (str(ex)))})

        db_path = os.path.expanduser("~%s/pgdb" % username)
        try:
            output = subprocess.check_output([
                '/bin/su', username, '-l',  '-c',
                """
rm  -rf /tmp/pg_{2}.log /tmp/{2}; \
{0}initdb --auth=md5 --username=postgres --pwfile={3} {1} && \
mkdir /tmp/{2} && \
{0}pg_ctl start -w -t 10 -D {1} -o "--listen_addresses='*' -p {4} -k /tmp/{2}" >/tmp/pg_{2}.log""" \
                .format(program_path, db_path, username, passfile, port_number)], stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({"error": ('initdb & start failed: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace')))});

        os.remove(passfile)
        return json.JSONEncoder(ensure_ascii=False).encode({"result":
                                         {"user_name":  username,
                                          "os_user_password": password,
                                          "postgres_password": postgres_password,
                                          "pg_version": pg_version,
                                          "program_path": program_path,
                                          "db_path": db_path,
                                          "port_number": port_number
                                          }});

    @dbus.service.method('com.postgrespro.PGManager')
    def DropCluster(self, username, program_path):
        messages = ''
        db_path = os.path.expanduser("~%s/pgdb" % username)
        if program_path != '':
            try:
                output = subprocess.check_output([
                    '/bin/su', username, '-l',  '-c',
                    """{0}pg_ctl stop -w -t 10 -D {1} -m immediate && rm -rf /tmp/{2}""" \
                    .format(program_path, db_path, username)],
                    stderr=subprocess.STDOUT)
                messages += 'pg_ctl returned: ' + output.decode('utf-8')
            except subprocess.CalledProcessError as ex:
                messages += 'pg stop failed with messages: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace'))

        try:
            subprocess.check_output(['/usr/sbin/userdel', username, '-f', '-r'], stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as ex:
            return json.JSONEncoder(ensure_ascii=False).encode({"error": ('userdel failed: %s (%s)' % (str(ex), ex.output.decode('utf-8', 'backslashreplace'))) });

        return json.JSONEncoder(ensure_ascii=False).encode({"result": {"removed_user_name" : username,
                                                     "messages": messages} });

DBusGMainLoop(set_as_default=True)
dbus_service = System_DBus()

try:
    GLib.MainLoop().run()
except KeyboardInterrupt:
    print("\nThe MainLoop will close...")
    GLib.MainLoop().quit()
