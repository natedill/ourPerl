#!/usr/bin/env perl
use strict;
use warnings;

use lib 'c:\ourPerl';
use StwaveUtils::StwaveObj;
use Mapping::UTMconvert;
use Cwd qw(getcwd);

# script to extract stwave results at a specific coordinate locations
my $simFile='stwave.sim';  # assume same for all directions

my @DIRS=('0','45','67.5','90','337.5');

# points to extract data  (geographic)
my @POINTS = ([-68.83731011499624,44.11561884969193],
              [-68.83669968501205,44.11559186685299]);


#################################################### end config

my $pwd=getcwd();
print "present working dir is $pwd\n";


my $I=[];
my $J=[];
my $E=[];
my $N=[];
my $HS=[];
my $TP=[];


# loop over points
my $k=0;
foreach my $point (@POINTS){
   my ($lon,$lat)=@{$point};
   print "extracting data at $lon, $lat\n";
   my $kk=0;
   foreach my $dir (@DIRS){
      # cd to dir for this direction
      chdir($dir);
      # create stwave object
      my $stw=StwaveObj->newFromSim($simFile);
    
      #load the wave data to get HS and TP
      $stw->loadSpatialData('wave');
      $stw->loadSpatialData('tp');

      # get utmzone
      my $coord_sys=$stw->getParm('coord_sys');
      my $zone=$stw->getParm('spzone');
      print "coord_sys = $coord_sys, zone=$zone\n";
      $zone.=' T';
      
      my ($e,$n)=UTMconvert::deg2utm($lon,$lat,$zone);
      print "easting = $e, northing = $n\n";

      # get i,j for the cell the point is in
      my ($i,$j)=$stw->getIj($e,$n);
      print "dir-$dir point $k is in cell (i,j) $i, $j\n";
      
      my $hs=$stw->getSpatialDataByIjRecField("WAVE",$i,$j,1,"wave height");
      my $tp=$stw->getSpatialDataByIjRecField("TP",$i,$j,1,'1/fma');

      $E->[$k]=$e;
      $N->[$k]=$n;
      $I->[$k]=$i;
      $J->[$k]=$j;
      $HS->[$k]->[$kk]=$hs;
      $TP->[$k]->[$kk]=$tp;

 
      chdir($pwd);
      $kk++;
   } 
   $k++;
}

   

$k=0;  
foreach my $point (@POINTS){
   print "\nPOINT $k---------------------------\n";
   print "   UTM Coords (e,n) meters: $E->[$k],$N->[$k]\n";
   print "   Cell (i,j):  $I->[$k], $J->[$k]\n";
   print "    DIR   |   HS (m)   |    TP (s)  |\n";      
   my $kk=0;
   foreach my $dir (@DIRS){
      my $str=sprintf("%5s |  %7.3f   |  %7.3f   |",$dir,$HS->[$k]->[$kk],$TP->[$k]->[$kk]); 
      print "    $str\n";
      $kk++;
   }

   $k++;
}
