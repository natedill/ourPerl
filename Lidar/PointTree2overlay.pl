#!/usr/bin/perl
#
#
# make a KML super overlay from PointTree quad-tree data
#
#
######################################################################## 
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
# some config

use strict;
use warnings;

use lib 'C:/ourPerl';
use Lidar::PointTree;

my $treeFile='tree.tree2';
my $colorFile='c:/ourPerl/jet.txt';

my @CLIM=(0,30);
my $numColors=15;
my $addAdjust=0;
my $multAdjust=3.280833333;
my $pngDir='Images';
my $kmlDir='Files';
my $cbarTitle='Elevation NAVD88 Feet';

# end config
#############################################################

my $tree=PointTree->loadTree($treeFile);


$tree->makePNGs(
                 -COLORFILE=>$colorFile,  
                 -CLIM1=>$CLIM[0],
                 -CLIM2=>$CLIM[1],
                 -NUMCOLORS=>$numColors,
                 -ZADDADJUST=>$addAdjust,
                 -ZMULTADJUST=>$multAdjust,
                 -PNGDIR=>$pngDir
                );  


$tree->makeColorbar($cbarTitle);
$tree->writeKMLOverlay(
                        -KMLDIR=>$kmlDir   
                         );



