# tools for polygons and polylines etc.
#
package PolyTools;
use strict;
use warnings;

   
#########################################################################
# sub pointInPoly     
#
# the subroutine will determine if a point ($x,$y) is in a polygon 
# described by arrays @px,@py, note: polygon must be closed
#
# usage:
#
# $inpoly=PolyTools::pointInPoly($x,$y,\@px,\@py);
#
# returns $inpoly=1 if the point is in the polygon, $inpoly=0 otherwise
#
#########################################################################
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



#########################################################################
# sub readKmlPoly {  
#
# this subroutine reads a kml file and extracts the coordinates 
# from the first <coordinates> tag (typically a polygon)
#
# usage:
#
# ($pxref,$pyref)=PolyTools::readKmlPoly($kmlName);
#
# $kmlName is the name of the kml file
#
# returns refernces to arrays that store the polygon vertices
#
#########################################################################
sub readKmlPoly { 

   my $polygonFile=shift;
   my @px;           # dereference to access arrays
   my @py;

   open PFILE, "<$polygonFile"  or die "cannot open $polygonFile\n";

   # read the data, assume first point in repeated as last

   my $inCoord=0;
   my $coordString='';

   # try to parse the coordinates data from the kml file

   while (<PFILE>) {
      chomp;
      $_ =~ s/^\s+//;
      $_ =~ s/\s+$//;
      if   ($_ =~ /<coordinates>/) {
         $inCoord=1;
      }
      if ($inCoord==1) {
	   $coordString="$coordString"." $_";
	   if ($_ =~ /<\/coordinates>/) {
		   $inCoord=2;
           }
      }
      last if ($inCoord==2);
   #   print "$coordString\n";
   #   sleep(1);
   }

   # remove the tags from the string
   $coordString =~ /<coordinates>(.*)<\/coordinates>/; 
   $coordString = $1;
   $coordString =~ s/^\s+//;
   $coordString =~ s/\s+$//;

   my @data=split(/\s+/,$coordString);

   foreach my $coord (@data) {
        my ($x,$y,$z)=split(/,/,$coord);
        push (@px,$x);
        push (@py,$y);
   }     

   close PFILE;
   return (\@px,\@py);
} # end readKMLPoly



#########################################################################
# sub readKmlPolys {  
#
# this subroutine reads a kml file and extracts the coordinates 
# from the first <coordinates> tag (typically a polygon)
#
# usage:
#
# ($pxref,$pyref)=PolyTools::readKmlPoly($kmlName);
#
# $kmlName is the name of the kml file
#
# returns refernces to arrays that store the polygon vertices
#
#########################################################################
sub readKmlPolys { 

   my $polygonFile=shift;
   my @px;           # dereference to access arrays
   my @py;
   my @PX;
   

   open PFILE, "<$polygonFile"  or die "cannot open $polygonFile\n";

   # read the data, assume first point in repeated as last

   my $inCoord=0;
   my $coordString='';

   # try to parse the coordinates data from the kml file

   while (<PFILE>) {
      chomp;
      $_ =~ s/^\s+//;
      $_ =~ s/\s+$//;
      if   ($_ =~ /<coordinates>/) {
         $inCoord=1;
      }
      if ($inCoord==1) {
	   $coordString="$coordString"."$_";
	   if ($_ =~ /<\/coordinates>/) {
		   $inCoord=2;
           }
      }
      last if ($inCoord==2);
   
   }

   # remove the tags from the string
   $coordString =~ /<coordinates>(.*)<\/coordinates>/; 
   $coordString = $1;

   my @data=split(/\s+/,$coordString);

   foreach my $coord (@data) {
        my ($x,$y,$z)=split(/,/,$coord);
        push (@px,$x);
        push (@py,$y);
   }     

   close PFILE;
   return (\@px,\@py);
} # end readKMLPolys


#######################################
# reads a kml file and returns
# ref to an array of placemarks
#

sub readKmlPlacemarks{

  my $kmlfile=shift;
  $/='</Placemark>';  # setting the record separator to the end placemark tag
  my @PMs;
  open KML, "<$kmlfile" or die "ERROR: PolyTools::readKmlPlacemarks:  cannot open $kmlfile\n";
  while (<KML>){
      chomp;
      $_ =~ s/.*<Placemark>?//;   # remove the start placemark tag from the string
      push @PMs, $_;
  }
  return \@PMs;
}
  






#######################################
# reads a kml file and returns
# ref to an array of placemarks
#

sub readKmlPlacemarks_2{

  my $kmlfile=shift;
  $/='</Placemark>';  # setting the record separator to the end placemark tag
  my @PMs;
  open KML, "<$kmlfile" or die "ERROR: PolyTools::readKmlPlacemarks:  cannot open $kmlfile\n";
  while (<KML>){
      chomp;
      $_ =~ s/.*<Placemark>?//s;   # remove the start placemark tag from the string
      my $pmarkString=$_;

      # extract coordinates
      # remove the tags from the string
      $_ =~ m/<coordinates>(.*)<\/coordinates>/s; 
      my $coordString = $1;
      $coordString =~ s/^\s+//s;
      $coordString =~ s/\s+$//s;
      my @data=split(/\s+/,$coordString);
      my @px;
      my @py;
      foreach my $coord (@data) {
         my ($x,$y,$z)=split(/,/,$coord);
         push (@px,$x);
         push (@py,$y);
      }     

      my %pm;
      $pm{'pmarkstring'}=$pmarkString;
      $pm{'coordinates'}=[\@px, \@py];

      #extract description
      $_ =~ m/<description>(.*)<\/description>/s; 
      my $desc=$1;
      $pm{'description'}=$desc;
    


      push @PMs, \%pm;
  }
  return \@PMs;
}






#########################################################################
# sub polylineInterp {  
#
# usage:
#
# (@pxo,@pyo)=PolyTools::polylineInterp(\@pxi,\@pyi,$nsegs);
#
# @pxi,@pyi are the input poly line (arrays holding x,y coordinates)
# $nsegs is the desired number of segments for the output polyline
#
# returns refernces to arrays that store the polygon vertices
#
########################################################################
sub polylineInterp {

   # get input arguments
   my @pxi = @{$_[0]}; # dereference to get arrays from argument
   my @pyi = @{$_[1]};
   my $nsegs=$_[2];


   # these will hold output
   my @pxo;
   my @pyo;
   $pxo[0]=$pxi[0];
   $pyo[0]=$pyi[0];

   # calculate the total length of the polyline and the segment size
   my $len=&polylineLength(\@pxi,\@pyi);
   print "len $len\n";
   my $segLength=$len/$nsegs;

   my $n=0;
   my $nlen=$segLength;

   foreach my $i (1..$#pxi) {
     my @spxi=@pxi[0..$i];
     my @spyi=@pyi[0..$i];
     my $len=&polylineLength(\@spxi,\@spyi);
     my $dx=$pxi[$i]-$pxi[$i-1];
     my $dy=$pyi[$i]-$pyi[$i-1];
     my $ds=($dx**2 + $dy**2)**0.5;
   
     while ($len>$nlen) {
        my $s=$len-$nlen;
        $n++;
	$pxo[$n]=$pxi[$i]-($dx/$ds)*$s;
	$pyo[$n]=$pyi[$i]-($dy/$ds)*$s;
	$nlen=$nlen+$segLength;
     }
   }
   $pxo[$nsegs]=$pxi[$#pxi];
   $pyo[$nsegs]=$pyi[$#pyi];

   return (\@pxo,\@pyo);

}



#########################################################################
# sub polylineLength {  
#
# usage:
#
# ($length)=PolyTools::polylineInterp(\@px,\@py);
#
#
# returns scalar length of poly line (sum of segment lengths)
#
########################################################################
sub polylineLength{

   my @px = @{$_[0]}; # dereference to get arrays from argument
   my @py = @{$_[1]};

   my $nsegs=$#px;
print "nsegs $nsegs\n";
   my $i=1;
   my $length=0;
   while ($i<=$nsegs){
      my $ds=( ($px[$i]-$px[$i-1])**2.0  + ($py[$i]-$py[$i-1])**2.0 )**0.5;
      $length=$length + $ds;
      $i++;
   }
   return $length;
}




#########################################################################
# sub boxInPoly     
#
# the subroutine will determine if a box is in a polygon 
# described by arrays @px,@py, note: polygon must be closed
#
# box is described as to poijts ($xmin,$ymin,$xmax,$ymax)
#
# usage:
#
# $inpoly=PolyTools::boxInPoly($xmin,$ymin,$xmax,$ymax,\@px,\@py);
#
# returns the number of corner points that are within the polygon
#
#########################################################################
sub boxInPoly {

     my ($xmin,$ymin,$xmax,$ymax,$pxref,$pyref)=@_;
     my $inpoly=0;
   
     # check southwest
     my $x=$xmin;
     my $y=$ymin;
     $inpoly++ if (pointInPoly($x,$y,$pxref,$pyref));
      
     # check southeast
     $x=$xmax;
     $y=$ymin;
     $inpoly++ if (pointInPoly($x,$y,$pxref,$pyref));

     # check northeast
     $x=$xmax;
     $y=$ymax;
     $inpoly++ if (pointInPoly($x,$y,$pxref,$pyref));

     #check northwest
     $x=$xmin;
     $y=$ymax;
     $inpoly++ if (pointInPoly($x,$y,$pxref,$pyref));
     
     return $inpoly;
}


#########################################################################
# sub polyInBox    
#
# the subroutine will determine if a polygin is in a box 
# described by arrays @px,@py, note: polygon must be closed
#
# box is described as to poijts ($xmin,$ymin,$xmax,$ymax)
#
# usage:
#
# $inpoly=PolyTools::polyInBox($xmin,$ymin,$xmax,$ymax,\@px,\@py);
#
# returns the number of polygon verticies in the box
#
#########################################################################
sub polyInBox {

     my ($xmin,$ymin,$xmax,$ymax,$pxref,$pyref)=@_;
     my $inpoly=0;

     my @PX=@{$pxref};
     my @PY=@{$pyref};

     my $inbox=0;

     my $j=0;
     foreach my $x (@PX) {
        my $y=$PY[$j];
	$j++;

	next unless ( $x <= $xmax);
	next unless ( $y <= $ymax);
	next unless ( $x >= $xmin);
	next unless ( $y >= $ymin);
        $inbox++;
     }
   
     return $inbox;
}


1;
