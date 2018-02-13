#!/usr/bin/env perl

use strict;
use warnings;
use lib 'c:\ourPerl';
use AdcircUtils::AdcGrid;
use Geometry::PolyTools;
use Mapping::UTMconvert;

# calculate the minimum/max/mean element edge size in meters for each node
#
# converts to utm for calculation

# write out size in fort.63 style file 

####################################
# configuration


my $fort14='fort.14';

my $utmZone='19 T';


#####################################


# load the grid
my $adcGrid=AdcGrid->new();
$adcGrid->loadGrid($fort14);


# get the nodal locations and convert to UTM
my $np = $adcGrid->getVar('NP');
my @NIDS=(0..$np);                             # first element is garbage so we can use 1 indexing below
my ($lon,$lat,$dp)=$adcGrid->getNode(\@NIDS);
my ($x_,$y_)=UTMconvert::deg2utm($lon,$lat,$utmZone);
# dereference x,y arrays
my @X=@{$x_};
my @Y=@{$y_};


# loop through nodes, get neighbors (from getNeighborNodes routine)

# first generate neighbor tables
my $neitab=$adcGrid->genNeighborTables;

my @NEITAB=@{$neitab};


my @MINDS;
my @MAXDS;
my @MEANDS;


foreach my $n (1..$np){
    #my @neighbors=$adcGrid->getNeighborNodes($n);

    my @neighbors=@{$NEITAB[$n]};  # much faster
    shift @neighbors if $neighbors[0] == $neighbors[$#neighbors];  # shift off the first element since non-boundary nodes repeat the first node as last.

print "node $n:   @neighbors\n";
    # coords if this poing
    my $x0=$X[$n]; 
    my $y0=$Y[$n];
    my $minds=999e99;
    my $maxds=-999e99;
    my $meands=0;
    my $knt=0;
    foreach my $k (@neighbors){
       my $ds=(($x0-$X[$k])**2 + ($y0-$Y[$k])**2)**0.5;
       $minds=$ds if $ds < $minds;
       $maxds=$ds if $ds > $maxds;
       $meands+=$ds;
       $knt++;
    }
    push @MINDS, $minds;
    push @MAXDS, $maxds;
    push @MEANDS, $meands=$meands/$knt;
}
    
 
# write some output showing the changes
open F63, ">edgeSize.63\n";
print F63 "rundes runid agrid\n";
print F63 " 3 $np 1. 1 1\n";
# the original
print F63 "1. 1\n";
foreach my $n (1..$np){
   print F63 "$n $MINDS[$n-1]\n";
}
# the new z
print F63 "2. 2\n";
foreach my $n (1..$np){
   print F63 "$n $MAXDS[$n-1]\n";
}
# the difference
print F63 "3. 3\n";
foreach my $n (1..$np){
   print F63 "$n $MEANDS[$n-1]\n";
}
close(F63);









