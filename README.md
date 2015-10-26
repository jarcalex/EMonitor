# EMonitor - Easy Monitor


## Installation de l'agent

### Pre-requis

apt-get install xinetd

ou

yum install xinetd

### MEP

 service EMonitor
 
 {
 
        type           = UNLISTED
        port           = 9500
        socket_type    = stream
        protocol       = tcp
        wait           = no
        user           = root
        server         = /usr/bin/e-monitor.sh

        # configure the IP address(es) of your Nagios server here:
        #only_from      = 127.0.0.1 10.0.20.1 10.0.20.2

        # Don't be too verbose. Don't log every check. This might be
        # commented out for debugging. If this option is commented out
        # the default options will be used for this service.
        log_on_success =

        disable        = no
 }

## Installation du Collecteur

TODO
