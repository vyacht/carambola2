import paramiko, base64
import time
import argparse
import telnetlib
import subprocess

import errno
from socket import error as socket_error

parser = argparse.ArgumentParser(description='prime carambola')

parser.add_argument('-c', '--configure', help='configure', action='store_true')
parser.add_argument('-u', '--update', help='upgrade', action='store_true')
parser.add_argument('-e', '--eth', help='ethernet', type=int, default=1)
parser.add_argument('-s', '--seatalk', help='seatalk', action='store_true')
parser.add_argument('-n', '--nmea0183', help='nmea0183', action='store_true')
parser.add_argument('-w', '--wifi', help='wifi', action='store_true')
parser.add_argument('-t', '--telnet', help='telnet', action='store_true')
parser.add_argument('--ssh', help='ssh', action='store_true')
parser.add_argument('--n2k', help='n2k', action='store_true')

args = parser.parse_args()

if args.configure:
    print 'configure'

if args.eth:
    print 'ethernet ' + str(args.eth)

if args.seatalk:
    print 'seatalk'

def upgradeTelnet():

    prompt = "root@carambola2:/# "

    print 'Connecting ...'
    tn = telnetlib.Telnet('192.168.1.1')

    print 'Connected ...'

    tn.write('uptime\r\n')
    print tn.read_until(prompt)
    tn.write('ls -l /tmp\r\n')
    print tn.read_until(prompt)
    tn.write("rm -f /tmp/openwrt-ar71xx-generic-carambola2-squashfs-sysupgrade.bin\r\n")
    print tn.read_until(prompt)
    tn.write("wget http://192.168.1.2/carambola2/openwrt-ar71xx-generic-carambola2-squashfs-sysupgrade.bin -P /tmp\r\n")
    print tn.read_until(prompt)
    tn.write('ls -l /tmp\r\n')
    print tn.read_until(prompt)
    tn.write('uptime\n')

    print 'Starting upgrade ...'

    tn.write("sysupgrade -v /tmp/openwrt-ar71xx-generic-carambola2-squashfs-sysupgrade.bin\r\n")
    print tn.read_until("Saving config files...")
    print tn.read_until("Sending TERM to remaining processes ...")
    print tn.read_until("Performing system upgrade...")
    print tn.read_until("Upgrade completed")

    tn.write('\x1d') 
    tn.close()

    print "done ..."


def upgrade():
    try:
        client = paramiko.SSHClient()

        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

	if args.wifi:
        	client.connect('192.168.10.1', username='root', password='admin')
	else:
        	client.connect('192.168.1.1', username='root', password='admin')

        stdin, stdout, stderr = client.exec_command('uptime')
        print stdout.read()

        # tn.write("rm -f /tmp/openwrt-ar71xx-generic-carambola2-squashfs-sysupgrade.bin\r\n")
        print "error"
        stdin, stdout, stderr = "" # client.exec_command('rm -f /tmp/openwrt-ramips-rt305x-carambola-squashfs-sysupgrade.bin')
        print stdout.read()

        stdin, stdout, stderr = "" 
        # stdin, stdout, stderr = client.exec_command('wget http://192.168.1.2/carambola/openwrt-ramips-rt305x-carambola-squashfs-sysupgrade.bin -P /tmp')
        print stdout.read()

        # stdin, stdout, stderr = client.exec_command('sysupgrade -v /tmp/openwrt-ramips-rt305x-carambola-squashfs-sysupgrade.bin')
        stdin, stdout, stderr = "" 

        # Wait for the command to terminate
        rebooting = 0
        while not stdout.channel.exit_status_ready() or rebooting:
            # Only print data if there is data to read in the channel
            if stdout.channel.recv_ready():
                buffer = stdout.channel.recv(1024) 
                print buffer 
                if "Upgrade completed" in buffer:
                    print "Upgrade completed!!!"
                    rebooting = 1
                    break

    finally:
        print "closing connection"
        client.close()


def configure():

    cmd = 'cd /www && lua /usr/sbin/vyacht-init-setup.lua --eth=1'
    if args.eth == 0:
        cmd = 'cd /www && lua /usr/sbin/vyacht-init-setup.lua --eth=0'

    if(args.eth == 2):
            cmd = 'cd /www && lua /usr/sbin/vyacht-init-setup.lua --eth=2'

    if args.n2k:
        cmd = cmd + " --n2k";
        if args.seatalk:
            cmd = cmd + " --seatalk";
        if args.nmea0183:
            cmd = cmd + " --nmea0183";

    elif args.seatalk:
        cmd = cmd + " --seatalk";

    print cmd

    
    retry = 0
    while retry < 10:
        try:
            print 'trying to connect'
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
	    if args.wifi:
        	client.connect('192.168.10.1', username='root', password='admin')
	    else:
        	client.connect('192.168.1.1', username='root', password='admin')

            print 'connected'

            stdin, stdout, stderr = client.exec_command(cmd)
            print stdout.read()
        
            break

        except socket_error as serr:
            print 'exception caught ' + `serr.errno`
            #if serr.errno != errno.ECONNREFUSED:
            #    raise serr
            time.sleep(10)

        except:
            time.sleep(10)
            print 'exception caught'

        finally:
            client.close()
            retry += 1


if args.update:

    if args.ssh:
        subprocess.call(['/usr/bin/ssh-keygen', '-f', 
                         '/home/bo/.ssh/known_hosts', '-R', '192.168.1.1'])
        upgrade()
    else:
        upgradeTelnet()

    print '... end'
    print 'waiting for reboot'

if args.update and args.configure:

    time.sleep(60)

if args.configure:

    subprocess.call(['/usr/bin/ssh-keygen', '-f', 
                     '/home/bo/.ssh/known_hosts', '-R', '192.168.1.1'])
    configure()


print 'DONE!'
