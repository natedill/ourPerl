#
#
#  some functions for making png plots
#
#
package MakePNG;
use strict;
use warnings;
use GD;

my $pi=atan2(0,-1);
my $deg2rad=$pi/180.0;

sub raster {
   my ($pngFile,$xpix,$ypix,$numColors,$alpha,$cll,$cul,$cmapRef,$dataref)=@_;
   my @data=@{$dataref};
   
   my @colors;
   my $im = new GD::Image($xpix,$ypix);
  
   @colors = &setColors($im,@{$cmapRef},$alpha);	
   my $transparent=$colors[0];

   $cul=$cll+1 if ($cul <= $cll);  # to avoid divide by zero down below if bad cul and cll were specified
   my $dzdc=($cul-$cll)/127;

   my $i;
   my $j =  0;
   my $cnt = 0;	
   my $C=0;
   while ($j<$ypix) {
      $i=0;	
      while ($i<$xpix) {
            $C=$data[$cnt];
            if (defined $C){
               $C=($C-$cll)/$dzdc +1;
               $C= int((int($numColors*($C-1)/128)+0.5 )*128/$numColors);
               $C=128 if ($C > 128); 
               $C=1 if ($C < 1);
            }else{
               $C=0;
            }
            $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map
	    $i++;
	    $cnt++;
      }
      $j++;
   }

   # now write the png file
   open FILE2, ">$pngFile";
   binmode FILE2;
   print FILE2 $im->png;
   close(FILE2);
   $im=undef;
}





sub raster_fade {
   my ($pngFile,$xpix,$ypix,$numColors,$alpha,$cll,$cul,$cmapRef,$dataref)=@_;
   my @data=@{$dataref};
   
   my @colors;
   my $im = new GD::Image($xpix,$ypix);
  
   @colors = &setColors_fade($im,@{$cmapRef},$alpha);	
   my $transparent=$colors[0];

   $cul=$cll+1 if ($cul <= $cll);  # to avoid divide by zero down below if bad cul and cll were specified
   my $dzdc=($cul-$cll)/127;

   my $i;
   my $j =  0;
   my $cnt = 0;	
   my $C=0;
   while ($j<$ypix) {
      $i=0;	
      while ($i<$xpix) {
            $C=$data[$cnt];
            if (defined $C){
               $C=($C-$cll)/$dzdc +1;
               $C= int((int($numColors*($C-1)/128)+0.5 )*128/$numColors);
               $C=128 if ($C > 128); 
               $C=1 if ($C < 1);
            }else{
               $C=0;
            }
            $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map
	    $i++;
	    $cnt++;
      }
      $j++;
   }

   # now write the png file
   open FILE2, ">$pngFile";
   binmode FILE2;
   print FILE2 $im->png;
   close(FILE2);
   $im=undef;
}




sub raster_wVectors {
   my ($pngFile,$xpix,$ypix,$numColors,$alpha,$cll,$cul,$cmapRef,$magref,$dirref,$azimuth,$vecSpacing,$minVecLength,$maxVecLength)=@_;
   my @MAG=@{$magref};
   my @DIR=@{$dirref};  # direction is degrees ccw from east minus azimuth 

   my @colors;
   my $im = new GD::Image($xpix,$ypix);
  
   @colors = &setColors($im,@{$cmapRef},$alpha);

   my $black = $colors[130];
	
   my $transparent=$colors[0];

   $cul=$cll+1 if ($cul <= $cll);  # to avoid divide by zero down below if bad cul and cll were specified
   my $dzdc=($cul-$cll)/127;

   my $i;
   my $j =  0;
   my $cnt = 0;	
   my $C=0;
   while ($j<$ypix) {
      $i=0;	
      while ($i<$xpix) {
            $C=$MAG[$cnt];
            if (defined $C){
               $C=($C-$cll)/$dzdc +1;
               $C= int((int($numColors*($C-1)/128)+0.5 )*128/$numColors);
               $C=128 if ($C > 128); 
               $C=1 if ($C < 1);
            }else{
               $C=0;
            }
            $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map
	    $i++;
	    $cnt++;
      }
      $j++;
   }
 
   $j=0;
   $cnt=0;
   $C=0;
   my $dldc=($maxVecLength-$minVecLength)/($cul-$cll);
   # draw the vectors
   while ($j<$ypix) {
      $i=0;	
      while ($i<$xpix) {
         if (($i % $vecSpacing == 0) and ($j % $vecSpacing ==0)){
            if ((defined $DIR[$cnt]) and (defined $MAG[$cnt])){
               my $mag=$MAG[$cnt];
               my $vecLength=$minVecLength;
               if ($mag > $cll){
                  $vecLength=$minVecLength + ($mag-$cll) * $dldc;
               }
               $vecLength=$maxVecLength if ($mag > $cul);               

               # get end points 

               my $dir=($DIR[$cnt] + $azimuth)*$deg2rad;
               my $p1x=$i;
               my $p1y=$j; 
               my $p2x=$i+cos($dir)*$vecLength;
               my $p2y=$j-sin($dir)*$vecLength;
               # draw shaft
               $im->line ($p1x,$p1y,$p2x,$p2y,$black);
 
               my $headLength=int($vecLength/5);
               $headLength=3 if $headLength < 3;

               # draw head for arrow
               my $dir2=$dir-195*$deg2rad;
               my $p3x=$p2x+cos($dir2)*$headLength;
               my $p3y=$p2y-sin($dir2)*$headLength;
               $im->line ($p2x,$p2y,$p3x,$p3y,$black);

               $dir2=$dir-165*$deg2rad;
               $p3x=$p2x+cos($dir2)*$headLength;
               $p3y=$p2y-sin($dir2)*$headLength;
               $im->line ($p2x,$p2y,$p3x,$p3y,$black);
        
            }
         }
         $i++;
         $cnt++;
      }
      $j++;
   }
   


   # now write the png file
   open FILE2, ">$pngFile";
   binmode FILE2;
   print FILE2 $im->png;
   close(FILE2);
   $im=undef;
}





sub makeKml4Overlay_wTimeSeriesPlot{
   my ($kmlName,$pngName,$tsPngName,$north,$east,$south,$west)=@_;
   

   open KML, ">$kmlName" or die "ERROR: MakePNG.pm:: cant open $kmlName\n";
   print KML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n";
   print KML "    <Document>\n";
      print KML "    <Region>\n";
      print KML "          <LatLonAltBox>\n";
      print KML "              <north>$north</north>\n";
      print KML "              <south>$south</south>\n";
      print KML "              <east>$east</east>\n";
      print KML "              <west>$west</west>\n";
      print KML "          </LatLonAltBox>\n";   
      print KML "         <Lod><minLodPixels>128</minLodPixels><maxLodPixels>-1</maxLodPixels></Lod>\n";
      print KML "     </Region>\n";
   print KML "       <GroundOverlay>\n";
   print KML "          <Icon>$pngName</Icon>\n";

   print KML "          <LatLonBox>\n";
   print KML "              <north>$north</north>\n";
   print KML "              <south>$south</south>\n";
   print KML "              <east>$east</east>\n";
   print KML "              <west>$west</west>\n";
   print KML "          </LatLonBox>\n";
   print KML "       </GroundOverlay>\n";

  print KML "     <ScreenOverlay>\n";
   print KML "       <name>timeseries</name>\n";
   print KML "        <Icon>\n";
   print KML "           <href>$tsPngName</href>\n";
   print KML "        </Icon>\n";
   print KML "        <overlayXY x=\"1\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
   print KML "        <screenXY x=\"0.99\" y=\".02\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
   print KML "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
   print KML "        <size x=\"0.4\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
   print KML "     </ScreenOverlay>\n";



   print KML "    </Document>\n";
   print KML "</kml>\n";
   
   close(KML);
}



sub makeKml4Overlay{
   my ($kmlName,$pngName,$north,$east,$south,$west,$altitude)=@_;
   

   open KML, ">$kmlName" or die "ERROR: MakePNG.pm:: cant open $kmlName\n";
   print KML "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n";
   print KML "    <Document>\n";
      print KML "    <Region>\n";
      print KML "          <LatLonAltBox>\n";
      print KML "              <north>$north</north>\n";
      print KML "              <south>$south</south>\n";
      print KML "              <east>$east</east>\n";
      print KML "              <west>$west</west>\n";
      print KML "          </LatLonAltBox>\n";   
      print KML "         <Lod><minLodPixels>128</minLodPixels><maxLodPixels>-1</maxLodPixels></Lod>\n";
      print KML "     </Region>\n";
   print KML "       <GroundOverlay>\n";
   print KML "          <Icon>$pngName</Icon>\n";
   if (defined $altitude){
     print KML "          <altitude>$altitude</altitude>\n";
     print KML "          <altitudeMode>absolute</altitudeMode>\n";
   }
   print KML "          <LatLonBox>\n";
   print KML "              <north>$north</north>\n";
   print KML "              <south>$south</south>\n";
   print KML "              <east>$east</east>\n";
   print KML "              <west>$west</west>\n";
   print KML "          </LatLonBox>\n";
   print KML "       </GroundOverlay>\n";

  
   print KML "    </Document>\n";
   print KML "</kml>\n";
   
   close(KML);
}







########################################################################
# sub setColors
# 
# a more general way to set the color palette for the pngs
#
#   this must be done for each image generated
#   acts on a GD object, not the quadtree object
#
#   e.g.
#   @colors=&setColors($im,@{$obj->{COLORMAP}},$alpha);  
#     $im - a gd image object
#     @{$obj->{COLORMAP}}  - scale, red, green, blue
#         references to arrays of values between 0-1 representing the
#         the colormap
#     $alpha -  transparency 0-127 opaque-transparent
#
#   my $transparent=$colors[0];  - may be useful for later when
#                                  setting transparent pixels	
#  
#   ...uses 128 colors.
#
########################################################################
sub setColors {

   my $im=shift; # the gd image

   my $ref=shift;   # ref to an array of scale values between 0 and 1
   my @scale=@$ref;

   $ref=shift;      # ref to an array of red values (0 to 1)
   my @red=@$ref;

   $ref=shift;   # ref to an array of green values (0 to 1)
   my @green=@$ref;

   $ref=shift;   # ref to an array of blue values (0 to 1)
   my @blue=@$ref;

   my $alpha=shift;  # 0 - 127 ; opaque - transparent
       $alpha=0 unless defined($alpha); 

   $scale[0]=0;
   $scale[$#scale]=1;

   my @X2;
   foreach my $i (1..128) {
       push @X2, $i/128;
   }

   my $r2=interp1(\@scale,\@red,\@X2);
   my @R2= @{$r2};

   my $g2=interp1(\@scale,\@green,\@X2);
   my @G2= @{$g2};
   
   my $b2=interp1(\@scale,\@blue,\@X2);
   my @B2= @{$b2};

 

   my @colors;
   $colors[0] = $im->colorAllocateAlpha(1,2,3,$alpha);  # reserve 0 for transparent

   foreach my $i (0..127) {
      my $ri=int(255 * $R2[$i]);   
      my $gi=int(255 * $G2[$i]);   
      my $bi=int(255 * $B2[$i]);   

      $colors[$i+1]=$im->colorAllocateAlpha($ri,$gi,$bi,$alpha);
   }

   $colors[129]=$im->colorAllocateAlpha(255,255,255,0); # reserved for white
   $colors[130]=$im->colorAllocateAlpha(0,0,0,0); # reserved for black

   $im->transparent($colors[0]);  
      
   return @colors;

}



########################################################################
# sub setColors_fade
# 
# a more general way to set the color palette for the pngs
#
#   this must be done for each image generated
#   acts on a GD object, not the quadtree object
#
#   e.g.
#   @colors=&setColors($im,@{$obj->{COLORMAP}},$alpha);  
#     $im - a gd image object
#     @{$obj->{COLORMAP}}  - scale, red, green, blue
#         references to arrays of values between 0-1 representing the
#         the colormap
#     $alpha -  transparency 0-127 opaque-transparent
#
#   my $transparent=$colors[0];  - may be useful for later when
#                                  setting transparent pixels	
#  
#   ...uses 128 colors.
#
########################################################################
sub setColors_fade {

   my $im=shift; # the gd image

   my $ref=shift;   # ref to an array of scale values between 0 and 1
   my @scale=@$ref;

   $ref=shift;      # ref to an array of red values (0 to 1)
   my @red=@$ref;

   $ref=shift;   # ref to an array of green values (0 to 1)
   my @green=@$ref;

   $ref=shift;   # ref to an array of blue values (0 to 1)
   my @blue=@$ref;

   my $alpha=shift;  # 0 - 127 ; opaque - transparent
       $alpha=0 unless defined($alpha); 

   $scale[0]=0;
   $scale[$#scale]=1;

   my @X2;
   foreach my $i (1..128) {
       push @X2, $i/128;
   }

   my $r2=interp1(\@scale,\@red,\@X2);
   my @R2= @{$r2};

   my $g2=interp1(\@scale,\@green,\@X2);
   my @G2= @{$g2};
   
   my $b2=interp1(\@scale,\@blue,\@X2);
   my @B2= @{$b2};

 

   my @colors;
   $colors[0] = $im->colorAllocateAlpha(1,2,3,$alpha);  # reserve 0 for transparent

   foreach my $i (0..127) {
      my $ri=int(255 * $R2[$i]);   
      my $gi=int(255 * $G2[$i]);   
      my $bi=int(255 * $B2[$i]);   

      $colors[$i+1]=$im->colorAllocateAlpha($ri,$gi,$bi,2*$i-1);
   }

   $colors[129]=$im->colorAllocateAlpha(255,255,255,0); # reserved for white
   $colors[130]=$im->colorAllocateAlpha(0,0,0,0); # reserved for black

   $im->transparent($colors[0]);  
      
   return @colors;

}




# sub to load colormap
sub loadColormap {

   #my $obj=shift;
   my $cmapFile=shift;

   #$/="\n";
   open CM, "$cmapFile" or die "cant oppen $cmapFile\n";

   my @s;
   my @r;
   my @g;
   my @b;

   while (my $line = <CM> ){

     chomp $line;

     $line =~ s/^\s+//;

     my ($ss,$rr,$gg,$bb)=split(/\s+/,$line);
     push @s, $ss;
     push @r, $rr;
     push @g, $gg;
     push @b, $bb;
   }
   close(CM);
   my $colormap= [ \@s,\@r,\@g,\@b];

#   $obj->{COLORMAP}=$colormap;
   return $colormap;
}


#################################################
#  sub interp1
#
#  e.g. 
# 
#   $Y2_ref = interp1 (\@X1,\@Y1,\@X2);
#  
#   @Y2=@{$Y2_ref};
#
#  like matlab's interp1...
#
################################################
sub interp1 {
    my ($x1r,$y1r,$x2r)=@_;
    my @X1=@$x1r;
    my @Y1=@$y1r;
    my @X2=@$x2r;

    my @Y2;


    # loop through the new x locations
    foreach my $x (@X2) {
       
      # if its out of bounds return a NaN
      if ($x<$X1[0]  or $x>$X1[$#X1] ) {
          push (@Y2, 'NaN'); 
          next;
      }
      
      foreach my $i (0..$#X1-1){
          
          if ($x == $X1[$i]) {       # its right on the first point in the segment
             push (@Y2,$Y1[$i]);
             last;
          }
         
          next if ($x > $X1[$i+1]);  # its past this segment

          my $slope = ($Y1[$i+1] -  $Y1[$i]) / ($X1[$i+1] -  $X1[$i]);  # its on the segment, interpolate
          my $dx=$x-$X1[$i];
          my $y=$Y1[$i] + $dx * $slope;
          push (@Y2, $y);
          last;  # go to the next point. 
      }
   }
   
   return (\@Y2); 
       
}




#################################################################
# sub makeColorbar($title,$numColors,$cmap,$cll,$cul)
#
# this subroutine makes a png with the colorbar
#
#################################################################
sub makeColorbar {
   my ($pngName,$title,$numColors,$cmap,$cll,$cul,$tickLabelFormatString) = @_;
     
   my $xpix=550;
   my $ypix=100;
   my $xMarg=15;
   my $yMarg=30;
   my $xWidth= ($xpix - 2*$xMarg);
   $tickLabelFormatString='%.1f' unless ( defined ($tickLabelFormatString)); 

   my $im = new GD::Image($xpix,$ypix);
   my @colors = &setColors($im,@{$cmap},0);

   my $black= $colors[130];
   my $white= $colors[129];

   my $i;
   my $j;
   my $cnt = 0;
   my $dClim=$cul-$cll;
   my $dzdc=$dClim/128;
   my $C;
  
   ### BPJ Make white background for colorbar area
   foreach $j ( 0 .. $ypix+$yMarg ) {
       foreach $i ( 0 .. $xpix+$xMarg ) {
	$im->setPixel($i,$j,$white);
       }
   }

### BPJ Make black 2 pixel border around white background
   foreach $j ( 0 .. $ypix+$yMarg ) {
       $im->setPixel(0,$j,$black);
       $im->setPixel(1,$j,$black);
       $im->setPixel($xpix-2,$j,$black);
       $im->setPixel($xpix-1,$j,$black);
   }
   foreach $i ( 0 .. $xpix+$xMarg ) {
       $im->setPixel($i,0,$black);
       $im->setPixel($i,1,$black);
       $im->setPixel($i,$ypix-2,$black);
       $im->setPixel($i,$ypix-1,$black);
   }
   # draw the colored part of the colorbar
   foreach $j ( $yMarg .. $ypix-$yMarg ) {

       foreach $i ( $xMarg .. $xpix-$xMarg ) {
          my $C1= 128 * ($i-$xMarg)  / $xWidth +1;
         my $C= int((int($numColors*($C1-1)/128)+0.5 )*128/$numColors)  unless ($C1==0);
          $C=128 if ($C > 128); 
          $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map
       }      
   }
   
   # add the title
   $im->string(gdGiantFont,40,5,$title,$black);
   # ticks on the bottom x-axis (speed)
      my $dx=$xWidth/$numColors;
      $dx=$xWidth/24 if $numColors > 24;  # just to keep ticks from crowding eachother
      my $x=$xMarg;
      my $x2=$xMarg+$xWidth;
      my $ytmp=$ypix-$yMarg;
      while ($x<=$x2){
        my $intx=int($x);
        foreach my $y ($ytmp-5 .. $ytmp+5) {              # tick marks
              $im->setPixel($intx,$y,$black);
              $im->setPixel($intx+1,$y,$black);
        } 
        my $dtmp = $cll + ($x - $xMarg)*$dClim/$xWidth;
        my $tickLabel=sprintf($tickLabelFormatString,$dtmp);
        $im->string(gdTinyFont,$x-11,$ytmp+6,$tickLabel,$black);
        $x=$x+$dx;
      } 
  # now write the png file
 # my $pngFile= "colorbar.png";
  open FILE2, ">$pngName";
  binmode FILE2;
  print FILE2 $im->png;
  close(FILE2);
  $im=undef;
}




sub TimeSeriesPlot{ # ($xref,$yref
   #--------------------------------------------------------------------------
   # config for time series plot
   # these variables can be used to adjust the the size and shape of the plot 
   # generally they should not have to be modified, but anyway...
   # note y-values are from the top down
   my $xpixels = 600;            # number of pixels in the x direction
   my $ypixels = 337;            # number of pixels in the y direction
   my $xmarg1 = 0.15;             # fractional x value in pixels where left side of plot box is drawn
   my $xmarg2 = 0.9;             # fractional x value in pixels where right side of plot box is drawn
   my $ymarg1 = 0.2;             # fractional y value in pixels where top plot box is drawn
   my $ymarg2 = 0.8;             # fractional y value in pixels where bottom of plot box is drawn
   my $titleYlocation = 0.5;     # fractional distance between top of plot box and top of image where the title will be written
   my $titleXlocation = 0.5;     # fractional distance between left and right sides of plot box where title will be written
   my $ytickXlocation = 0.75;    # fractional distance between left side of image and left side of plot box where y ticks will be written
   my $ytickFormat='%5.1f';
   my $ylabelXlocation = 0.45;    # fractional distance between left side of image and left side of plot box where y label will be written
   my $ylabelYlocation = 0.5;     # fractional distance between bottom and top plot box where y label will be written
   my $xtickYlocation  = 0.75;    # fractional distance between the x-axes and the top and bottom of the image where x ticks will be written
   my $xlabelXlocation = 0.5;     # fractional distance between left and right sides of plot box where xlabel will be written
   my $xlabelYlocation  = 0.25;   # fractional distance between the bottom of the image and the bottom of the plot box where x labels will be written
   my $markerSize = 8;
   my $halfMarker = 3;#$markerSize/2;

   my $nYlines=6;   # number of grid lines in Y  including axis line
   my $nXlines=8;   # number of grid lines in X including axis line
  
   #my @Y_RANGE=(-1,1);  # defining this fixes the Y-range on the plot
   #my @X_RANGE=(15,22.5);  # defining fixes Time range on plot in days since coldstart

   my $maxXvalue=-999999999;
   my $minXvalue=999999999;
   my $maxYvalue=-999999999;
   my $minYvalue=999999999;

   my $dotWidth=15;

   #my $xlabel="Date";
   #my $ylabel=$cbarTitle;
   #end CONFIG
   #-------------------------------------------------------------------------------------------------------------------------------------   

   # deal with input args
   my ($xref,$yref,$startYMDHMS,$ylabel,$xrng,$yrng,$title,$pngName,$rec)=@_;

   my @Y=@{$yref};
   my @X=@{$xref};    # should be time in decimal dayss after startYMDHMS
   my ($minX, $maxX)=@{$xrng};
   my ($minY, $maxY)=@{$yrng};
   $startYMDHMS =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/; 
   my $csyyyy=$1;
   my $csmm=$2;
   my $csdd=$3;
   my $csHH=$4;
   my $csMM=$5;
   my $csSS=$6;
   my $xlabel= "Date in $csyyyy";

    # create the image object
   my $im = new GD::Image($xpixels,$ypixels); 

   # Allocate colors
   my $white = $im->colorAllocate(255,255,255);
   my $black = $im->colorAllocate(0,0,0);
   my $gray = $im->colorAllocate(125,125,125);
   my $red = $im->colorAllocate(255,0,0);
   my $blue = $im->colorAllocate(0,0,255);
   my $green = $im->colorAllocate(0, 255, 0);
   my $brown = $im->colorAllocate(255, 0x99, 0);
   my $violet = $im->colorAllocate(255, 0, 255);
   my $yellow = $im->colorAllocate(255, 255, 0);
   
      
   # bounds for the figure
   my $x1=$xmarg1 * $xpixels;
   my $x2=$xmarg2 * $xpixels;
   my $y1=$ymarg1 * $ypixels;
   my $y2=$ymarg2 * $ypixels;
   my $width=$x2-$x1; # in pixels
   my $height=$y2-$y1; 
      
   $im->setThickness(1);
   # draw horizontal grid lines 
   $im->setStyle($gray,$gray,$gray,$gray,gdTransparent,gdTransparent,gdTransparent,gdTransparent); #gray dashed line
   my $dy=$height/($nYlines-1) ;
   my $y=$y1;
   while ($y<$y2){
       $im->line(int($x1),int($y),int($x2),int($y),gdStyled);
       $y=$y+$dy;
   }
      
   # draw vertical grid lines
   my $dx=$width/($nXlines-1) ;
   my $x=$x1+$dx;
   while ($x<=$x2){
      $im->line(int($x),int($y1),int($x),int($y2),gdStyled);
      $x=$x+$dx;
   }
   
   $im->setThickness(2);
   # draw the x axis 
   $im->line(int($x1),int($y),int($x2),int($y),$black);
      
   # draw the y axis
   $im->line(int($x1),int($y1),int($x1),int($y2),$black);
      
      
   # put title on the plot
   $x=$x1 + $titleXlocation*$width;  
   $y=$y1 - $titleYlocation*$ypixels*$ymarg1; 
   $im=&alignString ($im,$x,$y,$title,'gdLargeFont',$black);

      
   # label the x-axis
   $x=$x1 + $xlabelXlocation*$width;
   $y=$ypixels - $xlabelYlocation*(1-$ymarg2)*$ypixels;
   $im=&alignString ($im,$x,$y,$xlabel,'gdLargeFont',$black);
   
   # label the y-axis
   $x=$ylabelXlocation*$xmarg1*$xpixels;
   $y=$y2-$height*$ylabelYlocation;
   $im=&alignStringUp ($im,$x,$y,$ylabel,'gdLargeFont',$black);
   
   # ticks on the y-axis
   my $dYdPixels=($maxY-$minY)/$height;
   $y=$y2;
   $x=$ytickXlocation*$xmarg1*$xpixels;
   while ($y>=$y1){   # going from bottom to top
      my $dtmp=($y2-$y)*$dYdPixels + $minY;
      my $tickLabel=sprintf($ytickFormat,$dtmp);
      $im=&alignString ($im,$x,$y,$tickLabel,'gdLargeFont',$black);
      $y=$y-$dy;
   }
   
   # ticks on the bottom x-axis (date)
   
   my $dXdPixels=($maxX-$minX)/$width;
   $x=$x1;
   $y=$ypixels - $xtickYlocation*(1-$ymarg2)*$ypixels;
   while ($x<=$x2){
      my $dtmp=($x-$x1)*$dXdPixels + $minX;

      my ($yyyy,$mm,$dd,$HH,$MM,$SS)=&addDecimalDaysToDate($csyyyy,$csmm,$csdd,$csHH,$csMM,$csSS,$dtmp);

      my $tickLabel1=sprintf("%02d/%02d",$mm,$dd);
      my $tickLabel2=sprintf("%02d:%02d",$HH,$MM);
      $im=&alignString ($im,$x,$y,$tickLabel1,'gdLargeFont',$black);
      my $font_height=gdLargeFont->height;
      $im=&alignString ($im,$x,$y+$font_height,$tickLabel2,'gdLargeFont',$black);
      $x=$x+$dx; 
   }   
 
   #plot the model data polyline
   my $poly=new GD::Polygon;
   my $cnt=0;
   foreach my $yy (@Y) {
      unless ($yy<-99998) {
         $y=$y2-($yy-$minY)/$dYdPixels;
         $x=$x1+($X[$cnt]-$minX)/$dXdPixels;
         $poly->addPt($x,$y) if ($x > $x1) and ($x < $x2);   # add the point to the polyline if its in the plot box
        # $im->rectangle($x-$halfMarker,$y-$halfMarker,$x+$halfMarker,$y+$halfMarker,$blue);  #draw the square marker
      }
      $cnt++; 
   }
   $im->setThickness(3);
   $im->unclosedPolygon($poly,$blue);

   # make the dot
   $x=$x1+($X[$rec]-$minX)/$dXdPixels;
   $y=$y2-($Y[$rec]-$minY)/$dYdPixels;
   $im->filledEllipse($x,$y,$dotWidth,$dotWidth,$red);

   
   # make sure we are writing to a binary stream
   binmode STDOUT;
       
   open FILE2, ">$pngName";
   binmode FILE2;
      
   # Convert the image to PNG and print it on standard output
   print FILE2 $im->png;
   close(FILE2);


   


}# end sub plotTimeSeries



sub addDecimalDaysToDate {
   my ($csyyyy,,$csmm,$csdd,$csHH,$csMM,$csSS,$decimalDays)=@_;
   my $dtmp=$decimalDays;
   my $Dd=int($dtmp);
   my $rm=$dtmp-$Dd;
   my $Dh=int(24*$rm);
   $rm=24*$rm-$Dh;
   my $Dm=int(60*$rm);
   $rm=60*$rm-$Dm;
   my $Ds=int(60*$rm);
   my ($yyyy,$mm,$dd,$HH,$MM,$SS)=Date::Pcalc::Add_Delta_YMDHMS($csyyyy,$csmm,$csdd,$csHH,$csMM,$csSS,
                                                                            0,    0,  $Dd,  $Dh,  $Dm,  $Ds);
   return ($yyyy,$mm,$dd,$HH,$MM,$SS);
}




sub alignString{
   my ($im,$x,$y,$string,$font,$color)=@_;
   my ($font_width,$font_height);
   my $str='($font_width,$font_height)=('."$font".'->width,'."$font".'->height);';
   eval $str;
   #my ($font_width,$font_height)=($font->width,$font->height); # center text
   my $len=length($string);
   $x=$x-0.5*$font_width*$len;
   $y=$y-0.5*$font_height;
   $str= '$im->string('."$font".',int($x),int($y),$string,$color);';
   eval $str;
   return ($im);
}

sub alignStringUp{
   my ($im,$x,$y,$string,$font,$color)=@_;
   my ($font_width,$font_height);
   my $str='($font_width,$font_height)=('."$font".'->width,'."$font".'->height);';
   eval $str;
   #my ($font_width,$font_height)=($font->width,$font->height); # center text
   my $len=length($string);
   $y=$y+0.5*$font_width*$len;
   $x=$x-0.5*$font_height;
   $str= '$im->stringUp('."$font".',int($x),int($y),$string,$color);';
   eval $str;
   return ($im);
}
