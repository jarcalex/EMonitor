#!/usr/bin/perl

=head1 NAME
  
  QuickMonitor

=head1 USAGE
     [ -a action][[-c configuration_file]...]
     [-d delay][-h][-n][-v[v[...]]][-t timeout][-V]

=head1 DESCRIPTION
  QuickMonitor is designed to extract data from system and
  store statistic into RRD.

=head1 OPTIONS

  -a, --action      Define start or stop program
  -c, --conf        Define the configuration file

  -h, --help        Shows this help and exit
  -s, --show        Show configuration as loaded and exit
  -t, --timeout     KPI read timeout in seconds (Default: 5)
  -v, --verbose     Write debug info on screen

=head1 CONFIGURATION


=head1 AUTHOR

=cut

use strict;
use warnings;
use English;
use POSIX;
use Getopt::Long;
use Pod::Usage;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Configuration;
use Monitor;
use Data::Dumper;
use Log::Rolling;

my $VERSION  = "1.0.0";
my $pidfile  = "/var/run/quickmonitor.pid";
my $configuration = Configuration->new();
my $opt_help;
my $opt_action;
my $progName = "QuickMonitor";
my $TraceFile = "/var/log/quickmonitor.log";
my $outFile = "/var/log/quickmonitor.out";


# -----------------------------------------------------------------------------
# Fonction    : fctLog
# Description : Cette fonction permet d'enregistrer une ligne de log dans le 
#					 fichier de traces
# Entree(s)	  : Etape de l'action
#					Texte a mettre dans les traces
# Remarques	  : Utilise les variables log_file et debug du fichier de config
# -----------------------------------------------------------------------------
sub fctLog {
	my ($fonction, $texte, $debug) = @_;

	my $ligne	.= " ".$fonction." ";
	$ligne	.= " ".$texte."\n";
	
	my $log = Log::Rolling->new(log_file => $TraceFile, max_size => 1000);

	# $log->max_size(800);
	$log->entry($texte);

	$log->commit;
	
	if ($debug) {
		print $texte."\n";	
	}

}

# -----------------------------------------------------------------------------
# Fonction	  : fctGetDate
# Description : Cette fonction permet de retourné la date
# -----------------------------------------------------------------------------
sub fctGetDate {
	my $format = shift;
	my ($sec,$min,$hour,$mday,$mon,$year, $wday,$yday,$isdst) = localtime time;
	$year = 1900+$year;
	$mon	= (1+$mon);
	
	return sprintf("%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec) if ($format && $format == 1);
	return $sec,$min,$hour,$mday,$mon,$year,$wday,$yday;
}


# -----------------------------------------------------------------------------
# Fonction 	  : checkLockFile
# Description : verifie la presence du fichier de lock
# -----------------------------------------------------------------------------
sub checkLockFile {
	if ( ! -f $pidfile) {
		open(LOCK,">".$pidfile) or die "Creation de ".$pidfile;
		print LOCK $PID . "\n";
		close(LOCK);
	}
} # Fin checkLockFile

##################################################################################
#                               M A I N
##################################################################################

# read command lines
my $result = GetOptions ("help"         => \$opt_help,         "h" => \$opt_help,
                         "conf=s@"      => \@{$configuration->{'daemon'}->{'confFiles'}},
                         "delay=s"      => \$configuration->{'daemon'}->{'delay'},
                         "show"         => \$configuration->{'show'},
                         "timeout=s"    => \$configuration->{'daemon'}->{'timeout'},
						 "t=s"          => \$configuration->{'daemon'}->{'timeout'},
                         "action=s"     => \$opt_action,      "a=s"   => \$opt_action
						 ) or fctOptError();

Pod::Usage::pod2usage( -verbose => 1) if ( $opt_help );
   

# nom du processus qui apparaitra dans le ps
$0 = $progName;

# chargement de la configuration
$configuration->Load();

# demarrage du programme en mode demon
if ($opt_action eq 'start') {
	fctLog("Main",  "Demarrage de $progName en mode daemon");
	fctLog("Main",  "Fichier de lock associe : ".$pidfile);

	if (-f $pidfile) {
		print("Le programme tourne deja\n");
		exit;
	}

	# On se transforme en daemon
	my $child = fork();
	if ($child) { 
		exit;
	}
	fctLog("Main", "Demarrage ".$progName." - pid = $PID");

	checkLockFile();
	
	open(STDIN, '</dev/null');
	open(STDOUT, '> '.$outFile);
	open(STDERR, '>&STDOUT');
	chdir('/'); # Pour eviter de locker un FS
	
	POSIX::setsid(); # On se detache du groupe de processus actuels
	
	# pour eviter le pb de bufferisation dans les logs
	$| = 1;

	my $monitor = Monitor->new();
	
	while (1) {
		# verification que le fichier de lock est toujours positionne
		checkLockFile();
		
		$monitor->Monit($configuration, $PID);
		# attente toutes les ???
		# sleep(2);
	} # fin while (1)

} elsif ($opt_action eq 'stop') {
	#Affichage
	fctLog("Main",  "Arret de $PROGRAM_NAME en mode daemon");
	
	if (not(open(LOCK,$pidfile))) {
		fctLog("Main", "Le programme est deja arrete\n");
		exit;
	}
	
	my $pid = <LOCK>;
	chomp($pid);
	close(LOCK);
	if ($pid =~ /^\d+$/) {
		my $strMsg = "Arret du demon par kill du processus $pid\n";
		fctLog("Main", $strMsg);
		kill(SIGTERM,$pid);
		
		# suppression du fichier de lock
		unlink($pidfile) or die ("Suppression du fichier ".$pidfile);
		exit;
	} else {
		# suppression du fichier de lock
		unlink($pidfile) or die ("Suppression du fichier ".$pidfile);
		fctLog("Main", "Le fichier ".$pidfile." contenait des donnees erronees. Le programme n'a pas pu etre eteint");
		exit 1;
	}
}
