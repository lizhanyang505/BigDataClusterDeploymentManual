#!/bin/bash
SERVERS="cdh1 cdh2 cdh3 cdh4 cdh5"
PASSWD="111111"

function sshcopyid
{
cd ~
pwd
    expect -c "
        set timeout -1;
        spawn ssh-copy-id -i /app/hadoop/.ssh/id_rsa.pub $1;
        expect {
            \"yes/no\" { send \"yes\r\" ;exp_continue; }
            \"password:\" { send \"$PASSWD\r\";exp_continue; }
        };
        expect eof;
    "
}
for server in $SERVERS
do
    sshcopyid $server

done
