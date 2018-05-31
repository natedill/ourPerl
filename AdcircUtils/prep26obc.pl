#!/usr/bin/env perl
##################################################################################
# prep26obc.pl
#
# A script to prep the open boundary input for padcswan/punswan
#
# usage: (run in root directory of simulation after running adcprep)
#
# perl prep26obc.pl --np 36 --fort319 fort.319  --prepVersion 53
#
# --fort319 and --prepVersion are optional. default values are
# fort.319 and 53, respectively
#
# --prepVersion >= 54 will assume that adcprep has not renumbered the
# global node numbers to local node numbers (i.e. it ignores the fort.18)
# this should be used for ADCIRC version 54 or greater. 
#
# You must include a line in your fort.26 file that starts with the string 
# '$%%BOUNDSPEC%%' (without the quotes) where the swan boundary 
# commands should go (typically following all the READinp commands) 
# 
# The fort.319 file is a file similar in format to the fort.19 except that after
# the first line in the file, the lines contain the following data instead of the
# water surface elevtion:
# 
# for 1:numberOfRecords
#   for 1:numberOfOpenBoundaryNodes
#       yyyymmdd.HHMMSS Hs Tm DIR dd
#   end
# end
#
# where 
# yymmdd.HHMMSS is the iso formated time string
# Hs is the significant wave height (meters)
# Tm is the mean wave period (seconds)
# DIR is the wave direction in degrees ccw from east
# dd is the directional spreading coefficient in degrees
#
# np is the number of subdomains you preped for.  If you specify
# --np 1, then it assumes you are doing a serial run and does
# not try to enter into PE directories
#
# The script assumes you want to use the BOUnd SHAPespec command:
# BOUnd SHAPspec JONswap gamma=3.3 MEAN DSPR DEGRees 
# Obviously, if you change this you may also need to also change
# the data you put in the fort.319 or vice-versa (e.g. you are given 
# peak wave perod rath than mean wave period). see $boundShapspec 
# variable below 
#
# The script goes through all the PE* directories and reads the grid
# file to see if it has open boundaries. If the subdomain has an open 
# boundary it inserts the appropriate commands into the fort.26 file 
# in that PE directory, and writes associated TPAR files in the run
# root directory.  It assumes there is only one open boundary in each 
# subdomain, and will die if it finds NOPE > 1 
#
# 
#--------------------------------------------------------------------
# Copyright (C) 2017 Nathan Dill, Ransom Consulting, Inc.
#
# This program  is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3 of the 
# License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 59 Temple Place - Suite 330,Boston, MA  02111-1307,
# USA.
#----------------------------------------------------------------------                                       

# assumed BOU SHAP command...
my $boundShapespec='BOUnd SHAPespec MEAN DSPR DEGRees';
use strict;
use warnings;

use lib '/home/ycme/ourPerl';
use AdcircUtils::AdcGrid;
use Getopt::Long;

# some default settings
my $fort319='fort.319';
my $fort26out="fort.26";
my $np=1;
my $fulldomain14='fort.14';
my $prepVersion=53;

# get the command line options
GetOptions ( "np=i" => \$np,
             "fort319=s" => \$fort319,
             "fulldomain14=s" => \$fulldomain14,
             "prepversion=i" => \$prepVersion
           );
#----------------------------------------------------------------
# get the global node numbers for the open boundary nodes
my $adcGrid_full=AdcGrid->new();
$adcGrid_full->loadGrid($fulldomain14);
# how many open boundaries are there?
my $nope=$adcGrid_full->getNOPE();
die "ERROR: prep26obc.pl: fulldomain grid $fulldomain14 has no open boundaries\n" if $nope==0;
print "INFO: prep26obc.pl: fulldomain grid $fulldomain14 had $nope open boundaries\n";
my @GNIDS=();
# loop over the open boundaries
for my $ibnd (1..$nope) {
   # get the nodes these boundary nodes
   my ($nvdll,$ibtypee,$nodesref)=$adcGrid_full->getOpenBnd($ibnd);
   push @GNIDS,@{$nodesref};
}


#-------------------------------------------------------------------
# now read the fort.319 data 
open IN, "<$fort319" or die "ERROR: prep26obc.pl: cant open fort.319 $fort319\n";
my $line=<IN>;
my %DATA=(); # a hash to store all the TPAR data by global node id
foreach my $gnid (@GNIDS){
  $gnid =~ s/^\s+//;  # just in case there are leading or trailing spaces
  $gnid =~ s/\s+$//;
  $DATA{$gnid}=[];
}
my $gnid0=$GNIDS[0];
while (<IN>){
   chomp;
   my $gnid=shift(@GNIDS); push @GNIDS, $gnid;
   push @{$DATA{$gnid}},$_;
}
close(IN);
die "ERROR: prep26obc.pl: The number of records in $fort319".
    "is not evenly divisible by the number of open boundary nodes\n" unless ($gnid0 == $GNIDS[0]);

#---------------------------------------------------------
# loop over the subdirectories, read the grid, write the fort.26 and tpar files
foreach my $pe (0..$np-1){
print "INFO: prep26obc.pl: IN SUBDOMAIN $pe\n";
   my $pedir=sprintf("PE%04d/",$pe);
   $pedir='' if ($np==1); 
   my $fort14="$pedir".'fort.14';
   my $adcGrid=AdcGrid->new();
   $adcGrid->loadGrid($fort14);
   # how many open boundaries are there?
   my $nope=$adcGrid->getNOPE();
   next if ($nope==0);
   die "ERROR: prep26obc.pl: subdomain $pedir has $nope open boundaries, it can only handle one\n" if ($nope >1);  
   #print "nope is $nope\n";
   my @X;
   my @Y;
   my @NIDS;
   # loop over the open boundaries
   for my $ibnd (1..$nope) {
      # get the nodes these boundary nodes
      my ($nvdll,$ibtypee,$nodesref)=$adcGrid->getOpenBnd($ibnd);
      @NIDS=@{$nodesref};

      # loop over the nodes in this boundary and accumulate list of x,y coords.
      foreach my $nid (@NIDS) {
          # get the xyz for this node
          my ($x,$y,$z)=$adcGrid->getNode($nid);
          push (@X,$x);                           # reversing the order here
          push (@Y,$y);
      }
   }
   # calculate the LENgth along the boundary
   my @LEN=();
   my $len=0;
   push @LEN,$len;
   foreach my $n (1..$#X){
      $len=$len + ( ($X[$n]-$X[$n-1])**2. + ($Y[$n]-$Y[$n-1])**2. )**0.5;
      push @LEN, $len;
   }

   # read the fort.18 and get a table of local to global node ids
   my @L2G=();
   if ($np==1 or $prepVersion >= 54){
      foreach my $nid (@GNIDS){
         $L2G[$nid]=$nid;
      }
   }else{
      my $fort18="$pedir".'fort.18';
      open F18, "<$fort18" or die "ERROR: prep26obc.pl: cannot open $fort18";
      my $line=(<F18>);
      chomp $line;
      $line=(<F18>); # this line has the nuber of local elements
      $line =~ s/^\s+//;  # remove leading whitespece
      $line =~ s/\s+$//;  # remove trailing whitespace
      my @data=split(/\s+/,$line);
      my $nskip=$data[3];
      while($nskip--){
         <F18>;
      }
      $line=(<F18>); # this line has the nuber of local nodes 
      chomp $line;
      $line =~ s/^\s+//;  # remove leading whitespece
      $line =~ s/\s+$//;  # remove trailing whitespace
      @data=split(/\s+/,$line);
      my $lnn=$data[3];
      foreach my $n (1..$lnn){ 
        $line=<F18>;
        chomp $line;
        $line =~ s/^\s+//;  # remove leading whitespece
        $line =~ s/\s+$//;  # remove trailing whitespaceA
        $L2G[$n]=abs($line);
      }
   }
   close(F18);
 
   # write the insert for the fort.26;
   my $fort26str='';
   $fort26str .= "$boundShapespec\n\$\n";
   $fort26str .= "BOUndspec SIDE 1 CCW VARiable FILE &\n";
   foreach my $l (@LEN){
     my $lnid=shift(@NIDS); push @NIDS,$lnid;
     my $gnid=$lnid;
     $gnid=$L2G[$lnid] if $prepVersion < 54;
     if ($l < $LEN[$#LEN]){
        $fort26str .= "   $l \'TPAR-$gnid\' 1 &\n";
     }else{
        $fort26str .= "   $l \'TPAR-$gnid\' 1\n";
     }
   }
   $fort26str .=  "\$\n";

   #slurp the fort.26 file
   my $fort26="$pedir".'fort.26';
   my @LINES=();
   open F26, "<$fort26" or die "ERROR: prep26obc.pl: cant open $fort26 fir reading\n";
   while (<F26>){
      chomp;
      push @LINES, $_;
   }
   close(F26);
   #delete it
   unlink $fort26; # careful there
   open F26, ">$fort26" or die "ERROR: prep26obc.pl: cant open $fort26 for writing\n";
   foreach my $line (@LINES){
     if ($line =~ m/^\$%%BOUNDSPEC%%/){
        print F26 "$fort26str";
     }else{
        print F26 "$line\n";
     }
   }
   close(F26);

   # write the TPAR files
   foreach my $nid (@NIDS){
      my $gnid=$L2G[$nid];
      my $tparFile="TPAR-$gnid";  # in the run root directory
      open TPAR, ">$tparFile" or die "ERROR: prep26obc.pl: cant open TPAR-$gnid for writing\n";
      print TPAR "TPAR\n";
      my @Lines=@{$DATA{$gnid}};
      foreach my $line (@Lines){
         print TPAR "$line\n";
      }
      close (TPAR);
   }


} #end loop over PE dirs

