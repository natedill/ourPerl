#!/usr/bin/env perl
use strict;
use warnings;

use lib 'c:\ourPerl';
use SwanUtils::SwanObj;

use Lidar::PointTree;
use Geometry::PolyTools;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;

foreach my $grd (1..3){
 foreach my $var ('HS','Tp'){

  foreach my $dr ('0','45','90','135','180','225','270','315'){

 my $inputFile='D:\0_PROJECTS\211.06046-187-Penzance-Rd\SWAN\SwanRuns/'."$dr".'\Grid'."$grd".'.swn';
 my $dataFile='D:\0_PROJECTS\211.06046-187-Penzance-Rd\SWAN\SwanRuns/'."$dr".'\g'."$grd".'_'."$var".'.txt';
 my $kmzFile="Grid-$grd-$var-$dr".'.kmz';



# config for the points kmz
my $tileSize=0.00001*1000;   # size of "square" quad-tree leaf nodes in degrees
$tileSize=0.00001*10000 if ($grd==1);
$tileSize=0.00001*5000 if ($grd==2);
my $colorFile='c:/ourPerl/jet.txt';
my @CLIM=(0,6);
my $numColors=12;
my $addAdjust=0;
my $multAdjust=3.280833333;
my $pngDir='pImages';
my $kmlDir='pFiles';
my $cbarTitle='100-year Significant Waveheight (ft)'.", from $dr degrees";
my $nskip=1;
my $iconLabelScale=[0.5,0.5];




my $swn=SwanObj->newFromINPUT($inputFile);
 


 $swn->getCGRID();

my $xpc = $swn->{xpc};
my $ypc = $swn->{ypc};
my $xlenc = $swn->{xlenc};
my $ylenc = $swn->{ylenc};
my $mxc = $swn->{mxc};
my $myc = $swn->{myc};

# read the data
open IN, "<$dataFile";
my @Data=();
while (<IN>){
   chomp;
   $_ =~ s/^\s+//;
   my @d=split(/\s+/,$_);
   push @Data, @d;
}
close (IN);
print "nd -1 is $#Data\n";

my $nc=$mxc*$myc;
print "nc is $nc\n";

my @LON=();
my @LAT=();
my @Z=();
my @CELL=();
my @I=();
my @J=();

my $minLat=999999;
my $maxLat=-999999;
my $minLon=9999999;
my $maxLon=-9999999;

my $dy=$ylenc/$myc;
my $dx=$xlenc/$mxc;

my $cell=0;
foreach my $j (0..$myc){
   my $lat = $ypc+$j*$dy;
   foreach my $i (0..$mxc){
      my $lon = $xpc+$i*$dx;
      my $z=shift(@Data);
      if ($z > 0){
       push @LON, $lon;
       push @LAT, $lat;
       push @I, $i;
       push @J, $j;
       push @Z,$z;
       push @CELL, $cell;
      }

      # print "xyz $lon, $lat, $z\n";
      $maxLat=$lat if $lat > $maxLat;
      $minLat=$lat if $lat < $minLat;
      $maxLon=$lon if $lon > $maxLon;
      $minLon=$lon if $lon < $minLon;
      $cell++;

   }
}

#$fieldName =~ s/\//_div_/;
# print a lon,lat,z file
#my $xyzFile="$dataName-$fieldName-$record.xyz";
#open OUT, ">$xyzFile";
#print OUT "I,J,CELL_ID,lon,lat,$fieldName\n";
#
#foreach my $n (0..$#LON){
#    print OUT "$I[$n],$J[$n],$CELL[$n],$LON[$n],$LAT[$n],$Z[$n]\n";
#}
#close OUT;



# make the kmz points file

#initialze the tree
my $tree=PointTree->new(
                          -NORTH=>$maxLat,
                          -SOUTH=>$minLat,
                          -EAST=>$maxLon,
                          -WEST=>$minLon,
			  -MINDY=>$tileSize,      #approximately 256 x 256 meter
                          -IDBITS=>32

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




# zip it up  
my $zip = Archive::Zip->new();
 
    # add the Files Dirs
my $dir_member = $zip->addTree( $kmlDir,$kmlDir );
my $dir_member2 = $zip->addTree( $pngDir,$pngDir );

# add the doc.file
my $kmldoc='p_doc.kml';
my $file_member = $zip->addFile( $kmldoc );

# write it
unless ( $zip->writeToFileNamed("$kmzFile") == AZ_OK ) {
        die 'write error';
    }

#clean up
unlink $kmldoc;
rmtree($pngDir);
rmtree($kmlDir);


#####################################################################
# make an overlay

$kmzFile =~ s/kmz$/_overlay.kmz/;
$pngDir='Images';
$kmlDir='Files';




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




$zip = Archive::Zip->new();
 
    # add the Files Dirs
$dir_member = $zip->addTree( $kmlDir,$kmlDir );
$dir_member2 = $zip->addTree( $pngDir,$pngDir );

# add the doc.file
$kmldoc='doc.kml';
$file_member = $zip->addFile( $kmldoc );

# write it
unless ( $zip->writeToFileNamed("$kmzFile") == AZ_OK ) {
        die 'write error';
    }

 
unlink $kmldoc;
rmtree($pngDir);
rmtree($kmlDir);

unlink 'binfile';
unlink 'binfile.fin';
unlink 'binfile.fin.sfn';


} # end loop over directions
}
}
