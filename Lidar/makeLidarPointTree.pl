#!/usr/bin/perl
#
# make a pointTree quad-tree structure from lidar data in laz files
#
####################################################################### 
# Author: Nathan Dill, natedill@gmail.com
#
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
#                                       
#######################################################################

use strict;
use warnings;

use lib 'C:/ourPerl';
use Lidar::LasReader;
use Lidar::PointTree;
use Geometry::PolyTools;

use Storable;



##############################################################
# some Paths and Files
##############################################################
my $pathToLas='lazFiles';
my $kmlPolyName='LidarSearch.kml';
my $overlayName='McFarlandShores';

my $binFile='points.bin';
my $treeFile='tree.tree';
my $tree;

my $tmpBinFile='points.tmp';  # temporary bin file to hold output from lasReader

my $tileSize=0.00001*300;   # size of "square" quad-tree leaf nodes in degrees

my $batchSize=2000000;  # point batch size for processing when creating tree's bin file

my $dsID=0;  # an integer to specify the particular data set (incase adding multiple data sets to tree)

################################################
# get polygon 
################################################
my $pxRef;
my $pyRef;
if ($kmlPolyName){
   ($pxRef,$pyRef)=PolyTools::readKmlPoly($kmlPolyName);
}



##############################################################
#
# select points, write out to file, determine
# region encompassing all points.
#
# use LasReader to filter and consolidate points into a t
# temporary binary points file 
#
# this is the 1st stream of data
#
##############################################################
my $minLat=999999;
my $maxLat=-999999;
my $minLon=9999999;
my $maxLon=-9999999; # these will store the range of found points


my %pointSelect=(
	 # -REGION=>[$north,$south,$east,$west],  # if defined will only print points in this region
	   -POLY=>[$pxRef,$pyRef],                # if defined will only print points in this polygon(closed loop described by @px and @py)
           -CLASSES=>[2],                         # if defined will only print these classes.
	    -ZREGION=>[-1000,15],                 # if defined will only print points in this z range
           -BINSTREAM=>1,                         # if defined output binary stream of selected points (x,y,z 8-byte doubles) 
           -OUTFILE=>$tmpBinFile                  # if defined output will be appended to filename instead of STDOUT
                        );

# get list of files in the directory
opendir(DH, "$pathToLas") or die "Can't Open Directory $pathToLas\n";
my @files =readdir(DH);
   
# loop over files
# if you find a laz file, check its header to see if
# its in the region, if so unzip it with laszip, read it,
# then remove it 
foreach my $file (@files) {
       
    print "$file\n";
    # creat a temporary las file from the laz file
    next if ($file !~ /\.laz$/i);
       
    #check to see if file header is in polygon
    my ($xmax,$xmin,$ymax,$ymin,$zmax,$zmin)=LasReader::getHeaderRange("$pathToLas/$file");
    my $bxInPoly=PolyTools::boxInPoly($xmin,$ymin,$xmax,$ymax,$pxRef,$pyRef);
    my $polyInBox=PolyTools::polyInBox($xmin,$ymin,$xmax,$ymax,$pxRef,$pyRef);
    print "rrange: $xmin,$xmax,$ymin,$ymax,$zmin,$zmax\n";
    print "bx in poly $bxInPoly\n";
    print "poly in bx $polyInBox\n";
    next unless ($bxInPoly or $polyInBox);

    my $cmdStr="laszip -i $pathToLas/$file -o tmp.las";
    print "Executing> $cmdStr\n";
    system($cmdStr);

    # read the points from the file (see %pointSelect hash above to select points)
   # LasReader::printHeader('tmp.las');
#sleep(100);
    my ($mnLt,$mxLt,$mnLn,$mxLn)=LasReader::printPoints("tmp.las",%pointSelect);	 

    if (defined $mnLt) {
        $maxLat=$mxLt if $mxLt >= $maxLat;
        $maxLon=$mxLn if $mxLn >= $maxLon;
        $minLat=$mnLt if $mnLt <= $minLat;
        $minLon=$mnLn if $mnLn <= $minLon;
    }
       
print "minmax:$minLat,$maxLat,$minLon,$maxLon\n";
} #end loop over files
##############################################################
#
# end of the first stream  
#
##############################################################



################################################################
# 
# now build the tree using the selected points
#
###############################################################

#  intialize the tree
 $tree=PointTree->new(
                          -NORTH=>$maxLat,
                          -SOUTH=>$minLat,
                          -EAST=>$maxLon,
                          -WEST=>$minLon,
			  -MINDY=>$tileSize      #approximately 256 x 256 meter
                     );

# initialize/open the bin file for writing
$tree->openBin($binFile);

# make an ascii xyz file 
  open ASC, ">points.xyz";

#open original finalized for input
# loop through it and add points
open IN, "<$tmpBinFile";   # this file is in the binary format output by lasReader
binmode(IN);
$/=\26;
#my $batchSize=2000000;
my $nn=0;
while (1){
     print "processing batch $nn\n";
     $nn++;
     my @X=();
     my @Y=();
     my @Z=();
     my @ID=();

     foreach my $n (1..$batchSize){
         last if (eof(IN));
         my $xyz = <IN>;
         my ($x,$y,$z,$dsID)=unpack("d3n",$xyz);
         next if ($x <= -999998);        # this was a trick to read a finalized file, shouldn't matter now
         push @X, $x;
         push @Y, $y;
         push @Z, $z;
         push @ID, $dsID;  # here's where the data set ID gets specified
         
          print ASC "$x, $y, $z\n";
     }
     $tree->addPointToBin(\@X,\@Y,\@Z,\@ID);
     last if eof(IN);
}
close(IN);
 close(ASC);
print "done counting";

$tree->closeBin();
# end of the 2nd stream

# remove the tmp bin file
unlink ($tmpBinFile) ;


# report the count
$tree->reportCount('CountReport.txt');


# store the tree 
print "storing tree 1\n";
#store $tree, "$treeFile".'1';
$tree->storeTree("$treeFile".'1');

# finalize - the third stream
$tree->finalizeBin();


# superfinalize -  fourth stream also recores byte offsets in tree structure for quick reference to file
$tree->superFinalizeBin();

# report the count
$tree->reportCount('decrementReport.txt');


# store the tree 
print "storing tree 1\n";
#store $tree, "$treeFile".'2';
$tree->storeTree("$treeFile".'2');


###################################################################
#
# now we're done making the lasTree
#
###################################################################



