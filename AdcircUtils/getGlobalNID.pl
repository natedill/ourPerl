#!/usr/bin/perl
use warnings;
use strict;
# useage:
#
# with command line agruments: perl getGlobalNID.pl PE LocalNID
#
# via STDIN e.g.
#
# grep -i  warnelev PE*/fort.16 | gawk '{print $7" "$17}' | perl getGlobalNID.pl > warnElev_global.txt
# grep -i  "maximum allowed gradient" PE*/fort.16 | gawk '{print $7" "$11}' | perl getGlobalNID.pl > gradMax_global.txt


my $pe;
my $lnid;
my $line;


if ($ARGV[1]) {  
  $lnid=$ARGV[1];  # get pe and local id from command line
  $pe=$ARGV[0];
  &getGlobalId ($lnid,$pe);
}else{                # for piped input
 while (<STDIN>) {
    chomp ;
    $_ =~ s/^\s+//;  # remove leading whitespece
    $_ =~ s/\s+$//;  # remove trailing whitespace
    ($lnid,$pe)=split(/\s+/,$_);
    &getGlobalId ($lnid, $pe);
    
 }
}


 

sub getGlobalId {
  my ($lnid,$pe)=@_;
  my $lnid2=$lnid; 
  my $fort18=sprintf("PE%04d/fort.18",$pe);
  #print "$fort18\n";
  open FORT18, "<$fort18" or die "cannot open $fort18";
  my $line=(<FORT18>);
  chomp $line;
  $line=(<FORT18>); # this line has the nuber of local elements
  $line =~ s/^\s+//;  # remove leading whitespece
  $line =~ s/\s+$//;  # remove trailing whitespace
  my @data=split(/\s+/,$line);
  #print "@data\n"; 
  my $nskip=$data[3]+1;
  while($nskip--){
    <FORT18>;
  }
 # my $lnid=$LNID[$i];
  while ($lnid--){
    $line=<FORT18>;
  }
  chomp $line;
  $line =~ s/^\s+//;  # remove leading whitespece
  $line =~ s/\s+$//;  # remove trailing whitespace
  print "$lnid2 $pe $line\n";
  
}  
