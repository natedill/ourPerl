#!/usr/bin/perl
#
use strict;
use warnings;

use lib 'C:/ourPerl';
use Lidar::PointTree;

my $treeFile='tree.tree2';
my $colorFile='c:/ourPerl/jet.txt';

my @CLIM=(7,13);
my $numColors=12;
my $addAdjust=0;
my $multAdjust=3.280833333;
my $pngDir='pImages';
my $kmlDir='pFiles';
my $cbarTitle='Elevation NAVD88 Feet';
my $nskip=2;


my $tree=PointTree->loadTree($treeFile); 



$tree->writeKMLPoints(
                        -KMLDIR=>$kmlDir,
                        -COLORFILE=>$colorFile,  
                        -CLIM1=>$CLIM[0],
                        -CLIM2=>$CLIM[1],
                        -NUMCOLORS=>$numColors,
                        -ZADDADJUST=>$addAdjust,
                        -ZMULTADJUST=>$multAdjust,
                        -PNGDIR=>$pngDir,
                        -CBARTITLE=>$cbarTitle, 
                        -NSKIP=>$nskip 
                        );



