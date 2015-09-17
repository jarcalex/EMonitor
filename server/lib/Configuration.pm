#!/usr/bin/perl

package Configuration;
use strict;
use POSIX;
use Cwd 'abs_path';
use Data::Dumper;
our $verbose  = 0;
sub new
{
  my $this = bless { }, shift;
  $this->Debug(3,"");
  $this->{'RRD_graph'}=();
  $this->{'daemon'}->{'confFiles'} = [];
  return $this;
}

sub Debug
{
  my $this = shift;
  my $level = shift;

  $level <= $verbose or return;
  print STDERR "[", strftime("%Y/%m/%d-%H:%M:%S", localtime), "] ", " " x (5-$level), (caller 1)[3], " @_\n";
}

sub Load
{
  my $this = shift;
  $this->Debug(2,"");

  $_ = abs_path($0);
  my ($path,$file) = /(.*)\/([^\/]*)$/;

  if ( scalar(@{$this->{'daemon'}->{'confFiles'}}) == 0 ) {
    push (@{$this->{'daemon'}->{'confFiles'}}, '/opt/valhalla/QuickMonitor/etc/daemon.yml');
    @{$this->{'daemon'}->{'confFiles'}} = ( @{$this->{'daemon'}->{'confFiles'}}, glob "/opt/valhalla/QuickMonitor/conf.d/*.yml" ) ;
  }
  my %global;
  foreach ( @{$this->{'daemon'}->{'confFiles'}} ) {
    use YAML::XS qw/LoadFile/;

	my %configContent = LoadFile( $_ );
	# print "All  ".Dumper(\%configContent)."\n";
	foreach my $key (keys %configContent) {
		$this->{$key} = $configContent{$key};
		# print "Key: ".$key."  ".Dumper($configContent{$key})."\n";
  
		
	}
  }
  # print Dumper($this)."\n";
  
  # Set version (used by web pagescache mechanism)
  $this->{'version'} = localtime();

  # Load default values is not defined yet defined
  $this->{'daemon'}->{'user'}        ||= "pi";
  $this->{'daemon'}->{'group'}       ||= "pi";
  -d "$path/web" and $this->{'daemon'}->{'webroot'}     ||= "$path/web";
  $this->{'daemon'}->{'webroot'}     ||= "/usr/share/rpimonitor/web";
  $this->{'daemon'}->{'delay'}       ||= 10;
  $this->{'daemon'}->{'timeout'}     ||= 5;
  # $this->{'daemon'}->{'sharedmemkey'}||= 20130906;

  # Check user and group
  $this->{'daemon'}->{'gid'} = getgrnam($this->{'daemon'}->{'user'})  || 1000;
  $this->{'daemon'}->{'uid'} = getpwnam($this->{'daemon'}->{'group'}) || 1000;

  # Check rrd directory and files and create them if they are missing
  # construct the list of rrd page accessible
  -d "$this->{'daemon'}->{'webroot'}/stat" or mkdir "$this->{'daemon'}->{'webroot'}/stat";
  -f "$this->{'daemon'}->{'webroot'}/stat/empty.rrd" or $this->CreateRRD( "$this->{'daemon'}->{'webroot'}/stat/empty.rrd", 'empty', 'GAUGE', 'U', 'U' );

  #die Data::Dumper->Dump([$this->{'rrd'}]);

  # manage rrds
  foreach my $Host (sort keys %{$this->{'RAW_DATA'}}){
    foreach (@{$this->{'RAW_DATA'}->{$Host}}){
      my @name = split (',',$_->{'name'});
      my $type = $_->{'rrd'};
      my $min = defined($_->{'min'}) ? $_->{'min'} : "U";
      my $max = defined($_->{'max'}) ? $_->{'max'} : "U";
      foreach (@name) {
        my $filename="$this->{'daemon'}->{'webroot'}/stat/".$Host."_$_.rrd";
        -f "$filename" or $this->CreateRRD($filename,$_,$type,$min,$max);
        push(@{$this->{'rrdlist'}},"stat/".$Host."$_.rrd");
      }
    }
  }
  #print Data::Dumper->Dump([$this->{'web'}]);

  # manage menu
  # foreach (@{$this->{'web'}->{'status'}}) {
    # $_->{'name'} and push(@{$this->{'menu'}->{'status'}}, $_->{'name'});
  # }
  # foreach (@{$this->{'web'}->{'statistics'}}) {
    # $_->{'name'} and push(@{$this->{'menu'}->{'statistics'}}, $_->{'name'});
  # }

  # $this->{'sharedmem'} = IPC::ShareLite->new(
        # -key     => $this->{'daemon'}->{'sharedmemkey'},
        # -create  => 'yes',
        # -destroy => 'no'
    # ) or die $!;

  if ( $this->{'show'} ) {
    die Data::Dumper->Dump([$this]);
  }
}

sub CreateRRD
{
  my $this = shift;
  my $filename = shift;
  my $name = shift;
  my $type = shift;
  my $min = shift;
  my $max = shift;
  $this->Debug(2,"$filename - $name - $type - $min < value < $max");

  my $current = time();
  my $start = $current - 60;

  $this->Debug(2,"$filename",
                "--start", $start,
                "--step", $this->{'daemon'}->{'delay'},
                "DS:$name:$type:600:$min:$max",
                "RRA:AVERAGE:0.5:1:360",    # 1 day with interval of 10sec
                "RRA:AVERAGE:0.5:6:360",    # 2 day with interval of 1min
                "RRA:AVERAGE:0.5:60:360",   # 2 week with interval of 10min
                "RRA:AVERAGE:0.5:180:360",  # 1 mounth with interval of 30min
                "RRA:AVERAGE:0.5:360:360"   # 1 year with interval of 1hour
                );

  RRDs::create( "$filename",
                "--start", $start,
                "--step", $this->{'daemon'}->{'delay'},
                "DS:$name:$type:600:$min:$max",
                "RRA:AVERAGE:0.5:1:360",    # 1 day with interval of 10sec
                "RRA:AVERAGE:0.5:6:360",    # 2 day with interval of 1min
                "RRA:AVERAGE:0.5:60:360",   # 2 week with interval of 10min
                "RRA:AVERAGE:0.5:180:360",  # 1 mounth with interval of 30min
                "RRA:AVERAGE:0.5:360:360"   # 1 year with interval of 1hour
                );
}

1;
