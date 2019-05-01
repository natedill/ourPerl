#!/usr/bin/env perl
use strict;
use warnings;

use lib 'C:\ourPerl';
use StwaveUtils::StwaveObj;

my $nestSimFile="ScarboroughMarsh.sim";

my $parentSimFile="TO8_mid_v2.sim";

my $npoints=100; # number of points to extract spec output for nest boundary

my $parent=StwaveObj->new($parentSimFile);
my $nest=StwaveObj->new($nestSimFile);


# get the ni,nj values from the nest

my ($ni,$nj)=$nest->getNiNj();

# get the end points of the boundary

my ($x1,$y1)=$nest->getXy(1,1);
my ($x2,$y2)=$nest->getXy(1,$nj);


my $dx=$x2-$x1;
my $dy=$y2-$y1;
my $bndLen=($dx**2 +$dy**2)**0.5;  # the length of the boundary

my $ds=$bndLen/($npoints-1);  # spacing on which to get output/input for nest;
my $dxods=$dx/$bndLen;
my $dyods=$dy/$bndLen;

# print beginning of name list;
open FILE2, ">NestSimData.txt";
print FILE2 "#\n# Nest Point Data\n#\n";
print FILE2 '@nest_pts';
print FILE2 "\n";

print "dx,dy,ds $dx,$dy,$ds\n";
print "bndLen $bndLen\n";
sleep(10);

open FILE, ">NestBoundaryPoints.xyz";
# setp along the boundary and print out the i,j values from the parent
# where the nest boundary lies
my $s=0;
my $x=$x1;
my $y=$y1;
my $cnt=1;
while ($s<$bndLen) {
    $x=$x1+$dxods*$s;
    $y=$y1+$dyods*$s;
   my ($pi,$pj)=$parent->getIj($x,$y);
   print FILE2 "   inest($cnt) = $pi, jnest($cnt) = $pj,\n";
   print FILE "$x $y 0\n";
   $s=$s+$ds;
   $cnt++;
}
# now the last point
 my ($pi,$pj)=$parent->getIj($x2,$y2);
 print FILE2"   inest($cnt) = $pi, jnest($cnt) = $pj,\n";

   print FILE "$x2 $y2 0\n";
   close(FILE);
    
print FILE2 '/';
print FILE2 "\n";
print " numpoints =  $cnt\n";
close(FILE2);



