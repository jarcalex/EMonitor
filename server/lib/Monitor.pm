#!/usr/bin/perl

package Monitor;
use strict;
use POSIX;
use RRDs;
use JSON;
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
our $verbose  = 0;

sub new {
  my $this = bless { }, shift;
  $this->Debug(3,"");
  # @{$this->{'files'}} = ("rrd2graph.json");
  return $this;
}

sub Debug {
  my $this = shift;
  my $level = shift;

  $level <= $verbose or return;
  print STDERR "[", strftime("%Y/%m/%d-%H:%M:%S", localtime), "] ", " " x (5-$level), (caller 1)[3], " @_\n";
}

sub Monit {
  # start main loop
  my $this = shift;
  my $configuration = shift;
  my $serverpid = shift;
  $this->Debug(2,"");
  # print "Debug: ".Dumper($configuration->{'RRD_graph'})."\n";
  
  open(FILE, "> $configuration->{'daemon'}->{'webroot'}/rrd2graph.json") or warn $!;
  print FILE encode_json \%{$configuration->{'RRD_graph'}};
  close(FILE);

  for(;;)
  {
    # Process data
    $this->Process($configuration,'RAW_DATA');

    # Store and show extracted data
    $this->Status($configuration,'RAW_DATA');

    # tempo before next process
    $configuration->{'daemon'}->{'delay'} or last;
    sleep $configuration->{'daemon'}->{'delay'};
  }
  foreach (@{$this->{'files'}}) {
    -f "$configuration->{'daemon'}->{'webroot'}/$_"
      and unlink "$configuration->{'daemon'}->{'webroot'}/$_";
  }
}

sub Process {
  my $this = shift;
  my $configuration = shift;
  my $list = shift;
  $this->Debug(2,"Processing $list");

  $this->{$list} and delete $this->{$list};
  foreach my $host ( keys %{$configuration->{$list}} ) {
    if ($configuration->{'daemon'}->{$host}) {
      $this->fctExecCMD($configuration,$host);
    }
    foreach my $kpi ( @{$configuration->{$list}->{$host}} ) {
      $kpi or next;
      
      eval {
        local $SIG{ALRM} = sub { die "Timeout\n" };
        alarm $configuration->{'daemon'}->{'timeout'};
        my $raw;
        my $code = 0;
        my $file;
        if ($kpi->{'source'} && $kpi->{'source'} ne "") {
          $file = -f $kpi->{'source'} ? $kpi->{'source'} : "$kpi->{'source'} 2>/dev/null|";
          open(FEED, $file) or die "Can't open $file because $!\n";
	  while (<FEED>) {
            next if ($code == 1);
            ($code, $raw) = Parse($kpi, $_);
            
          }
          close(FEED);
        } else {
          my @FEED = split("\n", $this->{'main'}->{$host});
          foreach my $line (@FEED) {
            next if ($code == 1);
            ($code, $raw) = Parse($kpi, $line);
          }
        }
        my $i=0;
        my @names = split(',',$kpi->{'name'});
        foreach ( @{$raw} ) {
          $this->{$list}->{$host}->{$names[$i]}=$_;
          $i++;
        }
        alarm 0;
      }
    }
  }
  delete($this->{'main'});
#  print Dumper(\$this);
}

sub Status {
  my $this = shift;
  my $configuration = shift;
  my $list = shift;
  $this->Debug(2,"");

  # add data in round robin database
  foreach my $host ( keys %{$configuration->{$list}} ) {
    foreach my $kpi ( @{$configuration->{$list}->{$host}} ) {
      foreach my $name ( split(',',$kpi->{'name'}) ) {
        if ( looks_like_number( $this->{$list}->{$host}->{$name} ) ) {
#          print "Update RRD ".$host."_$name.rrd\n";
          RRDs::update("$configuration->{'daemon'}->{'webroot'}/stat/".$host."_$name.rrd", "N:".$this->{$list}->{$host}->{$name});
#          my $ERR=RRDs::error;
        }
        else {
          print "No real update RRD: ".$host."_$name.rrd\n";
          print "Value: '".$this->{$list}->{$host}->{$name}."'\n";
          RRDs::update("$configuration->{'daemon'}->{'webroot'}/stat/".$host."_$name.rrd", "N:U");
        }
      }
    }
  }
}

sub fctExecCMD {
  my $this = shift;
  my $configuration = shift;
  my $host = shift;
  
  eval {
    local $SIG{ALRM} = sub { die "Timeout\n" };
    alarm $configuration->{'daemon'}->{'timeout'};
    my $ret = `$configuration->{'daemon'}->{$host}`;
    $this->{'main'}->{$host} = $ret;
#    print Dumper($this->{'main'}->{$host});
    alarm 0;
  }
}

sub Parse {
  my $kpi = shift;
  my $line = shift;
  my @raw;
#  print "Temp: ".$line."\n";
#  print "KPI: ".Dumper($kpi)."\n";
  if (@_ = $line =~ /$kpi->{'regexp'}/) {
    if ( $kpi->{'postprocess'} ) {
      @raw = eval( $kpi->{'postprocess'} );
    } else {
      @raw = (@_);
    } 
  }
  if($raw[0]) {
#     print "Result: ".Dumper(\@raw)."\n";
     return 1, \@raw;
  }
  return 0,  \@raw;
}

1;

