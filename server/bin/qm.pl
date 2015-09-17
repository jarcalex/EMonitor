#!/usr/bin/perl

=head1 NAME
  

=head1 USAGE
     [ -b pidfile][[-c configuration_file]...]
     [-d delay][-h][-n][-v[v[...]]][-t timeout][-V]

=head1 DESCRIPTION
   is designed to extract data from system and
  store statistic into RRD.

=head1 OPTIONS

  -b, --background  Define the pid file when run in background
  -c, --conf        Define the configuration file
                     (Default: /etc/rpimonitord.conf and
                               /etc/rpimonitord.conf.d/*.conf)
  -d, --delay       Delay between check ins seconds (Default: 10)
                      Note: If you want to change the default delay, the
                      rrd file will have to be deleted rpimonitord will
                      recreate them at next startup with the new time
                      slice.
  -h, --help        Shows this help and exit
  -s, --show        Show configuration as loaded and exit
  -t, --timeout     KPI read timeout in seconds (Default: 5)
  -v, --verbose     Write debug info on screen
  -V, --Version     Show version and exit

=head1 CONFIGURATION
  Configuration can be defined into /etc/rpimonitord.conf and
  /etc/rpimonitord.conf.d/*.conf or in a list of files specified
  by -c parameter. See the /etc/rpimonitord.conf and
  /etc/rpimonitord.conf.d/default.conf files provided with at
  installation to see how to customize rpimonitord.
  Configuration defined inside a configuration file always overwrite
  default values.
  Configuration given as option of the command line always overwrite
  the one defined into a file.



=head1 AUTHOR

=cut


use strict;
# use IPC::ShareLite;
use POSIX;
use Getopt::Long;
use Pod::Usage;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Configuration;
use Monitor;
use Data::Dumper;

$|=1;
$SIG{CHLD}   = 'IGNORE';
$SIG{INT}    = sub { stop(); }; # catch Ctrl+C

my $VERSION  = "1.0.0";
our $verbose  = 0;
my $pidfile;
my $configuration = Configuration->new();
my $opt_help;




sub writePID {
  open(PID, ">> $pidfile") || die "Could not open '$pidfile' $!";
  print PID "$$\n";
  close(PID);
}

sub daemonize {
  chdir '/' or die "Can't chdir to /: $!";
#  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
#  open STDOUT, '>>/app/qm.log' or die "Can't write to /dev/null: $!";
#  open STDERR, '>>/app/qm.log' or die "Can't write to /dev/null: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  exit if $pid;
  setsid or die "Can't start a new session: $!";
  umask 0;
}


sub stop
{
  $configuration->{'daemon'}->{'delay'} = 0;
}

##################################################################################
#                               M A I N
##################################################################################

# read command lines
my $result = GetOptions ("help"         => \$opt_help,     "h" => \$opt_help,
                         "conf=s@"      => \@{$configuration->{'daemon'}->{'confFiles'}},
                         "delay=s"      => \$configuration->{'daemon'}->{'delay'},
                         "show"         => \$configuration->{'show'},
                         "timeout=s"    => \$configuration->{'daemon'}->{'timeout'},
						 "t=s"          => \$configuration->{'daemon'}->{'timeout'},
                         "background=s" => \$pidfile,      "b=s"   => \$pidfile
						 ) or fctOptError();

Pod::Usage::pod2usage( -verbose => 1) if ( $opt_help );

$configuration->Load();


$pidfile and &daemonize;

my $monitor = Monitor->new();

$monitor->Monit($configuration, "0");

exit;

my $serverpid;

my $startTime = 0;
for (;;) {
  my $currentTime=mktime(localtime());
  ( $currentTime - $startTime ) < 2 and die "Stopped because respawning too fast.\n";
  $startTime = $currentTime;
  if ( $pidfile ) {
    -f $pidfile and unlink $pidfile;
    writePID();
  }

  #Start process respawner
  if ( my $procpid = fork() ) {
    waitpid($procpid,0);
  }
  else{
    $pidfile and writePID();
    $monitor->Monit($configuration, $serverpid);
    exit(0);
  }
  $serverpid and kill (9,$serverpid);
  $configuration->{'daemon'}->{'delay'} or last; #delay == 0, it means we should stop the process.
}
