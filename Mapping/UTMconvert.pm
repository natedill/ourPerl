package UTMconvert;
use strict;
use warnings;
use Math::Trig;

# translated to Perl from Rafael Palacios Matlab scripts 
# utm2deg.m and deg2utm.m Translated by Nate Dill.

###################################################
#
# convert utm coordinates to geographic
#
# e.g.
#
# ($lon,$lat)=utm2deg($x,$y,$zone)
#
# $lat,$lon,$x,$y are scalars or array refs
# as appropriate. 
#
# $x,$ must be meters
#
# $ zone is a 4 character string (e.g. "19 T")
#
#####################################################

sub utm2deg{
   my ($xref,$yref,$zone)=@_;
   
   my @X;
   my @Y;
   my @LON;
   my @LAT;

   # some constants for the ellipsoid
   my $sa = 6378137.000000 ;  # semi-major axis
   my $sb = 6356752.314245;   # semi-minor axis
   my $e2 = ((($sa**2.0)-($sb**2.0))**0.5)/$sb;
   my $e2sq= $e2**2.0;
   my $c = ( $sa ** 2 ) / $sb;
   my $pi=4.0*atan2(1,1);
   my $alfa = ( 0.75 ) * $e2sq;
   my $beta = ( 5.0 / 3.0 ) * $alfa ** 2.0;
   my $gama = ( 35.0 / 27.0 ) * $alfa ** 3.0;

   # check to see if we need to dereference
   my $isarray=1;
   if (ref($xref)) {
      @X=@{$xref};
      @Y=@{$yref};
   }else{
      $X[0]=$xref;
      $Y[0]=$yref;
      $isarray=0;
   }

   #check the zone number
   my $zoneNum=substr($zone,0,2); 
   if (($zoneNum < 1) or ($zoneNum >60 )) {
       print "bad zone number\n";
       return (9999,9999);
   }
   my $S=($zoneNum*6.0)-183;
  
   # check the zone letter
   my $hemi; 
   if ($zone =~ m/[c-hj-m]/i){
        $hemi='S';
   }elsif ($zone =~ m/[np-x]/i) {
        $hemi='N';
   }else{
	print "bad zone letter\n";
	return (9999,9999);
   }

  
   # adjust values for offset
   for my $i (0 .. $#Y){
       $Y[$i]=$Y[$i]-10000000 if ($hemi eq 'S');
       $X[$i]=$X[$i]-500000;
   }



   # loop over points and do conversion
   for my $j (0 .. $#X){
      my $lat =  $Y[$j] / ( 6366197.724 * 0.9996 );    
      my $v = ( $c / ( ( 1 + ( $e2sq * ( cos($lat) ) ** 2.0 ) ) )**0.5 )*0.9996;
      my $a = $X[$j] / $v;
      my $a1 = sin( 2.0 * $lat );
      my $a2 = $a1 * ( cos($lat) ) ** 2;
      my $j2 = $lat + ( $a1 / 2.0 );
      my $j4 = ( ( 3 * $j2 ) + $a2 ) / 4.0;
      my $j6 = ( ( 5 * $j4 ) + ( $a2 * ( cos($lat) ) ** 2.0) ) / 3.0;

      my $Bm = 0.9996 * $c * ( $lat - $alfa * $j2 + $beta * $j4 - $gama * $j6 );
      my $b = ( $Y[$j] - $Bm ) / $v;
      my $Epsi = ( ( $e2sq * $a** 2.0 ) / 2.0 ) * ( cos($lat) )** 2.0;
      my $Eps = $a * ( 1.0 - ( $Epsi / 3.0 ) );
      my $nab = ( $b * ( 1.0 - $Epsi ) ) + $lat;
      my $senoheps = ( exp($Eps) - exp(-$Eps) ) / 2.0;
      my $Delt = atan($senoheps / cos($nab) );
      my $TaO = atan(cos($Delt) * tan($nab));
      $LON[$j] = ($Delt *(180 / $pi ) ) + $S;
      $LAT[$j] = ( $lat + ( 1.0 + $e2sq* (cos($lat)** 2.0) - ( 1.5 ) * $e2sq * sin($lat) * cos($lat) * ( $TaO - $lat ) ) * ( $TaO - $lat ) ) * (180.0 / $pi);
   
    }

    if ($isarray){
	    return (\@LON,\@LAT);
    }else{
	    return ($LON[0],$LAT[0]);
    }

}



###################################################
#
# convert geographic coordinates to UTM
#
# e.g.
#
# ($x,$y,$zone)=deg2utm($lon,$lat)
#
# $lat,$lon,$x,$y are scalars or array refs
# as appropriate. 
#
# $x,$y must be meters
#
# $ zone is a 4 character string (e.g. "19 T")
#
#####################################################

sub deg2utm{
   my ($lonref,$latref,$zone)=@_;
   
   my @X;
   my @Y;
   my @LON;
   my @LAT;
   my @ZONE;

   my $forceZone=0;
   $forceZone++ if (defined $zone);
   if ($forceZone) {print "forcing conversion in zone $zone\n";}

   # some constants for the ellipsoid
   my $sa = 6378137.000000 ;  # semi-major axis
   my $sb = 6356752.314245;   # semi-minor axis
   my $e2 = ((($sa**2.0)-($sb**2.0))**0.5)/$sb;
   my $e2sq= $e2**2.0;
   my $c = ( $sa ** 2 ) / $sb;
   my $pi=4.0*atan2(1,1);

   my $alfa =  0.75 * $e2sq;
   my $beta = ( 5. / 3. ) * $alfa ** 2.;
   my $gama = ( 35. / 27. ) * $alfa ** 3.;


   # check to see if we need to dereference
   my $isarray=1;
   if (ref($lonref)) {
      @LON=@{$lonref};
      @LAT=@{$latref};
   }else{
      $LON[0]=$lonref;
      $LAT[0]=$latref;
      $isarray=0;
   }


   for my $j (0 .. $#LON){

      my $la=$LAT[$j];
      my $lo=$LON[$j];
      my $latRads=$la*$pi/180.;
      my $lonRads=$lo*$pi/180.;
 
      my $zoneNumber=int($lo/6+31);
      $zoneNumber=substr($zone,0,2) if ($forceZone);
      my $s= $zoneNumber*6-183;

      my $deltas=$lonRads-$s*$pi/180;

    #  Huso = fix( ( lo / 6 ) + 31);
    #  S = ( ( Huso * 6 ) - 183 );
    #  deltaS = lon - ( S * ( pi / 180 ) );
      my $letr='A';
      if ($la < -72 ){$letr='C';}
      elsif ($la<-64){$letr='D';}
      elsif ($la<-56){$letr='E';}
      elsif ($la<-48){$letr='F';}
      elsif ($la<-40){$letr='G';}
      elsif ($la<-32){$letr='H';}
      elsif ($la<-24){$letr='J';}
      elsif ($la<-16){$letr='K';}
      elsif ($la<-8) {$letr='L';}
      elsif ($la<0)  {$letr='M';}
      elsif ($la<8)  {$letr='N';}
      elsif ($la<16) {$letr='P';}
      elsif ($la<24) {$letr='Q';}
      elsif ($la<32) {$letr='R';}
      elsif ($la<40) {$letr='S';}
      elsif ($la<48) {$letr='T';}
      elsif ($la<56) {$letr='U';}
      elsif ($la<64) {$letr='V';}
      elsif ($la<72) {$letr='W';}
      else {$letr='X';}
   
      my $a=cos($latRads)*sin($deltas);
      my $epsilon = 0.5 * log( ( 1 +  $a) / ( 1 - $a ) );
      my $nu = atan( tan($latRads) / cos($deltas) ) - $latRads;
      my $v = ( $c / ( ( 1 + ( $e2sq * ( cos($latRads) ) ** 2 ) ) ) ** 0.5 ) * 0.9996;
      my $ta = ( $e2sq / 2. ) * $epsilon ** 2. * ( cos($latRads) ) ** 2;
      my $a1 = sin( 2 * $latRads );
      my $a2 = $a1 * ( cos($latRads) ) ** 2.;
      my $j2 = $latRads + ( $a1 / 2.0 );
      my $j4 = ( ( 3. * $j2 ) + $a2 ) / 4.;
      my $j6 = ( ( 5. * $j4 ) + ( $a2 * ( cos($latRads) ) ** 2.) ) / 3.;
      my $Bm = 0.9996 * $c * ( $latRads - $alfa * $j2 + $beta * $j4 - $gama * $j6 );
      $X[$j] = $epsilon * $v * ( 1. + ( $ta / 3. ) ) + 500000;
      my $yy = $nu * $v * ( 1 + $ta ) + $Bm;

      $yy=9999999+$yy if ($yy < 0);
      $Y[$j]=$yy;
      $ZONE[$j]="$zoneNumber $letr";
   }
 
   if ($isarray) {
    return (\@X,\@Y,\@ZONE);
   }else{
    return ($X[0],$Y[0],$ZONE[0]);
  }


}


1;


