#!/usr/bin/env perl



use strict;
use warnings;
use lib 'c:\ourPerl';    # change this to point to the path to your ourPerl directory
use AdcircUtils::AdcGrid;
use AdcircUtils::ElementQuadTree;
use Geometry::PolyTools;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;

#################### some set file names

my $fort14 ='fort.14';  # name of ADCIRC grid file
my $stations='elev_stat.151';  # name of file containing 


###########################


my $treefile='treefile.tree';
my $tree;



# load the grid
my  $adcGrid=AdcGrid->new();
$adcGrid->loadGrid($fort14);


unless (-e $treefile){
  # make the quadtree
  $tree=ElementQuadTree->new_from_adcGrid(-MAXELEMS=>50000, -ADCGRID=>$adcGrid);
  #store it
  $tree->store_tree($treefile);
}else{
  $tree=ElementQuadTree->retrieve_tree($treefile);
}


#$tree->interpPixels();
#$tree->setDEMBLOCK(
#                    -SETNAME=>'belv',
                    #-ZDATA=>\@ZDATA,  
#                    -CLIM1=>-10,
#                    -CLIM2=>10,
#                    -PALETTE=>'c:\myPerl\jet.txt',
#                    -NUMCOLORS=>20,     # number of colors to display in png files for ovs
#                    -MULT_ADJUST=>-1.0
#                   );
#$tree->writeKMLOverlay();
#$tree->makeColorbar('belv');


# read the stations
open IN, "<$stations";
<IN>;

my $rad=0.03;
my $k=0;
while (<IN>){
    print "line $_\n";
   chomp;
   $k++;
   $_ =~ s/^\s+//;
   my ($coords,$desc)=split(/!/,$_);

   print "coods is $coords\n";
   print "desc is $desc\n";
   $desc =~ s/^\s+//;
   #my ($source)=split(/\s+/,$desc);
   #next unless ( ($source eq 'USACE') or ($source eq 'NOAA') or ($source eq 'USGS') );
   my $setName="station-$k";
   
   $coords =~ s/^\s+//;
   my ($xx, $yy) = split(/\s+/,$coords);

   my $eles_ref=$tree->findElements(-XX=>$xx,-YY=>$yy,-RADIUS=>$rad);

   next unless (@{$eles_ref});
   
   my $north=$yy+$rad;
   my $south=$yy-$rad;
   my $east=$xx+$rad;
   my $west=$xx-$rad;

   my $tree2=ElementQuadTree->new(
               -NORTH=>$north,   # the region for the tree
               -SOUTH=>$south,
               -EAST =>$east,
               -WEST =>$west,
               -XNODE=>$tree->{XNODE},   # references to the node position table arrays (x,y,z)
               -YNODE=>$tree->{YNODE},   # these are indexed by node number, so arrays should
               -ZNODE=>$tree->{ZNODE},   # have some value at index zero (could be undef)
               -MAXELEMS=>500 # maximum number of elements per tree node
                          );

   foreach my $eid (@{$eles_ref}){
      my ($n1,$n2, $n3)=$adcGrid->getElement($eid);
      $tree2->addElement(-ID=>$eid,-N1=>$n1,-N2=>$n2,-N3=>$n3);
   }
   $tree2->interpPixels();
   $tree2->setDEMBLOCK(
                    -SETNAME=>$setName,
                    #-ZDATA=>\@ZDATA,  
                    -CLIM1=>-2,
                    -CLIM2=>2,
                    -PALETTE=>'c:\ourPerl\jet.txt',
                    -NUMCOLORS=>9,     # number of colors to display in png files for overlays
                    -MULT_ADJUST=>-1.0
                   );
   $tree2->writeKMLOverlay();
   $tree2->makeColorbar('elev');
   $tree2->writeKMLPoly('description');
   

   my $zip = Archive::Zip->new();
   my $setDir="$setName".'_Files';
print "setdir is $setDir\n";
   my $dir_member = $zip->addTree( $setDir, $setDir );

   # add the doc.file
   my $file_member = $zip->addFile( 'doc.kml' );

   # write it
    my $kmzName="$setName".'.kmz';
    unless ( $zip->writeToFileNamed($kmzName) == AZ_OK ) {
       die 'write error';
   }

   # clean up
   unlink ('doc.kml');
   rmtree($setDir);

   $zip = Archive::Zip->new();
   $setDir='poly_Files';
   $dir_member = $zip->addTree( $setDir, $setDir );

   # add the doc.file
   $file_member = $zip->addFile( 'Elements_doc.kml' );

   # write it
   $kmzName="$setName".'_elements.kmz';
    unless ( $zip->writeToFileNamed($kmzName) == AZ_OK ) {
       die 'write error';
   }

   # clean up
   unlink ('Elements_doc.kml');
   rmtree($setDir);


}
