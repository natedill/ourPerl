#!/usr/bin/env perl
##################################################
# depressionFiller.pl
# a perl script to fill in depressions in ADCIRC fort.14 grids
#
# requires perl modules from the ourPerl repository 
# https://github.com/natedill/ourPerl 
#
#
#  algorithm based on:
#  Planchon and Darboux, 2001, "A fast, simple and versatile 
#  algorithm to fill the depressions of digital elevatio models"
#  Catena 46 pp. 159-76
#
#  copyleft, 2017 natedill
#                                       
#######################################################################

use strict;
use warnings;
use lib 'c:\ourPerl';          
use AdcircUtils::AdcGrid;
use Geometry::PolyTools;



# arrays indexed starting with data at 1 (junk is at zero)

####################################
# configuration


my $unfilledGrid='unfilled.14';     # input grid file
my $filledGrid='filled.14';         # output grid file
my $dontFillPoly=undef;#'dontFill.kml';    # a kml polygon file to specify an area you don't want filled in
                                    # leave undef if you don't have one.
 
my $out63='DepressionsFilled.63';   # output fort.63 style file with three records
                                    # 1: original Z; 2: new Z; 3: the difference 

my $eps=0.000005;       # zero value will make filled areas perfectly level, > 0 will maintain some slope in filled areas
my $drainElev=2.5;     # nodes below this elevation act as "drains" and don't get filled in



# end configuration
#####################################




# load the grid
my $adcGrid=AdcGrid->new();
$adcGrid->loadGrid($unfilledGrid);

# generate neighbor table
my ($neitab,$node2Ele)=$adcGrid->genNeighborTables;
my @NEITAB=@{$neitab};




# get the nodal depths 
my $np = $adcGrid->getVar('NP');
my @NIDS=(0..$np);
my ($x,$y,$dp)=$adcGrid->getNode(\@NIDS);
my @DP=@{$dp};


# fill single node depressions and peaks everywhere
my @DP_=@DP;
foreach my $n (1..$np){
   my $maxNeighborDp=-999999999;
   my $minNeighborDp=99999999;
   foreach my $nei (@{$NEITAB[$n]}){
print "node $n, nei $nei, DP $DP[$nei]\n";
      $maxNeighborDp=$DP[$nei] if $DP[$nei] > $maxNeighborDp;
      $minNeighborDp=$DP[$nei] if $DP[$nei] < $minNeighborDp;
   }
   $DP_[$n]=$maxNeighborDp if $DP[$n] > $maxNeighborDp;
   $DP_[$n]=$minNeighborDp if $DP[$n] < $minNeighborDp;
}
@DP=@DP_;


# set initial water level and elevation
my @WSE=();
my @Z=();
my @VISITED=();
foreach my $dp (@DP){
   push @WSE, 99999;
   push @Z, -$dp;
   push @VISITED, 0;
}


# set the drains
my ($px,$py);
if (defined $dontFillPoly){
  ($px,$py)=PolyTools::readKmlPoly($dontFillPoly);
}
foreach my $n (1..$np){
   $WSE[$n]=$Z[$n] if $Z[$n] < $drainElev;
   if (defined $dontFillPoly){
     my $inPoly=PolyTools::pointInPoly($x->[$n],$y->[$n],$px,$py);
     $WSE[$n]=$Z[$n] if $inPoly;
   }
}



my $changed=1;
my $iter=0;
my $recursDepth=0;

while ($changed){
   $changed=0;
   $iter++;
   print "iteration $iter\n";
  
   foreach my $n (1..$np){
  #  print "iter $iter, node $n\n";
      next unless $WSE[$n] > $Z[$n];
      
      foreach my $nei (@{$NEITAB[$n]}){

         if ($Z[$n] >= $WSE[$nei] + $eps){
             $WSE[$n]=$Z[$n];
             $changed=1;
             &dryUpwardCell(\@WSE,\@Z,$eps,$n,$neitab,$recursDepth);
             next;
         }
         if ($WSE[$n] > $WSE[$nei] + $eps){
             $WSE[$n] = $WSE[$nei] + $eps;
             $changed=1;
         }
       }
   }
}

# set the unset values back to the original
#foreach my $n (1..$np){
#   $WSE[$n]=$Z[$n] if ($WSE[$n] == 99999);
#}


# write some output showing the changes
open F63, ">$out63\n";
print F63 "rundes runid agrid\n";
print F63 " 3 $np 1. 1 1\n";
# the original
print F63 "1. 1\n";
foreach my $n (1..$np){
   print F63 "$n $Z[$n]\n";
}
# the new z
print F63 "2. 2\n";
foreach my $n (1..$np){
   print F63 "$n $WSE[$n]\n";
}
# the difference
print F63 "3. 3\n";
foreach my $n (1..$np){
   my $df = $WSE[$n] - $Z[$n];
   print F63 "$n $df\n";
}
close(F63);




# set the unset values back to the original
#foreach my $n (1..$np){
#   $WSE[$n]=$Z[$n] if ($WSE[$n] == 99999);
#}


# set the depth and write the modified grid file
foreach my $n (1..$np){
   $DP[$n]=-$WSE[$n];
}
$adcGrid->setNode([0..$np],$x,$y,\@DP);


#check the weirheights
$adcGrid->checkWeirheights(0.15);


$adcGrid->write14($filledGrid);









#################################################
# recursive subroutine to "dry" uphill nodes
sub dryUpwardCell{
  my ($wse,$z,$eps,$n,$neitab,$recursDepth)=@_;
  $recursDepth++;
  if ($recursDepth > 99) {
    print "exceeded 99 recursions\n";
    return
  }
  foreach my $nei (@{$neitab->[$n]}){
    next if $wse->[$nei] < 99999;
    if ($z->[$nei] > $wse->[$n] + $eps ){
       $wse->[$nei]=$z->[$nei];
       &dryUpwardCell($wse,$z,$eps,$nei,$neitab,$recursDepth);
    }
  }
}



