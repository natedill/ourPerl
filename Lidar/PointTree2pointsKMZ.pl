#!/usr/bin/perl
#
use strict;
use warnings;

use lib 'C:/ourPerl';
use Lidar::PointTree;

my $treeFile='tree.tree2';
my $colorFile='c:/ourPerl/jet.txt';

my @CLIM=(-6,10);
my $numColors=10;
my $addAdjust=0;
my $multAdjust=3.280833333;
my $pngDir='pImages';
my $kmlDir='pFiles';
my $cbarTitle='Elevation NAVD88 Feet';
my $nskip=50;
my $iconScale=0.5;
my $labelScale=0.5;


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
                        -NNSKIP=>$nskip, # use every nskip points
                        -CBARTITLE=>$cbarTitle, 
                        -ICONLABELSCALE=>[$iconScale, $labelScale]
                        );
$tree->makeColorbar($cbarTitle);



