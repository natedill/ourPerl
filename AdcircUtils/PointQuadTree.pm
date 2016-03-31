package PointQuadTree;

# contains subroutines for building a quadtree out of an adcirc grid
# and for writing the grid out as a kml superoverlay 

use strict;
use warnings;
use GD;



#####################################################################
# sub new()
#
# this is the constructor.  It will create the treeFort14 object 
#
# input is a hash e.g.
#
# $tree = pointQuadTree->new(

#                        );
#
#####################################################################
sub new
{
      my $self = shift;
      
      my $class = ref($self) || $self;
      
      my $obj = bless {} => $class;
      
      my %args = @_;
      
      my $north=$args{-NORTH};
      my $south=$args{-SOUTH};
      my $east=$args{-EAST};
      my $west=$args{-WEST};
      $obj->{MAXPOINTS}=$args{-MAXPOINTS};
      $obj->{LONS}  = [];
      $obj->{LATS}  = [];
      $obj->{ELEVS} = [];
      $obj->{DESC} = [];

      # set data for top level (index = 0)
      $obj->{REGION}   [0] = [$north, $south, $east, $west];
      $obj->{PARENT}   [0] =undef;
      $obj->{CHILDREN} [0] = [];
      $obj->{NPOINTS}  [0] = 0;
      $obj->{POINTNUMS} [0] = [];
      $obj->{ISFULL}   [0] = 0;
print "starting tree, region $north $south $east $west\n";

      return $obj;
      
}

#########################################################
# sub addPoint ()
#
# public method for adding points to the tree
#
# input is a hash e.g.
#
# $tree->addPoint (
#                   -PNUM=>$pnum,    # a consecutive number for the point 
#                   -XP=>$xp,    # longitude of the point
#                   -YP=>$yp,   # latitude of the point
#                   -ZP=>$yp,   # elevation of the point
#                   -DESC=>$desc);
#
###############################################################

sub addPoint {
	my $obj=shift;
	my %args=@_;

	my $pointNum=$args{-PNUM};
	my $xp=$args{-XP};
        my $yp=$args{-YP};
        my $zp=$args{-ZP};
	my $descp=" ";
	 $descp=$args{-DESC} if (defined($args{-DESC}));

#	print "adding point $pointNum $xp $yp $zp\n";
	push ( @{$obj->{LONS}} , $xp );
	push ( @{$obj->{LATS}} , $yp );
	push ( @{$obj->{ELEVS}} , $zp );
	push ( @{$obj->{DESC}}, $descp);

	# recurseively check down the tree til you find a node that is not full
	my $recurseDepth=1;
	my $index=0;

        $obj->_addPointToLevel ($pointNum,$recurseDepth,$index);
}


#####################################################
# sub _addPointToLevel()
#
# this private method recursed down the tree and adds
# points to a node if it isn't full yet.
#
#
#####################################################

sub _addPointToLevel{
        my $obj = shift;
        my ($pointNum,$recurseDepth,$index) = @_;
	my $xp=$obj->{LONS}[$pointNum];
	my $yp=$obj->{LATS}[$pointNum];
	
#print " adding point $pointNum to index $index, depth = $recurseDepth\n";
#print   "    xp,yp; $xp $yp\n";
	# check to see if this point is in this tree node
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
	
#print "     looking in, region $north $south $east $west\n";
	if ($yp <= $north) {
         if ($yp >= $south) {
          if ($xp >= $west)  {
	   if ($xp <= $east)  {
		   $inRegion=1;
#		 print "in Region\n";
		   
           }
	  }
	 }
	}	
           
	return unless ($inRegion);

       # if the tree node is not full add the point here
       unless ($obj->{ISFULL}[$index]==1) {

	  push ( @{$obj->{POINTNUMS}[$index]}, $pointNum);
	  $obj->{NPOINTS}[$index]++;

          # if it just filled up mark it full, divide it up, re-distribute the points
          if  ($obj->{NPOINTS}[$index] > $obj->{MAXPOINTS}){
#      print "index $index just filled up;  dividing up\n";  
            $obj->{ISFULL}[$index]=1;

            $obj->_divideRegion($recurseDepth,$index); 
            
	    $recurseDepth++;
	    foreach my $point ( @{$obj->{POINTNUMS}[$index]} ){
		foreach my $child ( @{$obj->{CHILDREN}[$index]} ){
                   $obj->_addPointToLevel($point,$recurseDepth,$child);
	        }
	    }	

          }  
       } else {   # this node is full, check the children
	 $recurseDepth++;      

#	 print " index $index is already full,  depth : $recurseDepth\n"; 
         foreach my $child ( @{$obj->{CHILDREN}[$index]} ){
              $obj->_addPointToLevel($pointNum,$recurseDepth,$child);
	    }

        }
       




}


#####################################################
# sub _divideRegion()
#
# this private method divides a node into 4 children
#
#
#####################################################
sub _divideRegion {
	my $obj = shift;
	my ($recurseDepth,$index) = @_;
        my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

        print "dividing region - index: $index, depth: $recurseDepth\n";
#	print "region: $north $south $east $west\n";

	$recurseDepth++;
	
	my $ew =  ($east + $west)/2.0;
	my $ns =  ($north + $south)/2.0;

        # northwest
	my $indx=4*$index+1;
	 $obj->{REGION}   [$indx] = [$north, $ns, $ew, $west];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
         $obj->{POINTNUMS} [$indx] = [];
         $obj->{ISFULL}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$index]}, $indx);
	
        # northeast
         $indx=4*$index+2;
	 $obj->{REGION}   [$indx] = [$north, $ns, $east, $ew];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
         $obj->{POINTNUMS} [$indx] = [];
         $obj->{ISFULL}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$index]}, $indx);

        # southeast
	 $indx=4*$index+3;
	 $obj->{REGION}   [$indx] = [$ns, $south, $east, $ew];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
         $obj->{POINTNUMS} [$indx] = [];
         $obj->{ISFULL}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$index]}, $indx);

        # southwest
	 $indx=4*$index+4;
	 $obj->{REGION}   [$indx] = [$ns, $south, $ew, $west];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
         $obj->{POINTNUMS} [$indx] = [];
         $obj->{ISFULL}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$index]}, $indx);
}



#######################################################
# sub writeKML() -  public method
#
# writes the kml files for the superoverlay
#######################################################
sub writeKML{
	my $obj = shift;
        my %args=@_;
         my $descString=$args{DESCSTRING};
        $obj->{CLIM}=$args{CLIM};
	#my ($descString)=@_;
	mkdir("Files");
	$obj->_writeKML(0,1,$descString);    # index, depth - for top layer
 
        #$obj->_makeColorbar('title');

}


#######################################################
# sub _writeKML() -  private method actually does the work
#
#######################################################

sub _writeKML{
	my ($obj, $index, $depth, $descString) = @_;
        my $kmlFile;
	my @kids = @{$obj->{CHILDREN}[$index]};
	 
        my $minLOD=128;
	my $maxLOD=512;
#        if ($depth==1) {$minLOD=0;}
        unless (@kids) {$maxLOD=-1;}

        my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

        
        if ($index ==0 ) {
	        $kmlFile = "doc.kml";
        }else{  
		$kmlFile = "Files/$index.kml";}
         


	# file beginning
	open FILE, ">$kmlFile" or die "can not open $kmlFile";
        print FILE '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print FILE '<kml xmlns="http://www.opengis.net/kml/2.2">'."\n";
	print FILE "   <Document>\n";
        
        # for the top level file write the style tags
	if ($index ==0 ) {
          my $color=1;
          while ($color<=255) {	 
             my $style="Style$color"; 
	     my $pngFile="$color.png";
	     print FILE "    <Style id=\"$style\">\n";
             print FILE "      <IconStyle>\n";
             print FILE "         <Icon><href>Files/$pngFile</href></Icon>\n";
             print FILE "         <scale>0.3</scale>\n";
             print FILE "      </IconStyle>\n";
             print FILE "      <BalloonStyle>\n";
             print FILE '         <text>$[description]</text>\n';
             print FILE "      </BalloonStyle>\n";
             print FILE "    </Style>\n";
           $color++;
	  }
          # write kml for colorbar screen overlay
          print FILE "   <Folder>\n";
          print FILE "     <Region>\n";
          print FILE "       <LatLonAltBox>\n";
          print FILE "          <north>$north</north>\n";
          print FILE "          <south>$south</south>\n";
          print FILE "          <east>$east</east>\n";
          print FILE "          <west>$west</west>\n";
          print FILE "       </LatLonAltBox>\n";
          print FILE "       <Lod>\n";
          print FILE "           <minLodPixels>128</minLodPixels><maxLodPixels>-1</maxLodPixels>\n";
          print FILE "           <minFadeExtent>0</minFadeExtent> <maxFadeExtent>0</maxFadeExtent>\n";
          print FILE "       </Lod>\n";
          print FILE "     </Region>\n";
          print FILE "     <ScreenOverlay>\n";
          print FILE "       <name>colograr</name>\n";
          print FILE "        <Icon>\n";
          print FILE "           <href>Files/colorbar.png</href>\n";
          print FILE "        </Icon>\n";
          print FILE "        <overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
          print FILE "        <screenXY x=\"0.01\" y=\".99\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
          print FILE "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
          print FILE "        <size x=\".5333333\" y=\"0.1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
          print FILE "     </ScreenOverlay>\n";
          print FILE "   </Folder>\n";

        } 	


        # region for this node
	print FILE "      <Region>\n";
	print FILE "         <LatLonAltBox>\n";
        print FILE "	       <north>$north</north>\n";
        print FILE "	       <south>$south</south>\n";
        print FILE "	       <east>$east</east>\n";
        print FILE "	       <west>$west</west>\n";
	print FILE "         </LatLonAltBox>\n";
        print FILE "	     <Lod>\n";
        print FILE "	       <minLodPixels>$minLOD</minLodPixels><maxLodPixels>$maxLOD</maxLodPixels>\n";
        print FILE "            <minFadeExtent>0</minFadeExtent> <maxFadeExtent>0</maxFadeExtent>\n";
        print FILE "	     </Lod>\n";
        print FILE "	  </Region>\n";

	# ground overlay for this node
	#print FILE "	  <GroundOverlay>\n";
	#print FILE "	    <drawOrder>$depth</drawOrder>\n";
	#print FILE "	    <Icon>\n";
	#print FILE "	      <href>$index.png</href>\n";
	#print FILE "	    </Icon>\n";
	#print FILE "	    <LatLonBox>\n";
	#print FILE "	       <north>$north</north>\n";
	#print FILE "	       <south>$south</south>\n";
	#print FILE "	       <east>$east</east>\n";
	#print FILE "	       <west>$west</west>\n";
	#print FILE "	    </LatLonBox>\n";
	#print FILE "	  </GroundOverlay>\n";
     
	# add the placemarks for this node if it is a leaf node
	unless  ($obj->{ISFULL}[$index]) {
		foreach my $point ( @{$obj->{POINTNUMS}[$index]} ){
                    my $x=$obj->{LONS}[$point];
                    my $y=$obj->{LATS}[$point];
                    my $z=$obj->{ELEVS}[$point] ;# * 3.28 ;  # convert meters to feet
		    my $descp='';
		     $descp=$obj->{DESC}[$point];
		    
		    my ($cll, $cul) = @{$obj->{CLIM}};  # hard coded limits for colors
		    

		    my $style =int( $cll+ 255* ($z-$cll)/($cul-$cll));
		    $style = 255 if ($style > 255);
		    $style = 1   if ($style <1) ; 

                    print FILE "     <Placemark>\n";
		    print FILE "        <name></name>\n";
		    print FILE "        <styleUrl>../doc.kml#Style$style</styleUrl>\n";
                    print FILE "        <description>\n";
		    print FILE "         <p><b>$descString</b></p>\n";
		    my $elevstring=sprintf ("%7.3f",$z);
		    print FILE "         <p><b>Z value: </b><br/>$elevstring</p>\n";
		    print FILE " $descp\n";
		    print FILE "        </description>\n";
                    print FILE "        <Point>\n ";
		    print FILE "          <coordinates>$x,$y,$z</coordinates>\n";
		    print FILE "        </Point>\n";
		    print FILE "     </Placemark>\n";

		}
	}

	# network links to children
	if (@kids) {
	foreach my $kid (@kids) {
           my $lnkName="$kid.kml";
           ($north, $south, $east, $west) = @{$obj->{REGION}[$kid]};
          
	   print FILE "	  <NetworkLink>\n";
           print FILE "	    <name>$kid</name>\n";
           print FILE "	    <Region>\n";
           print FILE "	      <Lod>\n";
           print FILE "            <minLodPixels>$minLOD</minLodPixels><maxLodPixels>$maxLOD</maxLodPixels>\n";
           print FILE "            <minFadeExtent>0</minFadeExtent> <maxFadeExtent>0</maxFadeExtent>\n";
	   print FILE "	      </Lod> \n";
           print FILE "	      <LatLonAltBox>\n";
           print FILE "	        <north>$north</north>\n";
           print FILE "	        <south>$south</south>\n";
           print FILE "	        <east>$east</east>\n";
           print FILE "	        <west>$west</west>\n";
           print FILE "	      </LatLonAltBox>\n";
           print FILE "	    </Region>\n";
           print FILE "	    <Link>\n";
	   if ($index==0) {
             print FILE "	      <href>Files/$lnkName</href>\n";
           }else{
             print FILE "	      <href>$lnkName</href>\n";
           }
	   print FILE "	      <viewRefreshMode>onRegion</viewRefreshMode>\n";
           print FILE "	     </Link>\n";
           print FILE "	  </NetworkLink>\n";
        }
        }  # if @kids

	print FILE " </Document>\n";
        print FILE "</kml>\n";
        
        close (FILE);
        
	return unless (@kids);
	foreach my $kid (@kids) {
		$obj->_writeKML($kid, $depth+1,$descString);
	}

           


}



####################################################
# sub makeColorDots()
#
# this subroutine makes a bunch of png files with color dots
#
################################################ 

sub makeColorDots {

  my $xpix=64;
  my $ypix=64;
  my $imid=$xpix/2;
  my $jmid=$ypix/2;

  my $color=255;

  while ($color>0) {

     my $im = new GD::Image($xpix,$ypix);
        &setColors($im);	 
      
	
        my $i;
        my $j =  0;
        my $cnt = 0;	
	while ($j<$ypix) {
	      $i=0;	
              while ($i<$xpix) {
                    my $r = sqrt(($i-$imid)**2 + ($j-$jmid)**2);
		     
		    if ($r<$imid) {
                       $im->setPixel($i,$j,$color);   #set the pixel color based on the map
	            }else{
                       $im->setPixel($i,$j,0);   #set the pixel color based on the map
	            }
		  $i++;
	      }
	      $j++;
        }

        # now write the png file
	my $pngFile= "Files/$color.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
        $im=undef;

	$color--;
  }

}



#####################################################
# sub setColors() 
#
# used by _makePNG to allocate the color map for png files
####################################################
sub setColors {
      my($im) = shift;
      my @color;
      my $alpha=0;
      $color[0] = $im->colorAllocateAlpha(0,0,131,127);
      $color[1] = $im->colorAllocateAlpha(0,0,135,$alpha);
      $color[2] = $im->colorAllocateAlpha(0,0,139,$alpha);
      $color[3] = $im->colorAllocateAlpha(0,0,143,$alpha);
      $color[4] = $im->colorAllocateAlpha(0,0,147,$alpha);
      $color[5] = $im->colorAllocateAlpha(0,0,151,$alpha);
      $color[6] = $im->colorAllocateAlpha(0,0,155,$alpha);
      $color[7] = $im->colorAllocateAlpha(0,0,159,$alpha);
      $color[8] = $im->colorAllocateAlpha(0,0,163,$alpha);
      $color[9] = $im->colorAllocateAlpha(0,0,167,$alpha);
      $color[10] = $im->colorAllocateAlpha(0,0,171,$alpha);
      $color[11] = $im->colorAllocateAlpha(0,0,175,$alpha);
      $color[12] = $im->colorAllocateAlpha(0,0,179,$alpha);
      $color[13] = $im->colorAllocateAlpha(0,0,183,$alpha);
      $color[14] = $im->colorAllocateAlpha(0,0,187,$alpha);
      $color[15] = $im->colorAllocateAlpha(0,0,191,$alpha);
      $color[16] = $im->colorAllocateAlpha(0,0,195,$alpha);
      $color[17] = $im->colorAllocateAlpha(0,0,199,$alpha);
      $color[18] = $im->colorAllocateAlpha(0,0,203,$alpha);
      $color[19] = $im->colorAllocateAlpha(0,0,207,$alpha);
      $color[20] = $im->colorAllocateAlpha(0,0,211,$alpha);
      $color[21] = $im->colorAllocateAlpha(0,0,215,$alpha);
      $color[22] = $im->colorAllocateAlpha(0,0,219,$alpha);
      $color[23] = $im->colorAllocateAlpha(0,0,223,$alpha);
      $color[24] = $im->colorAllocateAlpha(0,0,227,$alpha);
      $color[25] = $im->colorAllocateAlpha(0,0,231,$alpha);
      $color[26] = $im->colorAllocateAlpha(0,0,235,$alpha);
      $color[27] = $im->colorAllocateAlpha(0,0,239,$alpha);
      $color[28] = $im->colorAllocateAlpha(0,0,243,$alpha);
      $color[29] = $im->colorAllocateAlpha(0,0,247,$alpha);
      $color[30] = $im->colorAllocateAlpha(0,0,251,$alpha);
      $color[31] = $im->colorAllocateAlpha(0,0,255,$alpha);
      $color[32] = $im->colorAllocateAlpha(0,4,255,$alpha);
      $color[33] = $im->colorAllocateAlpha(0,8,255,$alpha);
      $color[34] = $im->colorAllocateAlpha(0,12,255,$alpha);
      $color[35] = $im->colorAllocateAlpha(0,16,255,$alpha);
      $color[36] = $im->colorAllocateAlpha(0,20,255,$alpha);
      $color[37] = $im->colorAllocateAlpha(0,24,255,$alpha);
      $color[38] = $im->colorAllocateAlpha(0,28,255,$alpha);
      $color[39] = $im->colorAllocateAlpha(0,32,255,$alpha);
      $color[40] = $im->colorAllocateAlpha(0,36,255,$alpha);
      $color[41] = $im->colorAllocateAlpha(0,40,255,$alpha);
      $color[42] = $im->colorAllocateAlpha(0,44,255,$alpha);
      $color[43] = $im->colorAllocateAlpha(0,48,255,$alpha);
      $color[44] = $im->colorAllocateAlpha(0,52,255,$alpha);
      $color[45] = $im->colorAllocateAlpha(0,56,255,$alpha);
      $color[46] = $im->colorAllocateAlpha(0,60,255,$alpha);
      $color[47] = $im->colorAllocateAlpha(0,64,255,$alpha);
      $color[48] = $im->colorAllocateAlpha(0,68,255,$alpha);
      $color[49] = $im->colorAllocateAlpha(0,72,255,$alpha);
      $color[50] = $im->colorAllocateAlpha(0,76,255,$alpha);
      $color[51] = $im->colorAllocateAlpha(0,80,255,$alpha);
      $color[52] = $im->colorAllocateAlpha(0,84,255,$alpha);
      $color[53] = $im->colorAllocateAlpha(0,88,255,$alpha);
      $color[54] = $im->colorAllocateAlpha(0,92,255,$alpha);
      $color[55] = $im->colorAllocateAlpha(0,96,255,$alpha);
      $color[56] = $im->colorAllocateAlpha(0,100,255,$alpha);
      $color[57] = $im->colorAllocateAlpha(0,104,255,$alpha);
      $color[58] = $im->colorAllocateAlpha(0,108,255,$alpha);
      $color[59] = $im->colorAllocateAlpha(0,112,255,$alpha);
      $color[60] = $im->colorAllocateAlpha(0,116,255,$alpha);
      $color[61] = $im->colorAllocateAlpha(0,120,255,$alpha);
      $color[62] = $im->colorAllocateAlpha(0,124,255,$alpha);
      $color[63] = $im->colorAllocateAlpha(0,128,255,$alpha);
      $color[64] = $im->colorAllocateAlpha(0,131,255,$alpha);
      $color[65] = $im->colorAllocateAlpha(0,135,255,$alpha);
      $color[66] = $im->colorAllocateAlpha(0,139,255,$alpha);
      $color[67] = $im->colorAllocateAlpha(0,143,255,$alpha);
      $color[68] = $im->colorAllocateAlpha(0,147,255,$alpha);
      $color[69] = $im->colorAllocateAlpha(0,151,255,$alpha);
      $color[70] = $im->colorAllocateAlpha(0,155,255,$alpha);
      $color[71] = $im->colorAllocateAlpha(0,159,255,$alpha);
      $color[72] = $im->colorAllocateAlpha(0,163,255,$alpha);
      $color[73] = $im->colorAllocateAlpha(0,167,255,$alpha);
      $color[74] = $im->colorAllocateAlpha(0,171,255,$alpha);
      $color[75] = $im->colorAllocateAlpha(0,175,255,$alpha);
      $color[76] = $im->colorAllocateAlpha(0,179,255,$alpha);
      $color[77] = $im->colorAllocateAlpha(0,183,255,$alpha);
      $color[78] = $im->colorAllocateAlpha(0,187,255,$alpha);
      $color[79] = $im->colorAllocateAlpha(0,191,255,$alpha);
      $color[80] = $im->colorAllocateAlpha(0,195,255,$alpha);
      $color[81] = $im->colorAllocateAlpha(0,199,255,$alpha);
      $color[82] = $im->colorAllocateAlpha(0,203,255,$alpha);
      $color[83] = $im->colorAllocateAlpha(0,207,255,$alpha);
      $color[84] = $im->colorAllocateAlpha(0,211,255,$alpha);
      $color[85] = $im->colorAllocateAlpha(0,215,255,$alpha);
      $color[86] = $im->colorAllocateAlpha(0,219,255,$alpha);
      $color[87] = $im->colorAllocateAlpha(0,223,255,$alpha);
      $color[88] = $im->colorAllocateAlpha(0,227,255,$alpha);
      $color[89] = $im->colorAllocateAlpha(0,231,255,$alpha);
      $color[90] = $im->colorAllocateAlpha(0,235,255,$alpha);
      $color[91] = $im->colorAllocateAlpha(0,239,255,$alpha);
      $color[92] = $im->colorAllocateAlpha(0,243,255,$alpha);
      $color[93] = $im->colorAllocateAlpha(0,247,255,$alpha);
      $color[94] = $im->colorAllocateAlpha(0,251,255,$alpha);
      $color[95] = $im->colorAllocateAlpha(0,255,255,$alpha);
      $color[96] = $im->colorAllocateAlpha(4,255,251,$alpha);
      $color[97] = $im->colorAllocateAlpha(8,255,247,$alpha);
      $color[98] = $im->colorAllocateAlpha(12,255,243,$alpha);
      $color[99] = $im->colorAllocateAlpha(16,255,239,$alpha);
      $color[100] = $im->colorAllocateAlpha(20,255,235,$alpha);
      $color[101] = $im->colorAllocateAlpha(24,255,231,$alpha);
      $color[102] = $im->colorAllocateAlpha(28,255,227,$alpha);
      $color[103] = $im->colorAllocateAlpha(32,255,223,$alpha);
      $color[104] = $im->colorAllocateAlpha(36,255,219,$alpha);
      $color[105] = $im->colorAllocateAlpha(40,255,215,$alpha);
      $color[106] = $im->colorAllocateAlpha(44,255,211,$alpha);
      $color[107] = $im->colorAllocateAlpha(48,255,207,$alpha);
      $color[108] = $im->colorAllocateAlpha(52,255,203,$alpha);
      $color[109] = $im->colorAllocateAlpha(56,255,199,$alpha);
      $color[110] = $im->colorAllocateAlpha(60,255,195,$alpha);
      $color[111] = $im->colorAllocateAlpha(64,255,191,$alpha);
      $color[112] = $im->colorAllocateAlpha(68,255,187,$alpha);
      $color[113] = $im->colorAllocateAlpha(72,255,183,$alpha);
      $color[114] = $im->colorAllocateAlpha(76,255,179,$alpha);
      $color[115] = $im->colorAllocateAlpha(80,255,175,$alpha);
      $color[116] = $im->colorAllocateAlpha(84,255,171,$alpha);
      $color[117] = $im->colorAllocateAlpha(88,255,167,$alpha);
      $color[118] = $im->colorAllocateAlpha(92,255,163,$alpha);
      $color[119] = $im->colorAllocateAlpha(96,255,159,$alpha);
      $color[120] = $im->colorAllocateAlpha(100,255,155,$alpha);
      $color[121] = $im->colorAllocateAlpha(104,255,151,$alpha);
      $color[122] = $im->colorAllocateAlpha(108,255,147,$alpha);
      $color[123] = $im->colorAllocateAlpha(112,255,143,$alpha);
      $color[124] = $im->colorAllocateAlpha(116,255,139,$alpha);
      $color[125] = $im->colorAllocateAlpha(120,255,135,$alpha);
      $color[126] = $im->colorAllocateAlpha(124,255,131,$alpha);
      $color[127] = $im->colorAllocateAlpha(128,255,128,$alpha);
      $color[128] = $im->colorAllocateAlpha(131,255,124,$alpha);
      $color[129] = $im->colorAllocateAlpha(135,255,120,$alpha);
      $color[130] = $im->colorAllocateAlpha(139,255,116,$alpha);
      $color[131] = $im->colorAllocateAlpha(143,255,112,$alpha);
      $color[132] = $im->colorAllocateAlpha(147,255,108,$alpha);
      $color[133] = $im->colorAllocateAlpha(151,255,104,$alpha);
      $color[134] = $im->colorAllocateAlpha(155,255,100,$alpha);
      $color[135] = $im->colorAllocateAlpha(159,255,96,$alpha);
      $color[136] = $im->colorAllocateAlpha(163,255,92,$alpha);
      $color[137] = $im->colorAllocateAlpha(167,255,88,$alpha);
      $color[138] = $im->colorAllocateAlpha(171,255,84,$alpha);
      $color[139] = $im->colorAllocateAlpha(175,255,80,$alpha);
      $color[140] = $im->colorAllocateAlpha(179,255,76,$alpha);
      $color[141] = $im->colorAllocateAlpha(183,255,72,$alpha);
      $color[142] = $im->colorAllocateAlpha(187,255,68,$alpha);
      $color[143] = $im->colorAllocateAlpha(191,255,64,$alpha);
      $color[144] = $im->colorAllocateAlpha(195,255,60,$alpha);
      $color[145] = $im->colorAllocateAlpha(199,255,56,$alpha);
      $color[146] = $im->colorAllocateAlpha(203,255,52,$alpha);
      $color[147] = $im->colorAllocateAlpha(207,255,48,$alpha);
      $color[148] = $im->colorAllocateAlpha(211,255,44,$alpha);
      $color[149] = $im->colorAllocateAlpha(215,255,40,$alpha);
      $color[150] = $im->colorAllocateAlpha(219,255,36,$alpha);
      $color[151] = $im->colorAllocateAlpha(223,255,32,$alpha);
      $color[152] = $im->colorAllocateAlpha(227,255,28,$alpha);
      $color[153] = $im->colorAllocateAlpha(231,255,24,$alpha);
      $color[154] = $im->colorAllocateAlpha(235,255,20,$alpha);
      $color[155] = $im->colorAllocateAlpha(239,255,16,$alpha);
      $color[156] = $im->colorAllocateAlpha(243,255,12,$alpha);
      $color[157] = $im->colorAllocateAlpha(247,255,8,$alpha);
      $color[158] = $im->colorAllocateAlpha(251,255,4,$alpha);
      $color[159] = $im->colorAllocateAlpha(255,255,0,$alpha);
      $color[160] = $im->colorAllocateAlpha(255,251,0,$alpha);
      $color[161] = $im->colorAllocateAlpha(255,247,0,$alpha);
      $color[162] = $im->colorAllocateAlpha(255,243,0,$alpha);
      $color[163] = $im->colorAllocateAlpha(255,239,0,$alpha);
      $color[164] = $im->colorAllocateAlpha(255,235,0,$alpha);
      $color[165] = $im->colorAllocateAlpha(255,231,0,$alpha);
      $color[166] = $im->colorAllocateAlpha(255,227,0,$alpha);
      $color[167] = $im->colorAllocateAlpha(255,223,0,$alpha);
      $color[168] = $im->colorAllocateAlpha(255,219,0,$alpha);
      $color[169] = $im->colorAllocateAlpha(255,215,0,$alpha);
      $color[170] = $im->colorAllocateAlpha(255,211,0,$alpha);
      $color[171] = $im->colorAllocateAlpha(255,207,0,$alpha);
      $color[172] = $im->colorAllocateAlpha(255,203,0,$alpha);
      $color[173] = $im->colorAllocateAlpha(255,199,0,$alpha);
      $color[174] = $im->colorAllocateAlpha(255,195,0,$alpha);
      $color[175] = $im->colorAllocateAlpha(255,191,0,$alpha);
      $color[176] = $im->colorAllocateAlpha(255,187,0,$alpha);
      $color[177] = $im->colorAllocateAlpha(255,183,0,$alpha);
      $color[178] = $im->colorAllocateAlpha(255,179,0,$alpha);
      $color[179] = $im->colorAllocateAlpha(255,175,0,$alpha);
      $color[180] = $im->colorAllocateAlpha(255,171,0,$alpha);
      $color[181] = $im->colorAllocateAlpha(255,167,0,$alpha);
      $color[182] = $im->colorAllocateAlpha(255,163,0,$alpha);
      $color[183] = $im->colorAllocateAlpha(255,159,0,$alpha);
      $color[184] = $im->colorAllocateAlpha(255,155,0,$alpha);
      $color[185] = $im->colorAllocateAlpha(255,151,0,$alpha);
      $color[186] = $im->colorAllocateAlpha(255,147,0,$alpha);
      $color[187] = $im->colorAllocateAlpha(255,143,0,$alpha);
      $color[188] = $im->colorAllocateAlpha(255,139,0,$alpha);
      $color[189] = $im->colorAllocateAlpha(255,135,0,$alpha);
      $color[190] = $im->colorAllocateAlpha(255,131,0,$alpha);
      $color[191] = $im->colorAllocateAlpha(255,128,0,$alpha);
      $color[192] = $im->colorAllocateAlpha(255,124,0,$alpha);
      $color[193] = $im->colorAllocateAlpha(255,120,0,$alpha);
      $color[194] = $im->colorAllocateAlpha(255,116,0,$alpha);
      $color[195] = $im->colorAllocateAlpha(255,112,0,$alpha);
      $color[196] = $im->colorAllocateAlpha(255,108,0,$alpha);
      $color[197] = $im->colorAllocateAlpha(255,104,0,$alpha);
      $color[198] = $im->colorAllocateAlpha(255,100,0,$alpha);
      $color[199] = $im->colorAllocateAlpha(255,96,0,$alpha);
      $color[200] = $im->colorAllocateAlpha(255,92,0,$alpha);
      $color[201] = $im->colorAllocateAlpha(255,88,0,$alpha);
      $color[202] = $im->colorAllocateAlpha(255,84,0,$alpha);
      $color[203] = $im->colorAllocateAlpha(255,80,0,$alpha);
      $color[204] = $im->colorAllocateAlpha(255,76,0,$alpha);
      $color[205] = $im->colorAllocateAlpha(255,72,0,$alpha);
      $color[206] = $im->colorAllocateAlpha(255,68,0,$alpha);
      $color[207] = $im->colorAllocateAlpha(255,64,0,$alpha);
      $color[208] = $im->colorAllocateAlpha(255,60,0,$alpha);
      $color[209] = $im->colorAllocateAlpha(255,56,0,$alpha);
      $color[210] = $im->colorAllocateAlpha(255,52,0,$alpha);
      $color[211] = $im->colorAllocateAlpha(255,48,0,$alpha);
      $color[212] = $im->colorAllocateAlpha(255,44,0,$alpha);
      $color[213] = $im->colorAllocateAlpha(255,40,0,$alpha);
      $color[214] = $im->colorAllocateAlpha(255,36,0,$alpha);
      $color[215] = $im->colorAllocateAlpha(255,32,0,$alpha);
      $color[216] = $im->colorAllocateAlpha(255,28,0,$alpha);
      $color[217] = $im->colorAllocateAlpha(255,24,0,$alpha);
      $color[218] = $im->colorAllocateAlpha(255,20,0,$alpha);
      $color[219] = $im->colorAllocateAlpha(255,16,0,$alpha);
      $color[220] = $im->colorAllocateAlpha(255,12,0,$alpha);
      $color[221] = $im->colorAllocateAlpha(255,8,0,$alpha);
      $color[222] = $im->colorAllocateAlpha(255,4,0,$alpha);
      $color[223] = $im->colorAllocateAlpha(255,0,0,$alpha);
      $color[224] = $im->colorAllocateAlpha(251,0,0,$alpha);
      $color[225] = $im->colorAllocateAlpha(247,0,0,$alpha);
      $color[226] = $im->colorAllocateAlpha(243,0,0,$alpha);
      $color[227] = $im->colorAllocateAlpha(239,0,0,$alpha);
      $color[228] = $im->colorAllocateAlpha(235,0,0,$alpha);
      $color[229] = $im->colorAllocateAlpha(231,0,0,$alpha);
      $color[230] = $im->colorAllocateAlpha(227,0,0,$alpha);
      $color[231] = $im->colorAllocateAlpha(223,0,0,$alpha);
      $color[232] = $im->colorAllocateAlpha(219,0,0,$alpha);
      $color[233] = $im->colorAllocateAlpha(215,0,0,$alpha);
      $color[234] = $im->colorAllocateAlpha(211,0,0,$alpha);
      $color[235] = $im->colorAllocateAlpha(207,0,0,$alpha);
      $color[236] = $im->colorAllocateAlpha(203,0,0,$alpha);
      $color[237] = $im->colorAllocateAlpha(199,0,0,$alpha);
      $color[238] = $im->colorAllocateAlpha(195,0,0,$alpha);
      $color[239] = $im->colorAllocateAlpha(191,0,0,$alpha);
      $color[240] = $im->colorAllocateAlpha(187,0,0,$alpha);
      $color[241] = $im->colorAllocateAlpha(183,0,0,$alpha);
      $color[242] = $im->colorAllocateAlpha(179,0,0,$alpha);
      $color[243] = $im->colorAllocateAlpha(175,0,0,$alpha);
      $color[244] = $im->colorAllocateAlpha(171,0,0,$alpha);
      $color[245] = $im->colorAllocateAlpha(167,0,0,$alpha);
      $color[246] = $im->colorAllocateAlpha(163,0,0,$alpha);
      $color[247] = $im->colorAllocateAlpha(159,0,0,$alpha);
      $color[248] = $im->colorAllocateAlpha(155,0,0,$alpha);
      $color[249] = $im->colorAllocateAlpha(151,0,0,$alpha);
      $color[250] = $im->colorAllocateAlpha(147,0,0,$alpha);
      $color[251] = $im->colorAllocateAlpha(143,0,0,$alpha);
      $color[252] = $im->colorAllocateAlpha(139,0,0,$alpha);
      $color[253] = $im->colorAllocateAlpha(135,0,0,$alpha);
      $color[254] = $im->colorAllocateAlpha(131,0,0,$alpha);
      $color[255] = $im->colorAllocateAlpha(128,0,0,$alpha);
      $color[256] = $im->colorAllocateAlpha(0,0,0,$alpha);
      $color[256] = $im->colorAllocateAlpha(0,0,0,$alpha);
     
     
     
      $im->transparent($color[0]);  
      return (@color);
}


#################################################################
# sub _makeColorbar($title)
#
# this subroutine makes a png with the colorbar
#
#################################################################
sub _makeColorbar {
   my ($self,$title) = @_;
     
        my $numColors=13;  # the default	
   if (defined $self->{NUMCOLORS}) {
           $numColors=$self->{NUMCOLORS};
   }
        

   my $xpix=550;
   my $ypix=100;
   my $xMarg=15;
   my $yMarg=30;
   my $xWidth= ($xpix - 2*$xMarg);
   

   my $im = new GD::Image($xpix,$ypix);
   my @colors;
   @colors = &setColors($im);  #if $self->{COLORMAP} eq "jet";	 
  # @colors = &setColors_jet($im)  if $self->{COLORMAP} eq "jet";	 
  # @colors = &setColors_slfpae($im)  if $self->{COLORMAP} eq "slfpae";	 
  # @colors = &setColors_diff($im)  if $self->{COLORMAP} eq "diff";	 
  # @colors = &setColors_marsh($im)  if $self->{COLORMAP} eq "marsh";	  

   my $i;
   my $j;
   my $cnt = 0;
    my ($cll, $cul) = @{$self->{CLIM}};  # hard coded limits for colors
    my $dClim=$cul-$cll;
  # my $dClim=$self->{CLIM2}-$self->{CLIM1};
   my $dzdc=$dClim/254;
#bpj bad change   my $dzdc=$dClim/253;
   my $C;
  

### BPJ Make white background for colorbar area 
#   $im->colorDeallocate($colors[255]);
#   $colors[255] = $im->colorAllocateAlpha(255,255,255,0);
   foreach $j ( 0 .. $ypix+$yMarg ) {
       foreach $i ( 0 .. $xpix+$xMarg ) {
	$im->setPixel($i,$j,$colors[255]);
       }
   }

### BPJ Make black 2 pixel border around white background
   foreach $j ( 0 .. $ypix+$yMarg ) {
       $im->setPixel(0,$j,$colors[254]);
       $im->setPixel(1,$j,$colors[254]);
       $im->setPixel($xpix-2,$j,$colors[254]);
       $im->setPixel($xpix-1,$j,$colors[254]);
   }
   foreach $i ( 0 .. $xpix+$xMarg ) {
       $im->setPixel($i,0,$colors[254]);
       $im->setPixel($i,1,$colors[254]);
       $im->setPixel($i,$ypix-2,$colors[254]);
       $im->setPixel($i,$ypix-1,$colors[254]);
   }
   # draw the colored part of the colorbar
   foreach $j ( $yMarg .. $ypix-$yMarg ) {

       foreach $i ( $xMarg .. $xpix-$xMarg ) {
          my $C= 255 * ($i-$xMarg)  / $xWidth;
          
         # $C= ($c-$self->{CLIM1})/$dzdc+1;       
          $C= int((int($numColors*$C/256)+0.5 )*256/$numColors)-1  unless ($C==0);
          $C=254 if ($C > 254); 
#bpj added:
#          $C=253 if ($C > 253); 
          $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map

       }      
   
   
   }
   
   # add the title
   my $black=$colors[256];
   $im->string(gdGiantFont,40,5,$title,$black);
    #my $label1= GD::Text::Align->new($im, valign => 'center', halign => 'center');
    #   $label1->set_font('arial',30);
    #   $label1->set_text("$title");
    #   $label1->set(color => $black);
    #   $label1->draw(250,10 , 0);
   
   # ticks on the bottom x-axis (speed)
      my $dx=$xWidth/$numColors;
      
      $dx=$xWidth/13 if $numColors > 13;  # just to keep ticks from crowding eachother
#bpj from old scale      $dx=$xWidth/11 if $numColors > 13;  # just to keep ticks from crowding eachother
      
      
      
      my $x=$xMarg;
      my $x2=$xMarg+$xWidth;
      my $ytmp=$ypix-$yMarg;

      while ($x<=$x2){
        foreach my $y ($ytmp-5 .. $ytmp+5) {              # tick marks
              $im->setPixel($x,$y,$black);
              $im->setPixel($x+1,$y,$black);
        } 
        
        my $dtmp = $cll + ($x - $xMarg)*$dClim/$xWidth;
        
#bpj        my $tickLabel=sprintf("%4.1f",$dtmp);
#bpj added:
        my $tickLabel=sprintf("%3.0f",$dtmp);
#        $im->string(gdMediumBoldFont,$x-5,$ytmp+6,$tickLabel,$black);
# BPJ change x offset
        $im->string(gdMediumBoldFont,$x-11,$ytmp+6,$tickLabel,$black);
        $x=$x+$dx;
      } 
   
   
   
   
   
   
  # now write the png file
  my $pngFile= "Files/colorbar.png";
  open FILE2, ">$pngFile";
  binmode FILE2;
  print FILE2 $im->png;
  close(FILE2);
        $im=undef;

}







1;
