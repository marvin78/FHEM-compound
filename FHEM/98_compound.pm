# $Id: 98_compound.pm  $

package main;

use strict;
use warnings;
use Time::Local;
use Data::Dumper; 
use JSON;

#######################
# Global variables
my $version = "0.9.82";

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
  "areyousure"        =>  "Are you sure?",
  "save"              =>  "Save",
  "restore"           =>  "Restore",
  "restoreconfirm"    =>  "Are you sure? This overwrites current plans.",
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
  "areyousure"        =>  "Sicher?",
  "save"              =>  "Speichern",
  "restore"           =>  "Wiederherstellen",
  "restoreconfirm"    =>  "Wirklich alle Pläne wiederherstellen?",
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
sub compound_setOff($$;$);
sub compound_SetPlan($;$);

sub compound_Initialize($) { 
  my ($hash) = @_;

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
    my @devs = devspec2array("TYPE=compound");
    if (@devs) {   
      if ($devs[0]) {
        # in any attribute redefinition readjust language
        my $lang = AttrVal($devs[0],"language", AttrVal("global","language","EN"));
        if( $lang eq "DE") {
          $compound_tt = \%compound_transtable_DE;
          $compound_month = \%compound_month_DE;
        }
        else{
          $compound_tt = \%compound_transtable_EN;
          $compound_month = \%compound_month_EN;
        }
      }
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
  
  delete($hash->{helper}{DATA});
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
        $hash->{helper}{DATA}{"tempDevices"}{$dev}=$compound;
        $hash->{helper}{DATA}{$compound}{"tempDevice"}=$dev;
        push @{$hash->{helper}{DATA}{$compound}{"compDevices"}},$dev;
        push @tdevices, $dev;
        readingsSingleUpdate($hash,$dev."_temperature",ReadingsVal($dev,"temperature","---"),1) if ($co ne "-" && $co eq $p[0]);
      }
      if ($r>1) {
        $i++;
        my @d=split(":",$dev);
        push @devices, $d[0];
        my $dStateType=$d[1]?$d[1]:"state";
        readingsSingleUpdate($hash,$d[0]."_state",ReadingsVal($d[0],$dStateType,"---"),1) if ($co ne "-" && $co eq $p[0]);
        $hash->{helper}{DATA}{"devices"}{$d[0]}=$compound;
        push @{$hash->{helper}{DATA}{$compound}{"devices"}},$d[0];
        push @{$hash->{helper}{DATA}{$compound}{"compDevices"}},$d[0];
        $hash->{helper}{DATA}{"DEVREADINGS"}{$d[0]}=$dStateType;    
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
    $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{DATA}{$co}{"compDevices"}}) if ($co ne "-" && defined($hash->{helper}{DATA}{$co}{"compDevices"}));
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
  
    my @devs=@{$hash->{helper}{DATA}{$compound}{devices}} if ($hash->{helper}{DATA}{$compound}{devices});
    
    foreach my $d (@devs) {
      
      if (ReadingsVal($name,$d."_type","-") eq "-") {
        $hash->{helper}{DATA}{$compound}{"TYPES"}{$d}="light";
        $hash->{helper}{DATA}{$compound}{"TYPE"}{"light"}=$d;
      }
      else {
        $hash->{helper}{DATA}{$compound}{"TYPES"}{$d}=ReadingsVal($name,$d."_type","-");
        $hash->{helper}{DATA}{$compound}{"TYPE"}{ReadingsVal($name,$d."_type","-")}=$d;
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
      $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{DATA}{$compound}{"compDevices"}}) if (defined($hash->{helper}{DATA}{$compound}{"compDevices"}));
      Log3 $name, 5, "$name: added NotifyDev ".$hash->{NOTIFYDEV}." to Device";
    }
    compound_SetDeviceTypes($hash);
    compound_SetPlan($hash);
  }
  else {
    if ($state eq "active" && $compound ne "-") {
      Log3 $name,5, $name."Notify: ".$devName;
      my $tDev=$hash->{helper}{DATA}{$compound}{"tempDevice"};
      my @devs;
      
      @devs=@{$hash->{helper}{DATA}{$compound}{"devices"}} if (defined($hash->{helper}{DATA}{$compound}{"devices"}));
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
            compound_checkTemp($hash,$name,$e[1]) if ($hash->{helper}{DATA}{"devices"}{$devName}=$compound && $dReading eq "temperature" && $init_done && $manu ne "on");
          }
          $doTable=1;
        }
        if (compound_inArray(\@devs,$devName)) {
          my $devStateType=$hash->{helper}{DATA}{"DEVREADINGS"}{$devName};
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
  
  if (!IsDisabled($name)) {
    push @sets, "compound:$compounds" if(!IsDisabled($name) );
    push @sets, "restore:noArg" if(!IsDisabled($name) );
    push @sets, "inactive:noArg" if(!IsDisabled($name) );
    push @sets, "save:noArg" if(!IsDisabled($name) );
  }
  push @sets, "active" if(IsDisabled($name) );
  
  if ($compound ne "-" && !IsDisabled($name)) {
    if (defined($hash->{"DEVICES"})) {
      my @devices = @{$hash->{"DEVICES"}};
      foreach my $de (@devices) {
        push @sets, $de."_type:camera,cool,heat,light";
        push @sets, $de."_plan:textFieldNL-long";
        push @sets, $de."_state:on,off,on-for-timer,on-till";   
      }
    }
  }
  
  @sets = sort { lc($a) cmp lc($b) } @sets;
  
  return join(" ", @sets) if ($cmd eq "?");
  
  return "$name is disabled. Enable it to set something." if( $cmd ne "active" && (AttrVal($name, "disable", 0 ) == 1 || ReadingsVal($name,"state","active") eq "inactive"));
  
  if ( $cmd =~ /^compound|active|inactive|restore|save|.*plan|.*type?$/ || $args[0] =~ /(.*on.*|.*off.*)/) {
    Log3 $name, 4, "$name: set cmd:$cmd".(defined($args[0])?" arg1:$args[0]":"").(defined($args[1])?" arg2:$args[1]":"");
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
      compound_ReloadPlan($name);
      compound_ReloadTable();
      compound_SetDeviceTypes($hash);
      $hash->{INTERVAL}=AttrVal($name,"interval",undef)?AttrVal($name,"interval",undef):300;
    }
    elsif ( $cmd eq "restore") {
      compound_Restore($hash);
    }
    elsif ( $cmd eq "save") {
      compound_Save($hash);
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
        compound_SetPlan($hash,$tPlan);
        compound_RestartGetTimer($hash);
      }
      else {
        map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
      }
    }
    if ( $cmd =~ /^.*state?$/ && defined($args[0]) && $args[0] =~ /^.*on.*$/ ) {
      Log3 $name, 4, "$name: set $args[0]";
      RemoveInternalTimer($hash);
      compound_setOn($hash,$name,$cmd,@args);
    }
    elsif ( $cmd =~ /^.*state?$/ && defined($args[0]) &&  $args[0] =~ /^.*off$/ ) {
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
sub compound_SetPlan($;$) {
  my ($hash,$oPlan) = @_;
  
  my $name=$hash->{NAME};
  my $error = "none";
  my $smerror = "none";
  
  $oPlan = "-" if (!defined($oPlan));
  
  if ($hash->{DEVICES}) {
    
    foreach my $dev (@{$hash->{DEVICES}}) {
      
      Log3 $name, 5, "$name: Plan Reading: ".ReadingsVal($name,$dev."_plan","-");
      
      my @plans = split(/\n/,ReadingsVal($name,$dev."_plan","-"));
      
      Log3 $name, 4, "$name: Dump Plan: ".Dumper(@plans);
      
      my @planArr;
      $error = "none";
      $smerror = "none";
      foreach my $line (@plans) {
        Log3 $name, 4, "compound [$name]: Line: $line";
        if ($line =~ /^(0?[1-9]|1[012])\ .*$/g) {
          my @mon = split(/ /,$line,2);
          Log3 $name, 4, "compound [$name]: Mon Dumper: ".Dumper(@mon);
          $line =~ s/^\s+|\s+$//g;
          if ($line =~ /^(0?[1-9]|1[012])(\ (([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?|(24:00(:00)?))\|(-|-?\d+))+$/ || $line eq "-") {
            $planArr[int($mon[0])] = $mon[1] if ($mon[0]=~/^\d+$/);
            Log3 $name, 4, "compound [$name]: Mon Dumper $mon[0]: ".Dumper($planArr[int($mon[0])]);
          }
          else {
            $smerror = "plan";
            Log3 $name, 2, "compound [$name]: Plan line has not the right format: ".$line; 
            if ($mon[0]=~/^\d+$/ && $hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{int($mon[0])}) {
              $planArr[int($mon[0])] = $hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{int($mon[0])};
            }
            else {
              $planArr[int($mon[0])] = "-";
            }
            readingsSingleUpdate( $hash,"lastError","plan has not the right format ($dev|".int($mon[0]).")",1 );
          }
        }
        else {
          $planArr[13] = "-";
          $error = "plan";
          readingsSingleUpdate( $hash,"lastError","plan has not the right format ($dev)",1 );
          Log3 $name, 2, "compound [$name]: plan has not the right format ($dev)";
        }
      }
      
      Log3 $name, 4, "compound [$name]: Error: ".$error;
      
      if ($error eq "none") {
        for(my $i=1;$i<=12;$i++) {
          #my $t = sprintf ('%02d',$i);
          if (defined($planArr[$i])) {
            $hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{$i} = $planArr[$i];
            Log3 $name, 4, "compound [$name]: Mon Dumper $i: ".Dumper($planArr[$i]);
          }
          else {
            $hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{$i}  = $planArr[13] if (defined($planArr[13]));
            $hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{$i}  = "-" if (!defined($planArr[13]));
          }
        }
      }
      if ($smerror eq "plan") {
        my $temp="";
        for(my $i=1;$i<=12;$i++) {
          if ($hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{$i}) {
            $temp .= $i." ".$hash->{helper}{DATA}{plan}{$hash->{helper}{DATA}{devices}{$dev}}{$dev}{$i};
            $temp .= "\n" if ($i!=12);
          }
        } 
        readingsSingleUpdate($hash,$dev."_plan",$temp,1);
      }
      map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
    }
  
    compound_RestartGetTimer($hash);
    
  }
  compound_ReloadPlan($name);
  
  return undef;
}

sub compound_Save($) {
  my ($hash) = @_;
  
  my $name=$hash->{NAME};
  
  my $json   = JSON->new->utf8;
    
  my $jhash = eval{ $json->encode(  $hash->{helper}{DATA} ) };
  Log3 $name,1,"compound [$name]: jhash: ".Dumper($jhash);
  my $error  = FileWrite("./log/compound_".$name,$jhash);
  
  
  Log3 $name,3,"compound [$name]: Data plan saved to files";
  
  readingsSingleUpdate( $hash, "lastSave", TimeNow(), 1 ); 
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
  
  return undef;
}

sub compound_Restore($) {
  my ($hash) = @_;
  
  my $name=$hash->{NAME};
  
  my ($error,@lines) = FileRead("./log/compound_".$name);
  
  if( defined($error) && $error ne "" ){
    Log3 $name,1,"compound [$name]: read error=$error";
    return undef;
  }
  my $json   = JSON->new->utf8;
  my $jhash = eval{ $json->decode( join('',@lines) ) };
  
  delete($hash->{helper}{DATA});
  
  $hash->{helper}{DATA} = {%{$jhash}}; 
  Log3 $name,5,"compound [$name]: Data plan restored from save file";
  
  readingsBeginUpdate( $hash );
  
  if ($hash->{helper}{DATA}{"activeCompound"} && $hash->{helper}{DATA}{"activeCompound"} ne ReadingsVal($name,"compound","-")) {
    readingsBulkUpdate( $hash, "compound", $hash->{helper}{DATA}{"activeCompound"});
  }
  
  foreach my $cp (@{$hash->{COMPOUNDS}}) {
    my @devs = @{$hash->{helper}{DATA}{$cp}{"devices"}} if ($hash->{helper}{DATA}{$cp}{"devices"});
    if (@devs) {
      foreach my $dev (@devs) {
        my $temp = "";
        for(my $i=1;$i<=12;$i++) {
          if ($hash->{helper}{DATA}{plan}{$cp}{$dev}{$i}) {
            $temp .= $i." ".$hash->{helper}{DATA}{plan}{$cp}{$dev}{$i};
            $temp .= "\n" if ($i!=12);
          }
        }
        my $devPlan = ReadingsVal($name,$dev."_plan","-");  
        my $devType = ReadingsVal($name,$dev."_type","-");  
        my $hashType = $hash->{helper}{DATA}{$cp}{TYPES}{$dev};
        readingsBulkUpdate($hash,$dev."_plan",$temp) if ($temp ne $devPlan);
        readingsBulkUpdate($hash,$dev."_type",$hashType) if ($hashType && $hashType ne $devType);
      }
    }
  }
  
  readingsBulkUpdate( $hash, "lastRestore", TimeNow());
  
  readingsEndUpdate( $hash, 1 );
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_removeLoading === \"function\") compound_removeLoading()", "")} devspec2array("TYPE=FHEMWEB");
  
  compound_ReloadPlan($name);
  
  compound_RestartGetTimer($hash);
  
  return 1;
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
      my @devices = @{$hash->{helper}{DATA}{$compound}{"devices"}};
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
    #readingsBulkUpdate($hash,$dev."_state",$cmd1);
    readingsBulkUpdate($hash,$dev."_manu",$cmd1);
    
    my $dHash;
    
    $dHash->{hash}=$hash;
    $dHash->{dev}=$dev;   
    $dHash->{cmd}=$cmd1;
    
    RemoveInternalTimer($dev);
    RemoveInternalTimer($hash);
    RemoveInternalTimer($dHash);
    
    InternalTimer(gettimeofday()+0.1, "compound_doSetOn", $dHash, 0);
    
    
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

## do set off
sub compound_setOff($$;$) {
  my ($hash, $dev, $auto) = @_;
  
  $auto = 0 if (!defined($auto));
  
  my @fDev=split(/_/,$dev);
    
  $dev=$fDev[0];
  
  my $name=$hash->{NAME};
  
  Log3 $name, 5, "$name: set off $dev";
  
  readingsSingleUpdate($hash,$dev."_manu","off",1);
  
  InternalTimer(gettimeofday()+1, "compound_doCheckTemp", $hash, 0);
  
  if (!$auto) {
    map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_ErrorDialog === \"function\") compound_ErrorDialog('$name','".$compound_tt->{"deviceaccplan"}."','".$compound_tt->{"attention"}."!')", "")} devspec2array("TYPE=FHEMWEB");
  }
  
  return undef;
}

sub compound_doSetOff ($) {
  my ($dHash) = @_;
  my $hash=$dHash->{hash};
  my $dev=$dHash->{dev};
  compound_setOff($hash,$dev,1);
  
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
    
    my $tempDev=$hash->{helper}{DATA}{$compound}{"tempDevice"};
              
    my $temp = ReadingsVal($tempDev,"temperature",0);
        
    readingsSingleUpdate($hash,$tempDev."_temperature",$temp,1);
    
    
    # aktuelle Zeit holen
    my $time=time;
    
    Log3 $name, 4, "$name: Begin check temperature: $name";
    if (defined($hash->{helper}{DATA}{$compound}{"devices"})) {
      my @devices=@{$hash->{helper}{DATA}{$compound}{"devices"}};
      foreach my $dev (@devices) {
        
        #Log3 $name, 5, "$name: Check temperature for device $dev with temperature $temp" if (defined($temp));
        
        my $cmd1=$hash->{helper}{DATA}{$compound}{"TYPES"}{$dev} ne "cool"?"on":"off";
        my $cmd2=$hash->{helper}{DATA}{$compound}{"TYPES"}{$dev} ne "cool"?"off":"on";
        
        my $tPlan=$hash->{helper}{DATA}{plan}{$compound}{$dev}{$month+1};
        
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
              
              my $planSec = 0;
              if (compound_isNumeric($planTime[2])) {
                $planSec = (int($planTime[2])>60 || int($planTime[2])<0)?0:int($planTime[2]);              
              }
              my $planMin = 0;
              if (compound_isNumeric($planTime[1])) {
                $planMin = (int($planTime[1])>60 || int($planTime[1])<0)?0:int($planTime[1]);              
              }
              my $planStd = 0;
              if (compound_isNumeric($planTime[0])) {
                $planStd = (int($planTime[0])>24 || int($planTime[0])<0)?0:int($planTime[0]);              
              }
              
              my $aPlanTime = timelocal($planSec,$planMin,int($planTime[0]),$mday,$month,$year);
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
      
      #my $oldC = "-";
      #$oldC = $hash->{helper}{DATA}{activeCompound} if ($hash->{helper}{DATA}{activeCompound});
      
      # set old devices off
      #if ($oldC ne "-" && $hash->{helper}{DATA}{$oldC}{"devices"}) {
      #  foreach (@{$hash->{helper}{DATA}{$oldC}{"devices"}}) {
      #    CommandSet(undef,"$_:FILTER=STATE!=off off");
      #  }
      #}
      
      $hash->{helper}{DATA}{activeCompound}=$co;
      
      readingsBeginUpdate($hash);
      
      readingsBulkUpdate($hash,"compound",$co);
      CommandDeleteReading(undef, "$hash->{NAME} .*_(state|temperature|humidity)");
      
      my $tempDev = $hash->{helper}{DATA}{$co}{"tempDevice"};
      
      if ($tempDev) {
        readingsBulkUpdate($hash,$tempDev."_temperature",ReadingsVal($tempDev,"temperature","---"));
        readingsBulkUpdate($hash,$tempDev."_humidity",ReadingsVal($tempDev,"humidity","---")) if (ReadingsVal($tempDev,"humidity","---") ne "---");
      }
      
      my $i=0;
      
      foreach my $dev (@{$hash->{helper}{DATA}{$co}{"devices"}}) {
        readingsBulkUpdate($hash,$dev."_state",ReadingsVal($dev,$hash->{helper}{DATA}{"DEVREADINGS"}{$dev},"---"));
        $i++;
      }
      
      readingsEndUpdate( $hash, 1 );
      if ($tempDev || $i>0) {
        $hash->{NOTIFYDEV} = "global,".join(",",@{$hash->{helper}{DATA}{$co}{"compDevices"}});
      }
      
      Log3 $name,4,"$name: compound set to $args[0]";
      
      compound_ReloadPlan($name);
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
sub compound_ReloadPlan($) {
  my ($regEx) = @_;
  
  $regEx=0 if (!defined($regEx));
  
  my $ret = compound_PlanHtml($regEx,1);
  $ret =~ s/\"/\'/g;
  $ret =~ s/\n//g;
  
  map {FW_directNotify("#FHEMWEB:$_", "if (typeof compound_reloadPlan === \"function\") compound_reloadPlan(\"$regEx\",\"$ret\")", "")} devspec2array("TYPE=FHEMWEB");
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
  
  my $ret = "";
  
#  my $compound = ReadingsVal($name,"compound","-");
#  
#  if ($compound ne "-") {
#  
#    my $devsLight = $hash->{helper}{DATA}{$compound}{TYPE}{"light"} if ($hash->{helper}{DATA}{$compound}{TYPE}{"light"});
#    my $devsHeat = $hash->{helper}{DATA}{$compound}{TYPE}{"heat"} if ($hash->{helper}{DATA}{$compound}{TYPE}{"heat"});
#    my $devsCam = $hash->{helper}{DATA}{$compound}{TYPE}{"camera"} if ($hash->{helper}{DATA}{$compound}{TYPE}{"camera"});
#    
#    my $options="";
#    $options .= "<option value=\"".$devsLight."\">".$compound_tt->{"light"}."</option>\n" if ($devsLight);
#    $options .= "<option value=\"".$devsHeat."\">".$compound_tt->{"heating"}."</option>\n" if ($devsHeat);
#    $options .= "<option value=\"".$devsCam."\">".$compound_tt->{"camera"}."</option>\n" if ($devsCam);
#    
#    my $time = FmtTime(gettimeofday()+3600);
#    
#    $ret .= "<div class=\"compound_on-till_container\" data-name=\"".$name."\">\n";
#    $ret .= " <a href=\"#\" class=\"set\">set</a>";
#    $ret .= " <select name=\"set_compound_device\" class=\"set_compound_device\">\n";
#    $ret .= "  ".$options;
#    $ret .= " </select>\n";
#    $ret .= " <select name=\"set_compound_type\" class=\"set_compound_type\">\n";
#    $ret .= "  <option value=\"on-till\">on-till</option>\n";
#    $ret .= "  <option value=\"on-for-timer\">on-for-timer</option>\n";
#    $ret .= " </select>\n";
#    $ret .= " <input type=\"time\" value=\"".$time."\" class=\"set_compound_timer\" />\n";
#    $ret .= " <input type=\"hidden\" value=\"".$time."\" class=\"set_compound_timer_hidden\" />\n";
#    $ret .= "</div>\n";
#  }

  return compound_Html($name,undef,1).compound_PlanHtml($name,undef,1).$ret;
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
    $rot .= " <script type=\"text/javascript\">
                compound_tt={};
                compound_tt.areyousure='".$compound_tt->{'areyousure'}."';
                compound_tt.save='".$compound_tt->{'save'}."';
                compound_tt.restore='".$compound_tt->{'restore'}."';
                compound_tt.restoreconfirm='".$compound_tt->{'restoreconfirm'}."';
              </script>";
    # Javascript
    $rot .= "<script type=\"text/javascript\" src=\"$FW_ME/www/pgm2/compound.js?version=".$version."\"></script>
                <style>
                  .compound_plan_container_div {
                      display: block;
                      padding: 0;
                      float:left;
                      margin-bottom:10px;
                      margin-right: 10px;
                  }
                  .compound_plan_container {
                      display: block;
                      padding: 0;
                  }
                  .compound_table {
                      float: left;
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
                    //width:220px;
                  }
                  tr.compound_plan td {
                    height:22px;
                  }
                  td.doDown {
                    cursor:pointer;
                    padding-right:10px;
                  }
                  div.compound_on-till_container {
                    margin-bottom: -10px
                  }
                  div.compound_on-till_container a {
                    border:2px solid;
                    padding-left: 4px;
                    padding-right: 4px;
                    margin-top: 2px;
                  }
                  div.compound_on-till_container select {
                    margin-right:0px!important;
                  }
                </style>";
    $ret .= "<div class='compound_plan_outer_container'>\n";
  }
                
  foreach my $name (@devs) {    
    if (!IsDisabled($name)) {
      my $hash = $defs{$name};  
      my $compound=ReadingsVal($name,"compound","-");
      
      my $lightDev = $hash->{helper}{DATA}{$compound}{TYPE}{light} if ($hash->{helper}{DATA}{$compound}{TYPE}{light});
      my $heatDev = $hash->{helper}{DATA}{$compound}{TYPE}{heat} if ($hash->{helper}{DATA}{$compound}{TYPE}{heat});
      my $camDev = $hash->{helper}{DATA}{$compound}{TYPE}{camera} if ($hash->{helper}{DATA}{$compound}{TYPE}{camera});
      my $coolDev = $hash->{helper}{DATA}{$compound}{TYPE}{cool} if ($hash->{helper}{DATA}{$compound}{TYPE}{cool});
    
      if ($compound ne "-") {     
        
        my $options="";
        $options .= "<option value=\"".$lightDev."\">".$compound_tt->{"light"}."</option>\n" if ($lightDev);
        $options .= "<option value=\"".$heatDev."\">".$compound_tt->{"heating"}."</option>\n" if ($heatDev);
        $options .= "<option value=\"".$camDev."\">".$compound_tt->{"camera"}."</option>\n" if ($camDev);
        
        my @timeArr = split(':',FmtTime(gettimeofday()+3600));
        my $time = $timeArr[0].":".$timeArr[1];
        
        if (!$refreshGet) {
          $ret .= "<div class=\"compound_plan_container_div\">";
          $ret .= "<div class=\"compound_on-till_container\" data-name=\"".$name."\">\n";
          $ret .= " <a href=\"#\" class=\"set\">set</a>";
          $ret .= " <select name=\"set_compound_device\" class=\"set_compound_device\">\n";
          $ret .= "  ".$options;
          $ret .= " </select>\n";
          $ret .= " <select name=\"set_compound_type\" class=\"set_compound_type\">\n";
          $ret .= "  <option value=\"on-till\">on-till</option>\n";
          $ret .= "  <option value=\"on-for-timer\">on-for-timer</option>\n";
          $ret .= " </select>\n";
          $ret .= " <input type=\"time\" value=\"".$time."\" class=\"set_compound_timer\" />\n";
          $ret .= " <input type=\"hidden\" value=\"".$time."\" class=\"set_compound_timer_hidden\" />\n";
          $ret .= "</div><br />\n";
          
          $ret .= "<div class=\"compound_plan_container\">\n";
          $ret .= "<table class=\"roomoverview compound_table\">\n";
            
          $ret .= "<tr class=\"devTypeTr\"><td colspan=\"3\">\n".
                  " <div class=\"compound_devType compound_devType_plan compound_devType_".$name." col_header\">\n".
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
        }
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
          
          my $valueL="-";
          my $valueH="-";
          my $valueC="-";
          my $valueF="-";
          
          $valueL = $hash->{helper}{DATA}{plan}{$compound}{$hash->{helper}{DATA}{$compound}{TYPE}{light}}{"$num"} if ($hash->{helper}{DATA}{$compound}{TYPE}{light} && $hash->{helper}{DATA}{plan}{$compound});
          $valueH = $hash->{helper}{DATA}{plan}{$compound}{$hash->{helper}{DATA}{$compound}{TYPE}{heat}}{"$num"} if ($hash->{helper}{DATA}{$compound}{TYPE}{heat} && $hash->{helper}{DATA}{plan}{$compound});
          $valueC = $hash->{helper}{DATA}{plan}{$compound}{$hash->{helper}{DATA}{$compound}{TYPE}{camera}}{"$num"} if ($hash->{helper}{DATA}{$compound}{TYPE}{camera} && $hash->{helper}{DATA}{plan}{$compound});
          $valueF = $hash->{helper}{DATA}{plan}{$compound}{$hash->{helper}{DATA}{$compound}{TYPE}{cool}}{"$num"} if ($hash->{helper}{DATA}{$compound}{TYPE}{cool} && $hash->{helper}{DATA}{plan}{$compound});

          
          $ret .= "<tr id=\"compound_plan_row_".$i."\" data-data=\"true\" data-line-id=\"".$i."\" class=\"sortit compound_plan ".$eo."\">\n".
                  " <td class=\"col1 compound_col1\">\n".
                    $month.
                  " </td>\n".
                  ($lightDev?"  <td class=\"col1 compound_plan_light\">\n".
                  "   <span class=\"compound_plan_light_text compound_plan_text_".$name."\" data-tid=\"".$lightDev."_".$i."\" data-name=\"".$lightDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\">".$valueL."</span>\n".
                  "   <input type=\"text\" style=\"display:none;\" data-tid=\"".$lightDev."_".$i."\" data-name=\"".$lightDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_lightInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueL."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_light_".$name."\" class=\"col2 doDown light_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($heatDev?" <td class=\"col1 compound_plan_heat\">\n".
                  "   <span class=\"compound_plan_light_text compound_plan_text_".$name."\" data-tid=\"".$heatDev."_".$i."\" data-name=\"".$heatDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\">".$valueH."</span>\n".
                  "   <input type=\"text\" style=\"display:none;\" data-tid=\"".$heatDev."_".$i."\" data-name=\"".$heatDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_heatInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueH."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_heat_".$name."\" class=\"col2 doDown heat_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($camDev?"  <td class=\"col1 compound_plan_cam\">\n".
                  "   <span class=\"compound_plan_light_text compound_plan_text_".$name."\" data-tid=\"".$camDev."_".$i."\" data-name=\"".$camDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\">".$valueC."</span>\n".
                  "   <input type=\"text\" style=\"display:none;\" data-tid=\"".$camDev."_".$i."\" data-name=\"".$camDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_camInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueC."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_cam_".$name."\" class=\"col2 doDown cam_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  ($coolDev?" <td class=\"col1 compound_plan_cool\">\n".
                  "   <span class=\"compound_plan_light_text compound_plan_text_".$name."\" data-tid=\"".$coolDev."_".$i."\" data-name=\"".$coolDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\">".$valueF."</span>\n".
                  "   <input type=\"text\" style=\"display:none;\" data-tid=\"".$coolDev."_".$i."\" data-name=\"".$coolDev."\" data-no=\"".$i."\" data-id=\"".$name."_".$i."\" class=\"compound_plan_input compound_coolInput compound_plan_input_".$name." compound_plan_input_".$name."_".$i."\" value=\"".$valueF."\" />\n".
                  " </td>\n".
                  " <td data-id=\"copy_cool_".$name."\" class=\"col2 doDown cool_down doDown_".$name."\">".
                  ($i==1?"↓":"&nbsp;").
                  " </td>\n":"").
                  "</tr>\n";
        }
        if (!$refreshGet) {
          $ret .= "</tbody>";
        
          $ret .= "</table></td></tr>\n";
          $ret .= "</table>\n";
          $ret .= "</div>\n";
        }
      }
      if (!$refreshGet) {
        $ret .= "</div>\n";
      }
    }
  }
  if (!$refreshGet) {
    $ret .= "</div>\n";
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
      if ($hash->{helper}{DATA}{$compound}{TYPE}{"light"}) {
        $lightDevice = $hash->{helper}{DATA}{$compound}{TYPE}{"light"};
        $lightState = ReadingsVal($name,$lightDevice."_state","off");
        $stateL = $lightState eq "on"?"off":"on";
        $lightState = FW_makeImage($lightState eq "on"?"light_light_dim_100\@yellow":"light_light_dim_00\@grey", ReadingsVal($name,$hash->{helper}{DATA}{$compound}{TYPE}{"light"}."_state","off"));
      }
      if ($hash->{helper}{DATA}{$compound}{TYPE}{"heat"}) {
        $heatDevice = $hash->{helper}{DATA}{$compound}{TYPE}{"heat"};
        $heatState = ReadingsVal($name,$heatDevice."_state","off");
        $stateH = $heatState eq "on"?"off":"on";
        $heatState = FW_makeImage($heatState eq "on"?"sani_heating\@red":"sani_heating\@grey", ReadingsVal($name,$hash->{helper}{DATA}{$compound}{TYPE}{"heat"}."_state","off"));
      }
      if ($hash->{helper}{DATA}{$compound}{TYPE}{"camera"}) {
        $camDevice = $hash->{helper}{DATA}{$compound}{TYPE}{"camera"};
        $camState = ReadingsVal($name,$camDevice."_state","off");
        $stateCam = $camState eq "on"?"off":"on";
        $camState = FW_makeImage($camState eq "on"?"it_camera\@#FF9900":"it_camera\@grey", ReadingsVal($name,$hash->{helper}{DATA}{$compound}{TYPE}{"camera"}."_state","off"));
      }
      if ($hash->{helper}{DATA}{$compound}{TYPE}{"cool"}) {
        $coolDevice = $hash->{helper}{DATA}{$compound}{TYPE}{"cool"};
        $coolState = ReadingsVal($name,$coolDevice."_state","off");
        $stateF = $coolState eq "on"?"off":"on";
        $coolState = FW_makeImage($coolState eq "on"?"weather_frost\@#FF9900":"weather_frost\@grey", ReadingsVal($name,$hash->{helper}{DATA}{$compound}{TYPE}{"cool"}."_state","off"));
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
                    ReadingsNum($name,$hash->{helper}{DATA}{$compound}{tempDevice}."_temperature",0)."°C".
              "   </span>\n".
              " </td>\n".
              " <td class=\"col2 compound_hum\">\n".
              "   <span class=\"compound_span compound_hum_span\" data-id=\"".$name."\">".
                    ReadingsNum($name,$hash->{helper}{DATA}{$compound}{tempDevice}."_humidity",0)."%".
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

sub compound_isNumeric {
	my $f = shift();
	if ($f =~ /^(\d+\.?\d*|\.\d+)$/) { return 1; }

	return 0;
}

1;

=pod
=item device
=item summary    manage your compound lights and heatings 
=item summary_DE Verwaltung für Gehege-Technik
=begin html

<a name="compound"></a>
<h3>compound</h3>
<ul>
</ul>