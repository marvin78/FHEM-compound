# $Id: 98_compound.pm  $

package main;

use strict;
use warnings;
use Time::Local;
use Data::Dumper; 

#######################
# Global variables
my $version = "0.9.4.2";

my %gets = (
  "version:noArg"     => "",
  #"status:noArg"     => "",
); 

## define variables for multi language
my %compound_transtable_EN = ( 
  "month"             =>  "Month",
  "light"             =>  "Light",
  "heating"           =>  "Heating",
  "camera"            =>  "Camera",
  "cooling"           =>  "Cooling",
  "schedule"          =>  "Schedule",
  "overview"          =>  "Overview",
  "animals"           =>  "Animals",
  "state"             =>  "State",
  "place"             =>  "Place",
  "temp"              =>  "Temp",
  "hum"               =>  "Hum",
  "attention"         =>  "Attention",
  "deviceaccplan"     =>  "Device acts according to configured schedule now",
);

my %compound_transtable_DE = ( 
  "month"             =>  "Monat",
  "light"             =>  "Licht",
  "heating"           =>  "Heizung",
  "camera"            =>  "Kamera",
  "cooling"           =>  "Kühlung",
  "schedule"          =>  "Zeitplan",
  "overview"          =>  "Übersicht",
  "animals"           =>  "Tiere",
  "state"             =>  "Status",
  "place"             =>  "Ort",
  "temp"              =>  "Temp",
  "hum"               =>  "Feuchte",
  "attention"         =>  "Achtung",
  "deviceaccplan"     =>  "Gerät arbeitet ab sofort nach konfiguriertem Zeitplan",
);

my %compound_month_EN = ( 
  "1"             =>  "Jan",
  "2"             =>  "Feb",
  "3"             =>  "Mar",
  "4"             =>  "Apr",
  "5"             =>  "Mai",
  "6"             =>  "Jun",
  "7"             =>  "Jul",
  "8"             =>  "Aug",
  "9"             =>  "Sep",
  "10"            =>  "Oct",
  "11"            =>  "Nov",
  "12"            =>  "Dec",  
);

my %compound_month_DE = ( 
  "1"             =>  "Jan",
  "2"             =>  "Feb",
  "3"             =>  "März",
  "4"             =>  "Apr",
  "5"             =>  "Mai",
  "6"             =>  "Jun",
  "7"             =>  "Jul",
  "8"             =>  "Aug",
  "9"             =>  "Sep",
  "10"            =>  "Okt",
  "11"            =>  "Nov",
  "12"            =>  "Dez",  
);

my $compound_tt;
my $compound_month;

sub compound_checkTemp($$;$);
sub compound_setOff($$);

sub compound_Initialize($) { 
  my ($hash) = @_;
  my $name = $hash->{NAME}; 

  $hash->{SetFn}        = "compound_Set";
  $hash->{GetFn}        = "compound_Get";
  $hash->{DefFn}        = "compound_Define";
  $hash->{NotifyFn}     = "compound_Notify";
  $hash->{UndefFn}      = "compound_Undefine";
  $hash->{AttrFn}       = "compound_Attr";
  
  $hash->{FW_detailFn}  = "compound_detailFn";
  
  $hash->{AttrList}     = "disable:1,0 ".
                          "hysterese ".
                          "interval ".
                          "showDetailWidget:1,0 ".
                          "language:EN,DE ".
                          $readingFnAttributes;
                          
  if( !defined($compound_tt) ){
    # in any attribute redefinition readjust language
    my $lang = AttrVal($name,"language", AttrVal("global","language","EN"));
    if( $lang eq "DE") {
      $compound_tt = \%compound_transtable_DE;
      $compound_month = \%compound_month_DE;
    }
    else{
      $compound_tt = \%compound_transtable_EN;
      $compound_month = \%compound_month_EN;
    }
  }
  
  return undef;
} 

sub compound_Define($$) {
  my ($hash, $def) = @_;
  my $now = time();
  my $name = $hash->{NAME}; 
  
  my @compounds;
  my @devices;
  my @tdevices;
  
  if( !defined($compound_tt) ){
    # in any attribute redefinition readjust language
    my $lang = AttrVal($name,"language", AttrVal("global","language","EN"));
    if( $lang eq "DE") {
      $compound_tt = \%compound_transtable_DE;
      $compound_month = \%compound_month_DE;
    }
    else{
      $compound_tt = \%compound_transtable_EN;
      $compound_month = \%compound_month_EN;
    }
  }
  
  
  my @a = split( "[ \t][ \t]*", $def );
  
  if ( int(@a) < 3 ) {
    my $msg = "Wrong syntax: define <name> compound <compound>,<tempDevice>,<device1>[:<reading>][,<device2>:<reading>...][|<compound2>...]";
    Log3 $name, 4, $msg;
    return $msg;
  }

  
  my @devs=split(/\|/,$a[2]);
  
  my $i=0; 
  my $v=0;
  
  delete($hash->{helper});
  CommandDeleteReading(undef, "$hash->{NAME} .*_(state|temperature|humidity)");
  
  my $cs="";
  
  my $state=ReadingsVal($name,"state","inactive");
  
  my $co=ReadingsVal($name,"compound","-");
  
  foreach my $e (@devs) {
    my $compound;
    my @p = split(",",$e);
    my $r=0;
    foreach my $dev (@p) {
      if ($r==0) {
        $compound=$dev;
        push @compounds, $dev;
        $cs.="," if ($v>0);
        $cs.=$dev;
        $v++;
      }
      if ($r==1) {
        $hash->{helper}{"tempDevices"}{$dev}=$compound;
        $hash->{helper}{$compound}{"tempDevice"}=$dev;
        push @{$hash->{helper}{$compound}{"compDevices"}},$dev;
        push @tdevices, $dev;
        readingsSingleUpdate($hash,$dev."_temperature",ReadingsVal($dev,"temperature","---"),1) if ($co ne "-" && $co eq $p[0]);
      }
      if ($r>1) {
        $i++;
        my @d=split(":",$dev);
        push @devices, $d[0];
        my $dStateType=$d[1]?$d[1]:"state";
        readingsSingleUpdate($hash,$d[0]."_state",ReadingsVal($d[0],$dStateType,"---"),1) if ($co ne "-" && $co eq $p[0]);
        $hash->{helper}{"devices"}{$d[0]}=$compound;
        push @{$hash->{helper}{$compound}{"devices"}},$d[0];
        push @{$hash->{helper}{$compound}{"compDevices"}},$d[0];
        $hash->{helper}{"DEVREADINGS"}{$d[0]}=$dStateType;    
      }
      $r++;
    }
  }
  
  $hash->{COMPOUNDS} = \@compounds;
  $hash->{COMPOUND} = $cs;
  my $cCount=@compounds;
  compound_setCompound($hash,$name,$compounds[0]) if ($cCount==1);
  Log3 $name, 4, "$name: Compounds listed";
    
  $hash->{DEVICES} = \@devices;
  Log3 $name, 4, "$name: Devices listed";
  
  
  $hash->{TEMPDEVICES} = \@tdevices;
  #Log3 $name, 4, "$name: set tempDevice to $a[3]";
  
  $hash->{COUNT}=$i;  
  Log3 $name, 5, "$name: COUNT set to $i";
  
  if ($init_done) {
    readingsSingleUpdate($hash,"state","inactive",1) if(ReadingsVal($name,"state","active") eq "active");
    RemoveInternalTimer($hash);
    compound_SetPlan($hash);
    $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{$co}{"compDevices"}}) if ($co ne "-" && defined($hash->{helper}{$co}{"compDevices"}));
    Log3 $name, 5, "$name: added NotifyDev $hash->{NOTIFYDEV} to Device";
  }
  
  $hash->{INTERVAL}=AttrVal($name,"interval",undef)?AttrVal($name,"interval",undef):300;
  
  $hash->{VERSION}=$version;
  
  compound_RestartGetTimer($hash);
  
  return undef;
}

sub compound_SetDeviceTypes($) {
  my ($hash) = @_;
  
  my $name = $hash->{NAME};
  
  my $compound=ReadingsVal($name,"compound","-");
  
  if ($compound ne "-") {
  
    my @devs=@{$hash->{helper}{$compound}{devices}} if ($hash->{helper}{$compound}{devices});
    
    foreach my $d (@devs) {
      
      if (ReadingsVal($name,$d."_type","-") eq "-") {
        $hash->{helper}{$compound}{"TYPES"}{$d}="light";
        $hash->{helper}{$compound}{"TYPE"}{"light"}=$d;
      }
      else {
        $hash->{helper}{$compound}{"TYPES"}{$d}=ReadingsVal($name,$d."_type","-");
        $hash->{helper}{$compound}{"TYPE"}{ReadingsVal($name,$d."_type","-")}=$d;
      }
    }
  }
}

sub compound_Undefine($$) {
  my ($hash, $arg) = @_;
  
  RemoveInternalTimer($hash);
  
  return undef;
}

sub compound_Notify($$) {
  my ($hash,$dev) = @_;
  
  my $events = deviceEvents($dev,1);
  return if( !$events );
  
  my $name = $hash->{NAME};
  my $devName = $dev->{NAME};
  
  my $state = ReadingsVal($name,"state","inactive");
  
  return undef if ($state ne "active"); 
  
  return if( AttrVal($name,"disable", 0) > 0 );
  
  return if($dev->{TYPE} eq $hash->{TYPE});
  
  my $compound=ReadingsVal($name,"compound","-");
  
  my $manu=ReadingsVal($name,$devName."_manu","off");
  
  my $doTable=0;
  
  my $dReading; # device Reading
  
  ## update device list, if FHEM starts or rereadcfg
  if( $dev->{NAME} eq "global" && (grep(m/^INITIALIZED$/, @{$events}) || grep(m/^REREADCFG$/, @{$events}))) {
    readingsSingleUpdate($hash,"state","active",1) if( AttrVal($name,"disable", 0) > 0 && ReadingsVal($name,"state","inactive") ne "inactive");
    if ($compound ne "-") {
      $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{$compound}{"compDevices"}}) if (defined($hash->{helper}{$compound}{"compDevices"}));
      Log3 $name, 5, "$name: added NotifyDev ".$hash->{NOTIFYDEV}." to Device";
    }
    compound_SetDeviceTypes($hash);
    compound_SetPlan($hash);
  }
  else {
    if ($state eq "active" && $compound ne "-") {
      Log3 $name,5, $name."Notify: ".$devName;
      my $tDev=$hash->{helper}{$compound}{"tempDevice"};
      my @devs;
      
      @devs=@{$hash->{helper}{$compound}{"devices"}} if (defined($hash->{helper}{$compound}{"devices"}));
      # get temperature and/or humidity Readings
      
      # analyse events
      foreach my $event (@{$events}) {
        my @e = split(": ",$event);
        
        $event = "" if(!defined($event));
        $dReading = "-";
        $dReading = "temperature" if (grep(m/^temperature.*$/, $event));
        $dReading = "humidity" if (grep(m/^humidity.*$/, $event));
        if ($tDev eq $devName) {
          if (grep(m/^temperature.*$/, $event) || grep(m/^temperature.*$/, $event)) {
            readingsSingleUpdate($hash,$devName."_$dReading",$e[1],1);
            compound_checkTemp($hash,$name,$e[1]) if ($hash->{helper}{"devices"}{$devName}=$compound && $dReading eq "temperature" && $init_done && $manu ne "on");
          }
          $doTable=1;
        }
        if (compound_inArray(\@devs,$devName)) {
          my $devStateType=$hash->{helper}{"DEVREADINGS"}{$devName};
          readingsSingleUpdate($hash,$devName."_state",$e[1],1) if (grep(m/^$devStateType.*$/, $event));
          RemoveInternalTimer($hash);
        
          my $interval=$hash->{INTERVAL}?$hash->{INTERVAL}:300;
    
          InternalTimer(gettimeofday()+$interval, "compound_doCheckTemp", $hash, 0) if ($manu ne "on");
          $doTable=1;
        }
        #Log3 $name,5,"$name: got $dReading $e[1] from $devName in NotifyFn";
        #Log3 $name,4,"$name: set reading ".$devName."_$dReading to $e[1] in NotifyFn";
      }
    }
  }
  
  if ($doTable == 1) {
    compound_ReloadTable($name);
  }
  
  return undef;
}

sub compound_Attr(@) {
  my ($cmd,$name,$attrName,$attrVal) = @_;
  
  my $hash = $defs{$name};
  
  if ( $attrName eq "disable" ) {

    if ( $cmd eq "set" && $attrVal == 1 ) {
      if ($hash->{READINGS}{state}{VAL} ne "disabled") {
        readingsSingleUpdate($hash,"state","disabled",1);
        RemoveInternalTimer($hash);
        RemoveInternalTimer($hash,"todoist_GetTasks");
        Log3 $name, 4, "compound ($name): $name is now disabled";
      }
    }
    elsif ( $cmd eq "del" || $attrVal == 0 ) {
      if ($hash->{READINGS}{state}{VAL} ne "active") {
        readingsSingleUpdate($hash,"state","active",1);
        RemoveInternalTimer($hash);
        Log3 $name, 4, "compound ($name): $name is now ensabled";
        todoist_RestartGetTimer($hash);
      }
    }
  }
  
  if ( $attrName eq "interval") {
    if ( $cmd eq "set" ) {
      return "compound ($name): interval has to be a number (seconds)" if ($attrVal!~ /\d+/);
      return "compound ($name): interval has to be greater than or equal 10" if ($attrVal < 10);
      $hash->{INTERVAL}=$attrVal;
      Log3 $name, 4, "compound ($name): set new pollInterval to $attrVal";
    }
    elsif ( $cmd eq "del" ) {
      $hash->{INTERVAL}=300;
      Log3 $name, 4, "compound ($name): set new pollInterval to 300 (standard)";
    }
    compound_RestartGetTimer($hash);
  }
  
  if ($attrName eq "language") {
    # in any attribute redefinition readjust language
    if ($cmd eq "set") {
      return "compound ($name): language can only be DE or EN" if ($attrVal !~ /(^DE|EN)$/);
      if( $attrVal eq "DE") {
        $compound_tt = \%compound_transtable_DE;
        $compound_month = \%compound_month_DE;
      }
      else{
        $compound_tt = \%compound_transtable_EN;
        $compound_month = \%compound_month_EN;
      }
    }
    else {
      $compound_tt = \%compound_transtable_EN;
      $compound_month = \%compound_month_EN;
    }
  }

  return undef;
}


sub compound_Get($@) {
  my ($hash, $name, $cmd, @args) = @_;
  my $ret = undef;
  
  if ( $cmd eq "version") {
    $hash->{VERSION} = $version;
    return "Version: ".$version;
  }
  else {
    $ret ="$name get with unknown argument $cmd, choose one of " . join(" ", sort keys %gets);
  }
 
  return $ret;
}


sub compound_Set($@)
{
  my ($hash, $name, $cmd, @args) = @_;
  
  my @sets = ();
  
  my @aCompounds=@{$hash->{COMPOUNDS}};
  my $compounds=$hash->{COMPOUND};
  
  my $compound=ReadingsVal($name,"compound","-");
  
  push @sets, "compound:$compounds" if(ReadingsVal($name,"state","active") eq "active");
  push @sets, "active" if(ReadingsVal($name,"state","active") ne "active");
  push @sets, "inactive" if(ReadingsVal($name,"state","inactive") eq "active");
  
  if ($compound ne "-" && ReadingsVal($name,"state","active") eq "active") {
    if (defined($hash->{"DEVICES"})) {
      my @devices = @{$hash->{"DEVICES"}};
      foreach my $de (@devices) {
        push @sets, $de."_type:camera,cool,heat,light";
        push @sets, $de."_plan:textFieldNL-long";
        push @sets, $de."_state:on,off,on-for-timer,on-till:undef";   
      }
    }
  }
  
  @sets = sort { lc($a) cmp lc($b) } @sets;
  
  return join(" ", @sets) if ($cmd eq "?");
  
  return "$name is disabled. Enable it to set something." if( $cmd ne "active" && (AttrVal($name, "disable", 0 ) == 1 || ReadingsVal($name,"state","active") eq "inactive"));
  
  if ( $cmd =~ /^compound|active|inactive|.*plan|.*type?$/ || $args[0] =~ /(.*on.*|.*off.*)/) {
    Log3 $name, 4, "$name: set cmd:$cmd arg1:$args[0] arg2:$args[1]";
    return "[$name] Invalid argument to set $cmd, has to be one of $compounds" if ( $cmd =~ /^compound?$/ && !compound_inArray(\@aCompounds,$args[0]) );
    if ( $cmd =~ /^compound?$/ ) {     
      compound_setCompound($hash,$name,$args[0]);
    }
    elsif ( $cmd =~ /^(active|inactive)?$/ ) {   
      readingsSingleUpdate($hash,"state",$cmd,1);
      RemoveInternalTimer($hash) if ($cmd eq "inactive");
      compound_setCompound($hash,$name,$compound) if ($cmd eq "active");
      $attr{$name}{"disable"} = 0 if (AttrVal($name,"disable",0) == 1);
      Log3 $name, 3, "$name: set Device $cmd";
      compound_ReloadPlan();
      compound_ReloadTable();
      compound_SetDeviceTypes($hash);
      $hash->{INTERVAL}=AttrVal($name,"interval",undef)?AttrVal($name,"interval",undef):300;
    }
    elsif ( $cmd =~ /^.*type?$/ ) {
      my $do = join(" ", @args);
      return return "[$name] Unknown argument " . $do if ($do !~ /^heat|light|camera|cool$/);
      readingsSingleUpdate($hash,$cmd,$do,0);
      compound_SetDeviceTypes($hash);
      compound_RestartGetTimer($hash);
    }
    elsif ($cmd =~ /^.*plan?$/ ) {
      my $tPlan = ReadingsVal($name,$cmd,"-");
      my $do = join(" ", @args);
      if ($tPlan ne $do) {
        readingsSingleUpdate($hash,$cmd,$do,1);
        compound_SetPlan($hash);
        compound_RestartGetTimer($hash);
      }
      else {
        map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
      }
    }
    if ( $args[0] =~ /^.*on.*$/ ) {
      Log3 $name, 4, "$name: set $args[0]";
      RemoveInternalTimer($hash);
      compound_setOn($hash,$name,$cmd,@args);
    }
    elsif ( $args[0] =~ /^.*off$/ ) {
      Log3 $name, 4, "$name: set $cmd $args[0] ";
      RemoveInternalTimer($hash,"compound_doCheckTemp");
      compound_setOff($hash,$cmd);
    }
  }
  else {
    my $str =  join(",",(1..(2-1)));
    return "[$name] Unknown argument " . $cmd . ", choose one of compound:$str";
  }
  return undef;
}

# set the plan in hash
sub compound_SetPlan($) {
  my ($hash) = @_;
  
  my $name=$hash->{NAME};
  
  if ($hash->{DEVICES}) {
    
    foreach(@{$hash->{DEVICES}}) {
      
      my @plans = split(/(\n|\r)/m,ReadingsVal($name,$_."_plan","-"));
      
      Log3 $name, 5, "$name: ".Dumper(@plans);
      
      my @planArr;
      foreach (@plans) {
         my @mon = split(/ /,$_,2);
         $planArr[int($mon[0])] = $mon[1];
      }
      
      for(my $i=1;$i<=12;$i++) {
        #my $t = sprintf ('%02d',$i);
        if (defined($planArr[$i])) {
          $hash->{helper}{plan}{$hash->{helper}{devices}{$_}}{$_}{$i} = $planArr[$i];
        }
        else {
          $hash->{helper}{plan}{$hash->{helper}{devices}{$_}}{$_}{$i}  = $planArr[13] if (defined($planArr[13]));
          $hash->{helper}{plan}{$hash->{helper}{devices}{$_}}{$_}{$i}  = "-" if (!defined($planArr[13]));
        }
      }
      map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
    }
  
    compound_RestartGetTimer($hash);
  }
  compound_ReloadPlan();
  
  return undef;
}

## set on
sub compound_setOn($$@) {
    my ($hash,$name,$devH,@args) = @_;
  
    my @fDev=split(/_/,$devH);
    
    my $dev=$fDev[0];
    
    my $compound=ReadingsVal($name,"compound","-");
    
    my $checkDev=0;
    
    if ($compound && defined($fDev[1])) {
      # check devices
      my @devices = @{$hash->{helper}{$compound}{"devices"}};
      foreach my $de (@devices) {
        $checkDev=1 if ($dev eq $de);
      }
    }
    else {
      CommandDeleteReading(undef, "$hash->{NAME} $dev");
    }
    
    return undef if ($checkDev==0);
    
    # get command
    my $cmd=$args[0];
    
    # get additional parameter if on-till or on-for-timer
    my $param= $args[1] if ($cmd eq "on-for-timer" || $cmd eq "on-till");
    
    my $cmd1 = ($cmd =~ m/^on.*/ ? "on" : "off");
    my $cmd2 = ($cmd =~ m/^on.*/ ? "off" : "on");
    
    
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,$dev."_state",$cmd1);
    readingsBulkUpdate($hash,$dev."_manu",$cmd1);
    
    my $dHash;
    
    $dHash->{hash}=$hash;
    $dHash->{dev}=$dev;   
    $dHash->{cmd}=$cmd1;
    
    RemoveInternalTimer($dev);
    RemoveInternalTimer($hash);
    RemoveInternalTimer($dHash);
    
    InternalTimer(gettimeofday()+1, "compound_doSetOn", $dHash, 0);
    
    
    if ($cmd eq "on-for-timer") {
      readingsBulkUpdate($hash,$dev."_timer",FmtDateTime(gettimeofday()+$param));
      InternalTimer(gettimeofday()+$param, "compound_doSetOff", $dHash, 0);  
    }
    elsif ($cmd eq "off") {
      compound_setOff($hash,$dev);
    }
    elsif ($cmd eq "on-till") {
      my $till=compound_abstime2rel($param);
      
      readingsBulkUpdate($hash,$dev."_timer",FmtDateTime(gettimeofday()+$till));
      
      Log3 $name, 3, "$name: set off $dev $till";
            
      InternalTimer(gettimeofday()+$till, "compound_doSetOff", $dHash, 0);
    }
    
    readingsEndUpdate( $hash, 1 );
    
    return undef;
}

sub compound_doSetOn ($) {
  my ($dHash) = @_;
  my $hash=$dHash->{hash};
  my $dev=$dHash->{dev};
  my $cmd=$dHash->{cmd};
  CommandSet(undef,"$dev:FILTER=STATE!=$cmd $cmd");
  
  return undef;
}

sub compound_doSetOff ($) {
  my ($dHash) = @_;
  my $hash=$dHash->{hash};
  my $dev=$dHash->{dev};
  compound_setOff($hash,$dev);
  
  return undef;
}

## do set off
sub compound_setOff($$){
  my ($hash, $dev) = @_;
  
  my @fDev=split(/_/,$dev);
    
  $dev=$fDev[0];
  
  my $name=$hash->{NAME};
  
  Log3 $name, 5, "$name: set off $dev";
  
  readingsSingleUpdate($hash,$dev."_manu","off",1);
  
  InternalTimer(gettimeofday()+2, "compound_doCheckTemp", $hash, 0);
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_ErrorDialog === \"function\") compound_ErrorDialog('$name','".$compound_tt->{"deviceaccplan"}."','".$compound_tt->{"attention"}."!')", "")} devspec2array("TYPE=FHEMWEB");
  
  return undef;
}

sub compound_doCheckTemp($) {
  my ($hash) = @_;
  
  my $name = $hash->{NAME};
  
  my $interval=$hash->{INTERVAL}?$hash->{INTERVAL}:10;
  
  
  RemoveInternalTimer($hash);
    
  InternalTimer(gettimeofday()+$interval, "compound_doCheckTemp", $hash, 0);
  
  compound_checkTemp($hash,$name);
  
  Log3 $name, 5, "$name: doCheckTemp";
  
  return undef;
}

# main function
sub compound_checkTemp($$;$) {
  my ($hash, $name, $temp) = @_;
  
  my $compound=ReadingsVal($name,"compound","-");
  
  if ($compound ne "-") {
  
    my $hyst = AttrVal($name,"hysterese",0);
    
    my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime(time);
    
    my $tempDev=$hash->{helper}{$compound}{"tempDevice"};
              
    my $temp = ReadingsVal($tempDev,"temperature",0);
        
    readingsSingleUpdate($hash,$tempDev."_temperature",$temp,1);
    
    
    # aktuelle Zeit holen
    my $time=time;
    
    Log3 $name, 4, "$name: Begin check temperature: $name";
    if (defined($hash->{helper}{$compound}{"devices"})) {
      my @devices=@{$hash->{helper}{$compound}{"devices"}};
      foreach my $dev (@devices) {
        
        #Log3 $name, 5, "$name: Check temperature for device $dev with temperature $temp" if (defined($temp));
        
        my $cmd1=$hash->{helper}{$compound}{"TYPES"}{$dev} ne "cool"?"on":"off";
        my $cmd2=$hash->{helper}{$compound}{"TYPES"}{$dev} ne "cool"?"off":"on";
        
        my $tPlan=$hash->{helper}{plan}{$compound}{$dev}{$month+1};
        
        if ($tPlan ne "-") {
          my @plans = split(/ /, $tPlan );
          if (defined($plans[0])) {
            my $i=0;
            my @oldTime=(0,0,0);
            foreach my $plan (@plans) {
              my @d = split(/\|/,$plan);
              #Log3 $name, 5, "$name:$d[0],$d[1]";
              my @planTime = split(":",$d[0]);
              @planTime=(23,59,59) if ($planTime[0]==24);
              $planTime[2]=0 unless defined($planTime[2]);
              my $aPlanTime = timelocal(int($planTime[2]),int($planTime[1]),int($planTime[0]),$mday,$month,$year);
              my $refTime = timelocal($oldTime[2],$oldTime[1],$oldTime[0],$mday,$month,$year);
              
              Log3 $name, 5, "$name: Check temperature for device $dev ($plan) with new temperature $temp and $time and ".$d[0]." and ".$d[1]." and $refTime and $aPlanTime" if (defined($temp));
              
              if ($time>$refTime && $time<$aPlanTime) {
                  
                  Log3 $name, 5, "$name: Check temperature for device $dev and tempDevice $tempDev with given temperature $temp and $d[1] and $refTime and $aPlanTime" if (defined($temp));
                  
                  my $manu=ReadingsVal($name,$dev."_manu","off");
                  
                  if (!defined($d[1])) {
                    $d[1] = 1000;
                  }
                  
                  if ($d[1] ne "-" && $dev) {
                    Log3 $name, 5, "$name: DEBUG: $dev";
                    $d[1]=int($d[1]);
                    # on
                    if ($temp < $d[1] && Value($dev) ne $cmd1) {
                      CommandSet(undef,"$dev $cmd1");
                      readingsSingleUpdate($hash,$dev."_timer",'none',1);
                    }
                    # off
                    my $refTemp=$d[1]+$hyst;
                    if ($temp >= $refTemp && Value($dev) ne $cmd2 && $manu ne "on") {
                      CommandSet(undef,"$dev $cmd2");
                      readingsSingleUpdate($hash,$dev."_timer",'none',1);
                    }
                  }
                  else {
                    CommandSet(undef,"$dev:FILTER=STATE!=off off") if ($manu ne "on");
                    readingsSingleUpdate($hash,$dev."_timer",'none',1);
                  }
                #}
              }     
              $i++;
              @oldTime = @planTime;
            }
          }
        }
        else {
          CommandSet(undef,"$dev $cmd2");
          readingsSingleUpdate($hash,$dev."_timer",'none',1);
        }
      }
      Log3 $name, 4, "$name: Check for time and temperature";
      readingsSingleUpdate($hash,"lastCheckTime",FmtDateTime( gettimeofday() ),1);
      
    }
    
  }
  return undef;
}

sub compound_setCompound($$@) {
  my ($hash, $name, @args) = @_;
  
  my $co = $args[0];
  
  
  if ($co ne "-") {
    my @compounds=@{$hash->{COMPOUNDS}};
    
    if (compound_inArray(\@compounds,$co)) {
  
      readingsBeginUpdate($hash);
      
      readingsBulkUpdate($hash,"compound",$co);
      CommandDeleteReading(undef, "$hash->{NAME} .*_(state|temperature|humidity)");
      
      my $tempDev = $hash->{helper}{$co}{"tempDevice"};
      
      if ($tempDev) {
        readingsBulkUpdate($hash,$tempDev."_temperature",ReadingsVal($tempDev,"temperature","---"));
        readingsBulkUpdate($hash,$tempDev."_humidity",ReadingsVal($tempDev,"humidity","---")) if (ReadingsVal($tempDev,"humidity","---") ne "---");
      }
      
      my $i=0;
      
      foreach my $dev (@{$hash->{helper}{$co}{"devices"}}) {
        readingsBulkUpdate($hash,$dev."_state",ReadingsVal($dev,$hash->{helper}{"DEVREADINGS"}{$dev},"---"));
        $i++;
      }
      
      readingsEndUpdate( $hash, 1 );
      if ($tempDev || $i>0) {
        $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{$co}{"compDevices"}});
      }
      
      Log3 $name,4,"$name: compound set to $args[0]";
      
      compound_ReloadPlan();
      compound_ReloadTable();
      compound_SetDeviceTypes($hash);
      
      RemoveInternalTimer($hash);
      
      InternalTimer(gettimeofday()+2, "compound_doCheckTemp", $hash, 0) if ($i!=0);
    }
    else {
      return "The compound $co doesn't exist!";
    }
  }
  else {
    return undef;
    
  }
  
  return;
}

# restart timers if active
sub compound_RestartGetTimer($) {
  my ($hash) = @_;
  
  my $name = $hash->{NAME};
  
  RemoveInternalTimer($hash);
    
  InternalTimer(gettimeofday()+0.3, "compound_doCheckTemp", $hash, 0);
  
  return undef;
}

# called if weblink widget table has to be updated
sub compound_ReloadPlan(;$) {
  my ($regEx) = @_;
  
  $regEx=0 if (!defined($regEx));
  
  my $ret = compound_PlanHtml($regEx,1);
  $ret =~ s/\"/\'/g;
  $ret =~ s/\n//g;
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_reloadPlan === \"function\") compound_reloadPlan(\"$ret\")", "")} devspec2array("TYPE=FHEMWEB");
}

# called if weblink widget table has to be updated
sub compound_ReloadTable(;$) {
  my ($regEx) = @_;
  
  $regEx=0 if (!defined($regEx));
  
  my $ret = compound_Html($regEx,1);
  $ret =~ s/\"/\'/g;
  $ret =~ s/\n//g;
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_reloadTable === \"function\") compound_reloadTable(\"$ret\")", "")} devspec2array("TYPE=FHEMWEB");
}

# show widget in detail view of todoist device
sub compound_detailFn(){
  my ($FW_wname, $devname, $room, $pageHash) = @_; # pageHash is set for summaryFn.

  my $hash = $defs{$devname};
  
  $hash->{mayBeVisible} = 1;
  
  my $name=$hash->{NAME};
  
  return undef if (IsDisabled($name) || AttrVal($name,"showDetailWidget",1)!=1);
  
  #return compound_Html($name,undef,1).compound_PlanHtml($name,undef,1);
  return compound_Html($name,undef,1);
}

sub compound_PlanHtml(;$$$) {
  my ($regEx,$refreshGet,$detail) = @_;
  $regEx=0 if (!defined($regEx));
  $refreshGet=0 if (!defined($refreshGet));
  $detail=0 if (!defined($detail));
  
  my $filter="";
  
  $filter.=":FILTER=".$regEx if ($regEx);
  
  my @devs = devspec2array("TYPE=compound".$filter);
  my $ret="";
  my $rot="";
  
  my $sM = $compound_month;
  
  # refresh request? don't show everything
  if (!$refreshGet) {
    # Javascript
    $rot .= "<script type=\"text/javascript\" src=\"$FW_ME/www/pgm2/compound.js?version=".$version."\"></script>
                <style>
                  .compound_plan_container {
                      display: block;
                      padding: 0;
                      float:left;
                  }
                  .compound_table {
                      float: left;
                      margin-right: 10px;
                  }
                  div.compound_devType {
                    padding: 4px!important;     
                  }
                  table.compound_table th {
                    padding:4px;;
                  }
                  table.compound_table th.col1 {
                    text-align:left;
                  }
                  div.compound_icon {
                    cursor: pointer;
                    display: block;
                    float: right;
                    width: 1em;
                    height: 1em;
                    margin-left: 0.5em;
                  }
                  div.compound_icon svg {
                    height: 12px!important;
                    width: 12px!important;
                  }
                  span.compound_status_span {
                    cursor:pointer;
                  }
                  tr.compound_plan td input {
                    width:220px;
                  }
                  td.doDown {
                    cursor:pointer;
                  }
                </style>";
  }
  $ret .= "<div class='compound_plan_outer_container'>\n";
                
  foreach my $name (@devs) {    
    if (!IsDisabled($name)) {
      my $hash = $defs{$name};  
      my $compound=ReadingsVal($name,"compound","-");
      
      my $lightDev = $hash->{helper}{$compound}{TYPE}{light} if ($hash->{helper}{$compound}{TYPE}{light});
      my $heatDev = $hash->{helper}{$compound}{TYPE}{heat} if ($hash->{helper}{$compound}{TYPE}{heat});
      my $camDev = $hash->{helper}{$compound}{TYPE}{camera} if ($hash->{helper}{$compound}{TYPE}{camera});
      my $coolDev = $hash->{helper}{$compound}{TYPE}{cool} if ($hash->{helper}{$compound}{TYPE}{cool});
    
      if ($compound ne "-") {     

        $ret .= "<div class=\"compound_plan_container\">\n";
        $ret .= "<table class=\"roomoverview compound_table\">\n";
          
        $ret .= "<tr class=\"devTypeTr\"><td colspan=\"3\">\n".
                " <div class=\"compound_devType col_header\">\n".
                    $compound_tt->{"schedule"}.": ".(!$FW_hiddenroom{detail}?"<a title=\"\" href=\"/fhem?detail=".$name."\">":"").
                      AttrVal($name,"alias",$name).
                    (!$FW_hiddenroom{detail}?"</a>":"").
                    " - ".$compound.
                " </div>".
                "</td></tr>";
        $ret .= "<tr><td colspan=\"3\">\n";
        $ret .= "<table class=\"block wide\" id=\"compound_planung_table\">\n"; 
      
        $ret .= "<thead id=\"compound_head_th\">\n".
                " <tr>\n".
                "   <th class=\"col1\">".$compound_tt->{"month"}."</th>\n".
                ($lightDev?"  <th class=\"col3\" colspan=\"2\">".$compound_tt->{"light"}."</th>\n":"").
                ($heatDev?"   <th class=\"col3\" colspan=\"2\">".$compound_tt->{"heating"}."</th>\n":"").
                ($camDev?"  <th class=\"col3\" colspan=\"2\">".$compound_tt->{"camera"}."</th>\n":"").
                ($coolDev?"   <th class=\"col3\" colspan=\"2\">".$compound_tt->{"cooling"}."</th>\n":"").
                " </tr>".
                "</thead>\n";
      
        

        $ret .= "<tbody class=\"compound_planung_data_body\" id=\"compound_data_body_".$name."\">";
        my $eo;
        my $month;
        my $num;
        
        for(my $i=1;$i<=12;$i++) {
          if ($i%2==0 || $i==0) {
            $eo="even";
          }
          else {
            $eo="odd";
          }
          $num = $i;
          $month=$sM->{$num};
          
          my $valueL = $hash->{helper}{plan}{$compound}{$hash->{helper}{$compound}{TYPE}{light}}{"$num"} if ($hash->{helper}{$compound}{TYPE}{light} && $hash->{helper}{plan}{$compound});
          my $valueH = $hash->{helper}{plan}{$compound}{$hash->{helper}{$compound}{TYPE}{heat}}{"$num"} if ($hash->{helper}{$compound}{TYPE}{heat} && $hash->{helper}{plan}{$compound});
          my $valueC = $hash->{helper}{plan}{$compound}{$hash->{helper}{$compound}{TYPE}{camera}}{"$num"} if ($hash->{helper}{$compound}{TYPE}{camera} && $hash->{helper}{plan}{$compound});
          my $valueF = $hash->{helper}{plan}{$compound}{$hash->{helper}{$compound}{TYPE}{cool}}{"$num"} if ($hash->{helper}{$compound}{TYPE}{cool} && $hash->{helper}{plan}{$compound});

          
          $ret .= "<tr id=\"compound_plan_row_".$i."\" data-data=\"true\" data-line-id=\"".$i."\" class=\"sortit compound_plan ".$eo."\">\n".
                  " <td class=\"col1 compound_col1\">\n".
                    $month.
                  " </td>\n".
                  ($lightDev?"  <td class=\"col2 compound_plan_light\">\n".
                  "   <input type=\"text\" data-name=\"".$lightDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_lightInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueL."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_light_".$name."\" class=\"col2 doDown light_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($heatDev?" <td class=\"col2 compound_plan_heat\">\n".
                  "   <input type=\"text\" data-name=\"".$heatDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_heatInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueH."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_heat_".$name."\" class=\"col2 doDown heat_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($camDev?"  <td class=\"col2 compound_plan_cam\">\n".
                  "   <input type=\"text\" data-name=\"".$camDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_camInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueC."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_cam_".$name."\" class=\"col2 doDown cam_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($coolDev?" <td class=\"col2 compound_plan_cool\">\n".
                  "   <input type=\"text\" data-name=\"".$coolDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_coolInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueF."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_cool_".$name."\" class=\"col2 doDown cool_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  "</tr>\n";
        }
        
        $ret .= "</tbody>";
      
        $ret .= "</table></td></tr>\n";
        $ret .= "</table>\n";
        $ret .= "</div>\n";
      }
    }
  }
  $ret .= "</div>\n";
  if (!$refreshGet) {
    $ret .= "<br style=\"clear:both;\" /><br />";
  }
  return $rot.$ret;
}

sub compound_Html(;$$$) {
  my ($regEx,$refreshGet,$detail) = @_;
  
  $regEx=0 if (!defined($regEx));
  $refreshGet=0 if (!defined($refreshGet));
  $detail=0 if (!defined($detail));
  
  my $filter="";
  
  $filter.=":FILTER=".$regEx if ($regEx);
  
  my @devs = devspec2array("TYPE=compound");
  my $ret="";
  my $rot="";
  
  # refresh request? don't show everything
  if (!$refreshGet) {
   $rot .= " <script type=\"text/javascript\">
              compound_tt={};
            </script>";
    # Javascript
    $rot .= "<script type=\"text/javascript\" src=\"$FW_ME/www/pgm2/compound.js?version=".$version."\"></script>
                <style>
                  .compound_container {
                      display: block;
                      padding: 0;
                      float:none;
                  }
                  .compound_table {
                      float: left;
                      margin-right: 10px;
                  }
                  div.compound_devType {
                    padding: 4px!important;     
                  }
                  table.compound_table th {
                    padding:4px;;
                  }
                  table.compound_table th.col1 {
                    text-align:left;
                  }
                  div.compound_icon {
                    cursor: pointer;
                    display: block;
                    float: right;
                    width: 1em;
                    height: 1em;
                    margin-left: 0.5em;
                  }
                  div.compound_icon svg {
                    height: 12px!important;
                    width: 12px!important;
                  }
                  span.compound_status_span {
                    cursor:pointer;
                  }
                  td.compound_switch span {
                    cursor:pointer;
                  }
                </style>";
    
    
    $ret .= "<div class=\"compound_container\">\n";
    $ret .= "<table class=\"roomoverview compound_table\">\n";
      
    $ret .= "<tr class=\"devTypeTr\"><td colspan=\"3\">\n".
            " <div class=\"compound_devType col_header\">\n".
            "   ".$compound_tt->{"overview"}.
            " </div>".
            "</td></tr>";
    $ret .= "<tr><td colspan=\"3\">\n";
    $ret .= "<table class=\"block wide\" id=\"compound_schaltung_table\">\n"; 
  
    $ret .= "<thead id=\"compound_head_th\">\n".
            " <tr>\n".
            "   <th class=\"col1\">".$compound_tt->{"animals"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"light"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"place"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"light"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"heating"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"camera"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"temp"}."</th>\n".
            "   <th class=\"col3\">".$compound_tt->{"hum"}."</th>\n".
            " </tr>".
            "</thead>\n";
  }
  
  my $dataDetail = defined($detail)?"detail-$regEx":"-";
  
  $ret .= "<tbody id=\"compound_data_body\" data-detail=\"".$dataDetail."\">";
  
  my $i=1;
  my $eo;
  
  foreach my $name (@devs) {
    my $compound=ReadingsVal($name,"compound","-");
    
    if ($compound ne "-") {
    
      my $hash = $defs{$name};
      
      if ($i%2==0) {
        $eo="even";
      }
      else {
        $eo="odd";
      }
      
      my $state = ReadingsVal($name,"state","inactive");
      my $stateIcon = FW_makeImage($state eq "active"?"rc_GREEN":"rc_RED", $state);
      my $lightState = "-";
      my $heatState = "-";
      my $camState = "-";
      my $coolState = "-";
      my $stateL = "-";
      my $stateH = "-";
      my $stateCam = "-";
      my $stateF = "-";
      my $lightDevice = "-";
      my $heatDevice = "-";
      my $camDevice = "-";
      my $coolDevice = "-";
      if ($hash->{helper}{$compound}{TYPE}{"light"}) {
        $lightDevice = $hash->{helper}{$compound}{TYPE}{"light"};
        $lightState = ReadingsVal($name,$lightDevice."_state","off");
        $stateL = $lightState eq "on"?"off":"on";
        $lightState = FW_makeImage($lightState eq "on"?"light_light_dim_100\@yellow":"light_light_dim_00\@grey", ReadingsVal($name,$hash->{helper}{$compound}{TYPE}{"light"}."_state","off"));
      }
      if ($hash->{helper}{$compound}{TYPE}{"heat"}) {
        $heatDevice = $hash->{helper}{$compound}{TYPE}{"heat"};
        $heatState = ReadingsVal($name,$heatDevice."_state","off");
        $stateH = $heatState eq "on"?"off":"on";
        $heatState = FW_makeImage($heatState eq "on"?"sani_heating\@red":"sani_heating\@grey", ReadingsVal($name,$hash->{helper}{$compound}{TYPE}{"heat"}."_state","off"));
      }
      if ($hash->{helper}{$compound}{TYPE}{"camera"}) {
        $camDevice = $hash->{helper}{$compound}{TYPE}{"camera"};
        $camState = ReadingsVal($name,$camDevice."_state","off");
        $stateCam = $camState eq "on"?"off":"on";
        $camState = FW_makeImage($camState eq "on"?"it_camera\@#FF9900":"it_camera\@grey", ReadingsVal($name,$hash->{helper}{$compound}{TYPE}{"camera"}."_state","off"));
      }
      if ($hash->{helper}{$compound}{TYPE}{"cool"}) {
        $coolDevice = $hash->{helper}{$compound}{TYPE}{"cool"};
        $coolState = ReadingsVal($name,$coolDevice."_state","off");
        $stateF = $coolState eq "on"?"off":"on";
        $coolState = FW_makeImage($coolState eq "on"?"weather_frost\@#FF9900":"weather_frost\@grey", ReadingsVal($name,$hash->{helper}{$compound}{TYPE}{"cool"}."_state","off"));
      }
      my $stateC = $state eq "active"?"inactive":"active";
      
      my @compounds = @{$hash->{COMPOUNDS}};
      
      my $options = "";
      
      foreach (@compounds) {
        $options .= " <option value='".$_."'";
        if ($_ eq $compound) {
           $options .= " selected='selected'";
        }
        $options .= ">".$_."</option>\n";
      }

      $ret .= "<tr id=\"compound_row_".$name."\" data-data=\"true\" data-line-id=\"".$name."\" class=\"sortit compound_data ".$eo."\">\n".
              " <td class=\"col1 compound_col1\">\n".
              " <input type=\"hidden\" class=\"compound_name\" id=\"compound_name_".$name."\" value=\"".$name."\" />\n".
              #"    <div class=\"compound_move\"></div>\n".
              "   <span>".(!$FW_hiddenroom{detail}?"<a title=\"\" href=\"/fhem?detail=".$name."\">":"").
                      AttrVal($name,"alias",$name).
                    (!$FW_hiddenroom{detail}?"</a>":"")."</span>\n".
              " </td>\n".
              " <td class=\"col2 compound_status\">\n".
              "   <span class=\"compound_span compound_status_span compound_status_span_".$name."\" data-id=\"".$name."\" data-do=\"".$stateC."\">".
                    $stateIcon.
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_compound\">\n".
              "   <span class=\"compound_span compound_compound_span compound_compound_span_".$name."\" data-id=\"".$name."\">\n".
              "     <select id=\"compound_compound_".$name."\" name=\"compound_compound_".$name."\">".$options."</select>\n".
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_light".($lightState ne "-"?" compound_switch compound_switch_".$name:"")."\">\n".
              "   <span class=\"compound_span compound_light_span\" data-device=\"".$lightDevice."\" data-do=\"".$stateL."\" data-id=\"".$name."\">".
                    $lightState.
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_heat".($heatState ne "-"?" compound_switch compound_switch_".$name:"")."\">\n".
              "   <span class=\"compound_span compound_heat_span\" data-device=\"".$heatDevice."\" data-do=\"".$stateH."\" data-id=\"".$name."\">".
                    $heatState.
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_cam".($camState ne "-"?" compound_switch compound_switch_".$name:"")."\">\n".
              "   <span class=\"compound_span compound_cam_span\" data-device=\"".$camDevice."\" data-do=\"".$stateCam."\" data-id=\"".$name."\">".
                    $camState.
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_temp\">\n".
              "   <span class=\"compound_span compound_temp_span\" data-id=\"".$name."\">".
                    ReadingsNum($name,$hash->{helper}{$compound}{tempDevice}."_temperature",0)."°C".
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_hum\">\n".
              "   <span class=\"compound_span compound_hum_span\" data-id=\"".$name."\">".
                    ReadingsNum($name,$hash->{helper}{$compound}{tempDevice}."_humidity",0)."%".
              "   </span>\n".
              " </td>\n".
              "</tr>\n";
              
      $i++;
    }
  }
  
  $ret .= "</tbody>";
  
  # refresh request? don't show everything
  if (!$refreshGet) {
    $ret .= "</table></td></tr>\n";
    $ret .= "</table>\n";
    $ret .= "</div>\n";
    $ret .= "<br style=\"clear:both;\" /><br />";
  }
  
  return $rot.$ret;
}

sub compound_inArray {
  my ($arr,$search_for) = @_;
  foreach (@$arr) {
    return 1 if ($_ eq $search_for);
  }
  return 0;
}

sub compound_abstime2rel($) {
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $t1 = 3600*$h+60*$m+$s;

  my @now = localtime;
  my $t2 = 3600*$now[2]+60*$now[1]+$now[0];
  my $diff = $t1-$t2;
  $diff += 86400 if($diff <= 0);

  return $diff;
}

1;

=pod
=item device
=item summary    manage your compound lights and heatings 
=item summary_DE Verwaltung für Gehege-Technik
=begin html

<a name="compound"></a>
<h3compound</h3>
<ul>
</ul>