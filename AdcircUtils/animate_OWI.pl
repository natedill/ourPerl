#!/usr/bin/env perl
use strict;
use warnings;

# make a kml animation of a OWI fort.222 file

use lib '/homeq/qrisq/ourPerl';
use KML::MakePNG;
use Date::Pcalc;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;


my $pi=atan2(0,-1);
my $deg2rad=$pi/180.0;


my $fort222='fort.222';

my $kmzFile="$fort222".'.kmz';

# some settings to control colors on plot
my $cmapFile='/homeq/qrisq/ourPerl/jet.txt';  # file containing the colormap. See "sub loadColormap" for file format
my $numColors=20;
my $alpha=255;
 # vectors
 my $vecSpacing=30;  # pixels 
 my $minVecLength =5 ; # pixel 
 my $maxVecLength = 50; # pixels


my $framesDir='OWI_PRE_files';
$framesDir='OWI_WND_files' if ($fort222 =~ m/\.222$/);
my $cbarTitle='sea level pressure (millibars)';
$cbarTitle='Wind Speed (m/s)' if ($fort222 =~ m/\.222$/);




#################################################### end config

 



mkdir "$framesDir";


# load colormap 
my $cmap=MakePNG::loadColormap($cmapFile);





# read the beginning
open IN, "<$fort222" or die "cant open $fort222\n";
my $line=<IN>;
$line=<IN>;
chomp $line;
my $ilat=substr($line,5,4);
my $ilon=substr($line,15,4);
my $dx=substr($line,22,6);
my $dy=substr($line,31,6);
my $swlat=substr($line,43,8);
my $swlon=substr($line,57,8);
my @DT;
$DT[0]=substr($line,68,12);

print "ilat = $ilat, ilon = $ilon, dx = $dx, dy = $dy, swlat = $swlat, swlon = $swlon, DT0 = $DT[0]\n";

my $north=$swlat+$dy*$ilat;
my $east=$swlon+$dx*$ilon;
my $west=$swlon;
my $south=$swlat;

 

my $binfile="$fort222".'.$binfile';
open BIN, ">$binfile";
binmode(BIN);
my $nv=0;
#my $knt=0;
while (<IN>){
  chomp;
  $_.='                                                             ';
  if (substr($_,68,12) =~ m/(\d\d\d\d\d\d\d\d\d\d\d\d)/){
     #$knt++;
     #last if ($knt >20);
     push @DT, $1;
     print "$1\n";
  }else{
     $_ =~ s/^\s+//;
     $_ =~ s/\s+$//;
     my @data=split(/\s+/,$_);
     #push @DATA, @data;
     foreach my $d (@data){
        my $packed=pack("f",$d);
        print BIN "$packed";
        $nv++;
        if ($d =~ m/nan/i){
          die "found a nan\n";
        }
        die "d is $d undefined\n" unless (defined $d);
     }

  }
}

close(BIN);
close(IN);

# get the data limits
#my ($cll,$cul)=minMax(\@DATA);
my $cll=999999;
my $cul=-999999;
open BIN, "<$binfile";
binmode(BIN);
my $buf;
foreach my $off (0..$nv-1){
   read(BIN,$buf,4);
   my $val=unpack("f",$buf);
   if (defined $val){
    $cll=$val if $val < $cll;
    $cul=$val if $val > $cul;
   }
  # print "sbstr $sbstr\n";
  # print " val is $val,  off is $off of nv $nv\n" unless (defined $val);
}
close(BIN);

if ($fort222 =~ m/\.222$/){
   my $maxxx=($cul*$cul +$cul*$cul)**0.5;
   $cul=$maxxx if $maxxx > $cul;
   $maxxx=($cll*$cll +$cll*$cll)**0.5;
   $cul=$maxxx if $maxxx > $cul;
   $cll=0.0000000000001;
}
print "minmax: $cll, $cul\n";



# get time difference between records for making timestamps

my $tdstr="$DT[0]--$DT[1]";
$tdstr =~ s/\s+//g;
print "testr $tdstr\n";
$tdstr  =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)--(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
my ($D_y,$D_m,$D_d, $Dh,$Dm,$Ds) = Date::Pcalc::Delta_YMDHMS($1,$2,$3,$4,$5,0,$6,$7,$8,$9,$10,0);



# now we've read all the data, make the pngs
my @TIMESPANS=();
my @KMLNAMES=();
open BIN, "<$binfile";
binmode(BIN);
my $rec=0;
foreach my $dt (@DT){
   # read the binary string for this record
   my $strlen=4*$ilon*$ilat;
   $strlen=$strlen*2 if ($fort222 =~ m/\.222$/);
   read(BIN,$buf,$strlen);   
my $lln=length($buf);
   print "buf len is $lln\n";
   # re-order the data from bottom up to top down
   my $pngName="$dt".'.png';
   my @WX=();
   my $j=$ilat-1;
   while ( $j > 0 ){
      my $i=0;
      while ($i < $ilon){  
          my $c= $j*$ilon + $i;
          #my $c=$rec*$ilat*$ilon + $j*$ilon + $i;
          #push @WX, $DATA[$c];
          push @WX, unpack("f",substr($buf,$c*4,4));
          $i++;
      }
      $j--;
   }
   $rec++;          
   my @WY=();


  if ($fort222 =~ m/\.222$/){
   $j=$ilat-1;
   while ( $j > 0 ){
      my $i=0;
      while ($i < $ilon){  
          my $c=$ilat*$ilon + $j*$ilon + $i;
          #push @WY, $DATA[$c];
          push @WY, unpack("f",substr($buf,$c*4,4));
          $i++;
      }
      $j--;
   }
   $rec++;
 

   my @Mag=();
   my @DIR=();
   foreach my $wx (@WX){
       my $wy=shift(@WY); push @WY, $wy;
       my $mag = ( $wx**2 + $wy**2 )**0.5;
       my $dir = atan2($wy,$wx)/$deg2rad; 
       if ($mag <= 0){ 
          $mag=undef;  # undef if you want it transparent 
          $dir=undef;
       }
       push @Mag, $mag;
       push @DIR, $dir; 
   }


   my $azimuth=0;
   MakePNG::raster_wVectors("$framesDir/$pngName",$ilon,$ilat,$numColors,$alpha,$cll,$cul,$cmap,\@Mag,\@DIR,$azimuth,$vecSpacing,$minVecLength,$maxVecLength);
 }else{ # end if 222
   MakePNG::raster("$framesDir/$pngName",$ilon,$ilat,$numColors,$alpha,$cll,$cul,$cmap,\@WX);
 }
   

   # figure the timespan
   $dt =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
   my $begin=sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$1,$2,$3,$4,$5,0);
   my ($yr,$mo,$da,$hr,$mn,$sc)=Date::Pcalc::Add_Delta_YMDHMS($1,$2,$3,$4,$5,0,$D_y,$D_m,$D_d, $Dh,$Dm,$Ds);
   my $end=sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$yr,$mo,$da,$hr,$mn,$sc);
   my $timeSpan="<TimeSpan><begin>$begin</begin><end>$end</end></TimeSpan>\n";
   push @TIMESPANS,$timeSpan;
   print "$timeSpan\n";

   # make the kml file associated with this overlay
   my $kmlName=$pngName;
   $kmlName=~ s/\.png/.kml/;
                                                           # north,          east,            south, west
   MakePNG::makeKml4Overlay("$framesDir/$kmlName",$pngName,$north,$east,$south,$west);
   
   push @KMLNAMES,$kmlName;


}




MakePNG::makeColorbar("$framesDir/colorbar.png",$cbarTitle,$numColors,$cmap,$cll,$cul);


# write the kml
# make the timeSpan file linking them all together, and zip it all up
    my $kmldoc='doc.kml';
    #$kmldoc =~ s/kmz$/kml/;
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
    close(BIN);
    unlink "$binfile";
   










sub minMax{
  my @data=@{$_[0]};
  my $min=9999e99;
  my $max=-99999e99;
  my $kmin=0;
  my $kmax=0;
  my $k=0;
  foreach my $datum (@data){
     next if $datum < -99998;
     $min=$datum if $datum < $min;
     $kmin=$k if $datum <= $min;
     $max=$datum if $datum > $max;
     $kmax=$k if $datum >= $max;
     $k++;
     
  }
  return ($min,$max,$kmin,$kmax);
}
