#!/usr/bin/env perl
use warnings;
use strict;

use lib 'c:\ourPerl';
use StwaveUtils::StwaveObj;
use Mapping::UTMconvert;
use Lidar::PointTree;
use Geometry::PolyTools;

my $simfile='Bingham.sim';

my $dataName='wave';
my $fieldName='wave height';
my $record=1; 

my $kmlPolygon='search.kml';  # kml polygon to select area leave undef if you want to use the whole grid


# config for the points kmz
my $tileSize=0.00001*100;   # size of "square" quad-tree leaf nodes in degrees
my $colorFile='c:/ourPerl/jet.txt';
my @CLIM=(0,3);
my $numColors=12;
my $addAdjust=0;
my $multAdjust=3.280833333;
my $pngDir='pImages';
my $kmlDir='pFiles';
my $cbarTitle='Significant Wave Height, Feet';
my $nskip=1;
my $iconLabelScale=[0.5,0.5];


############################################################# end config
my ($pxRef,$pyRef);
if ($kmlPolygon){
    ($pxRef,$pyRef)=PolyTools::readKmlPoly($kmlPolygon);
}


my $stw=StwaveObj->newFromSim($simfile);

# read the output files
$stw->loadSpatialData($dataName);


my $ni=$stw->getParm('n_cell_i');
my $nj=$stw->getParm('n_cell_j');
print "ni = $ni, nj = $nj\n";

my $coordSys=$stw->getParm('coord_sys');
my $zone=$stw->getParm('spzone');
 
unless (lc($coordSys) eq 'utm'){
   print "coord_sys is $coordSys, but this script only works with UTM coordinate system\n";
   sleep(1000000);
}


my @LON=();
my @LAT=();
my @Z=();
my @CELL=();

my $minLat=999999;
my $maxLat=-999999;
my $minLon=9999999;
my $maxLon=-9999999;


foreach my $i (1..$ni){
   foreach my $j (1..$nj){
      my $cell=$stw->getCellNumber($i,$j,$record);
      push @CELL, $cell;

      my ($x,$y)=$stw->getXy($i,$j);
      my ($lon,$lat)=UTMconvert::utm2deg($x,$y,"$zone T");
      if ($kmlPolygon){
         my $inpoly=PolyTools::pointInPoly($lon,$lat,$pxRef,$pyRef);
         next unless ($inpoly);
      }
      push @LON, $lon;
      push @LAT, $lat;

      my $z=$stw->getSpatialDataByIjRecField($dataName,$i,$j,$record,$fieldName);
      push @Z,$z;

      $maxLat=$lat if $lat > $maxLat;
      $minLat=$lat if $lat < $minLat;
      $maxLon=$lon if $lon > $maxLon;
      $minLon=$lon if $lon < $minLon;


   }
}


# print a lon,lat,z file
open OUT, ">$dataName-$fieldName-$record.xyz";
print OUT "lon,lat,$fieldName\n";

foreach my $n (0..$#LON){
    print OUT "$LON[$n],$LAT[$n],$Z[$n]\n";
}
close OUT;



# make the kmz points file

#initialze the tree
my $tree=PointTree->new(
                          -NORTH=>$maxLat,
                          -SOUTH=>$minLat,
                          -EAST=>$maxLon,
                          -WEST=>$minLon,
			  -MINDY=>$tileSize      #approximately 256 x 256 meter
                     );

# create bin file
$tree->openBin('binfile');
# add points to the tree
$tree->addPointToBin(\@LON,\@LAT,\@Z,\@CELL);
#finalize the bin file
$tree->closeBin();
$tree->finalizeBin();
$tree->superFinalizeBin();
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
                        -NSKIP=>$nskip,
                        -ICONLABELSCALE=>$iconLabelScale
                        );


