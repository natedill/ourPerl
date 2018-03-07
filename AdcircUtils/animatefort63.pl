#!/usr/bin/env perl
#
#  a script to make a kmz animation of water levels from fort.63
#
#  uses AdcGrid and ElementQuadTree packages from AdcircUtils
#   and KML::MakePNG
#
#  copyleft 2017 Nate Dill.
#
use strict;
use warnings;

use lib 'c:\ourPerl'; # this is the directory where you store the AdcircUtils perl packages
use AdcircUtils::AdcGrid;
use AdcircUtils::ElementQuadTree;
use KML::MakePNG;
use Date::Pcalc;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;


##########################################################
# configure the script
#
my $gridFile='fort.14';
my $fullDomainOutput='fort.63';
my $coldStartDate= '20080813013000';

my $animationStartDate='20010917000000';  # set to undef if you want whole timeseries
my $animationEndDate='20010920000000';

# name for output kmz file
my $kmzFile='WSE.kmz';

# some settings to control colors on plot
my $cmapFile='c:\ourPerl\jet.txt';  # file containing the colormap. See "sub loadColormap" for file format
my $numColors=20; # number of distinct colors to use
my $alpha=50;  # controls transparency (0-opaque, 255-transparent)
my $cll=0; # lower limit for colorbar
my $cul=5; # upper limit for colorbar
my $framesDir='Frames';  # name of the dir within the final kmz file that will hold individual frames' kml and png files
my $cbarTitle='Water Level (ft-NAVD88)';
my $wseConvert=3.280833333;              # multiplied by WSE prior to plotting

# specify the maximum number of elements in an elementQuadTree node
# a smaller value will take longer to build the tree (and might use up all your RAM), but will interpolate more quickly
my $maxelems=1000;          

# specify a region to make the animation (set to undef to use the whole domain)
my $minLat=undef;
my $minLon=undef;
my $maxLat=undef;
my $maxLon=undef;


# specify the resolution of the images
my $meanLat=29.5;  # mean latitude of grid
my $pixelSize=200;  # approximate size of pixels in meters

#
# end config
############################################## end config



my $dlon=$pixelSize * 1/60/1852 / cos($meanLat*3.14159/180);  # determines size of pixels
my $dlat=$pixelSize * 1/60/1852;  

mkdir "$framesDir";

# load colormap 
my $cmap=MakePNG::loadColormap($cmapFile);

# create the AdcGrid object and load the grid
my $adcGrid=AdcGrid->new($gridFile);

# get the number of elements in the grid to estimate how elements we wan to use for maxelems in the quadtree
my $ne=$adcGrid->getVar('NE');
my $np=$adcGrid->getVar('NP');

# create a ElementQuadTree object from the grid
my $tree = ElementQuadTree->new_from_adcGrid(   -MAXELEMS => $maxelems,  # maximum number of elements per tree node
                                                -ADCGRID=>$adcGrid,       # and adcGrid objecvt
                                               -NORTH=>$maxLat,          # the region for the tree, to only look at a portion of the grid (optional)
                                               -SOUTH=>$minLat,
                                               -EAST =>$maxLon,
                                               -WEST =>$minLon
                                            );
print "done building ElementQuadTree\n";

$maxLat=$adcGrid->getVar('MAX_Y') unless defined $maxLat;
$minLat=$adcGrid->getVar('MIN_Y') unless defined $minLat;
$maxLon=$adcGrid->getVar('MAX_X') unless defined $maxLon;
$minLon=$adcGrid->getVar('MIN_X') unless defined $minLon;

my @Interpolants; 
my $ypix=0;
my $xpix=0;
my $lat=$maxLat;
my @Y;
my @X;
my $k=0;
my $maxk=int(($maxLat-$minLat)/$dlat);
while ($lat >= $minLat){  # loop row by row from the top and figure lat,lon
   my $lon=$minLon;
   $xpix=0;
   $k++;
   print "$k of $maxk\n";
   while ($lon <= $maxLon){
      push @X,$lon;
      push @Y,$lat;
      my $interp=$tree->getInterpolant( -XX => $lon,
                                        -YY => $lat  
                                      );
     # print "$lat,$lon is \n";# unless (defined $interp);  
  
      push @Interpolants, $interp;

      $xpix++;           # count the x dimension
      $lon=$lon+$dlon;
   } 
   $ypix++;              # count the y dimention
   $lat=$lat-$dlat;
}

#--print "getting interpolants...\n";

#--my $interp=$tree->getInterpolant( -XX => \@X,
#--                                  -YY => \@Y  
#--                                      );
#--@Interpolants=@{$interp};

print "done getting interpolants\n";
     


# now open the fort.63 and read through it and write out the time series
open F63, "<$fullDomainOutput" or die "cant open $fullDomainOutput\n";

# skip the first line
<F63>; 
# read the number of nodes from the second line
my $line=<F63>;
$line =~ s/^\s+//;              # remove leading white space
my @data=split(/\s+/,$line);    # split on white space
my $np_ = $data[1];             # the number of nodes should be the 2nd element in the @data list
my $nspooleit=$data[2];

#check if the grid and fort.63 match 
die "grid number of nodes $np does not match fulldomain output number of nodes $np_\n" unless ($np == $np_);

# now get on with it
my @TIMESPANS;
my @KMLNAMES;

while (<F63>){
    chomp;
    $_ =~ s/^\s+//;              # remove leading white space
    $_ =~ s/\s+$//;              # remove trailing white space
    
    # get the time
    my ($time, $it)=split (/\s+/,$_); 

    # get the timespan
    $coldStartDate =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    my ($yr,$mo,$da,$hr,$mn,$sc)=Date::Pcalc::Add_Delta_YMDHMS($1,$2,$3,$4,$5,$6,0,0,0,0,0,$time);
    my $begin=sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$yr,$mo,$da,$hr,$mn,$sc);
    my $now=sprintf("%04d%02d%02d%02d%02d%02d",$yr,$mo,$da,$hr,$mn,$sc);
    $time=$time+$nspooleit;
    ($yr,$mo,$da,$hr,$mn,$sc)=Date::Pcalc::Add_Delta_YMDHMS($1,$2,$3,$4,$5,$6,0,0,0,0,0,$time);
    my $end=sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$yr,$mo,$da,$hr,$mn,$sc);
    my $timeSpan="<TimeSpan><begin>$begin</begin><end>$end</end></TimeSpan>\n";

    # skip snaps if before the time we want in the animation
    if (defined $animationStartDate){
       if ($now < $animationStartDate){
           foreach my $nid (1..$np){
               <F63>;
           }
           next;
       }
    }   


    push @TIMESPANS,$timeSpan;
    print "$timeSpan\n";


    my @FullDomainData=();
    print "interpolating timestep $it:  ";

    #read the full domain scalar data
    foreach my $nid (1..$np){
       my $line=<F63>;
       $line =~ s/^\s+//;              # remove leading white space
       $line =~ s/\s+$//;              # remove trailing white space
       my ($n,$wse)=split(/\s+/,$line);
       $FullDomainData[$n]=$wse;       # remember AdcGrid expects nothing at index 0
    }   
       
    # interpolate at the stations
    my @WSE=();
    foreach my $interp (@Interpolants){
        if (defined $interp){
           my $wse= $tree->interpValue ( -ZDATA => \@FullDomainData,
                                      -INTERPOLANT => $interp );
           if ($wse < -99998) {
              push @WSE, undef;
           }else{
              push @WSE, $wse * $wseConvert;
           }
        }else{
           push @WSE, undef;
        }

    } 
    # make the png
    my $tstr=$begin;
    $tstr =~ s/:/-/g;
    my $pngName="$tstr".'.png';   
    MakePNG::raster("$framesDir/$pngName",$xpix,$ypix,$numColors,$alpha,$cll,$cul,$cmap,\@WSE);

    # make the kml file associated with this overlay
    my $kmlName=$pngName;
    $kmlName=~ s/\.png/.kml/;
                                                           # north,          east,            south, west
    MakePNG::makeKml4Overlay("$framesDir/$kmlName",$pngName,$maxLat,$maxLon,$minLat,$minLon);
   
    push @KMLNAMES,$kmlName;

    # skip snaps if after the time we want in the animation
    if (defined $animationEndDate){
      last if ($now > $animationEndDate);
    } 

}

close (F63);

my $north=$maxLat;
my $south=$minLat;
my $west=$minLon;
my $east=$maxLon;


MakePNG::makeColorbar("$framesDir/colorbar.png",$cbarTitle,$numColors,$cmap,$cll,$cul);



# write the kml
# make the timeSpan file linking them all together, and zip it all up
    my $kmldoc=$kmzFile;
    $kmldoc =~ s/kmz$/kml/;
    open KML, ">$kmldoc";
    print KML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n";
    print KML "    <Document>\n";
    print KML "    <Region>\n";
    print KML "          <LatLonAltBox>\n";
    print KML "              <north>$north</north>\n";
    print KML "              <south>$south</south>\n";
    print KML "              <east>$east</east>\n";
    print KML "              <west>$west</west>\n";
    print KML "          </LatLonAltBox>\n";   
    print KML "          <Lod><minLodPixels>128</minLodPixels><maxLodPixels>-1</maxLodPixels></Lod>\n";
    print KML "     </Region>\n";
    print KML "     <ScreenOverlay>\n";
    print KML "       <name>colorbar</name>\n";
    print KML "        <Icon>\n";
    print KML "           <href>$framesDir/colorbar.png</href>\n";
    print KML "        </Icon>\n";
    print KML "        <overlayXY x=\"0.5\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
    print KML "        <screenXY x=\"0.5\" y=\".99\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
    print KML "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
    print KML "        <size x=\".5\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
    print KML "     </ScreenOverlay>\n";
    foreach my $lnkName ( @KMLNAMES){
       my $ts=shift(@TIMESPANS);
       print KML "      <NetworkLink>\n";
       print KML "         <name>$lnkName</name>\n";
       print KML "    <Region>\n";
       print KML "          <LatLonAltBox>\n";
       print KML "              <north>$north</north>\n";
       print KML "              <south>$south</south>\n";
       print KML "              <east>$east</east>\n";
       print KML "              <west>$west</west>\n";
       print KML "          </LatLonAltBox>\n";   
       print KML "         <Lod><minLodPixels>128</minLodPixels><maxLodPixels>-1</maxLodPixels></Lod>\n";
       print KML "     </Region>\n";
       print KML "$ts\n";
       print KML "         <Link><href>$framesDir/$lnkName</href><viewRefreshMode>onRegion</viewRefreshMode></Link>\n";
       print KML "      </NetworkLink>\n";
    }
    print KML "</Document>\n</kml>\n";
    close KML;
 
    # zip it up  
    my $zip = Archive::Zip->new();
 
    # add the Files Dir
    my $dir_member = $zip->addTree( $framesDir,$framesDir );

    # add the doc.file
    my $file_member = $zip->addFile( $kmldoc );

    # write it
 

    unless ( $zip->writeToFileNamed("$kmzFile") == AZ_OK ) {
        die 'write error';
    }
    #clean up
    unlink $kmldoc;
    rmtree($framesDir);
   

