# elementQuadTree.pm
#
# contains subroutines for building a quadtree out of an adcirc grid
# and for writing the grid out as a kml superoverlay, and other stuff...

####################################################################### 
# Author: Nathan Dill, natedill@gmail.com
#
# Copyright (C) 2014-2016 Nathan Dill
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




package ElementQuadTree;

use strict;
use warnings;
use GD;
use Storable;


#####################################################################
# sub new()
#
# this is the constructor.  It will create the elementQuadTree object 
#
# input is a hash e.g.
#
# $tree = elementQuadTree->new(
#                                  -NORTH=>$north   # the region for the tree
#                                  -SOUTH=>$south
#                                  -EAST =>$east
#                                  -WEST =>$west
#                                  -XNODE=>\@X   # references to the node position table arrays (x,y,z)
#                                  -YNODE=>\@Y   # these are indexed by node number, so arrays should
#                                  -ZNODE=>\@Z   # have some value at index zero (could be undef)
#                                  -MAXELEMS=>$maxelems # maximum number of elements per tree node
#                               #                              );
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
      $obj->{MAXELEMS}= $args{-MAXELEMS};
      $obj->{XNODE}   = $args{-XNODE};         # references to arrays of nodal positions
      $obj->{YNODE}   = $args{-YNODE};         #
      $obj->{ZNODE}   = $args{-ZNODE};
      $obj->{N1}      = ''; # this is the connectivity table, getsbuilt as elements are added
      $obj->{N2}      = ''; # binary strings of 32 bit integers
      $obj->{N3}      = '';
      $obj->{LASTINDEX}=0;  # used to store last index where a point was found
      

      $obj->{SETNAME}='';

      # set data for top level (index = 0)
      $obj->{REGION}   [0] = [$north, $south, $east, $west];
      $obj->{PARENT}   [0] = undef;
      $obj->{CHILDREN} [0] = [];
      $obj->{NELEMS}   [0] = 0;
      $obj->{ELEMIDS}  [0] = ''; # binary string of 32 bit integers
      $obj->{ISFULL}   [0] = 0;
      $obj->{DEMBLOCK} [0] = undef; # binary string of 8 bit itegers, color map index 
      $obj->{T}[0]         =undef; # these (T,U,I) are used to store binary strings of the 
      $obj->{U}[0]         =undef; # interplonalt values and element ids for pixels
      $obj->{I}[0]         =undef; # T and U are floats, I is an integer.   only stored at the leaf node level. 

      print "starting tree, region $north $south $east $west\n";

      return $obj;
      
}



#####################################################################
# sub new_from_adcGrid()
#
# this is the constructor.  It will create the elementQuadTree object 
# from an $adcGrid object
# it also then adds all the elements to the tree
#
# input is a hash e.g.
#
# $tree = elementQuadTree->new_from_adcGrid(
#                                  -MAXELEMS=>$maxelems, # maximum number of elements per tree node
#                                  -ADCGRID=>$adcGrid,  # and adcGrid objecvt
#
#                                  -NORTH=>$north,   # the region for the tree (optional)
#                                  -SOUTH=>$south,
#                                  -EAST =>$east,
#                                  -WEST =>$west,
#                               #                              );
#
#####################################################################
sub new_from_adcGrid
{
      my $self = shift;
      
      my $class = ref($self) || $self;
      
      my $obj = bless {} => $class;
      
      my %args = @_;
     
      $obj->{MAXELEMS}= $args{-MAXELEMS};
      my $adcGrid=$args{-ADCGRID};      
      my $north;
      my $south;
      my $east;
      my $west; 

      # set bounds based on optional input argument or full region from adcGrid obj     
      if (defined $args{-NORTH}){
         $north=$args{-NORTH};
      }else{
         $north=$adcGrid->{MAX_Y};
      }
      if (defined $args{-SOUTH}){
         $south=$args{-SOUTH};
      }else{
         $south=$adcGrid->{MIN_Y};
      }
      if (defined $args{-EAST}){
         $east=$args{-EAST};
      }else{
         $east=$adcGrid->{MAX_X};
      }
      if (defined $args{-WEST}){
         $west=$args{-WEST};
      }else{
         $west=$adcGrid->{MIN_X};
      }

      $obj->{N1}      = ''; # this is the connectivity table, getsbuilt as elements are added
      $obj->{N2}      = ''; # binary strings of 32 bit integers
      $obj->{N3}      = '';
      $obj->{LASTINDEX}=0;  # used to store last index where a point was found
      

      $obj->{SETNAME}='';

      # set data for top level (index = 0)
      $obj->{REGION}   [0] = [$north, $south, $east, $west];
      $obj->{PARENT}   [0] = undef;
      $obj->{CHILDREN} [0] = [];
      $obj->{NELEMS}   [0] = 0;
      $obj->{ELEMIDS}  [0] = ''; # binary string of 32 bit integers
      $obj->{ISFULL}   [0] = 0;
      $obj->{DEMBLOCK} [0] = undef; # binary string of 8 bit itegers, color map index 
      $obj->{T}[0]         =undef; # these (T,U,I) are used to store binary strings of the 
      $obj->{U}[0]         =undef; # interplonalt values and element ids for pixels
      $obj->{I}[0]         =undef; # T and U are floats, I is an integer.   only stored at the leaf node level. 

      print "starting tree, region $north $south $east $west\n";

      # load the xyz data
      print "new_from_adcGrid: getting nodal positions from adcGrid\n";

      my $xyz =  $adcGrid->{XYZ};
      my $nn = $adcGrid->{NP};
      my @X;
      my @Y;
      my @Z;  

      foreach my $i (0..$nn) {
          my $offset =  $i*24;
          my $packed = substr($xyz,$offset,24);
          my ($x,$y,$z)=unpack("d3",$packed);
          push @X, $x;
          push @Y, $y;
          push @Z, $z;
      }
      $obj->{XNODE}   = \@X;         
      $obj->{YNODE}   = \@Y;
      $obj->{ZNODE}   = \@Z;
      $obj->{ZDATA}   = \@Z;

      # add all the elements to the tree
      print "new_from_adcGrid: adding elements from adcGrid\n";
      my $ne=$adcGrid->{NE};
      foreach my $eid (1..$ne){
         my ($n1, $n2, $n3)=unpack("l3", substr($adcGrid->{NM},$eid*12,12) );
         $obj->addElement(
                           -ID=>$eid,
                           -N1=>$n1,
                           -N2=>$n2,
                           -N3=>$n3
                          );
      }

      return $obj;
      
}



#########################################################
# sub addElement ()
#
# public method for adding points to the tree
#
# input is a hash e.g.
#
# $tree->addElement (
#                   -ID=>$id,    # the element id
#                   -N1=>$n1,    # node number 1   (index into x,y position array)
#                   -N2=>$n2,    # node number 2
#                   -N3=>$n3,    # node number 3 
#                 )
#
###############################################################
sub addElement {
	my $obj=shift;
	my %args=@_;

	my $elemID=$args{-ID};

#	my $n1=pack('N', $args{-N1}); # convert to binary 32 bit integer
#	my $n2=pack('N', $args{-N2}); # convert to binary 32 bit integer
#	my $n3=pack('N', $args{-N3}); # convert to binary 32 bit integer
	my $n1=$args{-N1};
	my $n2=$args{-N2};

	my $n3=$args{-N3};
	#  print " id $elemID, n1$n1,  args $args{-N1}\n ";
	#sleep;	
	
	vec($obj->{N1},$elemID,32)=$n1;   # put the node number values in the binary strings at the proper offset
	vec($obj->{N2},$elemID,32)=$n2;
	vec($obj->{N3},$elemID,32)=$n3;
#	$obj->{N1}[$elemID] = $args{-N1};   # building arrays of node connectivity
#	$obj->{N2}[$elemID] = $args{-N2};   # 
#	$obj->{N3}[$elemID] = $args{-N3};

		
        # recurseively check down the tree til you find a node that is not full
	my $recurseDepth=1;
	my $index=0;

        $obj->_addElementToLevel ($elemID,$recurseDepth,$index);
}


#####################################################
# sub _addElementToLevel()
#
# this private method recursed down the tree and elements 
# to a tree node if it isn't full yet.
#
#####################################################

sub _addElementToLevel{
        my $obj = shift;
        my ($elemID,$recurseDepth,$index) = @_;

#        print "debug  $obj->{N1}[$elemID],,\n";
#        print "	$obj->{XNODE}[ $obj->{N1}[$elemID] ]\n";
#	sleep;
#
        # get node numbers for this element from binary strings
	#my $c;

        my $n1=vec($obj->{N1},$elemID,32);
        my $n2=vec($obj->{N2},$elemID,32);
        my $n3=vec($obj->{N3},$elemID,32);


	my @x= sort {$a <=> $b} ($obj->{XNODE}[ $n1 ],
                                 $obj->{XNODE}[ $n2 ],
                                 $obj->{XNODE}[ $n3 ]);
			 
	my @y= sort {$a <=> $b} ($obj->{YNODE}[ $n1 ],
                                 $obj->{YNODE}[ $n2 ],
                                 $obj->{YNODE}[ $n3 ]);

       print "eid n1n2n3 $elemID, $n1, $n2, $n3 - $recurseDepth\n"  unless defined($y[0]);

	# check to see if any part of this element is in this tree node
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
	

	if ($y[0] <= $north) {    # check of lowest y is below north
         if ($y[2] >= $south) {    # if highest y is above south
          if ($x[2] >= $west)  {    # if highest x is right of west
	   if ($x[0] <= $east)  {    # if lowest x is left of east
 		   $inRegion=1;
#		 print "in Region\n";
		   
           }
	  }
	 }
	}	
           
	return unless ($inRegion);

       # if the tree node is not full add the point here
       unless ($obj->{ISFULL}[$index]==1) {
          
          vec($obj->{ELEMIDS}[$index],$obj->{NELEMS}[$index],32)=$elemID;
	  $obj->{NELEMS}[$index]++;

          # if it just filled up mark it full, divide it up, re-distribute the points
          if  ($obj->{NELEMS}[$index] > $obj->{MAXELEMS}){
           
            $obj->{ISFULL}[$index]=1;

            $obj->_divideRegion($recurseDepth,$index); 
            
	    $recurseDepth++;

            my $cnt=$obj->{NELEMS}[$index];
            while ($cnt--) {
		    #foreach my $elem ( @{$obj->{ELEMIDS}[$index]} ){
		my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);
	
		foreach my $child ( @{$obj->{CHILDREN}[$index]} ){
                   $obj->_addElementToLevel($elem,$recurseDepth,$child);
	        }
	    }
            # now that we have re-distributed, free up the ELEMIDS for this node, 
	    # since we only need to have that info at the leaf level 	    
              undef $obj->{ELEMIDS}[$index];
          }  
       } else {   # this node is full, check the children
	 $recurseDepth++;      

#	 print " index $index is already full,  depth : $recurseDepth\n"; 
         foreach my $child ( @{$obj->{CHILDREN}[$index]} ){
              $obj->_addElementToLevel($elemID,$recurseDepth,$child);
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
         $obj->{NELEMS}  [$indx] = 0;
         $obj->{ELEMIDS}  [$indx] = '';
         $obj->{ISFULL}   [$indx] = 0;
	 $obj->{DEMBLOCK} [$indx]= undef;
         push (@{$obj->{CHILDREN}[$index]}, $indx);
	
        # northeast
         $indx=4*$index+2;
	 $obj->{REGION}   [$indx] = [$north, $ns, $east, $ew];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NELEMS}   [$indx] = 0;
         $obj->{ELEMIDS}  [$indx] = '';
         $obj->{ISFULL}   [$indx] = 0;
	 $obj->{DEMBLOCK} [$indx]= undef;
         push (@{$obj->{CHILDREN}[$index]}, $indx);

        # southeast
	 $indx=4*$index+3;
	 $obj->{REGION}   [$indx] = [$ns, $south, $east, $ew];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NELEMS}  [$indx] = 0;
         $obj->{ELEMIDS}  [$indx] = '';
         $obj->{ISFULL}   [$indx] = 0;
	 $obj->{DEMBLOCK} [$indx]=undef;
         push (@{$obj->{CHILDREN}[$index]}, $indx);

        # southwest
	 $indx=4*$index+4;
	 $obj->{REGION}   [$indx] = [$ns, $south, $ew, $west];
         $obj->{PARENT}   [$indx] = $index;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NELEMS}  [$indx] = 0;
         $obj->{ELEMIDS}  [$indx] = '';
         $obj->{ISFULL}   [$indx] = 0;
	 $obj->{DEMBLOCK} [$indx]=undef;
         push (@{$obj->{CHILDREN}[$index]}, $indx);
}



#######################################################
# sub writeKMLPoly() -  public method
#
# writes the tree in kml files with polygons 
#######################################################
sub writeKMLPoly{
	my $obj = shift;
	my ($descString)=@_;
	mkdir("poly_Files");
	print "writing kml polygons\n";
	$obj->_writeKMLPoly(0,1,$descString);    # index, depth - for top layer
}


#######################################################
# sub _writeKMLPoly() -  private method actually does the work
#
#######################################################

sub _writeKMLPoly{
	my ($obj, $index, $depth, $descString) = @_;

	return unless($obj->{NELEMS}[$index]);  # don't write kml for nodes that are empty
        
	my $kmlFile;
	my @kids = @{$obj->{CHILDREN}[$index]};
	 
        my $minLOD=128;
	my $maxLOD=512;
#        if ($depth==1) {$minLOD=0;}
        unless (@kids) {$maxLOD=-1;}

        my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

        
        if ($index ==0 ) {
	        $kmlFile = "Elements_doc.kml";
        }else{  
		$kmlFile = "poly_Files/poly$index.kml";}
         


	# file beginning
	open FILE, ">$kmlFile" or die "can not open $kmlFile";
        print FILE '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print FILE '<kml xmlns="http://www.opengis.net/kml/2.2">'."\n";
	print FILE "   <Document>\n";
        
        # for the top level file write the style tags
	if ($index ==0 ) {

             print FILE "    <Style id=\"blkStyle\">\n";
             print FILE "      <PolyStyle>\n";
             print FILE "         <color>ff00ffff</color>\n";   # this is yellow
             #print FILE "         <color>ffffffff</color>\n";  # this is black
             print FILE "         <colorMode>normal</colorMode>\n";
             print FILE "         <fill>0</fill>\n";
	     print FILE "         <outline>1</outline>\n";
             print FILE "      </PolyStyle>\n";
             print FILE "      <BalloonStyle>\n";
             print FILE '         <text>$[description]</text>\n';
             print FILE "      </BalloonStyle>\n";
             print FILE "    </Style>\n";
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

	# add the placemarks for this node if it is a leaf node
	unless  ($obj->{ISFULL}[$index]) {
	   
           my $cnt=$obj->{NELEMS}[$index];
	   
           while ($cnt--) {
                my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);
                    #foreach my $elem ( @{$obj->{ELEMIDS}[$index]} ){
                
                my $n1=vec($obj->{N1},$elem,32);
                my $n2=vec($obj->{N2},$elem,32);
                my $n3=vec($obj->{N3},$elem,32);

                my ($x1, $x2, $x3)= ($obj->{XNODE}[ $n1 ],
                                     $obj->{XNODE}[ $n2 ],
                                     $obj->{XNODE}[ $n3 ] );
                my ($y1, $y2, $y3)= ($obj->{YNODE}[ $n1 ],
                                     $obj->{YNODE}[ $n2 ],
                                     $obj->{YNODE}[ $n3 ] );
                my ($z1, $z2, $z3)= ($obj->{ZNODE}[ $n1 ],
                                     $obj->{ZNODE}[ $n2 ],
                                     $obj->{ZNODE}[ $n3 ] );
		    
                my $cul=25;  # hard coded limits for colors
                my $cll=0;

		    #my $style =int( $cll+ 255* (($z1+$z2+$z3)/3.-$cll)/($cul-$cll));
		    #$style = 255 if ($style > 255);
		    #$style = 1   if ($style <1) ; 

                    print FILE "     <Placemark>\n";
		    print FILE "        <name></name>\n";
		    print FILE "        <styleUrl>..\\Elements_doc.kml#blkStyle</styleUrl>\n";
                    print FILE "        <description>\n";
		    print FILE "         <p><b>$descString</b></p>\n";
		    my $tmpstr=sprintf ("element %i\n nodes:  %i, %i, %i\n",$elem,$n1,$n2,$n3);
		    print FILE "$tmpstr";
		      print FILE " z: $z1, $z2, $z3\n";
		    print FILE "        </description>\n";
                    print FILE "        <Polygon>\n ";
		    print FILE "          <altitudeMode>clampToGround</altitudeMode>\n";
		    print FILE "           <outerBoundaryIs>\n";
		    print FILE "            <LinearRing>\n";
		    print FILE "             <coordinates>$x1,$y1,$z1 $x2,$y2,$z2 $x3,$y3,$z3 $x1,$y1,$z1</coordinates>\n";
		    print FILE "            </LinearRing>\n";
		    print FILE "           </outerBoundaryIs>\n";
		    print FILE "        </Polygon>\n";
		    print FILE "     </Placemark>\n";

		}
	}

	# network links to children
	if (@kids) {
	foreach my $kid (@kids) {

	   next unless($obj->{NELEMS}[$kid]);	# dont write the link for children that dont have elements in them
           
	   my $lnkName="poly$kid.kml";
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
             print FILE "	      <href>poly_Files/$lnkName</href>\n";
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
	   
           next unless($obj->{NELEMS}[$kid]);  # don't write kml for tree nodes with no elemets under them

	   $obj->_writeKMLPoly($kid, $depth+1,$descString);
	
        }
}

#######################################################
# sub interpPixels(                  # public method
#                   
#
# determines t and u values and I of interpolant for pixels 
# at bottom level nodes. 
#######################################################
sub interpPixels {
      my $obj=shift;
       
      print "interpolating pixels\n";
      $obj->_interpPixels(0,1);
     

}

##############################################################
# sub _interpPixels - determines t and u values and I of interpolant for pixels
#
# ###########################################################
sub _interpPixels { # private method actualy does the work
      my ($obj,$index,$depth)=@_;
      
      # recurse down to the bottom of the tree and determine interpolant data for bottom level pixels
      my @kids = @{$obj->{CHILDREN}[$index]};   

      if (@kids) {  #  this node has children, keep going
	  
          foreach my $kid (@kids) {
		   print "index $index, kid=$kid\n";
		    print "deptn = $depth\n";
		   #sleep;
		  
             $obj->_interpPixels($kid,$depth+1);
	  }
	   print "returning!!\n";
	  return;
      }
      
      # here only if its a leaf node
      # now do the interpolation

      my $npix=256;
      my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
      my $dxdi=($east-$west)/($npix-1);
      my $dydj=($south-$north)/($npix-1);
      # my $dzdc=($obj->{CLIM2}-$obj->{CLIM1})/254;



      
      # initialize DEMBLOCK as zero
      #  $obj->{DEMBLOCK}[$index]="";
      #  vec($obj->{DEMBLOCK}[$index],($npix*$npix-1),8)=0;

      my @I;  # temporary arrays to hold interpolatation data
      my @T; 
      my @U;
      my $cnt=$npix*$npix; 
      while ($cnt--){
	     $I[$cnt]=0;
	     $T[$cnt]=0;
	     $U[$cnt]=0;
       }

      # loop over elements
      $cnt=$obj->{NELEMS}[$index];
      print "$cnt elements in index $index\n";

      while ($cnt--) {
          my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);
#print "elem = $elem index= $index  depth=$depth\n";
          my $n1=vec($obj->{N1},$elem,32);
          my $n2=vec($obj->{N2},$elem,32);
          my $n3=vec($obj->{N3},$elem,32);

          my @x = ($obj->{XNODE}[ $n1 ],
                   $obj->{XNODE}[ $n2 ],
                   $obj->{XNODE}[ $n3 ] );
          my @y = ($obj->{YNODE}[ $n1 ],
                   $obj->{YNODE}[ $n2 ],
                   $obj->{YNODE}[ $n3 ] );
	   #  my @z = ($obj->{ZDATA}[ $n1 ],
	   #        $obj->{ZDATA}[ $n2 ],
	   #        $obj->{ZDATA}[ $n3 ] ); 

        

	  # determine the i,j range for this element (0,0 is the upper left corner of this leaf node)
	  my @xs = sort {$a <=> $b} @x;
	  my @ys = sort {$b <=> $a} @y;
	  #my @zs = sort {$a <=> $b} @z;
	  my $imin = int (($xs[0] - $west) / $dxdi);
	  $imin=0 if $imin<0;
          my $jmin = int (($ys[0] - $north) / $dydj);
	  $jmin=0 if $jmin<0;
	  my $imax = int (($xs[2] - $west) / $dxdi )+ 1;
	  $imax=255 if $imax>255;
	  my $jmax = int (($ys[2] - $north) / $dydj) + 1;
	  $jmax=255 if $jmax>255;
	  my $xmin=$west+$imin*$dxdi;
	  my $ymin=$north+$jmin*$dydj;
          # loop over the pixels in this range, check if they are in the element and set I T and U if the are
          my $i = $imin;
	  my $xi= $xmin;
          while ($i <= $imax) {
             my $j  = $jmin;
	     my $yj = $ymin;
	     while ($j <= $jmax) {
		 my $offset = $j*$npix+$i;           # image date are in row by row order starting from top left
                 # check to see if this point is in the triangle
		 my $inPoly = &locat_chk($xi, $yj, \@x, \@y);
		 
		 if ($inPoly) {		 # if it is, get the interpoolant values and set T, U, and I 
		   
		       $I[$offset]=$elem;
		      ($T[$offset], $U[$offset])= &triInterp1($xi, $yj, \@x, \@y);     # interpolate z on the triangle
		  }
                  $j++;
		  $yj=$yj+$dydj;   # remember $dydj is negative
             }
             $i++;
	     $xi=$xi+$dxdi;
          }	  
          

      }
      # now pack interpolation data and store in object
         $obj->{I}[$index]=pack('N*',@I);
         $obj->{T}[$index]=pack('f*',@T);
         $obj->{U}[$index]=pack('f*',@U);


      #$obj->_makePNG($index,$npix,$npix);
      return;
}



#######################################################
# sub setDEMBLOCK(                  # public method
#                    -SETNAME=>'belv',
#                    -ZDATA=>\@ZDATA,  # optional, uses mesh Z if not given
#                    -CLIM1=>-10,
#                    -CLIM2=>10,
#                    -PALETTE=>'palette_file.txt',
#                    -NUMCOLORS=>20,     # number of colors to display in png files for overlays
#                    -ALPHA=>$alpha,  #transparency 0-127 opaque - transparent
#                    -ADD_ADJUST=>0.0,    #optional value added to ZDATA after applying MULT_ADJUST
#                    -MULT_ADJUST=>1.0,    #optional value multiplied by ZDATA 
#                 ) 
#   input is a hash
#
# interpolates values at pixels into DEMBLOCK and makes 
# png files for leaf nodes, then goes from the bottom up
# and combines DEMBLOCK to make png for the rest of tree
#######################################################
sub setDEMBLOCK {
      my $obj=shift;
       
       my %args=@_;
       
      $obj->{SETNAME}=$args{-SETNAME} if defined ($args{-SETNAME}); # unique, short, whitespaceless, inentifyer for the dataset 
      if (defined $args{-ZDATA}){
         $obj->{ZDATA}=$args{-ZDATA}; # an array reference to data on nodes (e.g. maxele data)
      }else{
         $obj->{ZDATA}=$obj->{ZNODE};
      }
      $obj->{CLIM1}=$args{-CLIM1}; # lower limit for color
      $obj->{CLIM2}=$args{-CLIM2}; # upper imit for color
      $obj->{COLORMAP}=$args{-COLORMAP}; # an array ref to arrays for the color pallette
      my $CMAP = $obj->loadColormap($args{-PALETTE}); # loadColormap sets the colormap arrays
      $obj->{NUMCOLORS}=$args{-NUMCOLORS}; 
      $obj->{ALPHA}=$args{-ALPHA} if defined ($args{-ALPHA});
      my $addAdjust=0;
      my $multAdjust=1.0;
     $addAdjust=$args{-ADD_ADJUST} if defined ($args{-ADD_ADJUST});
     $multAdjust=$args{-MULT_ADJUST} if defined ($args{-MULT_ADJUST});
  #    print "settingDEMBLOCK";
      mkdir("$obj->{SETNAME}_Files"); 
      $obj->_setDEMBLOCK(0,1,$addAdjust,$multAdjust);
      $obj->_bottomUp(0,1);
 

}

##############################################################
# sub  _setDEMBLOCK - private method generates DEMBLOCKS at leaf nodes
#
# ###########################################################
sub _setDEMBLOCK { # private method actualy does the work
      my ($obj,$index,$depth,$addAdjust,$multAdjust)=@_;
      
      # recurse down to the bottom of the tree and set DEMBLOCK based on interpolant values
      my @kids = @{$obj->{CHILDREN}[$index]};   

      if (@kids) {  #  this node has children, keep going
	  
          foreach my $kid (@kids) {
		   #print "index $index, kid=$kid\n";
		   print "depth = $depth\n";
		   #sleep;
		  
             $obj->_setDEMBLOCK($kid,$depth+1,$addAdjust,$multAdjust);
	  }
 print "returning _SETDEMBLOCK!!\n";
	  return;
      }
      
      # here only if its a leaf node
      # now do the interpolation

      my $npix=256;
      # my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
      # my $dxdi=($east-$west)/($npix-1);
      # my $dydj=($south-$north)/($npix-1);
      my $dzdc=($obj->{CLIM2}-$obj->{CLIM1})/127;


      unless ($obj->{I}[$index]) {
          print "you need to interpPixels before setting DEMBLOCK\n";
          return;
        }
      
      # initialize DEMBLOCK as zero
      $obj->{DEMBLOCK}[$index]="";
      my @I=unpack('N*',$obj->{I}[$index]);
      my @T=unpack('f*',$obj->{T}[$index]);
      my @U=unpack('f*',$obj->{U}[$index]);
      
    
      
      my $i=$npix;
      while ($i--){
	      my $j=$npix;
         while ($j--) {
           my $offset=$j*$npix+$i; # get the offset to this pixel 
           my $C=0;
           if ($I[$offset] > 0) {
	     my $n1=vec($obj->{N1},$I[$offset],32);  # get the nodes for the element thhis pixel is in
             my $n2=vec($obj->{N2},$I[$offset],32);
             my $n3=vec($obj->{N3},$I[$offset],32);    
             my @z = ($obj->{ZDATA}[ $n1 ],  # get the zvalues need to dereference?
                    $obj->{ZDATA}[ $n2 ],
                    $obj->{ZDATA}[ $n3 ] );

             unless ($z[0] <= -99999 || $z[1] <= -99999 || $z[2] <= -99999) {

	        my $c=&triInterp2($T[$offset],$U[$offset],\@z);
                $c=$c*$multAdjust + $addAdjust;
                $C= ($c-$obj->{CLIM1})/$dzdc+1;
                $C=1 if $C<1; 
	        $C=128 if $C>128;
             }
           }
           vec($obj->{DEMBLOCK}[$index],$offset,8)=int($C);

         }
      }	 
      
       $obj->_makePNG($index,$npix,$npix);   
      return;
}


##########################################################
# sub _bottomUp 
# private method, creates png files and combines
# DEMBLOCKS
###########################################################
sub _bottomUp {

    my ($obj, $index, $depth)=@_;

    my @kids = @{$obj->{CHILDREN}[$index]};

    my $allFour=0;
  
   
    foreach my $kid (@kids) {
 	   $allFour++ if (defined $obj->{DEMBLOCK}[$kid] );
    }
    if ($allFour==4) {
       print "making DEMBLOCK for $index\n";
       print " my kids are @kids\n";

       my $tlDEM=$obj->{DEMBLOCK}[$kids[0]];  # same order here as in _addLevel
       my $trDEM=$obj->{DEMBLOCK}[$kids[1]];
       my $brDEM=$obj->{DEMBLOCK}[$kids[2]];
       my $blDEM=$obj->{DEMBLOCK}[$kids[3]];

       my $l1=length($tlDEM);
       my $l2=length($trDEM);
       my $l3=length($brDEM);
       my $l4=length($blDEM);
       print "DEM lengths $l1, $l2, $l3, $l4\n";


       my $bigJ = 512;
       my $bigI = 512;
       my $demBlock='';
       my $i;
       my $j;
       my $C;
       my ($tlcnt,$trcnt,$brcnt,$blcnt) = (0,0,0,0);
       my $cnt=0;
       foreach $j (0..255){
			 foreach $i (0..255) {
				 $C=vec($tlDEM,$tlcnt,8);        
				 # $demBlock=$demBlock.pack("C",$C);  
				 vec($demBlock,$cnt,8)=$C;
				 $cnt++;
				 $tlcnt++;
                         } 
			 foreach $i (0..255) {
				 $C=vec($trDEM,$trcnt,8);         
				 #$demBlock=$demBlock.pack("C",$C);
				 vec($demBlock,$cnt,8)=$C;
				 $cnt++;
				 $trcnt++;
			 }
        }
        foreach $j (0..255){
			 foreach $i (0..255) {
				 $C=vec($blDEM,($j*256+$i),8);         
				 #$demBlock=$demBlock.pack("C",$C);  
				 vec($demBlock,$cnt,8)=$C;
				 $cnt++;
			 } 
			 foreach $i (0..255) {
				 $C=vec($brDEM,($j*256+$i),8);         
				 # $demBlock=$demBlock.pack("C",$C); 
				 vec($demBlock,$cnt,8)=$C;
				 $cnt++;
			 }
        }


		 # now reduce the resolution
		 #
		 my $ij1;
		 my $ij2;
		 my $ij3;
		 my $ij4;
		 my $c1;
		 my $c2;
		 my $c3;
		 my $c4;
		 my $ipix=0;
		 my $jpix=0;
		 my $demBlock2='';
		 my $offset=0;
		 $j=0;
		 while ($j < $bigJ) {
			 $i=0;
			 #	 $ipix=0;
			 while ($i < $bigI) {
				 $ij1=($j)*$bigI+$i;
				 $ij2=($j+1)*$bigI+$i;
				 $ij3=($j)*$bigI+$i+1;
				 $ij4=($j+1)*$bigI+$i+1;
				 $c1=vec($demBlock,$ij1,8);         
				 $c2=vec($demBlock,$ij2,8);         
				 $c3=vec($demBlock,$ij3,8);         
				 $c4=vec($demBlock,$ij4,8);  
			         my $nc=0;
				 my $C=0;
				 if ($c1 > 0) { $nc++; $C=$C+$c1; }
				 if ($c2 > 0) { $nc++; $C=$C+$c2; }
				 if ($c3 > 0) { $nc++; $C=$C+$c3; }
				 if ($c4 > 0) { $nc++; $C=$C+$c4; }
                                 if ($nc > 0) {$C=int($C/$nc);} 				 
				 # $demBlock2=$demBlock2.pack("C",$C); 
				 vec($demBlock2,$offset,8)=$C;
				 $offset++;
				 # $ipix++;
				 $i=$i+2;
			 }
			 # $jpix++;
			 $j=$j+2;
		 }
		# print "offset is $offset\n";
		 $obj->{DEMBLOCK} [$index] = $demBlock2;
		 
		 $obj->_makePNG($index,256,256);

		 my $mama=$obj->{PARENT}[$index];
		 if (defined $mama) {
			 $obj->_bottomUp($mama);   # go back up
		 }else {
			 return
		 }
      }  # if allFour

      foreach my $kid (@kids) {
	   unless (defined $obj->{DEMBLOCK}[$kid]){
              $obj->_bottomUp($kid);
	   }
      }
}


#######################################################
# sub writeKMLOverlay() -  public method
#
# writes the kml for superoverlay
#######################################################
sub writeKMLOverlay{
	my $obj = shift;
	my ($descString)=@_;
	mkdir("$obj->{SETNAME}_Files");
	print "writing kml overlay\n";
	$obj->_writeKMLOverlay(0,1,$descString);    # index, depth - for top layer
}


#######################################################
# sub _writeKMLOverlay() -  private method actually does the work
#
#######################################################

sub _writeKMLOverlay{
	my ($obj, $index, $depth, $descString) = @_;
	return unless($obj->{NELEMS}[$index]);  # don't write kml for nodes that are empty
        
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
		$kmlFile = "$obj->{SETNAME}_Files/over$index.kml";}
         
      print "filename $kmlFile\n";

  # file beginning
  open FILE, ">$kmlFile" or die "can not open $kmlFile";
        print FILE '<?xml version="1.0" encoding="UTF-8"?>'."\n";
  print FILE '<kml xmlns="http://www.opengis.net/kml/2.2">'."\n";
  print FILE "   <Document>\n";

  # write kml for colorbar screen overlay if at top level doc.kml
  if ($index==0) {
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
      print FILE "       <name>colorbar</name>\n";
      print FILE "        <Icon>\n";
      print FILE '           <href>'."$obj->{SETNAME}_Files/colorbar.png</href>\n";
      print FILE "        </Icon>\n";
      print FILE "        <overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      print FILE "        <screenXY x=\"0.01\" y=\".99\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      print FILE "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      #print FILE "        <size x=\".5333333\" y=\"0.1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      print FILE "        <size x=\".6\" y=\"0.15\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
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
	print FILE "	  <GroundOverlay>\n";
	print FILE "	    <drawOrder>$depth</drawOrder>\n";
	print FILE "	    <Icon>\n";
        if ($index==0){
 	    print FILE "	      <href>$obj->{SETNAME}_Files/$obj->{SETNAME}_$index.png</href>\n";
        }else{
 	    print FILE "	      <href>$obj->{SETNAME}_$index.png</href>\n";
        }
	print FILE "	    </Icon>\n";
	print FILE "	    <LatLonBox>\n";
	print FILE "	       <north>$north</north>\n";
	print FILE "	       <south>$south</south>\n";
	print FILE "	       <east>$east</east>\n";
	print FILE "	       <west>$west</west>\n";
	print FILE "	    </LatLonBox>\n";
	print FILE "	  </GroundOverlay>\n";
     


	# network links to children
	if (@kids) {
	foreach my $kid (@kids) {

	   next unless($obj->{NELEMS}[$kid]);	# dont write the link for children that dont have elements in them
           
	   my $lnkName="over$kid.kml";
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
             print FILE "	      <href>$obj->{SETNAME}_Files/$lnkName</href>\n";
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
	   
           next unless($obj->{NELEMS}[$kid]);  # don't write kml for tree nodes with no elemets under them

	   $obj->_writeKMLOverlay($kid, $depth+1,$descString);
	
        }

           


}



##################################
# sub undefDEM - undefines the DEM block for each tree node
####################################
sub undefDEM {

	my $obj=shift;
	$obj->_undefDEM(0);
}


sub _undefDEM {
	my $obj=shift;
	my $index=shift;

	$obj->{DEMBLOCK}[$index]=undef;

	my @kids =  @{$obj->{CHILDREN}[$index]};

	return unless (@kids);

	foreach my  $kid (@kids) {
		$obj->_undefDEM($kid);
	}

}

####################################################
# sub makeColorDots()
#
# this subroutine makes a bunch of png files with color dots
#
################################################ 

sub makeColorDots {

  my $obj = shift;

 
  my $xpix=64;
  my $ypix=64;
  my $imid=$xpix/2;
  my $jmid=$ypix/2;

  my $color=128;
  my @colors;

  while ($color>0) {

     my $im = new GD::Image($xpix,$ypix);
     #   @colors = &setColors_jet($im);	 
#        @colors = &setColors_slfpae($im);	 
         @colors = &setColors($im,@{$obj->{COLORMAP}});
	
        my $i;
        my $j =  0;
        my $cnt = 0;	
	while ($j<$ypix) {        # loop draws a filled circle
	      $i=0;	
              while ($i<$xpix) {
                    my $r = sqrt(($i-$imid)**2 + ($j-$jmid)**2);
		     
		    if ($r<$imid) {
                       $im->setPixel($i,$j,$color);   #set the pixel color based on the map
	            }else{
                       $im->setPixel($i,$j,0);   #set the pixel color based on the map, zero is transparent
	            }
		  $i++;
	      }
	      $j++;
        }

        # now write the png file
        
	my $pngFile= "$obj->{SETNAME}_Files/dot_$color.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
        $im=undef;

	$color--;
  }

}




##########################################################################
##sub pointInPoly {  # $x $y \@px \@py    note: polygon described by vectors px,py must be closed 
#
#the subroutine will determine if a point ($x,$y) is in a polygon described by t
#############################################################
sub pointInPoly {  # $x $y \@px \@py    note: polygon described by vectors px,py must be closed 
   
   my $crs;
   my $inPoly=0;
	
   my $x = $_[0];
   my $y = $_[1];
   my @px = @{$_[2]}; # dereference to get arrays from argument
   my @py = @{$_[3]};
   
   my $nsegs=@px;

   my $wn=0;   # the winding number

   my $i=0;
   while ($i<$nsegs-1) {
        
     # test if at least one vertex is right of the point
     if ( ($px[$i] > $x) ||  ($px[$i+1] > $x) ) {

	 if (     ($py[$i] < $y) && ($py[$i+1] > $y) ) {  # this one crosses
            $crs= ($px[$i]-$x)*($py[$i+1]-$y) - ($px[$i+1]-$x)*($py[$i]-$y) ;
	    $wn++ if ($crs > 0) ; # upward cross on the right
         }elsif (($py[$i] > $y) && ($py[$i+1] < $y) ) {
            $crs= ($px[$i]-$x)*($py[$i+1]-$y) - ($px[$i+1]-$x)*($py[$i]-$y) ;
	    $wn-- if ($crs < 0); #downward cross on the right
         }
      }
      $i++;
   }
   $inPoly=1 if ($wn !=  0);

   return $inPoly;

}




#################################################################
# sub _makePNG() -  private method
#
# this subroutine makes a png file for a given node
#
#################################################################
sub _makePNG {
	my ($self,$index,$xpix,$ypix) = @_;
     
        my $numColors=13;  # the default	
	if (defined $self->{NUMCOLORS}) {
           $numColors=$self->{NUMCOLORS};
        }

        my $alpha=0;  # the default	
	if (defined $self->{ALPHA}) {
           $alpha=$self->{ALPHA};
        }
        
#	print  "8888 area = @{$self->{AREA}[$index]}\n";
#       my @imArea = @{$self->{AREA}[$index]};
#	my $xpix = $imArea[1]-$imArea[0] + 1;
#	my $ypix = $imArea[3]-$imArea[2] + 1;
	my $demBlock2 = $self->{DEMBLOCK}[$index];
	my @colors;
#	print "xpix,ypix  $xpix $ypix\n";

        my $im = new GD::Image($xpix,$ypix);
       # @colors = &setColors_jet($im)  if $self->{COLORMAP} eq "jet";	 
       # @colors = &setColors_slfpae($im)  if $self->{COLORMAP} eq "slfpae";	 
       # @colors = &setColors_diff($im)  if $self->{COLORMAP} eq "diff";	 
       # @colors = &setColors_marsh($im)  if $self->{COLORMAP} eq "marsh";	  
         @colors = &setColors($im,@{$self->{COLORMAP}},$alpha);	
        my $transparent=$colors[0];

        my $i;
        my $j =  0;
        my $cnt = 0;	
        my $C=0;
	while ($j<$ypix) {
	      $i=0;	
              while ($i<$xpix) {
                 $C=vec($demBlock2,$cnt,8);  # get the 8 bit integer from the big dem block
		  
                 $C= int((int($numColors*($C-1)/128)+0.5 )*128/$numColors)  unless ($C==0);
                 $C=128 if ($C > 128); 
		 $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map
		 $i++;
		 $cnt++;
              }
              $j++;
        }
#	print "cnt is $cnt\n";

        # now write the png file
	my $pngFile= "$self->{SETNAME}_Files/$self->{SETNAME}_$index.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
        $im=undef;

}

####################################################
# sub triInterp1 - interpolates a value on a plane 
# passing through the points @x,@y at the point xp,yp
#
#  this just computes the interpolant and returns the t and u values
sub triInterp1 {  # $xp $yp \@x \@y

   my $xp = $_[0];
   my $yp = $_[1];
   my @x = @{$_[2]}; # dereference to get arrays from argument
   my @y = @{$_[3]};

   my $xx1=$x[1]-$x[0];
   my $xx2=$x[2]-$x[0];
   my $yy1=$y[1]-$y[0];
   my $yy2=$y[2]-$y[0];
   my $xxp=$xp-$x[0];
   my $yyp=$yp-$y[0];

   my $det=$yy2*$xx1 - $xx2*$yy1;
   my $t=($xxp*$yy2 - $xx2*$yyp)/$det;
   my $u=($xx1*$yyp - $yy1*$xxp)/$det;

   return ($t, $u);
   # return my $vp= $z[0] + $t*($z[1]-$z[0]) + $u*($z[2]-$z[0]);

}

####################################################################
# sub triInterp2 () does the 2nd part using t and u and @ z as input
sub triInterp2 {  # $xp $yp \@x \@y
   
   # my $xp = $_[0];
   # my $yp = $_[1];
   # my @x = @{$_[2]}; # dereference to get arrays from argument
   #my @y = @{$_[3]};
   my $t=$_[0];
   my $u=$_[1];
   my @z = @{$_[2]};

   #my $xx1=$x[1]-$x[0];
   #my $xx2=$x[2]-$x[0];
   #my $yy1=$y[1]-$y[0];
   #my $yy2=$y[2]-$y[0];
   #my $xxp=$xp-$x[0];
   #my $yyp=$yp-$y[0];

   #my $det=$yy2*$xx1 - $xx2*$yy1;
   #my $t=($xxp*$yy2 - $xx2*$yyp)/$det;
   #my $u=($xx1*$yyp - $yy1*$xxp)/$det;
   foreach my $k (0..2){
      return -99999 if ($z[$k] < -99998);
   }
   return my $vp= $z[0] + $t*($z[1]-$z[0]) + $u*($z[2]-$z[0]);

}

#############################################################
# the whole triInterp function - not used
sub triInterp {  # $xp $yp \@x \@y \@z

   my $xp = $_[0];
   my $yp = $_[1];
   my @x = @{$_[2]}; # dereference to get arrays from argument
   my @y = @{$_[3]};
   my @z = @{$_[4]};

   my $xx1=$x[1]-$x[0];
   my $xx2=$x[2]-$x[0];
   my $yy1=$y[1]-$y[0];
   my $yy2=$y[2]-$y[0];
   my $xxp=$xp-$x[0];
   my $yyp=$yp-$y[0];

   my $det=$yy2*$xx1 - $xx2*$yy1;
   my $t=($xxp*$yy2 - $xx2*$yyp)/$det;
   my $u=($xx1*$yyp - $yy1*$xxp)/$det;

   return my $vp= $z[0] + $t*($z[1]-$z[0]) + $u*($z[2]-$z[0]);

}

      

#################################
sub locat_chk { # $x $y \@px \@py   

my  $XP=$_[0];
my  $YP=$_[1];
my  @X=@{$_[2]};
my  @Y=@{$_[3]};

# first check to see if we're exactly on one of the nodes
my $found=0;
 
foreach my $i (0..2){
   if ($XP == $X[$i]  and $YP == $Y[$i]){
      $found=1; 
      return $found;
   }  
}

my @DS1;
my @DS2;
my @DS3;

       $DS1[0]=$X[0]-$XP;
       $DS1[1]=$Y[0]-$YP;
       $DS2[0]=$X[1]-$XP;
       $DS2[1]=$Y[1]-$YP;

      my $c1=&cross(\@DS1,\@DS2); 
      if ( $c1 >= 0) {
              $DS3[0]=$X[2]-$XP;
              $DS3[1]=$Y[2]-$YP;
              my $c2=&cross(\@DS2,\@DS3); 
	      if ($c2 >=0 ) {
                      my $c3=&cross(\@DS3,\@DS1); 
		      if ($c3 >=0) {
		         $found=1;
	              }
              }
      }
      return $found;
}


##########################
sub cross { #@ds1, @ds2 # cross product of 2 2d vectors

my @ds1=@{$_[0]};
my @ds2=@{$_[1]};

my $cross= $ds1[0]*$ds2[1] - $ds1[1]*$ds2[0]; 

return $cross;

}





#######################################################
# $zValue = $tree->getZvalue(            # public method
#                    -ZDATA=>\@ZDATA,
#                    -XX=>$longitude,
#                    -YY=>$latitude,
#                 ) 
#   input is a hash
#
# interpolates values of @ZDATA at xx,yy
##############################################
sub getZvalue {
	my $obj=shift;
	my %args=@_;

	my $xx=$args{-XX};
	my $yy=$args{-YY};
        $obj->{ZVALUE}=undef;

        $obj->{ZDATA}=$args{-ZDATA} 	if ($args{-ZDATA});

	# try the last tree node first, before starting from the top of the tree
        if ($obj->{LASTINDEX} > 0) {         
            $obj->_getZvalue($obj->{LASTINDEX},1,$xx,$yy);
	    return $obj->{ZVALUE} if defined $obj->{ZVALUE};
        }

	# start from the top if we didn't get it above
        $obj->_getZvalue(0,1,$xx,$yy);  
	return $obj->{ZVALUE};
}

sub _getZvalue {
	my ($obj,$index,$depth,$xx,$yy)=@_;
	# print "getting index $index\n";
        my $zz=undef;
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
        	
 
	if ($yy <= $north) {    # check of lowest y is below north
         if ($yy >= $south) {    # if highest y is above south
          if ($xx >= $west)  {    # if highest x is right of west
	   if ($xx <= $east)  {    # if lowest x is left of east
 		   $inRegion=1;
		   #	 print "in Region\n";
		   
           }
	  }
	 }
	}	

        return unless ($inRegion);

        my @kids = @{$obj->{CHILDREN}[$index]};   

        if (@kids) {  #  this node has children, keep going
	  
          foreach my $kid (@kids) {

              $zz=$obj->_getZvalue($kid,$depth+1,$xx,$yy);

	  }
	  return;
	  
        }else{   # here if its a leaf node do the interpolation
	
	   # loop over elements
           my $cnt=$obj->{NELEMS}[$index];
          while ($cnt--) {
             my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);

             my $n1=vec($obj->{N1},$elem,32);
             my $n2=vec($obj->{N2},$elem,32);
             my $n3=vec($obj->{N3},$elem,32);

             my @x = ($obj->{XNODE}[ $n1 ],
                   $obj->{XNODE}[ $n2 ],
                   $obj->{XNODE}[ $n3 ] );
             my @y = ($obj->{YNODE}[ $n1 ],
                   $obj->{YNODE}[ $n2 ],
                   $obj->{YNODE}[ $n3 ] );

	   # print "X: @x\n";
	   # print "Y: @y\n";
	   # print "Z: @x\n";

            
             # check to see if this point in in the element
	     my $inPoly = &locat_chk($xx, $yy, \@x, \@y);
          
	     if ($inPoly) { 
		    
                my @z = ($obj->{ZDATA}[ $n1 ],  # get the zvalues need to dereference?
                         $obj->{ZDATA}[ $n2 ],
                         $obj->{ZDATA}[ $n3 ] );

	        $obj->{ZVALUE} = &triInterp($xx, $yy, \@x, \@y, \@z);
		$obj->{LASTINDEX}=$index;
		return;
             }
          }
      } #end if kids

}
	





#######################################################
# $findElement = $tree->findElement(            # public method
#                    -XX=>$longitude,
#                    -YY=>$latitude,
#                 ) 
#   returns the element number for the element 
#   the point is in, undef if it is not in the grid
# 
##############################################
sub findElement {
	my $obj=shift;
	my %args=@_;

	my $xx=$args{-XX};
	my $yy=$args{-YY};
        $obj->{MYELE}=undef;      

       	# try the last tree node first, before starting from the top of the tree
        if ($obj->{LASTINDEX} > 0) {         
            $obj->_findElement($obj->{LASTINDEX},1,$xx,$yy);
	    return $obj->{MYELE} if defined $obj->{MYELE};
        }

	# start from the top if we didn't get it above
        $obj->_findElement(0,1,$xx,$yy);  
	return $obj->{MYELE};
}

sub _findElement {
	my ($obj,$index,$depth,$xx,$yy)=@_;
	# print "getting index $index\n";
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
        	
 
	if ($yy <= $north) {    # check of lowest y is below north
         if ($yy >= $south) {    # if highest y is above south
          if ($xx >= $west)  {    # if highest x is right of west
	   if ($xx <= $east)  {    # if lowest x is left of east
 		   $inRegion=1;
		   #	 print "in Region\n";
		   
           }
	  }
	 }
	}	

        return unless ($inRegion);

        my @kids = @{$obj->{CHILDREN}[$index]};   
        if (@kids) {  #  this node has children, keep going
          foreach my $kid (@kids) {
              $obj->_findElement($kid,$depth+1,$xx,$yy);
	  }
	  return;
        }else{   # here if its a leaf node do the interpolation
	   # loop over elements
           my $cnt=$obj->{NELEMS}[$index];
          while ($cnt--) {
             my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);

             my $n1=vec($obj->{N1},$elem,32);
             my $n2=vec($obj->{N2},$elem,32);
             my $n3=vec($obj->{N3},$elem,32);

             my @x = ($obj->{XNODE}[ $n1 ],
                   $obj->{XNODE}[ $n2 ],
                   $obj->{XNODE}[ $n3 ] );
             my @y = ($obj->{YNODE}[ $n1 ],
                   $obj->{YNODE}[ $n2 ],
                   $obj->{YNODE}[ $n3 ] );

             # check to see if this point in in the element
	     my $inPoly = &locat_chk($xx, $yy, \@x, \@y);
             if ($inPoly) { 
	        $obj->{MYELE}=$elem;  	    
                return;
             }
          }
      } #end if kids

}







#######################################################
# $findElements = $tree->findElements(            # public method
#                    -XX=>$longitude,
#                    -YY=>$latitude,
#                    -RADIUS=>$radius   # search radius to look in
#                 ) 
#   returns the element number for the element 
#   the point is in, undef if it is not in the grid
# 
##############################################
sub findElements {
	my $obj=shift;
	my %args=@_;

	my $xx=$args{-XX};
	my $yy=$args{-YY};
        my $radius=$args{-RADIUS};
        $obj->{MYELES}=[];      


	# start from the top if we didn't get it above
        $obj->_findElements(0,1,$xx,$yy,$radius);  
	return $obj->{MYELES};
}

sub _findElements {
	my ($obj,$index,$depth,$xx,$yy,$radius)=@_;
	# print "getting index $index\n";
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
        my $rsq=$radius*$radius;	
        #check each corner to see if any are in the circle 
        my @PX1=($west, $east, $east, $west);
        my @PY1=($south, $south, $north, $north);
        my @PX2=($xx-$radius, $xx+$radius, $xx+$radius, $xx-$radius);
        my @PY2=($yy-$radius, $yy-$radius, $yy+$radius, $yy+$radius);

        # check if the points of the search box are in the node
        foreach my $n (0..3){
           $inRegion=pointInPoly($PX2[$n],$PY2[$n],\@PX1,\@PY1);
           last if ($inRegion);
        }
        # check if the node coorners are in the search box
        unless ($inRegion){
          foreach my $n (0..3){
             $inRegion=pointInPoly($PX1[$n],$PY1[$n],\@PX2,\@PY2);
             last if ($inRegion);
          }
        }   
        return unless ($inRegion);


        my @kids = @{$obj->{CHILDREN}[$index]};   
        if (@kids) {  #  this node has children, keep going
          foreach my $kid (@kids) {
              $obj->_findElements($kid,$depth+1,$xx,$yy,$radius);
	  }
	  return;
        }else{   # here if its a leaf node do the interpolation
	   # loop over elements
           my $cnt=$obj->{NELEMS}[$index];
          while ($cnt--) {
             my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);

             my $n1=vec($obj->{N1},$elem,32);
             my $n2=vec($obj->{N2},$elem,32);
             my $n3=vec($obj->{N3},$elem,32);
             
             #skip element if all nodes are outside the search box
             next if ( ($obj->{XNODE}[$n1] < $xx - $radius) and
                       ($obj->{XNODE}[$n2] < $xx - $radius) and
                       ($obj->{XNODE}[$n3] < $xx - $radius) );

             next if ( ($obj->{XNODE}[$n1] > $xx + $radius) and
                       ($obj->{XNODE}[$n2] > $xx + $radius) and
                       ($obj->{XNODE}[$n3] > $xx + $radius) );

             next if ( ($obj->{YNODE}[$n1] < $yy - $radius) and
                       ($obj->{YNODE}[$n2] < $yy - $radius) and
                       ($obj->{YNODE}[$n3] < $yy - $radius) );

             next if ( ($obj->{YNODE}[$n1] > $yy + $radius) and
                       ($obj->{YNODE}[$n2] > $yy + $radius) and
                       ($obj->{YNODE}[$n3] > $yy + $radius) );
             

             # check to see if any of the nodes are in the search radius
             my $ds=($obj->{XNODE}[$n1]-$xx)**2.0 + ($obj->{YNODE}[$n1]-$yy)**2.0;
             if ($ds <= $rsq){
                 push @{$obj->{MYELES}},$elem; 
                 next;
             }
             $ds=($obj->{XNODE}[$n2]-$xx)**2.0 + ($obj->{YNODE}[$n2]-$yy)**2.0;
             if ($ds <= $rsq){
                 push @{$obj->{MYELES}},$elem; 
                 next;
             }
             $ds=($obj->{XNODE}[$n3]-$xx)**2.0 + ($obj->{YNODE}[$n3]-$yy)**2.0;
             if ($ds <= $rsq){
                 push @{$obj->{MYELES}},$elem; 
                 next;
             }
          }
      } #end if kids

}









#################################################################
# sub makeColorbar($title)
#
# this subroutine makes a png with the colorbar
#
#################################################################
sub makeColorbar {
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
   my @colors = &setColors($im,@{$self->{COLORMAP}},0);

   my $black= $colors[130];
   my $white= $colors[129];

   my $i;
   my $j;
   my $cnt = 0;
   my $dClim=$self->{CLIM2}-$self->{CLIM1};
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
          
         # $C= ($c-$self->{CLIM1})/$dzdc+1;       
         my $C= int((int($numColors*($C1-1)/128)+0.5 )*128/$numColors)  unless ($C1==0);
          $C=128 if ($C > 128); 
#bpj added:
#          $C=253 if ($C > 253); 
          $im->setPixel($i,$j,$colors[$C]);   #set the pixel color based on the map

       }      
   
   
   }
   
   # add the title

   $im->string(gdGiantFont,40,5,$title,$black);
    #my $label1= GD::Text::Align->new($im, valign => 'center', halign => 'center');
    #   $label1->set_font('arial',30);
    #   $label1->set_text("$title");
    #   $label1->set(color => $black);
    #   $label1->draw(250,10 , 0);
   
   # ticks on the bottom x-axis (speed)
      my $dx=$xWidth/$numColors;
      
      $dx=$xWidth/20 if $numColors > 20;  # just to keep ticks from crowding eachother
#bpj from old scale      $dx=$xWidth/11 if $numColors > 13;  # just to keep ticks from crowding eachother
      
      
      
      my $x=$xMarg;
      my $x2=$xMarg+$xWidth;
      my $ytmp=$ypix-$yMarg;

      while ($x<=$x2){

        my $intx=int($x);
        #$x++ if ($x-$intx > 0.5);
        foreach my $y ($ytmp-5 .. $ytmp+5) {              # tick marks
              $im->setPixel($intx,$y,$black);
              $im->setPixel($intx+1,$y,$black);
        } 
        
        my $dtmp = $self->{CLIM1} + ($x - $xMarg)*$dClim/$xWidth;
        
#bpj        my $tickLabel=sprintf("%4.1f",$dtmp);
#bpj added:
        my $tickLabel=sprintf("%.3g",$dtmp);
#        $im->string(gdMediumBoldFont,$x-5,$ytmp+6,$tickLabel,$black);:w

# BPJ change x offset
        $im->string(gdMediumBoldFont,$x-11,$ytmp+6,$tickLabel,$black);
        $x=$x+$dx;
      } 
   
   
   
   
   
   
  # now write the png file
  my $pngFile= "$self->{SETNAME}_Files/colorbar.png";
  open FILE2, ">$pngFile";
  binmode FILE2;
  print FILE2 $im->png;
  close(FILE2);
        $im=undef;

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



#################################################################
# sub loadColormap($cmapFile)
#
# reads a colormap from a file and sets the colormap scale and
# r,g,b arrays for the ElementQuadtree object {COLORMAP}, 
# which can later be used by setColors to set the colors for 
# images
#
#################################################################
sub loadColormap {

   my $obj=shift;
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

   $obj->{COLORMAP}=$colormap;
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


########################## incase you are reading in from stgorable	
sub setXYZ {
      my ($obj,%args)=@_;

      $obj->{XNODE}   = $args{-XNODE};         # references to arrays of nodal positions
      $obj->{YNODE}   = $args{-YNODE};
      $obj->{ZNODE}   = $args{-ZNODE};
      $obj->{ZDATA}   = $args{-ZDATA};
      $obj->{LASTINDEX} = 0;
      

}


############################################################
# sub store_tree($treeFile)
#
# uses Storable module to store tree in a file
#
# e.g. $tree->store_tree($treeFile) 
# 
############################################################
sub store_tree{
      my $obj=shift;
      my $treeFile=shift;

      # actually put the nodal positions into object instead of just references 
      my @X=@{$obj->{XNODE}};
      my @Y=@{$obj->{YNODE}};
      my @Z=@{$obj->{ZNODE}};

      # store it in a packed string to save space
      my $xyz='1234567890122345678901234';

      foreach my $i (0..$#X){     
           my $packed=pack("d3",$X[$i],$Y[$i],$Z[$i]); # should be 24 bytes ling
           my $offset=$i*24; # there will be nothing valuable at offset 0
           substr ($xyz,$offset,24,$packed); 
       }

       $obj->{XYZ}=$xyz;
       $obj->{NUMNODES}=$#X;

       store $obj, "$treeFile";

}

############################################################
# sub retrieve_tree($treeFile)
#
# uses Storable module to store tree in a file
#
# e.g. $tree = ElementQuadTree->retrieve_tree($treeFile) 
# 
############################################################
sub retrieve_tree {
   my $self = shift;
   my $class = ref($self) || $self;
   my $obj = bless {} => $class;
   
   my $treeFile=shift;
   
   $obj = retrieve ($treeFile);
  
   # unpack the xyz data
   my $xyz =  $obj->{XYZ};
   my $nn = $obj->{NUMNODES};
   my @X;
   my @Y;
   my @Z;  

   foreach my $i (0..$nn) {
       my $offset =  $i*24;
       my $packed = substr($xyz,$offset,24);
       my ($x,$y,$z)=unpack("d3",$packed);
       push @X, $x;
       push @Y, $y;
       push @Z, $z;
   }

   
   $obj->{XNODE}   = \@X;         
   $obj->{YNODE}   = \@Y;
   $obj->{ZNODE}   = \@Z;
   $obj->{ZDATA}   = \@Z;


   $obj->{LASTINDEX} = 0; 


   return $obj;
}

   
##############################################################################
# sub getInterpolant
#
# $interpolant = $tree->getInterpolant(               # public method
#                                     -XX=>$longitude,
#                                     -YY=>$latitude,
#                 ) 
#   input is a hash
#
#   returns a reference to an array of interpolant data for the input location 
#   undef if the point is outside the grid or tree region
#   use the returned reference as input interpValue to get the interpolated
#   value from the grid. this uses triInterp1, interpValue uses triInterp2
###############################################################################
sub getInterpolant {
	my $obj=shift;
	my %args=@_;

	my $xx=$args{-XX};
	my $yy=$args{-YY};
        
        $obj->{INTERPOLANT}=undef;

	# try the last tree node first, before starting from the top of the tree
        if ($obj->{LASTINDEX} > 0) {         
            $obj->_getInterpolant($obj->{LASTINDEX},1,$xx,$yy);
	    return $obj->{INTERPOLANT} if defined $obj->{INTERPOLANT};
        }

	# start from the top if we didn't get it above
        $obj->_getInterpolant(0,1,$xx,$yy);  
	return $obj->{INTERPOLANT};
}

sub _getInterpolant {
	my ($obj,$index,$depth,$xx,$yy)=@_;
	# print "getting index $index\n";
        my $zz=undef;
	my $inRegion=0;
	my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
        	
 
	if ($yy <= $north) {    # check of lowest y is below north
         if ($yy >= $south) {    # if highest y is above south
          if ($xx >= $west)  {    # if highest x is right of west
	   if ($xx <= $east)  {    # if lowest x is left of east
 		   $inRegion=1;
		   #	 print "in Region\n";
		   
           }
	  }
	 }
	}	

        return unless ($inRegion);

        my @kids = @{$obj->{CHILDREN}[$index]};   

        if (@kids) {  #  this node has children, keep going
	  
          foreach my $kid (@kids) {

              $zz=$obj->_getInterpolant($kid,$depth+1,$xx,$yy);

	  }
	  return;
	  
        }else{   # here if its a leaf node do the interpolation
	
	   # loop over elements
           my $cnt=$obj->{NELEMS}[$index];
          while ($cnt--) {
             my $elem=vec($obj->{ELEMIDS}[$index],$cnt,32);

             my $n1=vec($obj->{N1},$elem,32);
             my $n2=vec($obj->{N2},$elem,32);
             my $n3=vec($obj->{N3},$elem,32);

             my @x = ($obj->{XNODE}[ $n1 ],
                   $obj->{XNODE}[ $n2 ],
                   $obj->{XNODE}[ $n3 ] );
             my @y = ($obj->{YNODE}[ $n1 ],
                   $obj->{YNODE}[ $n2 ],
                   $obj->{YNODE}[ $n3 ] );

	   # print "X: @x\n";
	   # print "Y: @y\n";
	   # print "Z: @x\n";

            
             # check to see if this point in in the element
	     my $inPoly = &locat_chk($xx, $yy, \@x, \@y);
          
	     if ($inPoly) { 
		    
                my ($t,$u) = &triInterp1($xx, $yy, \@x, \@y);
		$obj->{LASTINDEX}=$index;
		return $obj->{INTERPOLANT}=[$elem, $t, $u];
             }
          }
      } #end if kids

}



###################################################################
# sub interpValue
#
#  my $z = $obj->interpValue( 
#                              -ZDATA => \@ZDATA,
#                              -INTERPOLANT => $interpolant ) # a ref returned by getInterpolant
#
#
#################################################################### 
sub interpValue{

   my $obj=shift;
   my %args=@_;

#print "fron interp value args \n";
#foreach my $key (keys %args){
#   print "key $key ,  $args{$key}\n";
#}

 
   $obj->{ZDATA}=$args{-ZDATA} 	if ($args{-ZDATA});
   $obj->{INTERPOLANT}=$args{-INTERPOLANT} 	if ($args{-INTERPOLANT});

   my ($elem, $t, $u) = @{$obj->{INTERPOLANT}};

   my $n1=vec($obj->{N1},$elem,32);
   my $n2=vec($obj->{N2},$elem,32);
   my $n3=vec($obj->{N3},$elem,32);

   my @z = ($obj->{ZDATA}[ $n1 ],
             $obj->{ZDATA}[ $n2 ],
             $obj->{ZDATA}[ $n3 ] );
   
   my $zz=&triInterp2($t,$u,\@z);
   return $zz;
}

1;
