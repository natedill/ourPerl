package PointTree;
#
# An OO perl package for streaming and working with 2D point data in
# a quadtree structure
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
use Storable;
use GD;

#####################################################################
# constructor: create a new PointTree object
# 
# $tree=PointTree->new(
#                   -NORTH=>$north,
#                   -SOUTH=>$south,
#                   -EAST=>$east,
#                   -WEST=>$west,
#                   -MINDY=>$mindy  # the nominal size for leaf nodes
#                   )
#                   
# 
#
#####################################################################
sub new
{
     my $class = shift;
     my %args = @_;
     my $self = {}; # the object is a hash

     my $north=$args{-NORTH};
     my $south=$args{-SOUTH};
     my $east=$args{-EAST};
     my $west=$args{-WEST};
     
     # make the region a square (in degrees) for good measure
     my $dy=$north-$south;
     my $dx=$east-$west;
     if ($dy > $dx) {  # tall and thin, make it wider
         $east=$west+$dy;
     }else{            # short and fat, make it taller
	 $north=$south+$dx;
     }	 

     # set data for top level (index=0)
     $self->{MINDY}=$args{-MINDY};
     $self->{LASTINDX}=0;
     $self->{DECREMENTED}=0;   
     $self->{POINTCOUNTED}=0;
     $self->{REGION}[0]=[$north,$south,$east,$west];
     $self->{PARENT}[0]=undef;
     $self->{CHILDREN}[0]=[];
     $self->{NPOINTS}[0]=0;
     $self->{INTREE}[0]=1;
     $self->{MAXINDX}=0;  # to keep track of the maximum indexA
     $self->{LEAFDY}=$self->{MINDY};  # will be set to the actual dy
     $self->{MINZ}=undef;
     $self->{MAXZ}=undef;

     $self->{PNTPACKSTR}='d3n';
     $self->{PNTBUFBYTES}=26;
     if ($args{-IDBITS} == 32){
        $self->{PNTPACKSTR}='d3N';
        $self->{PNTBUFBYTES}=28;
     }


     bless $self, $class;
     return $self;
      
}

##################################################################
#  sub loadTree
#
#  a constructor to load an existing tree 
#     (uses storable's retrieve method)
#
#  e.g.  
#       my $tree=PointTree->loadTree('treefile.tree')
#
#
##################################################################


sub loadTree {
    my $class=shift;
    my $treeFile=shift;
    my $self=retrieve($treeFile);
    bless $self, $class;
    return $self;
}

#################################################################
#  sub storeTree
#
#  store a tree to a file using Storable
#
#  e.g.
#
#     $tree->storeTree('treeFile.tree');
#
#################################################################

sub storeTree {
    my $obj=shift;
    my $treeFile=shift;
    store $obj, $treeFile;
}



#########################################################
# sub countPoint ()
#
# public method for counting points in the tree nodes
#
#
#  $indx = $tree->countPoint (
#                   $xp,   # longitude of the point
#                   $yp,   # latitude of the point
#                 )
#
#  returns the index of the leaf node where the point was found
#  or undef if the point is outside the tree 
#
###############################################################

sub countPoint {
	my $obj=shift;
	my ($x,$y)=@_;
        # in case point is not in the tree 
     	my ($north, $south, $east, $west) = @{$obj->{REGION}[0]};
        return undef unless ($y <= $north);
        return undef unless ($y >= $south);
        return undef unless ($x >= $west);
        return undef unless ($x <= $east);



	my $recurseDepth=0;
	my $index=$obj->{LASTINDX};

        $obj->{POINTCOUNTED}=0;

        # check the last index that found a point first
        $obj->_countPoint ($x,$y,$recurseDepth,$index);
        return $index=$obj->{LASTINDX} if ($obj->{POINTCOUNTED});

	# if not found in the last index recurse up the 
	# tree checking the parent/siblings, grandparents/cousins ... 
	while (defined $index) {
	    $index=$obj->{PARENT}[$index];
	    $obj->_countPoint ($x,$y,$recurseDepth,$index);
            return $index=$obj->{LASTINDX} if ($obj->{POINTCOUNTED});
        }

}


#####################################################
# sub _countPoint()
#
# this private method recursed down the tree till it 
# hits a leaf, creating nodes as it goes if necessary.
# it also keeps a tally of the number of points in each
# leaf.
#
#
#####################################################

sub _countPoint{
       my $obj = shift;
       return if ($obj->{POINTCOUNTED});

       my ($x,$y,$recurseDepth,$index) = @_;
       $recurseDepth++;
      
       my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

       return unless ($y <= $north);
       return unless ($y >= $south);
       return unless ($x >= $west);
       return unless ($x <= $east);

       # check if this is a leaf node
       my $dy=$north-$south;
       if ($dy <= $obj->{MINDY}) {    # this is a leaf node, count this point
            
             $obj->{LEAFDY}=$dy if ( $dy < $obj->{LEAFDY});
                       
             $obj->{NPOINTS}[$index]++;
	     $obj->{LASTINDX}=$index;
	     $obj->{POINTCOUNTED}=1;
	     return;

	     
       }else{                         # this is not a leaf node, keep going

            unless (defined $obj->{CHILDREN}[$index][0]) {  # checking if array referenced by $obj->{CHILDREN} has zero length
                $obj->_divideRegion($recurseDepth,$index);  # if so we need to create children for it
            }

	    foreach  my $child ( @{$obj->{CHILDREN}[$index]} ) {  # loop through the children counting points
                  $obj->_countPoint($x,$y,$recurseDepth,$child)
            }
   
       }

}


#####################################################
# sub _divideRegion()
#
# this private method divides a node into 4 children
#
#####################################################


sub _divideRegion {
	my $obj = shift;
        my ($recurseDepth,$parent) = @_;
        my ($north, $south, $east, $west) = @{$obj->{REGION}[$parent]};

       print "dividing region - index: $parent, depth: $recurseDepth\n";
#	print "region: $north $south $east $west\n";

       $recurseDepth++;
	
	my $ew =  ($east + $west)/2.0;
	my $ns =  ($north + $south)/2.0;

        # northwest
	#my $indx=4*$parent+1;
        $obj->{MAXINDX}++;
        my $indx=$obj->{MAXINDX};
	 $obj->{REGION}   [$indx] = [$north, $ns, $ew, $west];
         $obj->{PARENT}   [$indx] = $parent;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
	 $obj->{INTREE}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$parent]}, $indx);
	
        # northeast
        #$indx=4*$parent+2;
        $obj->{MAXINDX}++;
         $indx=$obj->{MAXINDX};
	 $obj->{REGION}   [$indx] = [$north, $ns, $east, $ew];
         $obj->{PARENT}   [$indx] = $parent;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
	 $obj->{INTREE}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$parent]}, $indx);

        # southeast
	#$indx=4*$parent+3;
        $obj->{MAXINDX}++;
         $indx=$obj->{MAXINDX};
	 $obj->{REGION}   [$indx] = [$ns, $south, $east, $ew];
         $obj->{PARENT}   [$indx] = $parent;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
	 $obj->{INTREE}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$parent]}, $indx);

        # southwest
	#$indx=4*$parent+4;
        $obj->{MAXINDX}++;
         $indx=$obj->{MAXINDX};
	 $obj->{REGION}   [$indx] = [$ns, $south, $ew, $west];
         $obj->{PARENT}   [$indx] = $parent;
         $obj->{CHILDREN} [$indx] = [];
         $obj->{NPOINTS}  [$indx] = 0;
	 $obj->{INTREE}   [$indx] = 0;
         push (@{$obj->{CHILDREN}[$parent]}, $indx);
}





#####################################################
# sub reportCount()
#
# this method prints out the count recursively
#
#
#####################################################
sub reportCount {
	my $obj=shift;
        my $reportFile=shift;
    


        my $file;
        if (defined $reportFile){
           print "writing count report to $reportFile\n";
           open $file, ">$reportFile" or die "cant open $reportFile\n";
        }

        my $recurseDepth=0;
	my $index=0;

        $obj->_reportCount($recurseDepth,$index,$file) ;
      
        close ($file) if (defined $reportFile);
}

sub _reportCount {
	my $obj=shift;
	my ($recurseDepth,$index,$file)=@_;

        unless (defined $file){
	   print "index,depth,count : $index, $recurseDepth, $obj->{NPOINTS}[$index]\n";
        }else{ 
           print $file "$index, $recurseDepth, $obj->{NPOINTS}[$index]\n";
        }

        $recurseDepth++;
        
	foreach  my $child ( @{$obj->{CHILDREN}[$index]} ) {  # loop through the children
		    $obj->_reportCount($recurseDepth,$child,$file)
            }
}


########################################################
# sub decrementPoint ()
#
# public method for decrementing points in the tree nodes
# return the index of the leaf node when the final point 
# in that node has been decremented, otherwise returns 0 
# if there are more points to be decremented, or -1 if the
# point is not within the region of the tree's root.
#
# input is a hash e.g.
#
# $lastIndex=$tree->decrementPoint (
#                   $xp,   # longitude of the point
#                   $yp,   # latitude of the point
#                 )
#
###############################################################

sub decrementPoint {
	my $obj=shift;
	my ($x,$y)=@_;
        
        # in case point is not in the tree 
     	my ($north, $south, $east, $west) = @{$obj->{REGION}[0]};
        return -1 unless ($y <= $north);
        return -1 unless ($y >= $south);
        return -1 unless ($x >= $west);
        return -1 unless ($x <= $east);

	my $recurseDepth=0;
	my $index=$obj->{LASTINDX};

        $obj->{POINTCOUNTED}=0;
	$obj->{DECREMENTED}=0;   # will hold the index of the leaf node
	                       # as soon as it is fully decremented
 
        # check the last index that found a point first
        $obj->_decrementPoint ($x,$y,$recurseDepth,$index);
        return $obj->{DECREMENTED} if ($obj->{POINTCOUNTED});

	# if not found in the last index recurse up the 
	# tree checking the parent/siblings, grandparents/cousins ... 
	while (defined $index) {
	    $index=$obj->{PARENT}[$index];
	    $obj->_decrementPoint ($x,$y,$recurseDepth,$index);
            return $obj->{DECREMENTED} if ($obj->{POINTCOUNTED});
        }

}


#####################################################
# sub _decrementPoint()
#
# decrement the points in the leaf nodes, return the
# inde
#
#
#####################################################

sub _decrementPoint{
        
       my $obj = shift;
       return if ($obj->{POINTCOUNTED});

       my ($x,$y,$recurseDepth,$index) = @_;

       my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

       return unless ($y <= $north);
       return unless ($y >= $south);
       return unless ($x >= $west);
       return unless ($x <= $east);

       $obj->{INTREE}[$index]=1;

       # check if this is a leaf node
       my $dy=$north-$south;
       if ($dy <= $obj->{MINDY}) {    # this is a leaf node, decrement this index

             $obj->{NPOINTS}[$index]--;
	     $obj->{LASTINDX}=$index;
	     $obj->{POINTCOUNTED}=1;
	     $obj->{DECREMENTED}=$index if ($obj->{NPOINTS}[$index]==0); # set this index as fully decremented if this is the last  point
	  #   print "decremented $index\n" if ($obj->{NPOINTS}[$index]==0);
	     return;

	     
       }else{                         # this is not a leaf node, keep going


	    $recurseDepth++;
	    foreach  my $child ( @{$obj->{CHILDREN}[$index]} ) {  # loop through the children decrementing points
		    $obj->_decrementPoint($x,$y,$recurseDepth,$child)
            }
   
       }

}




#####################################################
# sub setPixel($x,$y,$z,$index)
#
# finds pixel indices for
# this point, increments the number of points per
# pixel, and adds on to the total pixel value.
# I.e. pixel values will ultimately be the average 
# elevation of all points that are within that pixel
#
# this name should probably be changed to avoid
# confusion with "setPixel" method in the GD module
####################################################
sub setPixel {

     my $obj=shift;
     my ($x,$y,$z,$index)=@_;
     
     return unless( defined $index );

     my $npix=256;
     
     #   unless (defined $obj->{ZDATA}[$index]) { 
     #   $obj->{ZDATA}[$index]=[];
     #   $obj->{ZCNT}[$index]=[];
     # }

     # find the pixel this point is in
     my ($north,$south,$east,$west)=@{$obj->{REGION}[$index]};
     my $dy = $north - $south;
     #my $dx = $east - $west; dx and dy are the same
     my $djdy= $npix/$dy;

    
     my $i = int(($x-$west)*$djdy);
     my $j = int(($north-$y)*$djdy);

     #print "x west $x $west\n";

     $i=255 if $i>255;
     $j=255 if $j>255;

     my $offset=$j*$npix+$i;
    
     unless (defined ${$obj->{ZDATA}[$index]}[$offset]) {
          ${$obj->{ZDATA}[$index]}[$offset]=0;
          ${$obj->{ZCNT}[$index]}[$offset]=0;
     }

     ${$obj->{ZDATA}[$index]}[$offset]=${$obj->{ZDATA}[$index]}[$offset] + $z;
     ${$obj->{ZCNT}[$index]}[$offset]++;

     #print "ijoff $i $j $offset\n";
     #print "z z(off) $z  ${$obj->{ZDATA}[$index]}[$offset]  ${$obj->{ZCNT}[$index]}[$offset]\n";
     # sleep (10);
}

     

#################################################################
# sub makePNG() -  
#
# this subroutine makes a png file for a given node
#
#################################################################
sub makePNG {
	my $obj = shift;
        my $index=shift;
        my $pngDir=$obj->{PNGDIR};
        my $clim1=$obj->{CLIM1};
        my $clim2=$obj->{CLIM2};
	my $crng=$clim2-$clim1;
        my $numColors=$obj->{NUMCOLORS};
	my @Zdata=@{$obj->{ZDATA}[$index]};
	my @Zcnt=@{$obj->{ZCNT}[$index]};

        my $im = new GD::Image(256,256);
   
        my @colors=&setColors($im,@{$obj->{COLORMAP}});  
        my $transparent=$colors[0];	


        my $j=256;
	while ($j--) {
            my $i=256;
	      while ($i--) {
                 my $offset=$j*256+$i;
		 if (defined $Zcnt[$offset]) {
                      my $avgZ=$Zdata[$offset]/$Zcnt[$offset];
		      my $Cint= int(127*($avgZ-$clim1)/$crng)+1;
                         $Cint=1 if $Cint<1; 
	                 $Cint=128 if $Cint>128;
                         my $C= int(   (  int($numColors*($Cint-1)/128)+0.5 )*128/$numColors);
			 # print "$i, $j, cint c : $avgZ $Cint $C\n";
                         $im->setPixel($i,$j,$colors[$C]);
                 }else{ # set it transparent
		      $im->setPixel($i,$j,$transparent);  
                 }
	         	 
	      }
        }
        # now write the png file
	my $pngFile= "$pngDir/$index.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
	# undef $im;
	undef @{$obj->{ZDATA}[$index]};
	undef @{$obj->{ZCNT}[$index]};
	undef @colors;
	undef @Zcnt;
	undef @Zdata;

}

################################################################
# sub makePNGs
#
# public sub to make all the png files 
#
#  e.g.   
#       $tree->makePNGs(
#                 -COLORFILE=>$colorFile,   # file containing the color map data
#                 -CLIM1=>$CLIM[0],         # lower limit of elevation for colormap
#                 -CLIM2=>$CLIM[1],         # upper limit of elevation for colormap
#                 -NUMCOLORS=>$numColors,   # number of colors in color bar
#                 -ZMULTADJUST=>$MultAdjust,  # multiply by z value prior to applying color map
#                 -ZADDADJUST=>$addAdjust,  # add to z value prior to applying color map, after multiply adjust
#                 -PNGDIR=>$pngDir          # directory to hold the png files (and reference them in kml
#                );  
#
##################################################################
sub makePNGs{
    my $obj=shift;
    my %args=@_;

    my $clim1;
    my $clim2;
    my $pngDir='Files';
    my $numColors=16;
    my $zMultAdjust=1.0;
    my $zAddAdjust=0.0;
    my $colorFile='';

    if (defined $args{-CLIM1}){    
       $clim1=$args{-CLIM1};
    }else{
       $clim1=$obj->{MINZ};
    }
    if (defined $args{-CLIM2}){    
       $clim2=$args{-CLIM2};
    }else{
       $clim2=$obj->{MAXZ};
    }        
    $pngDir=$args{-PNGDIR} if defined $args{-PNGDIR};
    $numColors=$args{-NUMCOLORS} if defined $args{-NUMCOLORS};
    $zAddAdjust=$args{-ZADDADJUST} if defined $args{-ZADDADJUST};
    $zMultAdjust=$args{-ZMULTADJUST} if defined $args{-ZMULTADJUST}; 
    $colorFile=$args{-COLORFILE} if defined $args{-COLORFILE};

    $obj->{CLIM1}=$clim1;
    $obj->{CLIM2}=$clim2;
    $obj->{PNGDIR}=$pngDir;
    $obj->{NUMCOLORS}=$numColors;

    mkdir ("$pngDir");

    $obj->loadColormap($colorFile);

    my $superfinalized;
   
    # make the leaf node png files
    # open a fialized file
    if (defined $obj->{SFINALIZED}){
        print "making PNGs using superfinalized file $obj->{SFINALIZED} \n";
        open FH, "<$obj->{SFINALIZED}" or die "PointTree::makePNGs can not open $obj->{SFINALIZED}\n";
        $superfinalized=1;
    }elsif (defined $obj->{FINALIZED}){
        print "making PNGs using finalized file $obj->{FINALIZED}\n";
        open FH, "<$obj->{SFINALIZED}" or die "PointTree::makePNGs can not open $obj->{FINALIZED}\n";
        $superfinalized=0;
    }else{
        die "no finalized of super-finalized binary points file has been assigned to the tree\n";
    }
    binmode(FH);
    if ($superfinalized){  # for a file with index and offset pre-tags
        $/=\8;
        while (<FH>){
           my ($index,$npts)=unpack("L2",$_);
           $/=\$obj->{PNTBUFBYTES};
           while ($npts--){
               my $buf=<FH>;
               my ($x,$y,$z,$id)=unpack($obj->{PNTPACKSTR},$buf);
               $z=$z*$zMultAdjust + $zAddAdjust; 
               $obj->setPixel($x,$y,$z,$index);
           }
           print "making PNG $index\n";
           $obj->makePNG($index);
           $/=\8;
        }
    }else{           # for a file with finalizaton tags
       $/=\$obj->{PNTBUFBYTES};;
       while (<FH>){ 
          my ($x,$y,$z,$id)=unpack($obj->{PNTPACKSTR},$_);
          if ($x==-999999) {
            #  my $finishMe=$z;
              print "finishing $z\n";
              $obj->makePNG($z);
          }else{
             my $index=$obj->countPoint($x,$y);
             $z=$z*$zMultAdjust + $zAddAdjust; 
             $obj->setPixel($x,$y,$z,$index);
          }
       }
    }
    close(FH);

    $obj->_bottomUp(0,$obj->{COLORMAP});  # this should write the rest of the png file
    $/="\n";

}




#######################################################
# sub writeKMLOverlay() -  public method
#
# writes the kml for superoverlay
#######################################################
sub writeKMLOverlay{
	my $obj = shift;
	my %args=@_;
        my $kmlDir=$args{-KMLDIR};
        $obj->{KMLDIR}=$kmlDir;
	
        mkdir("$kmlDir");
	print "writing kml overlay\n";
	$obj->_writeKMLOverlay(0,1);    # index, depth - for top layer

}


#######################################################
# sub _writeKMLOverlay() -  private method actually does the work
#
#######################################################

sub _writeKMLOverlay{
	my ($obj, $index, $depth) = @_;
	return unless($obj->{INTREE});  # don't write kml for nodes that are empty
       
        my $kmlDir=$obj->{KMLDIR};
        my $pngDir=$obj->{PNGDIR};
 
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
		$kmlFile = "$kmlDir/over$index.kml";}
         
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
         print FILE "       <name>colograr</name>\n";
         print FILE "        <Icon>\n";
         print FILE "           <href>$pngDir/colorbar.png</href>\n";
         print FILE "        </Icon>\n";
         print FILE "        <overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
         print FILE "        <screenXY x=\"0.01\" y=\".99\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
         print FILE "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
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
 	    print FILE "	      <href>$pngDir/$index.png</href>\n";
        }else{
 	    print FILE "	      <href>../$pngDir/$index.png</href>\n";
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

	   next unless($obj->{INTREE}[$kid]);	# dont write the link for children that dont have elements in them
           
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
             print FILE "	      <href>$kmlDir/$lnkName</href>\n";
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
	   
           next unless($obj->{INTREE}[$kid]);  # don't write kml for tree nodes with no elemets under them

	   $obj->_writeKMLOverlay($kid, $depth+1);
	
        }

           
      
     
}





#######################################################
# sub writeKMLPoints(                                 #  public method
#                   $obj->{KMLDIR}='pFiles';
#                   $obj->{PNGDIR}='pImages';
#                   $obj->{NUMCOLORS}=16;
#                   $obj->{ZADDADJUST}=0;
#                   $obj->{ZMULTADJUST}=1; 
#                   $obj->{COLORFILE}='c:/ourPerl/jet.txt';	
#                   $obj->{CLIM1}=-10;
#                   $obj->{CLIM2}=10;
#                   $obj->{CBARTITLE}='colorbar title';
#                   $obj->{NSKIP}=1;
#                   $obj->{ICONLABELSCALE}=[0.5, 0.5];
#                   ) 
#
# writes the kml for Points 
# writes network linked superoverlay type structure
# but with kml files containing points rather
# than ground overlays
#######################################################
sub writeKMLPoints{
   my $obj = shift;
   my %args=@_;
   
   # some defaults
   $obj->{KMLDIR}='pFiles';
   $obj->{PNGDIR}='pImages';
   $obj->{NUMCOLORS}=16;
   $obj->{ZADDADJUST}=0;
   $obj->{ZMULTADJUST}=1; 
   $obj->{COLORFILE}='c:/ourPerl/jet.txt';	
   $obj->{CLIM1}=-10;
   $obj->{CLIM2}=10;
   $obj->{CBARTITLE}='colorbar title';
   $obj->{NSKIP}=1;
   $obj->{ICONLABELSCALE}=[0.5, 0.5];

   $obj->{KMLDIR}=$args{-KMLDIR} if defined $args{-KMLDIR};
   $obj->{PNGDIR}=$args{-PNGDIR} if defined $args{-KMLDIR};
   $obj->{NUMCOLORS}=$args{-NUMCOLORS} if defined $args{-NUMCOLORS};
   $obj->{ZADDADJUST}=$args{-ZADDADJUST} if defined $args{-ZADDADJUST};
   $obj->{ZMULTADJUST}=$args{-ZMULTADJUST} if defined $args{-ZMULTADJUST}; 
   $obj->{COLORFILE}=$args{-COLORFILE} if defined $args{-COLORFILE};	
   $obj->{CLIM1}=$args{-CLIM1} if defined $args{-CLIM1};
   $obj->{CLIM2}=$args{-CLIM2} if defined $args{-CLIM2};
   $obj->{CBARTITLE}=$args{-CBARTITLE} if defined $args{-CBARTITLE};
   $obj->{NSKIP}=$args{-NSKIP} if defined $args{-NSKIP};
   $obj->{ICONLABELSCALE}=$args{-ICONLABELSCALE} if defined $args{-ICONLABELSCALE};

   # make directories to hold images and kml
   mkdir("$obj->{KMLDIR}");
   mkdir("$obj->{PNGDIR}");

   # make colorbar and color dots files
   $obj->loadColormap($obj->{COLORFILE});
   $obj->makeColorDots();
   $obj->makeColorbar($obj->{CBARTITLE});

   print "writing kml points\n";

   $obj->_writeKMLPoints(0,1);    # index, depth - for top layer

}


#######################################################
# sub _writeKMLPoints() -  private method actually does the work
#
#######################################################

sub _writeKMLPoints{
   my ($obj, $index, $depth) = @_;
   return unless($obj->{INTREE});  # don't write kml for nodes that are empty
       
   my $kmlDir=$obj->{KMLDIR};
   my $pngDir=$obj->{PNGDIR};
 
   my $kmlFile;
   my @kids = @{$obj->{CHILDREN}[$index]};
	 
   my $minLOD=128;
   my $maxLOD=512;
   unless (@kids) {$maxLOD=-1;}

   my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};
   my ($iconScale,$labelScale)=@{$obj->{ICONLABELSCALE}};


   if ($index ==0 ) {
      $kmlFile = "doc.kml";
   }else{  
      $kmlFile = "$kmlDir/pts$index.kml";
   }
         
   print "filename $kmlFile\n";

   # file beginning
   open FILE, ">$kmlFile" or die "can not open $kmlFile";
   print FILE '<?xml version="1.0" encoding="UTF-8"?>'."\n";
   print FILE '<kml xmlns="http://www.opengis.net/kml/2.2">'."\n";
   print FILE "   <Document>\n";

   # write kml for styles and colorbar screen overlay if at top level doc.kml
   if ($index==0) {

      #write styles
      my $color=0;
      while ($color<=128) {	 
        my $style="Style$color";  
        my $pngFile="$color.png";
        print FILE "    <Style id=\"$style\">\n";
        print FILE "      <IconStyle>\n";
        print FILE "         <Icon><href>$obj->{PNGDIR}/$pngFile</href></Icon>\n";
        print FILE "         <scale>$iconScale</scale>\n";
        print FILE "      </IconStyle>\n";
        print FILE "      <LabelStyle>\n";
        print FILE "         <scale>$labelScale</scale>\n";
        print FILE "      </LabelStyle>\n";
        print FILE "      <BalloonStyle>\n";
        print FILE '         <text>$[description]</text>\n';
        print FILE "      </BalloonStyle>\n";
        print FILE "    </Style>\n";
        $color++;
      }
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
      print FILE "           <href>$obj->{PNGDIR}/colorbar.png</href>\n";
      print FILE "        </Icon>\n";
      print FILE "        <overlayXY x=\"0\" y=\"1\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      print FILE "        <screenXY x=\"0.01\" y=\".99\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
      print FILE "        <rotationXY x=\"0\" y=\"0\" xunits=\"fraction\" yunits=\"fraction\"/>\n";
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
   print FILE "      <Lod>\n";
   print FILE "	       <minLodPixels>$minLOD</minLodPixels><maxLodPixels>$maxLOD</maxLodPixels>\n";
   print FILE "            <minFadeExtent>0</minFadeExtent> <maxFadeExtent>0</maxFadeExtent>\n";
   print FILE "	     </Lod>\n";
   print FILE "	  </Region>\n";

   # points kml for this node
   # network links to children
   if (@kids) {    # if it has kids it is not a leaf, just write the network links
      foreach my $kid (@kids) {
         next unless($obj->{INTREE}[$kid]);	# dont write the link for children that dont have elements in them
         my $lnkName="pts$kid.kml";
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
            print FILE "	      <href>$kmlDir/$lnkName</href>\n";
         }else{
            print FILE "	      <href>$lnkName</href>\n";
         }
         print FILE "	      <viewRefreshMode>onRegion</viewRefreshMode>\n";
         print FILE "	     </Link>\n";
         print FILE "	  </NetworkLink>\n";
      }
   }else{  # leaf nodes have no kids, write kml points instead
      my $superfinalized;
      # loop through all points in leaf node and write the kml
      # open a fialized file
      if (defined $obj->{SFINALIZED}){
         print "making KML points using superfinalized file $obj->{SFINALIZED} \n";
         open FH, "<$obj->{SFINALIZED}" or die "PointTree::writeKMLPoints can not open $obj->{SFINALIZED}\n";
         $superfinalized=1;
      }else{
         die "no super-finalized binary points file has been assigned to the tree\n";
      }
      binmode(FH);
     
      my $offset =  $obj->{BEGINOFFSET}->[$index];
      my $buffer;
      seek(FH,$offset,0);
      read(FH,$buffer,8);
      my ($chkIndex,$npoints)=unpack('L2',$buffer);
      unless (defined $chkIndex){  # maybe incomplete file
         print "undefined chkIndx at offset $offset\n";
         next;     
      }
      unless ($chkIndex == $index){
          print "whoa $chkIndex does not match file $index at offset $offset\n";
          next;
      }
      foreach my $point (1..$npoints){
         read(FH,$buffer,$obj->{PNTBUFBYTES});
         next unless ($buffer);
         my ($x,$y,$z,$id)=unpack($obj->{PNTPACKSTR},$buffer);
         my $skipping = ($point-1) % $obj->{NSKIP}; # % is modulo
         unless ($skipping){
            my $pmark=$obj->writePointPlacemark($x,$y,$z,$id);
            print FILE "$pmark";
         }
      } 
      close(FH);
   }# end if @kids

   print FILE " </Document>\n";
   print FILE "</kml>\n";
   close (FILE);
      
   return unless (@kids);
   foreach my $kid (@kids) {
      next unless($obj->{INTREE}[$kid]);  # don't write kml for tree nodes with no elemets under them
      $obj->_writeKMLPoints($kid, $depth+1);
   }
}

# private sub for writing a string of a point placemark
sub writePointPlacemark{
   my $obj=shift;
   my ($x,$y,$z,$id)=@_;
   $z=$z*$obj->{ZMULTADJUST}+$obj->{ZADDADJUST};

   my $style =int( 128* ($z-$obj->{CLIM1})/($obj->{CLIM2}- $obj->{CLIM1}));
 
   $style = 128 if ($style > 128);
   $style = 1   if ($style <1) ; 

   my $zstr=sprintf('%5.1f',$z);

   my $pmark='';
   $pmark.= "     <Placemark>\n";
   $pmark.= "        <name>$zstr</name>\n";
   $pmark.= "        <styleUrl>../doc.kml#Style$style</styleUrl>\n";
   $pmark.= "        <description>\n";
   #$pmark.= "         <p><b>$desc</b></p>\n";
   my $elevstring=sprintf ("%7.3f",$z);
   $pmark.= "         <p> Value = $elevstring</p>\n";
   $pmark.= "         <p> Id = $id</p>\n";
   $pmark.= "        </description>\n";
   $pmark.= "        <Point>\n ";
   $pmark.= "          <coordinates>$x,$y,$z</coordinates>\n";
   $pmark.= "        </Point>\n";
   $pmark.= "     </Placemark>\n";
   return $pmark;
}


####################################################
# sub makeColorDots()
#
# this subroutine makes a bunch of png files with color dots
#
################################################ 

sub makeColorDots {
  my $obj=shift;

  my $pngDir='Images';
  $pngDir=$obj->{PNGDIR} if (defined $obj->{PNGDIR});

  my $xpix=64;
  my $ypix=64;
  my $imid=$xpix/2;
  my $jmid=$ypix/2;

  my $color=128;

  while ($color>0) {

     my $im = new GD::Image($xpix,$ypix);
        &setColors($im,@{$obj->{COLORMAP}}); 
        my @colors=@{$obj->{COLORMAP}};
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
	my $pngFile= "$pngDir/$color.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
        $im=undef;

	$color--;
  }

}











#####################################################
# sub _bottomUp(0) 
#
# used to make pngs for branch nodes based on data
# from leaf nodes
#
# how to prevent deep recursion?????
#
#####################################################
sub _bottomUp {

   my ($obj,$index) = @_;
   my @kids = @{$obj->{CHILDREN}[$index]};
   my $allFour=0;
   my $j;
   my $i;
   my $cnt;

   my $pngDir=$obj->{PNGDIR};  #set in makePNGs
  
   return if (-e "$pngDir/$index.png"); 

   my $numColors=$obj->{NUMCOLORS};
        

   foreach my $kid (@kids) {
      my $pngName="$pngDir/$kid.png";
      $allFour++ if (-e $pngName or $obj->{INTREE}[$kid]==0 );  # making sure all childern have pngs written, or are not in the tree
   }

   if ($allFour==4) { 
      my $tlPngName="$pngDir/$kids[0].png";
      my $trPngName="$pngDir/$kids[1].png";
      my $brPngName="$pngDir/$kids[2].png";
      my $blPngName="$pngDir/$kids[3].png";

      my @data;
      #  my $im = GD::Image->new(256,256);
      # my @colors=&setColors_jet($im);
      
      my $maxCindx=130;  # the highest color index used in the png files


      # top left 
      if (-e $tlPngName) {
           my $im= GD::Image->new("$tlPngName");
	   # &setColors_jet($im);
	   print "name $tlPngName\n";
	   foreach $j (0..255) {
              foreach $i (0..255) {
		     $cnt = $j*512 +$i;
		     my $C=$im->getPixel($i,$j);
		     #   my ($r,$g,$b)=$im->rgb($cIndx);
		     #my $C=$im->colorExact($r,$g,$b);
		     $C=$maxCindx if $C<=0;
		     $data[$cnt]=$maxCindx-$C;
		     # print "1 i,j,c $i,$j,$C\n";
              }
            }
	    undef $im; 
      }else{
	   foreach $j (0..255) {
              foreach $i (0..255) {
		     $cnt = $j*512 +$i;
		     $data[$cnt]=0;
              }
            }
      }
      # top right 
      if (-e $trPngName) {
           my $im= GD::Image->new("$trPngName") ;
	   #  &setColors_jet($im);
	   foreach $j (0..255) {
              foreach $i (256..511) {
		     $cnt = $j*512 +$i;
		     my $C=$im->getPixel($i-256,$j);
		     #my ($r,$g,$b)=$im->rgb($cIndx);
		     #my $C=$im->colorExact($r,$g,$b);
		     $C=$maxCindx if $C<=0;
		     $data[$cnt]=$maxCindx-$C;
		     # print "2 i,j,c $i,$j,$C\n";
              }
            }
	    undef $im; 
      }else{
	   foreach $j (0..255) {
              foreach $i (256..511) {
		     $cnt = $j*512 +$i;
		     $data[$cnt]=0;
              }
            }
      }
      # bottom left 
      if (-e $blPngName) {
           my $im= GD::Image->new("$blPngName") ;
	   # &setColors_jet($im);
	   foreach $j (256..511) {
              foreach $i (0..255) {
		     $cnt = $j*512 +$i;
		     my $C=$im->getPixel($i,$j-256);
		     #my ($r,$g,$b)=$im->rgb($cIndx);
		     #my $C=$im->colorExact($r,$g,$b);
		     $C=$maxCindx if $C<=0;
		     $data[$cnt]=$maxCindx-$C;
		     # print "3 i,j,c $i,$j,$C\n";
              }
            }
	    undef $im; 
      }else{
	   foreach $j (256..511) {
              foreach $i (0..255) {
		     $cnt = $j*512 +$i;
		     $data[$cnt]=0;
              }
            }
      }
      # bottom right 
      if (-e $brPngName) {
           my $im= GD::Image->new("$brPngName") ;
	   #  &setColors_jet($im);
	   foreach $j (256..511) {
              foreach $i (256..511) {
		     $cnt = $j*512 +$i;
		     my $C=$im->getPixel($i-256,$j-256);
		     #my ($r,$g,$b)=$im->rgb($cIndx);
		     #my $C=$im->colorExact($r,$g,$b);
		     $C=$maxCindx if $C<=0;
		     $data[$cnt]=$maxCindx-$C;
		     #print "4 i,j,c $i,$j,$C\n";
              }
            }
	    undef $im; 
      }else{
	   foreach $j (256..511) {
              foreach $i (256..511) {
		     $cnt = $j*512 +$i;
		     $data[$cnt]=0;
              }
            }
      }

      # reduce resolution and make image
      my $im2 = new GD::Image(256,256);
      #my @colors = &setColors_jet($im2)  ; 
      #$im2->transparent($colors[255]);
      my @colors;
     #  @colors = &setColors_jet($im2)  if $obj->{COLORMAP} eq "jet";
     #  @colors = &setColors_diff($im2)  if $obj->{COLORMAP} eq "diff";	 
     #  @colors =  &setColors_marsh($im2)  if $obj->{COLORMAP} eq "marsh";	  
     @colors=&setColors($im2,@{$obj->{COLORMAP}});  


      my $ij;
      my $c1;
      my $c2;
      my $c3;
      my $c4;
      my $ipix=0;
      my $jpix=0;
      my $i2=0;
      my $j2=0;
      my $Cint=0;

      $cnt=0;
      $j=0;
      while ($j < 512) {
         $i=0;
	 $i2=0;
	 while ($i < 512) {
              $ij=($j)*512+$i;
	     $c1=$data[$ij];
              $ij=($j+1)*512+$i;
	     $c2=$data[$ij];
              $ij=($j)*512+$i+1;
	     $c3=$data[$ij];
              $ij=($j+1)*512+$i+1;
	     $c4=$data[$ij];
              my $nc=0;
              my $C=0;
              if ($c1 > 0) { $nc++; $C=$C+$c1; }
              if ($c2 > 0) { $nc++; $C=$C+$c2; }
              if ($c3 > 0) { $nc++; $C=$C+$c3; }
              if ($c4 > 0) { $nc++; $C=$C+$c4; }
	      
	      if ($nc > 0) {
                  $Cint=int($C/$nc);
                  $C= int(   (  int($numColors*($Cint-1)/128)+0.5 )*128/$numColors);
                  #$C=1 if ($C<1);
                  #$C=128 if ($C > 128);
              }


              if ($C < 1 and $nc >=1) {print "whoaa 1 c=  $C\n"; sleep (1);}
              if ($C > 128) {print "whoaa 2 c= $C\n"; sleep (1);}
              if ($C < 0) {print "whoaa 3 c= $C\n"; sleep (1);}
  
	     #  print "c1c2c3c4 $c1 $c2 $c3 $c4 nc $nc\n  C $C";

              $im2->setPixel($i2,$j2,$colors[$C]);
       	      
              $i2++;
              $i=$i+2;
         }
	 $j2++;
	 $j=$j+2;
      }

      my $pngFile= "$pngDir/$index.png";
      print "bottomUp writing $pngFile\n";
      open FILE2, ">$pngFile";
      binmode FILE2;
      print FILE2 $im2->png;
      close(FILE2);
      undef $im2;
      undef @data;
      undef @colors;
      
      #  my $mama=$obj->{PARENT}[$index];
      #  if (defined $mama) {
      #    $obj->_bottomUp($mama);   # go back up
      # }else {
          return
      # }




   } # end if allFour
   foreach my $kid (@kids) {
	   my $pngName="$pngDir/$kid.png";
  	   unless (-e $pngName or $obj->{INTREE}[$kid]==0 ){
		   $obj->_bottomUp($kid);
	   }
   }
   $obj->_bottomUp($index);
}



#################################################################
# sub makeColorbar($title)
#
# this subroutine makes a png with the colorbar
#
#################################################################
sub makeColorbar {
   my ($self,$title) = @_;
     
        my $numColors=16;  # the default	
   if (defined $self->{NUMCOLORS}) {
           $numColors=$self->{NUMCOLORS};
   }
   my $pngDir='Images';
   $pngDir=$self->{PNGDIR} if (defined $self->{PNGDIR});     

   my $xpix=550;
   my $ypix=100;
   my $xMarg=15;
   my $yMarg=30;
   my $xWidth= ($xpix - 2*$xMarg);
   

   my $im = new GD::Image($xpix,$ypix);
 #  @colors = &setColors_jet($im)  if $self->{COLORMAP} eq "jet";	 
 #  @colors = &setColors_diff($im)  if $self->{COLORMAP} eq "diff";	 
 #  @colors = &setColors_marsh($im)  if $self->{COLORMAP} eq "marsh";	  
   
   my @colors=&setColors($im,@{$self->{COLORMAP}});  
 
   my $black= $colors[130];
   my $white= $colors[129];

   my $i;
   my $j;
   my $cnt = 0;
   my $dClim=$self->{CLIM2}-$self->{CLIM1};
   my $dzdc=$dClim/128;
   my $C;
  
   ### BPJ Make white background for colorbar area 
#   $im->colorDeallocate($colors[255]);
#   $colors[255] = $im->colorAllocateAlpha(255,255,255,0);
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

  # my @colorBreaks;
  # push @colorBreaks[0],1;
  # my $dColor=127-$numColors;
  # my $cc=1;
  # while ($cc <128){
  #    $cc=$cc+$dcolor;
  #    my $intcc=$int(cc);
  #    $intcc++ if ($cc-$intcc > 0.5);
  #    push @colorBreaks,$intcc;
  # }
  # push @colorBreaks,128;

  # print "number of ColorBreaks - 1 = $#colorBreaks\n";
  # print "numcolors is $numColors\n";

   # determine a color to represent each break
  # my @trunColors;
  # foreach my $i (1..$#ColorBreaks);
  #    my $trunColor[$i-1]=int ( ($ColorBreaks[$i]+$colorBreaks[$i-1])/2 );
   

   foreach $j ( $yMarg .. $ypix-$yMarg ) {

       foreach $i ( $xMarg .. $xpix-$xMarg ) {
          my $C1= 128 * ($i-$xMarg)  / $xWidth+1;
          
         # $C= ($c-$self->{CLIM1})/$dzdc+1;       
          my $C= int(   (  int($numColors*($C1-1)/128)+0.5 )*128/$numColors)  unless ($C1==0);
          $C=128 if ($C > 128); 

 #print "i,c1,c $i  $C1  $C\n";
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
      my $dx=($xWidth)/$numColors;
      
      $dx=($xWidth)/20 if $numColors > 20;  # just to keep ticks from crowding eachother
      
      
      
      my $x=$xMarg-1;
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
        
        my $tickLabel=sprintf("%0.1f",$dtmp);
        $im->string(gdMediumBoldFont,$intx-11,$ytmp+6,$tickLabel,$black);
        $x=$x+$dx;            
    
      } 
  
      

   
  # now write the png file
  my $pngFile= "$pngDir/colorbar.png";
  open FILE2, ">$pngFile";
  binmode FILE2;
  print FILE2 $im->png;
  close(FILE2);
        $im=undef;

}





#####################################################
# sub setColors_diff() 
#
# used by _makePNG to allocate the color map for png files
####################################################
sub setColors_diff {
      my($im) = shift;

      my $cnt=255;
     while ($cnt--) {
         $im->colorDeallocate($cnt);
     }


      my @color;
      my $alpha=0;
      $color[0] = $im->colorAllocateAlpha(0,0,255,0);
      $color[1] = $im->colorAllocateAlpha(2,2,255,$alpha);
      $color[2] = $im->colorAllocateAlpha(4,4,255,$alpha);
      $color[3] = $im->colorAllocateAlpha(6,6,255,$alpha);
      $color[4] = $im->colorAllocateAlpha(8,8,255,$alpha);
      $color[5] = $im->colorAllocateAlpha(10,10,255,$alpha);
      $color[6] = $im->colorAllocateAlpha(12,12,255,$alpha);
      $color[7] = $im->colorAllocateAlpha(14,14,255,$alpha);
      $color[8] = $im->colorAllocateAlpha(16,16,255,$alpha);
      $color[9] = $im->colorAllocateAlpha(18,18,255,$alpha);
      $color[10] = $im->colorAllocateAlpha(20,20,255,$alpha);
      $color[11] = $im->colorAllocateAlpha(22,22,255,$alpha);
      $color[12] = $im->colorAllocateAlpha(24,24,255,$alpha);
      $color[13] = $im->colorAllocateAlpha(26,26,255,$alpha);
      $color[14] = $im->colorAllocateAlpha(28,28,255,$alpha);
      $color[15] = $im->colorAllocateAlpha(30,30,255,$alpha);
      $color[16] = $im->colorAllocateAlpha(32,32,255,$alpha);
      $color[17] = $im->colorAllocateAlpha(34,34,255,$alpha);
      $color[18] = $im->colorAllocateAlpha(36,36,255,$alpha);
      $color[19] = $im->colorAllocateAlpha(38,38,255,$alpha);
      $color[20] = $im->colorAllocateAlpha(40,40,255,$alpha);
      $color[21] = $im->colorAllocateAlpha(42,42,255,$alpha);
      $color[22] = $im->colorAllocateAlpha(44,44,255,$alpha);
      $color[23] = $im->colorAllocateAlpha(46,46,255,$alpha);
      $color[24] = $im->colorAllocateAlpha(48,48,255,$alpha);
      $color[25] = $im->colorAllocateAlpha(50,50,255,$alpha);
      $color[26] = $im->colorAllocateAlpha(52,52,255,$alpha);
      $color[27] = $im->colorAllocateAlpha(54,54,255,$alpha);
      $color[28] = $im->colorAllocateAlpha(56,56,255,$alpha);
      $color[29] = $im->colorAllocateAlpha(58,58,255,$alpha);
      $color[30] = $im->colorAllocateAlpha(60,60,255,$alpha);
      $color[31] = $im->colorAllocateAlpha(62,62,255,$alpha);
      $color[32] = $im->colorAllocateAlpha(64,64,255,$alpha);
      $color[33] = $im->colorAllocateAlpha(66,66,255,$alpha);
      $color[34] = $im->colorAllocateAlpha(68,68,255,$alpha);
      $color[35] = $im->colorAllocateAlpha(70,70,255,$alpha);
      $color[36] = $im->colorAllocateAlpha(72,72,255,$alpha);
      $color[37] = $im->colorAllocateAlpha(74,74,255,$alpha);
      $color[38] = $im->colorAllocateAlpha(76,76,255,$alpha);
      $color[39] = $im->colorAllocateAlpha(78,78,255,$alpha);
      $color[40] = $im->colorAllocateAlpha(80,80,255,$alpha);
      $color[41] = $im->colorAllocateAlpha(82,82,255,$alpha);
      $color[42] = $im->colorAllocateAlpha(84,84,255,$alpha);
      $color[43] = $im->colorAllocateAlpha(86,86,255,$alpha);
      $color[44] = $im->colorAllocateAlpha(88,88,255,$alpha);
      $color[45] = $im->colorAllocateAlpha(90,90,255,$alpha);
      $color[46] = $im->colorAllocateAlpha(92,92,255,$alpha);
      $color[47] = $im->colorAllocateAlpha(94,94,255,$alpha);
      $color[48] = $im->colorAllocateAlpha(96,96,255,$alpha);
      $color[49] = $im->colorAllocateAlpha(98,98,255,$alpha);
      $color[50] = $im->colorAllocateAlpha(100,100,255,$alpha);
      $color[51] = $im->colorAllocateAlpha(102,102,255,$alpha);
      $color[52] = $im->colorAllocateAlpha(104,104,255,$alpha);
      $color[53] = $im->colorAllocateAlpha(106,106,255,$alpha);
      $color[54] = $im->colorAllocateAlpha(108,108,255,$alpha);
      $color[55] = $im->colorAllocateAlpha(110,110,255,$alpha);
      $color[56] = $im->colorAllocateAlpha(112,112,255,$alpha);
      $color[57] = $im->colorAllocateAlpha(114,114,255,$alpha);
      $color[58] = $im->colorAllocateAlpha(116,116,255,$alpha);
      $color[59] = $im->colorAllocateAlpha(118,118,255,$alpha);
      $color[60] = $im->colorAllocateAlpha(120,120,255,$alpha);
      $color[61] = $im->colorAllocateAlpha(122,122,255,$alpha);
      $color[62] = $im->colorAllocateAlpha(124,124,255,$alpha);
      $color[63] = $im->colorAllocateAlpha(126,126,255,$alpha);
      $color[64] = $im->colorAllocateAlpha(129,129,255,$alpha);
      $color[65] = $im->colorAllocateAlpha(131,131,255,$alpha);
      $color[66] = $im->colorAllocateAlpha(133,133,255,$alpha);
      $color[67] = $im->colorAllocateAlpha(135,135,255,$alpha);
      $color[68] = $im->colorAllocateAlpha(137,137,255,$alpha);
      $color[69] = $im->colorAllocateAlpha(139,139,255,$alpha);
      $color[70] = $im->colorAllocateAlpha(141,141,255,$alpha);
      $color[71] = $im->colorAllocateAlpha(143,143,255,$alpha);
      $color[72] = $im->colorAllocateAlpha(145,145,255,$alpha);
      $color[73] = $im->colorAllocateAlpha(147,147,255,$alpha);
      $color[74] = $im->colorAllocateAlpha(149,149,255,$alpha);
      $color[75] = $im->colorAllocateAlpha(151,151,255,$alpha);
      $color[76] = $im->colorAllocateAlpha(153,153,255,$alpha);
      $color[77] = $im->colorAllocateAlpha(155,155,255,$alpha);
      $color[78] = $im->colorAllocateAlpha(157,157,255,$alpha);
      $color[79] = $im->colorAllocateAlpha(159,159,255,$alpha);
      $color[80] = $im->colorAllocateAlpha(161,161,255,$alpha);
      $color[81] = $im->colorAllocateAlpha(163,163,255,$alpha);
      $color[82] = $im->colorAllocateAlpha(165,165,255,$alpha);
      $color[83] = $im->colorAllocateAlpha(167,167,255,$alpha);
      $color[84] = $im->colorAllocateAlpha(169,169,255,$alpha);
      $color[85] = $im->colorAllocateAlpha(171,171,255,$alpha);
      $color[86] = $im->colorAllocateAlpha(173,173,255,$alpha);
      $color[87] = $im->colorAllocateAlpha(175,175,255,$alpha);
      $color[88] = $im->colorAllocateAlpha(177,177,255,$alpha);
      $color[89] = $im->colorAllocateAlpha(179,179,255,$alpha);
      $color[90] = $im->colorAllocateAlpha(181,181,255,$alpha);
      $color[91] = $im->colorAllocateAlpha(183,183,255,$alpha);
      $color[92] = $im->colorAllocateAlpha(185,185,255,$alpha);
      $color[93] = $im->colorAllocateAlpha(187,187,255,$alpha);
      $color[94] = $im->colorAllocateAlpha(189,189,255,$alpha);
      $color[95] = $im->colorAllocateAlpha(191,191,255,$alpha);
      $color[96] = $im->colorAllocateAlpha(193,193,255,$alpha);
      $color[97] = $im->colorAllocateAlpha(195,195,255,$alpha);
      $color[98] = $im->colorAllocateAlpha(197,197,255,$alpha);
      $color[99] = $im->colorAllocateAlpha(199,199,255,$alpha);
      $color[100] = $im->colorAllocateAlpha(201,201,255,$alpha);
      $color[101] = $im->colorAllocateAlpha(203,203,255,$alpha);
      $color[102] = $im->colorAllocateAlpha(205,205,255,$alpha);
      $color[103] = $im->colorAllocateAlpha(207,207,255,$alpha);
      $color[104] = $im->colorAllocateAlpha(209,209,255,$alpha);
      $color[105] = $im->colorAllocateAlpha(211,211,255,$alpha);
      $color[106] = $im->colorAllocateAlpha(213,213,255,$alpha);
      $color[107] = $im->colorAllocateAlpha(215,215,255,$alpha);
      $color[108] = $im->colorAllocateAlpha(217,217,255,$alpha);
      $color[109] = $im->colorAllocateAlpha(219,219,255,$alpha);
      $color[110] = $im->colorAllocateAlpha(221,221,255,$alpha);
      $color[111] = $im->colorAllocateAlpha(223,223,255,$alpha);
      $color[112] = $im->colorAllocateAlpha(225,225,255,$alpha);
      $color[113] = $im->colorAllocateAlpha(227,227,255,$alpha);
      $color[114] = $im->colorAllocateAlpha(229,229,255,$alpha);
      $color[115] = $im->colorAllocateAlpha(231,231,255,$alpha);
      $color[116] = $im->colorAllocateAlpha(233,233,255,$alpha);
      $color[117] = $im->colorAllocateAlpha(235,235,255,$alpha);
      $color[118] = $im->colorAllocateAlpha(237,237,255,$alpha);
      $color[119] = $im->colorAllocateAlpha(239,239,255,$alpha);
      $color[120] = $im->colorAllocateAlpha(241,241,255,$alpha);
      $color[121] = $im->colorAllocateAlpha(243,243,255,$alpha);
      $color[122] = $im->colorAllocateAlpha(245,245,255,$alpha);
      $color[123] = $im->colorAllocateAlpha(247,247,255,$alpha);
      $color[124] = $im->colorAllocateAlpha(249,249,255,$alpha);
      $color[125] = $im->colorAllocateAlpha(251,251,255,$alpha);
      $color[126] = $im->colorAllocateAlpha(253,253,255,$alpha);
      $color[127] = $im->colorAllocateAlpha(255,255,255,$alpha);
      $color[128] = $im->colorAllocateAlpha(255,255,255,$alpha);
      $color[129] = $im->colorAllocateAlpha(255,253,253,$alpha);
      $color[130] = $im->colorAllocateAlpha(255,251,251,$alpha);
      $color[131] = $im->colorAllocateAlpha(255,249,249,$alpha);
      $color[132] = $im->colorAllocateAlpha(255,247,247,$alpha);
      $color[133] = $im->colorAllocateAlpha(255,245,245,$alpha);
      $color[134] = $im->colorAllocateAlpha(255,243,243,$alpha);
      $color[135] = $im->colorAllocateAlpha(255,241,241,$alpha);
      $color[136] = $im->colorAllocateAlpha(255,239,239,$alpha);
      $color[137] = $im->colorAllocateAlpha(255,237,237,$alpha);
      $color[138] = $im->colorAllocateAlpha(255,235,235,$alpha);
      $color[139] = $im->colorAllocateAlpha(255,233,233,$alpha);
      $color[140] = $im->colorAllocateAlpha(255,231,231,$alpha);
      $color[141] = $im->colorAllocateAlpha(255,229,229,$alpha);
      $color[142] = $im->colorAllocateAlpha(255,227,227,$alpha);
      $color[143] = $im->colorAllocateAlpha(255,225,225,$alpha);
      $color[144] = $im->colorAllocateAlpha(255,223,223,$alpha);
      $color[145] = $im->colorAllocateAlpha(255,221,221,$alpha);
      $color[146] = $im->colorAllocateAlpha(255,219,219,$alpha);
      $color[147] = $im->colorAllocateAlpha(255,217,217,$alpha);
      $color[148] = $im->colorAllocateAlpha(255,215,215,$alpha);
      $color[149] = $im->colorAllocateAlpha(255,213,213,$alpha);
      $color[150] = $im->colorAllocateAlpha(255,211,211,$alpha);
      $color[151] = $im->colorAllocateAlpha(255,209,209,$alpha);
      $color[152] = $im->colorAllocateAlpha(255,207,207,$alpha);
      $color[153] = $im->colorAllocateAlpha(255,205,205,$alpha);
      $color[154] = $im->colorAllocateAlpha(255,203,203,$alpha);
      $color[155] = $im->colorAllocateAlpha(255,201,201,$alpha);
      $color[156] = $im->colorAllocateAlpha(255,199,199,$alpha);
      $color[157] = $im->colorAllocateAlpha(255,197,197,$alpha);
      $color[158] = $im->colorAllocateAlpha(255,195,195,$alpha);
      $color[159] = $im->colorAllocateAlpha(255,193,193,$alpha);
      $color[160] = $im->colorAllocateAlpha(255,191,191,$alpha);
      $color[161] = $im->colorAllocateAlpha(255,189,189,$alpha);
      $color[162] = $im->colorAllocateAlpha(255,187,187,$alpha);
      $color[163] = $im->colorAllocateAlpha(255,185,185,$alpha);
      $color[164] = $im->colorAllocateAlpha(255,183,183,$alpha);
      $color[165] = $im->colorAllocateAlpha(255,181,181,$alpha);
      $color[166] = $im->colorAllocateAlpha(255,179,179,$alpha);
      $color[167] = $im->colorAllocateAlpha(255,177,177,$alpha);
      $color[168] = $im->colorAllocateAlpha(255,175,175,$alpha);
      $color[169] = $im->colorAllocateAlpha(255,173,173,$alpha);
      $color[170] = $im->colorAllocateAlpha(255,171,171,$alpha);
      $color[171] = $im->colorAllocateAlpha(255,169,169,$alpha);
      $color[172] = $im->colorAllocateAlpha(255,167,167,$alpha);
      $color[173] = $im->colorAllocateAlpha(255,165,165,$alpha);
      $color[174] = $im->colorAllocateAlpha(255,163,163,$alpha);
      $color[175] = $im->colorAllocateAlpha(255,161,161,$alpha);
      $color[176] = $im->colorAllocateAlpha(255,159,159,$alpha);
      $color[177] = $im->colorAllocateAlpha(255,157,157,$alpha);
      $color[178] = $im->colorAllocateAlpha(255,155,155,$alpha);
      $color[179] = $im->colorAllocateAlpha(255,153,153,$alpha);
      $color[180] = $im->colorAllocateAlpha(255,151,151,$alpha);
      $color[181] = $im->colorAllocateAlpha(255,149,149,$alpha);
      $color[182] = $im->colorAllocateAlpha(255,147,147,$alpha);
      $color[183] = $im->colorAllocateAlpha(255,145,145,$alpha);
      $color[184] = $im->colorAllocateAlpha(255,143,143,$alpha);
      $color[185] = $im->colorAllocateAlpha(255,141,141,$alpha);
      $color[186] = $im->colorAllocateAlpha(255,139,139,$alpha);
      $color[187] = $im->colorAllocateAlpha(255,137,137,$alpha);
      $color[188] = $im->colorAllocateAlpha(255,135,135,$alpha);
      $color[189] = $im->colorAllocateAlpha(255,133,133,$alpha);
      $color[190] = $im->colorAllocateAlpha(255,131,131,$alpha);
      $color[191] = $im->colorAllocateAlpha(255,129,129,$alpha);
      $color[192] = $im->colorAllocateAlpha(255,126,126,$alpha);
      $color[193] = $im->colorAllocateAlpha(255,124,124,$alpha);
      $color[194] = $im->colorAllocateAlpha(255,122,122,$alpha);
      $color[195] = $im->colorAllocateAlpha(255,120,120,$alpha);
      $color[196] = $im->colorAllocateAlpha(255,118,118,$alpha);
      $color[197] = $im->colorAllocateAlpha(255,116,116,$alpha);
      $color[198] = $im->colorAllocateAlpha(255,114,114,$alpha);
      $color[199] = $im->colorAllocateAlpha(255,112,112,$alpha);
      $color[200] = $im->colorAllocateAlpha(255,110,110,$alpha);
      $color[201] = $im->colorAllocateAlpha(255,108,108,$alpha);
      $color[202] = $im->colorAllocateAlpha(255,106,106,$alpha);
      $color[203] = $im->colorAllocateAlpha(255,104,104,$alpha);
      $color[204] = $im->colorAllocateAlpha(255,102,102,$alpha);
      $color[205] = $im->colorAllocateAlpha(255,100,100,$alpha);
      $color[206] = $im->colorAllocateAlpha(255,98,98,$alpha);
      $color[207] = $im->colorAllocateAlpha(255,96,96,$alpha);
      $color[208] = $im->colorAllocateAlpha(255,94,94,$alpha);
      $color[209] = $im->colorAllocateAlpha(255,92,92,$alpha);
      $color[210] = $im->colorAllocateAlpha(255,90,90,$alpha);
      $color[211] = $im->colorAllocateAlpha(255,88,88,$alpha);
      $color[212] = $im->colorAllocateAlpha(255,86,86,$alpha);
      $color[213] = $im->colorAllocateAlpha(255,84,84,$alpha);
      $color[214] = $im->colorAllocateAlpha(255,82,82,$alpha);
      $color[215] = $im->colorAllocateAlpha(255,80,80,$alpha);
      $color[216] = $im->colorAllocateAlpha(255,78,78,$alpha);
      $color[217] = $im->colorAllocateAlpha(255,76,76,$alpha);
      $color[218] = $im->colorAllocateAlpha(255,74,74,$alpha);
      $color[219] = $im->colorAllocateAlpha(255,72,72,$alpha);
      $color[220] = $im->colorAllocateAlpha(255,70,70,$alpha);
      $color[221] = $im->colorAllocateAlpha(255,68,68,$alpha);
      $color[222] = $im->colorAllocateAlpha(255,66,66,$alpha);
      $color[223] = $im->colorAllocateAlpha(255,64,64,$alpha);
      $color[224] = $im->colorAllocateAlpha(255,62,62,$alpha);
      $color[225] = $im->colorAllocateAlpha(255,60,60,$alpha);
      $color[226] = $im->colorAllocateAlpha(255,58,58,$alpha);
      $color[227] = $im->colorAllocateAlpha(255,56,56,$alpha);
      $color[228] = $im->colorAllocateAlpha(255,54,54,$alpha);
      $color[229] = $im->colorAllocateAlpha(255,52,52,$alpha);
      $color[230] = $im->colorAllocateAlpha(255,50,50,$alpha);
      $color[231] = $im->colorAllocateAlpha(255,48,48,$alpha);
      $color[232] = $im->colorAllocateAlpha(255,46,46,$alpha);
      $color[233] = $im->colorAllocateAlpha(255,44,44,$alpha);
      $color[234] = $im->colorAllocateAlpha(255,42,42,$alpha);
      $color[235] = $im->colorAllocateAlpha(255,40,40,$alpha);
      $color[236] = $im->colorAllocateAlpha(255,38,38,$alpha);
      $color[237] = $im->colorAllocateAlpha(255,36,36,$alpha);
      $color[238] = $im->colorAllocateAlpha(255,34,34,$alpha);
      $color[239] = $im->colorAllocateAlpha(255,32,32,$alpha);
      $color[240] = $im->colorAllocateAlpha(255,30,30,$alpha);
      $color[241] = $im->colorAllocateAlpha(255,28,28,$alpha);
      $color[242] = $im->colorAllocateAlpha(255,26,26,$alpha);
      $color[243] = $im->colorAllocateAlpha(255,24,24,$alpha);
      $color[244] = $im->colorAllocateAlpha(255,22,22,$alpha);
      $color[245] = $im->colorAllocateAlpha(255,20,20,$alpha);
      $color[246] = $im->colorAllocateAlpha(255,18,18,$alpha);
      $color[247] = $im->colorAllocateAlpha(255,16,16,$alpha);
      $color[248] = $im->colorAllocateAlpha(255,14,14,$alpha);
      $color[249] = $im->colorAllocateAlpha(255,12,12,$alpha);
      $color[250] = $im->colorAllocateAlpha(255,10,10,$alpha);
      $color[251] = $im->colorAllocateAlpha(255,8,8,$alpha);
      $color[252] = $im->colorAllocateAlpha(255,6,6,$alpha);
      $color[253] = $im->colorAllocateAlpha(255,4,4,$alpha);
      $color[254] = $im->colorAllocateAlpha(255,2,2,$alpha);
      $color[255] = $im->colorAllocateAlpha(250,250,250,$alpha);

      $im->transparent($color[0]);  
      return @color;
}







#####################################################
# sub setColors_jet() 
#
# used by _makePNG to allocate the color map for png files
####################################################
sub setColors_jet {
      my($im) = shift;
    

      my $cnt=255;
     while ($cnt--) {
         $im->colorDeallocate($cnt);
     }


      my @color;
      my $alpha=0;
      $color[0] = $im->colorAllocateAlpha(0,0,131,$alpha);
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
      $color[255] = $im->colorAllocateAlpha(127,0,0,$alpha);
      

     # $color[256] = $im->colorAllocateAlpha(255,255,255,$alpha); # white
     # $color[257] = $im->colorAllocateAlpha(0,0,0,$alpha); # black
     
     
     
      $im->transparent($color[0]);  

      return @color;
      # $im->setAntiAliasedDontBlend($color[0]);
}



#####################################################
# sub setColors_marsh() 
#
# used by _makePNG to allocate the color map for png files
####################################################
sub setColors_marsh {
      my($im) = shift;
     my $cnt=255;
     while ($cnt--) {
         $im->colorDeallocate($cnt);
     }


      my @color;
      my $alpha=0;
      $color[0] = $im->colorAllocateAlpha(131,131,131,0);
      $color[1] = $im->colorAllocateAlpha(0,0,135,$alpha);   # subtidal
      $color[2] = $im->colorAllocateAlpha(139,69,13,$alpha); # mudflat
      $color[3] = $im->colorAllocateAlpha(153,204,50,$alpha);   # low marsh
      $color[4] = $im->colorAllocateAlpha(20,125,20,$alpha);   # high marsh
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
      $color[255] = $im->colorAllocateAlpha(250,250,250,$alpha);
     
     
      $im->transparent($color[0]);  
      
      return @color;
}

########################################################################
# sub setColors
# 
# a more general way to set the color palette for the pngs
#
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

   my $alpha=0;  # 0 - 127 ; opaque - transparent

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


################################################################
# sub loadColormap
#
# loads the colormap array from a file and sets $obj{COLORMAP}
# array reference
#
#   e.g. 
#        $tree->loadColormap('colormapFile')
#
#   colormap file is a space delimited ASCII file with
#   4 columns of numbers that range between 0 and 1
#
#   Columns 2,3,4 are R,G,B, values (decimal beteen 0-1)
#
#   the first column is a scale value (0-1) that determines
#   how colors are interpolated between CLIM1 and CLIM2 values
#   e.g. ZDATA values <= CLIM1 will be colored with color 
#   associated with scale = 0,  ZDATA value >= CLIM2 with color
#   associated with scale = 1,  for values between CLIM1 and 
#   CLIM2 colors will be linearly interpolated between 
#   intermediate values given in the colormap array
#  
################################################################
sub loadColormap{
    my $obj=shift;
    my $colormapFile=shift;
    open CM, "$colormapFile" or die "cant open colormap file $colormapFile\n";
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

      # print "ssrrggbb $ss,$rr,$gg,$bb\n";

    }
    close(CM);
    $obj->{COLORMAP}=  [ \@s,\@r,\@g,\@b];

 
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






##########################################################
# sub $index=getLeafIndex($x,$y)
#
# subroutine to find out which leaf node the point x,y is in
##########################################################
sub getLeafIndex{

   my $obj=shift;
   my ($x,$y)=@_;

   # return -1 immediately if the point isn't in the tree
   
   my ($north, $south, $east, $west) = @{$obj->{REGION}[0]};

   #print "nsew $north, $south, $east, $west\n";

   return "-1" unless ($y <= $north);
   return "-1" unless ($y >= $south);
   return "-1" unless ($x >= $west);
   return "-1" unless ($x <= $east);


   my $recurseDepth=0;
 
   $obj->{POINTCOUNTED}=0;
  
   my $index=$obj->{LASTINDX};
   $index=0 if ($index <0);
   

   # check the last index that found a point first
    $obj->_getLeafIndex($x,$y,$recurseDepth,$index);
    return $obj->{LASTINDX} if ($obj->{POINTCOUNTED});

   # if not found in the last index recurse up the 
   # tree checking the parent/siblings, grandparents/cousins ... 
    while ($index>=0) {
      $index=$obj->{PARENT}[$index];
      $obj->_getLeafIndex($x,$y,$recurseDepth,$index);
      return $obj->{LASTINDX} if ($obj->{POINTCOUNTED});
    }




}


#####################################################
# sub _getleafIndex()
#
# recursive function checks if point is in a leaf node
# returns the index of the leaf node
#
#
#####################################################

sub _getLeafIndex{
        
       my $obj = shift;
       return if ($obj->{POINTCOUNTED});

       my ($x,$y,$recurseDepth,$index) = @_;

       # return if $index == -3;
 

       my ($north, $south, $east, $west) = @{$obj->{REGION}[$index]};

       return unless ($y <= $north);
       return unless ($y >= $south);
       return unless ($x >= $west);
       return unless ($x <= $east);

       # check if this is a leaf node
       my $dy=$north-$south;
       if ($dy <= $obj->{MINDY}) {    # this is a leaf node, decrement this index

	     $index=-7 unless $obj->{INTREE}[$index]; # this leaf has no points 

	     $obj->{LASTINDX}=$index;
	     $obj->{POINTCOUNTED}=1;
	     return;

	     
       }else{                         # this is not a leaf node, keep going or return -1 if its not in the tree b/c it has no points
  

	    $recurseDepth++;
	    foreach  my $child ( @{$obj->{CHILDREN}[$index]} ) {  # loop through the children decrementing points
		    $obj->_getLeafIndex($x,$y,$recurseDepth,$child)
            }
	    unless ($obj->{POINTCOUNTED}==1) { # we're here if the point is in a leaf node that doesn't have any points, 
                  $obj->{LASTINDX}=-2;
		  return;
	   }
		                              
   
       }

}




sub getIndicesInCircle{
    my $obj=shift;
    my ($x,$y,$r)=@_;
    
    # get a point in the corner
    my $xtl=$x-$r;
    my $ytl=$y+$r;
     
    my $nsteps=int(2*$r/$obj->{LEAFDY})+1;

    my $xx=$xtl;
    
  
    my %Indices;
    my $indx=$obj->getLeafIndex($x,$y); # add the indx the point is in.
    $Indices{$indx}=1 if $indx >0 ;

    # step mindy down the columns and across rows and check each leaf to see if its in there
    foreach my $i (1..$nsteps){ 
       my $yy=$ytl;
       foreach my $j (1..$nsteps){
           $indx=$obj->getLeafIndex($xx,$yy);
          if ($indx < 0) { $yy=$yy-$obj->{LEAFDY}; next;}

          my ($n, $s, $e, $w) = @{$obj->{REGION}[$indx]};
          
          my $dx=abs($x-$w);
          if ($dx <= $r) { $Indices{$indx}=1; $yy=$yy-$obj->{LEAFDY}; next; }

           $dx=abs($x-$e);
          if ($dx <= $r) { $Indices{$indx}=1; $yy=$yy-$obj->{LEAFDY}; next; }

          my $dy=abs($y-$n);
          if ($dy <= $r) { $Indices{$indx}=1; $yy=$yy-$obj->{LEAFDY}; next; }

           $dy=abs($y-$s);
          if ($dy <= $r) { $Indices{$indx}=1; $yy=$yy-$obj->{LEAFDY}; next; }
          $yy=$yy-$obj->{LEAFDY};
    
       }  
       $xx=$xx+$obj->{LEAFDY};

    }   
    my @I=keys %Indices;

    return \@I;

}                 

    


#################################################################
#
#  subs to create bin file and finalize/superfinalize it.
#  each point is 26 bytes binary packed with
#      pack("d3n",$x,$y,$z,$id)
#  
#  add points to it (while counting them)
#
#  and close it
#
#  e.g.
#
#  $tree->openBin($binFileName, ['append']);
#  
#  #loop over points
#      $tree->addPointTooBin($x,$y,$z,$id);
#  #end loop over points
#
#  $tree->closeBin();
#
#
#  # finalize
#  $tree->finalizeBin();
#
#  # superfinalize
#  $tree->superFinalizeBin();
#
#
#  # store the tree 
#  store $tree, "$treeFile";
#
#################################################################
sub openBin {
    my $obj=shift;
    my $binFile=shift;
    my $openType=shift;
    $openType='truncate' unless (defined $openType);
    $obj->{BINFILE}=$binFile;

    if (lc($openType) eq 'append'){
         open $obj->{BINFILE_HANDLE}, ">>$binFile" or die "cant open $binFile\n";
    }else{  # truncate
         open $obj->{BINFILE_HANDLE}, ">$binFile" or die "cant open $binFile\n";
    }
    
    binmode $obj->{BINFILE_HANDLE}
}


sub closeBin {
    my $obj=shift;
    close ($obj->{BINFILE_HANDLE});
    undef $obj->{BINFILE_HANDLE};
}
    
sub addPointToBin {
    my $obj=shift;
    my ($x,$y,$z,$id)=@_;
    my @X;
    my @Y;
    my @Z;
    my @ID;   
    my $fh=$obj->{BINFILE_HANDLE};
    if (ref($x)) {
        @X=@{$x};
        @Y=@{$y};
        @Z=@{$z};
        @ID=@{$id};
    }else{
        $X[0]=$x;
        $Y[0]=$y;
        $Z[0]=$z;
        $ID[0]=$id;
    }
   
    foreach my $x (@X){
         my $y=shift (@Y);
         my $z=shift (@Z);
         my $id=shift (@ID);
         $obj->countPoint($x,$y);
         my $buf=pack ($obj->{PNTPACKSTR},$x,$y,$z,$id);
         print $fh "$buf";
         if (defined $obj->{MAXZ}){
            $obj->{MAXZ}=$z if $z > $obj->{MAXZ};            
            $obj->{MINZ}=$z if $z < $obj->{MINZ};
         }else{
            $obj->{MAXZ}=$z;            
            $obj->{MINZ}=$z;
         }
    }


}

################################################################################
# sub finalizeBin
#
# metnod to create a "finalized" file.
#
# it incerts special points with x,y,leafIndexNumber,junkID into the
# after each point from in that leaf has been fully decremented.
#
# encountereing one of these points while reading the file indicates that
# all points in that leaf node have already been encountered and you can 
# do any processing on those points if they were stored in memory as 
# the file was read. 
#
# note, additional superfinalizing it may be better see superFinalizeBin() below
#
#
###############################################################################
sub finalizeBin{
     my $obj=shift;
     my $finalizedName=shift;
     
     open IN, "<$obj->{BINFILE}" or die "cant open $obj->{BINFILE} for read finalization\n";
     binmode(IN);

     if (defined $finalizedName){
          $obj->{FINALIZED}=$finalizedName;
     }else{
          $obj->{FINALIZED}="$obj->{BINFILE}".'.fin';
     }

     open OUT, ">$obj->{FINALIZED}" or die "cant open $obj->{FINALIZED} for write finalization\n";
      
     binmode(OUT);
     
     $/=\$obj->{PNTBUFBYTES};  # read 26 bytes at a time

    while (<IN>){ 
        my ($x,$y,$z,$ID)=unpack($obj->{PNTPACKSTR},$_);
        my $indx = $obj->decrementPoint($x,$y);
        next if ($indx < 0);  # will be -1 if the point is not in the root of the tree, so dont write it
        my $buf=pack($obj->{PNTPACKSTR},$x,$y,$z,$ID);     # surrvey id is a 2 byte value "network" big-endian order
        print OUT "$buf";
        if ($indx) {
           my $buf=pack($obj->{PNTPACKSTR},-999999,-999999,$indx,0);
	   print OUT "$buf";
        }
    }
    close(IN);
    close(OUT);
    $/="\n";
}

#########################################################################################
# sub superFinalizeBin();
#
# method to create a "super" finalized bin file. 
#
# the bin file contains a sequence of records of the xyz position and id for points found
# within each leaf node in the tree in "d3n" packed format.
# Eacch index record is preceeded by two long integers "L2" that give the index and number
# of points in the leaf node.  This file allows for quick non-sequential access to point
# in the tree without requiring the points to be in memory.  
# It also creates the $obj->{BEGINOFFSET} array (actually a array ref), which stores
# the offset to where each index record starts within the superfinalized file
#
# usage: see above for openBin
#  
#
#########################################################################################
 sub superFinalizeBin{
     my $obj=shift;
     my $superFinalized=shift;
     
     $superFinalized="$obj->{FINALIZED}".'.sfn' unless (defined $superFinalized);
     $obj->{SFINALIZED}= $superFinalized;

     open IN,"< $obj->{FINALIZED}";
     open OUT, ">$obj->{SFINALIZED}";
     binmode (IN);
     binmode (OUT);
     $/=\$obj->{PNTBUFBYTES};
 
     my @BeginOffset;
    
     my $offset=0;
     my @TT;

   while (<IN>){ 
      my ($x,$y,$z,$ID)=unpack($obj->{PNTPACKSTR},$_);
    
      if ($x==-999999) {
          my $finishMe=$z;
          my $npts=@{$TT[$finishMe]}; # write the leaf index and number of points
          #$Npoints[$finishMe]=$npts; # write the leaf index and number of points
          $BeginOffset[$finishMe]=$offset;
          my $buf=pack("L2",$finishMe,$npts);  # two 32-bit unsigned integers (8 bytes total)
          print OUT "$buf";
          $offset=$offset+8;
          print "superFinishing $z\n";
          foreach  my $point (@{$TT[$finishMe]}){
             print OUT "$point";
             $offset=$offset+$obj->{PNTBUFBYTES};    
          }
          @{$TT[$finishMe]}=undef;
          $TT[$finishMe]=undef; 
       }else{
          my $index=$obj->getLeafIndex($x,$y);
          die "whoaa not original point in the tree $x, $y, $z, $index, $ID\n" if ($index < 0);
          push (@{$TT[$index]},$_);
       }

   }
   close(OUT);
   close(IN);
   $obj->{BEGINOFFSET}=\@BeginOffset;
   $/="\n";
   
}

     
#####################################################################
#
# sub getPoints
#
# after you have created the superfinlalized bin file, this method
#
# will return points within a circle defined by its center location
# and radius
#
# e.g.
#
# my ($xrf,$yrf,$zrf,$idrf,$dsqrf)=$tree->getPoints($xx,$yy,$radius);
#
# where $xrf... are references to arrays containing points found
# and their ID value, and squared distance from xx,yy to the point.#
#
#####################################################################
sub getPoints{
   my $obj=shift;

   my ($x,$y,$radius)=@_;
#print " rrr $x, $y,$radius\n";

   my @OFFSETS= @{$obj->{BEGINOFFSET}};
   my @X=();
   my @Y=();
   my @Z=();
   my @S=();
   my @DSQ=();
   
   my $rsq=$radius*$radius;

   # get a list of indices to search
   my $iref=$obj->getIndicesInCircle($x,$y,$radius);
   my @INDICES=@{$iref};
   return \@INDICES unless (@INDICES);
#print "incides @INDICES\n";
#sleep(1);

    # now get the points
    open FH3, "<$obj->{SFINALIZED}" or die " cant open the superfinalized file, did you make it?";
    binmode(FH3);

   foreach my $leaf (@INDICES){
   #    print "leaf is $leaf\n";
      my $offset=$OFFSETS[$leaf];
      my $buffer;
      
      # get the number of points and check the index
      seek(FH3,$offset,0);
      read(FH3,$buffer,8);
      my ($chkIndex,$npoints)=unpack('L2',$buffer);
      unless (defined $chkIndex){  # maybe incomplete file
         print "undefined chkIndx at offset $offset\n";
         next;     
      }
      unless ($chkIndex == $leaf){
          print "whoa $chkIndex does not match file $leaf at offset $offset\n";
          next;
      }
      foreach my $point (1..$npoints){
         read(FH3,$buffer,$obj->{PNTBUFBYTES});
         next unless ($buffer);
         my ($xp,$yp,$zp,$sp)=unpack($obj->{PNTPACKSTR},$buffer);
        
         my $dsq=($xp-$x)**2 + ($yp-$y)**2;

         next unless ($dsq <= $rsq);
         push @X, $xp;
         push @Y, $yp;
         push @Z, $zp;
         push @S, $sp;
         push @DSQ,$dsq;
      }
    }
    close(FH3);
    return (\@X,\@Y,\@Z,\@S,\@DSQ);
   

}



#####################################################################
#
# sub getPoints_sorted
#
# after you have created the superfinlalized bin file, this method
#
# will return points within a circle defined by its center location
# and radius
#
# e.g.
#
# my ($xrf,$yrf,$zrf,$idrf,$dsqrf)=$tree->getPoints($xx,$yy,$radius);
#
# where $xrf... are references to arrays containing points found
# and their ID value, and squared distance from xx,yy to the point.#
#
# sorted by dsq, closest point first.
#
#####################################################################
sub getPoints_sorted{
   my $obj=shift;

   my ($x,$y,$radius)=@_;
#print " rrr $x, $y,$radius\n";

   my @OFFSETS= @{$obj->{BEGINOFFSET}};
   my @X=();
   my @Y=();
   my @Z=();
   my @S=();
   my @DSQ=();
   
   my $rsq=$radius*$radius;

   # get a list of indices to search
   my $iref=$obj->getIndicesInCircle($x,$y,$radius);
   my @INDICES=@{$iref};
   return \@INDICES unless (@INDICES);
#print "incides @INDICES\n";
#sleep(1);

    # now get the points
    open FH3, "<$obj->{SFINALIZED}" or die " cant open the superfinalized file, did you make it?";
    binmode(FH3);

   foreach my $leaf (@INDICES){
   #    print "leaf is $leaf\n";
      my $offset=$OFFSETS[$leaf];
      my $buffer;
      
      # get the number of points and check the index
      seek(FH3,$offset,0);
      read(FH3,$buffer,8);
      my ($chkIndex,$npoints)=unpack('L2',$buffer);
      unless (defined $chkIndex){  # maybe incomplete file
         print "undefined chkIndx at offset $offset\n";
         next;     
      }
      unless ($chkIndex == $leaf){
          print "whoa $chkIndex does not match file $leaf at offset $offset\n";
          next;
      }
      foreach my $point (1..$npoints){
         read(FH3,$buffer,$obj->{PNTBUFBYTES});
         next unless ($buffer);
         my ($xp,$yp,$zp,$sp)=unpack($obj->{PNTPACKSTR},$buffer);
        
         my $dsq=($xp-$x)**2 + ($yp-$y)**2;

         next unless ($dsq <= $rsq);
         push @X, $xp;
         push @Y, $yp;
         push @Z, $zp;
         push @S, $sp;
         push @DSQ,$dsq;
      }
    }
    close(FH3);
    # sort by ascending distance 
    my @SortedI=sort { $DSQ[$a] <=> $DSQ[$b] } 0..$#DSQ;
    @X=@X[@SortedI];
    @Y=@Y[@SortedI];
    @Z=@Z[@SortedI];
    @S=@S[@SortedI];
    @DSQ=@DSQ[@SortedI];
    return (\@X,\@Y,\@Z,\@S,\@DSQ);
}




1;
