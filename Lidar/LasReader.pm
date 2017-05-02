package LasReader;

# contains subroutines for getting data out of las files
# non OO version
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

#use lib 'E:\perl_scripts';
use Geometry::PolyTools;  # to get the pointInPoly routine  

use Mapping::P_spcs83;
use Mapping::UTMconvert;

###############################################
# sub printHeader 
#
# prints the header information to stdout
#
# $header=LasReader::printHeader()
#
#######################################################

sub printHeader {

   my $lasFileName=shift;
     
   open  FILE, "<$lasFileName"  or die "can't open $lasFileName";
   binmode(FILE);

   #variables
   my $recSize;
   my @data;
   my $buf;
   my $version;
   my $header=1;

   # get the file signature
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c4",$buf);   #c4 is for 4 signed characters
   my $fileSig=sprintf("%c%c%c%c", @data);
   print "\nFile Signature:  $fileSig\n"; 

   # get file source id
   $recSize=2;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S",$buf);           #S is for unsigned short
   printf "File Source ID:  %u\n", @data;

   # get the Gloabal encoding
   $recSize=2;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S",$buf);           #S is for unsigned short
   printf "Global Encoding:  %u\n", @data;

   # get the Project ID data  (ulong,ushort,ushort,8chars)
   $recSize=16;
   read(FILE, $buf, $recSize);
   @data=unpack("L S S c8",$buf);  
   printf "Project id = %u %u %u %c%c%c%c%c%c%c%c\n",@data;

   # get version
   $recSize=2;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c2",$buf);   # read 2 chars
   #printf "Version: %c.%c\n", @data;  it appears that we actually want the 8 bit integer values not encoded chars
   printf "Version: $data[0].$data[1]\n", @data;
   $version= "$data[0].$data[1]";


   # get system ID
   $recSize=32;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c32",$buf);   # read 32 chars
   printf "System ID: %c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c\n", @data;

   # get generating software
   $recSize=32;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c32",$buf);   # read 32  chars
   printf "Generating Software: %c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c\n", @data;

   # get file creation year-day and year
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S2",$buf);   # read 2 unsigned shorts
   printf "File Created: Day %u of %u\n",@data;

   # header size
   $recSize=2;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S",$buf);   # read 1 unsigned shorts
   printf "Header Size: %u bytes\n",@data;

   # offset to point data
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("L",$buf);   # read 1 unsigned long
   printf "Offset to Point Data: %u bytes\n",@data;

   # number of variable length records 
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("L",$buf);   # read 1 unsigned long
   printf "Number of Variable Length Records: %u \n",@data;

   # point data format ID
   $recSize=1;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c",$buf);   # read 1 char
   printf "Point Data Format ID: $data[0]\n",@data; # same here as for version number

   # point data record length etc
   $recSize=26;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S L6",$buf);   # read 1 short and 6 longs
   printf "Point Data Record Length: %u bytes\n".
          "Number of Point Records: %u\n".
          "Number of Points by Return: %u %u %u %u %u\n",@data;

   # scale factors
   $recSize=24;
   read(FILE, $buf, $recSize);
   (@data)=unpack("d3",$buf);   # read 3 doubles
   printf "Scale factors:\n".
          "   X_scale = %g\n".
          "   Y_scale = %g\n".
          "   Z_scale = %g\n",@data;

   # offsets
   $recSize=24;
   read(FILE, $buf, $recSize);
   (@data)=unpack("d3",$buf);   # read 3 doubles
   printf "Offsets:\n".
          "   X_offset =  %g\n".
          "   Y_offset = %g\n".
          "   Z_offset = %g\n",@data;


   # Range
   $recSize=48;
   read(FILE, $buf, $recSize);
   (@data)=unpack("d6",$buf);   # read 3 doubles
   printf "Range [max min]:\n".
          "   X_range = %g %g\n".
          "   Y_range = %g %g\n".
          "   Z_range = %g %g\n",@data;

   close FILE;
   return $header=0;

} #end sub printHeader



########################################################
#
# sub printPoints
# 
# prints [selected] points from the lasfile and returns 
# the lat/lon bounds of those [selected] points
#
# ($minLat,$maxLat,$minLon,$maxLon) 
#    =LasReader::printPoints ($filename,
#                         -REGION=>[$north,$south,$east,$west],  # if defined will only print points in this region
#                         -POLY=>[\@px,\@py],                    # if defined will only print points in this polygon(closed loop described by @px and @py)
#                         -CLASSES=>[@classesToPrint],           # if defined will only print these classes.
#                         -ZREGION=>[$bottom,$top],              # if defined will only print points in this z range
#                         -BINSTREAM=>1,                         # if defined output binary stream of selected points (x,y,z 8-byte doubles) 
#                         -OUTFILE=>filename                     # if defined output will be appended to filename instead of STDOUT
#                        )
#
##########################################################
sub printPoints {
   my $lasFileName=shift;
   
   # handle args
   my %args=@_; 

   my ($north,$south,$east,$west);
   my ($px,$py);
   my @classes;
   my ($bottom,$top);
   my $maxLon=-9999999999;
   my $minLon=99999999999;
   my $maxLat=-9999999999;
   my $minLat=99999999999;
   my $buf;
   my $recSize;
   my @data;
   my $outFH;  # default print to STDOUT
   


   if (defined $args{-REGION}) {
       ($north,$south,$east,$west)=@{$args{-REGION}};
       #     print "nsew: $north $south $east $west\n";

   }
   if (defined $args{-POLY}) {
       ($px,$py)=@{$args{-POLY}};  # these are references, need to dereference later
       #print "px: @{$px}\n";
       #print "py: @{$py}\n";
   }
   if (defined $args{-CLASSES}) {
       @classes=@{$args{-CLASSES}};
       # print "classes @classes\n";
   }
   if (defined $args{-ZREGION}) {
       ($bottom,$top)=@{$args{-ZREGION}};
       #print "zregion: $bottom $top\n";
   }
   if (defined $args{-OUTFILE}) {
         open $outFH, ">>$args{-OUTFILE}" or die "can't open $args{-OUTFILE} for append";
         binmode($outFH) if (defined $args{-BINSTREAM});
   }else{
      $outFH="STDOUT";
      if (defined $args{-BINSTREAM}) { 
          binmode(STDOUT);
      }
   }


   # get offset to points
   open  FILE, "<$lasFileName"  or die "can't open $lasFileName";
   binmode(FILE);

   # get the offset to point data
   seek(FILE, 96, 0);  # 96 bytes is the offset to the offset to points
   read(FILE, $buf, 4);
   my $off2Points=unpack("L",$buf);   # read 1 unsigned long
   #print "Offset to Point Data: $off2Points\n";

   # number of variable length records
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("L",$buf);   # read 1 unsigned long
   #printf "Number of Variable Length Records: %u \n",@data;
   my $nVLRs=$data[0];
    
   # point data format ID
   $recSize=1;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c",$buf);   # read 1 char
   #printf "Point Data Format ID: $data[0]\n",@data; # same here as for version number
   my $format=$data[0];

   # point data record length etc
   $recSize=26;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S L6",$buf);   # read 1 short and 6 longs
   # printf "Point Data Record Length: %u bytes\n".
   #       "Number of Point Records: %u\n".
   #       "Number of Points by Return: %u %u %u %u %u\n",@data;
   my $nPoints=$data[1];

   # scale factors
   $recSize=24;
   read(FILE, $buf, $recSize);
   my ($xScale,$yScale,$zScale)=unpack("d3",$buf);   # read 3 doubles
   #printf "Scale factors:\n".
   #       "   X_scale = %g\n".
   #       "   Y_scale = %g\n".
   #       "   Z_scale = %g\n",@data;
   #print "scale: $xScale $yScale $zScale\n";

   # offsets
   $recSize=24;
   read(FILE, $buf, $recSize);
   my ($xOff,$yOff,$zOff)=unpack("d3",$buf);   # read 3 doubles
   # printf "Offsets:\n".
   #       "   X_offset =  %g\n".
   #       "   Y_offset = %g\n".
   #       "   Z_offset = %g\n",@data;
   #print "offsets: $xOff $yOff $zOff\n";

   # Range
   $recSize=48;
   read(FILE, $buf, $recSize);
   my ($xRng1,$xRng2,$yRng1,$yRng2,$zRng1,$zRng2)=unpack("d6",$buf);   # read 3 doubles
   # printf "Range [max min]:\n".
   #       "   X_range = %g %g\n".
   #       "   Y_range = %g %g\n".
   #       "   Z_range = %g %g\n",@data;
   #print "xRng: $xRng1 $xRng2\n";
   #print "yRng: $yRng1 $yRng2\n";
   #print "zRng: $zRng1 $zRng2\n";
   
   # check to see if this file in any where within region or polygon 
   #   polygon takes preference if defined
   #   also need to check if the polygon is completely within the
   #   range of this file.
   my $polyInBox=0;
   my $boxInPoly=0;
   my $boxInRegion=0;
   if (defined $args{-POLY}) {
      $boxInPoly=PolyTools::boxInPoly($xRng2,$yRng2,$xRng1,$yRng1,$px,$py) ;
      $polyInBox=PolyTools::polyInBox($xRng2,$yRng2,$xRng1,$yRng1,$px,$py) ;
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng1,$yRng1,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng2,$yRng1,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng1,$yRng2,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng2,$yRng2,$px,$py);
      return if ($boxInPoly == 0 and $polyInBox==0);
   }elsif (defined $args{-REGION}) {
      return if $yRng2 > $north;
      return if $yRng1 < $south;
      return if $xRng2 > $east;
      return if $xRng1 < $west;
      $boxInRegion++ if ($yRng2 > $south);
      $boxInRegion++ if ($yRng1 < $north);
      $boxInRegion++ if ($xRng2 > $west);
      $boxInRegion++ if ($xRng1 < $east);
   }
   if (defined $args{-ZREGION}) {
      return if $zRng2 > $top;
      return if $zRng1 < $bottom;
   }


   # now start printing the points
    $recSize=20+$format*8;
    seek(FILE, $off2Points,0);
   

    while ($nPoints){

	read(FILE, $buf, $recSize);
	#data= (x,y,z,intensity,return bits,class,scan angle, usr data, point source id, GPStime(if format==1))
	(@data)=unpack("l3 S b8 C c C S d",$buf);
        my $x=$xOff+$xScale*$data[0];
        my $y=$yOff+$yScale*$data[1];
        my $z=$zOff+$zScale*$data[2];

	my $class=$data[5];
        
	# print "xyzclass: $x $y $z $class\n";
	# print "data; @data\n";

	# if the entire lidar box is not in the polygon or region
        # check if each point is in the polygon or region
	# if not skip ahead to the next point
	unless ($boxInPoly==4 or $boxInRegion==4){ 
           if (defined $args{-POLY}){
              my $inPoly=PolyTools::pointInPoly($x,$y,$px,$py);
	      if ($inPoly == 0) {  $nPoints--; next;}
           }elsif (defined $args{-REGION}){
               if ($y > $north) {  $nPoints--; next;}
               if ($y < $south) { $nPoints--; next;}
               if ($x > $east) { $nPoints--; next;}
               if ($x < $west) {  $nPoints--; next;}
	   }
        }
        
	# check to see if we want this class if not skip this point
	if (@classes) {
           my $foundClass=0;
           foreach my $cls (@classes) {
              if ($class==$cls) {$foundClass=1; last;}
           } 
	   if ($foundClass==0) { $nPoints--; next;}        
        }

	# check to see fi this point in in the zregion
        if (defined $args{-ZREGION}) {
             if ($z > $top)  { $nPoints--; next;}
	     if ($z < $bottom) {  $nPoints--; next;}
        }

	$maxLat=$y if $y >= $maxLat;
        $maxLon=$x if $x >= $maxLon;
        $minLat=$y if $y <= $minLat;
        $minLon=$x if $x <= $minLon;


        if (defined $args{-BINSTREAM}) {
             $buf=pack('d3',$x,$y,$z);
             if ($outFH eq 'STDOUT') {
                print STDOUT "$buf"
             }else{
                print $outFH "$buf";
             }
        }else{
             if ($outFH eq 'STDOUT') {
                print STDOUT "$x,$y,$z,$class\n";
             }else{
                print $outFH "$x,$y,$z,$class\n";
             }
        }

        $nPoints--;
    
    }   # end loop over points in this file 



close FILE;
close $outFH if (defined $args{-OUTFILE});
return ($minLat,$maxLat,$minLon,$maxLon);

}# end printPoints




########################################################
#
# sub convertAndPrintPoints
# 
# prints [selected] points from the lasfile and returns 
# the lat/lon bounds of those [selected] points
#
# ($minLat,$maxLat,$minLon,$maxLon) 
#    =LasReader::convertAndPrintPoints ($filename,
#                         -REGION=>[$north,$south,$east,$west],  # if defined will only print points in this region
#                         -POLY=>[\@px,\@py],                    # if defined will only print points in this polygon(closed loop described by @px and @py)
#                         -CLASSES=>[@classesToPrint],           # if defined will only print these classes.
#                         -ZREGION=>[$bottom,$top],              # if defined will only print points in this z range
#                         -BINSTREAM=>1,                         # if defined output binary stream of selected points (x,y,z 8-byte doubles) 
#                         -OUTFILE=>filename                     # if defined output will be appended to filename instead of STDOUT
#                         -CONVERT=>[SP,1/3.28083333,'LA S']     # if defined will convert points to geographic from state plane or UTM 
#                        )
#
##########################################################
sub convertAndPrintPoints {
   my $lasFileName=shift;
   
   # handle args
   my %args=@_; 

   my ($north,$south,$east,$west);
   my ($px,$py);
   my @classes;
   my ($bottom,$top);
   my $maxLon=-9999999999;
   my $minLon=99999999999;
   my $maxLat=-9999999999;
   my $minLat=99999999999;
   my $buf;
   my $recSize;
   my @data;
   my $outFH;  # default print to STDOUT
   
   my $cs;  #either SP of UTM for coordinate conversion
   my $unitConvert; # gets multiplied by x,y values in las file prior to conversion
   my $zone;   # 4 character string e.g. 'LA S' for state plane or '19 T' for UTM


   if (defined $args{-REGION}) {
       ($north,$south,$east,$west)=@{$args{-REGION}};
       #     print "nsew: $north $south $east $west\n";

   }
   if (defined $args{-POLY}) {
       ($px,$py)=@{$args{-POLY}};  # these are references, need to dereference later
       #print "px: @{$px}\n";
       #print "py: @{$py}\n";
   }
   if (defined $args{-CLASSES}) {
       @classes=@{$args{-CLASSES}};
       # print "classes @classes\n";
   }
   if (defined $args{-ZREGION}) {
       ($bottom,$top)=@{$args{-ZREGION}};
       #print "zregion: $bottom $top\n";
   }
   if (defined $args{-OUTFILE}) {
         open $outFH, ">>$args{-OUTFILE}" or die "can't open $args{-OUTFILE} for append";
         binmode($outFH) if (defined $args{-BINSTREAM});
   }else{
      $outFH="STDOUT";
      if (defined $args{-BINSTREAM}) { 
          binmode(STDOUT);
      }
   }
   if (defined $args{-CONVERT}) {
       ($cs,$unitConvert,$zone)=@{$args{-CONVERT}};
   }


   # get offset to points
   open  FILE, "<$lasFileName"  or die "can't open $lasFileName";
   binmode(FILE);

   # get the offset to point data
   seek(FILE, 96, 0);  # 96 bytes is the offset to the offset to points
   read(FILE, $buf, 4);
   my $off2Points=unpack("L",$buf);   # read 1 unsigned long
   #print "Offset to Point Data: $off2Points\n";

   # number of variable length records
   $recSize=4;
   read(FILE, $buf, $recSize);
   (@data)=unpack("L",$buf);   # read 1 unsigned long
   #printf "Number of Variable Length Records: %u \n",@data;
   my $nVLRs=$data[0];
    
   # point data format ID
   $recSize=1;
   read(FILE, $buf, $recSize);
   (@data)=unpack("c",$buf);   # read 1 char
   #printf "Point Data Format ID: $data[0]\n",@data; # same here as for version number
   my $format=$data[0];

   # point data record length etc
   $recSize=26;
   read(FILE, $buf, $recSize);
   (@data)=unpack("S L6",$buf);   # read 1 short and 6 longs
   # printf "Point Data Record Length: %u bytes\n".
   #       "Number of Point Records: %u\n".
   #       "Number of Points by Return: %u %u %u %u %u\n",@data;
   my $nPoints=$data[1];
 
   print "npoints $nPoints\n";

   # scale factors
   $recSize=24;
   read(FILE, $buf, $recSize);
   my ($xScale,$yScale,$zScale)=unpack("d3",$buf);   # read 3 doubles
   #printf "Scale factors:\n".
   #       "   X_scale = %g\n".
   #       "   Y_scale = %g\n".
   #       "   Z_scale = %g\n",@data;
   #print "scale: $xScale $yScale $zScale\n";

   # offsets
   $recSize=24;
   read(FILE, $buf, $recSize);
   my ($xOff,$yOff,$zOff)=unpack("d3",$buf);   # read 3 doubles
   # printf "Offsets:\n".
   #       "   X_offset =  %g\n".
   #       "   Y_offset = %g\n".
   #       "   Z_offset = %g\n",@data;
   #print "offsets: $xOff $yOff $zOff\n";

   # Range
   $recSize=48;
   read(FILE, $buf, $recSize);
   my ($xRng1,$xRng2,$yRng1,$yRng2,$zRng1,$zRng2)=unpack("d6",$buf);   # read 3 doubles

   # convert to geographic if necessary
   if (defined $cs){

  # print "converting before  $xRng1,$xRng2,$yRng1,$yRng2\n";
        if (lc($cs) eq 'sp'){
          my $x1=$xRng1;
          my $x2=$xRng2;
          my $y1=$yRng1;
          my $y2=$yRng2;
          
           $yRng1=-9999e999;
           $yRng2=9999e999;
           $xRng1=-9999e999;
           $xRng2=9999e999;

          my $lnTmp;
          my $ltTmp;

          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x1*$unitConvert,$y1*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x1*$unitConvert,$y2*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x2*$unitConvert,$y1*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x2*$unitConvert,$y2*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;

       }elsif(lc($cs) eq 'utm'){
          my $x1=$xRng1;
          my $x2=$xRng2;
          my $y1=$yRng1;
          my $y2=$yRng2;
          
           $yRng1=-9999e999;
           $yRng2=9999e999;
           $xRng1=-9999e999;
           $xRng2=9999e999;

          my $lnTmp;
          my $ltTmp;

          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x1*$unitConvert,$y1*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x1*$unitConvert,$y2*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x2*$unitConvert,$y1*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x2*$unitConvert,$y2*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
      }

   }
  
 
   # check to see if this file in any where within region or polygon 
   #   polygon takes preference if defined
   #   also need to check if the polygon is completely within the
   #   range of this file.
   my $polyInBox=0;
   my $boxInPoly=0;
   my $boxInRegion=0;
   if (defined $args{-POLY}) {
      $boxInPoly=PolyTools::boxInPoly($xRng2,$yRng2,$xRng1,$yRng1,$px,$py) ;
      $polyInBox=PolyTools::polyInBox($xRng2,$yRng2,$xRng1,$yRng1,$px,$py) ;
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng1,$yRng1,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng2,$yRng1,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng1,$yRng2,$px,$py);
      # $inPoly=$inPoly + PolyTools::pointInPoly($xRng2,$yRng2,$px,$py);
      return if ($boxInPoly == 0 and $polyInBox==0);
   }elsif (defined $args{-REGION}) {
      return if $yRng2 > $north;
      return if $yRng1 < $south;
      return if $xRng2 > $east;
      return if $xRng1 < $west;
      $boxInRegion++ if ($yRng2 > $south);
      $boxInRegion++ if ($yRng1 < $north);
      $boxInRegion++ if ($xRng2 > $west);
      $boxInRegion++ if ($xRng1 < $east);
   }
   if (defined $args{-ZREGION}) {
      return if $zRng2 > $top;
      return if $zRng1 < $bottom;
   }


   # now start printing the points
  
    $recSize=20+$format*8;
    seek(FILE, $off2Points,0);
  
    # grab the points ub batches and do the coordinate conversion on the batches
    my $batchSize=1000000;
 
    my $nBatches=0;
    while (1==1){

        my @X=();
        my @Y=();
        my @Z=();
        my @CL=();

        while (2==2){
           last if ($nPoints<=0);       
           read(FILE, $buf, $recSize);
	   #data= (x,y,z,intensity,return bits,class,scan angle, usr data, point source id, GPStime(if format==1))
	   (@data)=unpack("l3 S b8 C c C S d",$buf);
           my $x=$xOff+$xScale*$data[0];
           my $y=$yOff+$yScale*$data[1];
           my $z=$zOff+$zScale*$data[2];
           my $class=$data[5];
          # sleep 100 unless (defined $class);
          # sleep 100 if ($nPoints<10);

           # check to see if this point is in the zregion
           if (defined $args{-ZREGION}) {
                if ($z > $top)  { $nPoints--; next;}
	        if ($z < $bottom) {  $nPoints--; next;}
           }
           
           # check to see if we want this class if not skip this point
           if (@classes) {
              my $foundClass=0;
              foreach my $cls (@classes) {
                 if ($class==$cls) {$foundClass=1; last;}
              } 
	      if ($foundClass==0) { $nPoints--; next;}        
           }

           
           # if we're here, we're not excluding this point (at least not yet)
           # add the points to the batch
           push @X, $x*$unitConvert;
           push @Y, $y*$unitConvert;
           push @Z, $z;
           push @CL, $class;

           $nPoints--;
           
       #      print "npoints $nPoints  $#X\n";
               
           last if ($#X == $batchSize);
        } # end while 2==2

        $nBatches++;
        print "converting batch $nBatches, $nPoints remaining\n";
   
        # do the batch conversion
        my $x_ref;
        my $y_ref;
        if (defined $cs){
           if (lc($cs) eq 'sp'){
              my $n=\@Y;
              my $e=\@X;
              ($x_ref,$y_ref)=P_spcs83::sp2geo($e,$n,$zone);
              @Y=@{$y_ref};
              my @Xw=@{$x_ref};      # convert west degrees to east degrees
              @X=();
              foreach my $xw (@Xw){
                 push @X, -1*$xw 
              }
           }
           if (lc($cs) eq 'utm'){
              my $n=\@Y;
              my $e=\@X;
              ($x_ref,$y_ref)=UTMconvert::utm2deg($e,$n,$zone);
              @Y=@{$y_ref};
              @X=@{$x_ref};    
           }
        }
   
  print " done converting\n";
        
        # now loop over the points and print them
        my $ii=0;
        foreach my $x (@X){
           my $y=$Y[$ii];
           my $z=$Z[$ii];
           my $class=$CL[$ii]; 
   
	   # if the entire lidar box is not in the polygon or region
           # check if each point is in the polygon or region
	   # if not skip ahead to the next point

	   unless ($boxInPoly==4 or $boxInRegion==4){ 
              if (defined $args{-POLY}){
                  my $inPoly=PolyTools::pointInPoly($x,$y,$px,$py);  # px, py will already be geographic (from kml)
	          if ($inPoly == 0) {$ii++; next;} 
              }elsif (defined $args{-REGION}){
                   if ($y > $north) {$ii++; next;}    # range limits were converted above
                   if ($y < $south) {$ii++; next;} 
                   if ($x > $east) {$ii++; next;} 
                   if ($x < $west) {$ii++; next;} 
              }
           }
           # keep track of the range
           $maxLat=$y if $y >= $maxLat;  
           $maxLon=$x if $x >= $maxLon;
           $minLat=$y if $y <= $minLat;
           $minLon=$x if $x <= $minLon;

          if (defined $args{-BINSTREAM}) {
             $buf=pack('d3',$x,$y,$z);
             if ($outFH eq 'STDOUT') {
                print STDOUT "$buf"
             }else{
                print $outFH "$buf";
             }
           }else{
             if ($outFH eq 'STDOUT') {
                print STDOUT "$x,$y,$z,$class\n";
             }else{
                print $outFH "$x,$y,$z,$class\n";
             }
           }
           $ii++;
        }

        print "done printing\n  npoints $nPoints\n";

        last if ($nPoints<=0);
    
    }   # end while 1==1


close FILE;
close $outFH if (defined $args{-OUTFILE});
return ($minLat,$maxLat,$minLon,$maxLon);

}# end convertAndPrintPoints



###############################################
# sub getHeaderRange 
#
# prints the header information to stdout
#
# ($xmax,$xmin,$ymax,$ymin,$zmax,$zmin)=lasReader::getHeaderRange($file,%pointSelect)
#
# $cs in optional coordinate system e.
#
#######################################################

sub getHeaderRange {
    my $buf;
    my $lasFileName=shift;
    my %args=@_;
    my ($cs,$unitConvert,$zone);
    if (defined $args{-CONVERT}) {
      ($cs,$unitConvert,$zone)=@{$args{-CONVERT}};
    }

    open FH, "<$lasFileName" or die "cant open $lasFileName\n";
    binmode(FH);
    read(FH,$buf,375);
    close(FH);

    # las 1.4 header is 375 bytes
    # min/max xyz data are total of 48 bytes starting at offset 179
    my $range=substr($buf,179,48);
    
    my (@data)=unpack("d6",$range);   # read 3 doubles


   if (defined $cs){
        my ($xRng1,$xRng2,$yRng1,$yRng2,$zRng1,$zRng2)=@data;
       if (lc($cs) eq 'sp'){
          my $x1=$xRng1;
          my $x2=$xRng2;
          my $y1=$yRng1;
          my $y2=$yRng2;
          
           $yRng1=-9999e999;
           $yRng2=9999e999;
           $xRng1=-9999e999;
           $xRng2=9999e999;

          my $lnTmp;
          my $ltTmp;

          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x1*$unitConvert,$y1*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x1*$unitConvert,$y2*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x2*$unitConvert,$y1*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=P_spcs83::sp2geo($x2*$unitConvert,$y2*$unitConvert,$zone);
           $lnTmp=$lnTmp*-1;
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;

       }elsif(lc($cs) eq 'utm'){
          my $x1=$xRng1;
          my $x2=$xRng2;
          my $y1=$yRng1;
          my $y2=$yRng2;
          
           $yRng1=-9999e999;
           $yRng2=9999e999;
           $xRng1=-9999e999;
           $xRng2=9999e999;

          my $lnTmp;
          my $ltTmp;

          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x1*$unitConvert,$y1*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x1*$unitConvert,$y2*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x2*$unitConvert,$y1*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
          ($lnTmp,$ltTmp)=UTMconvert::utm2deg($x2*$unitConvert,$y2*$unitConvert,$zone);
           $xRng1=$lnTmp if $lnTmp > $xRng1;
           $yRng1=$ltTmp if $ltTmp > $yRng1;
           $xRng2=$lnTmp if $lnTmp < $xRng2;
           $yRng2=$ltTmp if $ltTmp < $yRng2;
       }



       return ($xRng1,$xRng2,$yRng1,$yRng2,$zRng1,$zRng2);
       
   }else{
       return (@data);
   }
}

1;

