#
# a perl version of the spcs83 fortran program from the NGS
#
# translated from fortran by Nathan Dill, 2014
#
# example :
#
#  use lib 'c:\myPerl';
#  use Mapping::P_spcs83;
#
#  # northing and easting in meters
# 
#  my $x=2645873.20/3.2808333;
#  my $y=465315.49/3.2808333;
#
#  my ($lon,$lat)=P_spcs83::sp2geo($x,$y,'LA S');
#
#  my ($xx,$yy)=P_spcs83::geo2sp($lon,$lat,'LA S');
#
#
#  my $xxx=$xx*3.2808333;
#  my $yyy=$yy*3.2808333;
#
#  print "$lon,$lat\n";
#  print "$xxx, $yyy\n";


package P_spcs83;

use warnings;
use strict;
use Math::Trig;

sub sp2geo{
   my ($xref,$yref,$zone)=@_;
   
   my @X;
   my @Y;
   my @LON;
   my @LAT;

   my $PI=3.1415926535897932;
   my $RAD=180.0/$PI;
   my $ER=6378137.0;
   my $RF=298.2572221010;
   my $F=1.0/$RF;
   my $ESQ=($F+$F-$F*$F);


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

   # deal with the zone and load the constants
   #my $IZ = get_IZ($zone);

   my $AP = get_AP($zone);

   my @SPCC = get_SPCC($zone);
print "AP $AP, zone $zone, SPCC @SPCC\n";
  

   if ($AP eq 'L'){
      my ($CM,$EO,$NB,$FIS,$FIN,$FIB)=@SPCC;
      $CM=$CM/$RAD;
      $FIS=$FIS/$RAD;
      $FIN=$FIN/$RAD;
      $FIB=$FIB/$RAD;

      # get constants
      my ($SINFO,$RB,$K,$KO,$NO,$G)=lconst($ER,$RF,$FIS,$FIN,$FIB,$ESQ,$NB);


      my $jkk=0;
      foreach my $x (@X) {
          my $y=$Y[$jkk];
          my ($CONV,$E,$KP);
          ($LON[$jkk],$LAT[$jkk],$CONV,$E,$KP)=lamr1($y,$x,$CM,$EO,$NB,$SINFO,$RB,$K,$ER,$ESQ);
        
           #lon(jkk)=rad2deg(LON); lat(jkk)=rad2deg(LAT);
          $LON[$jkk]=$LON[$jkk] * $RAD; 
          $LAT[$jkk]=$LAT[$jkk] * $RAD;
          $jkk++;

      }
   }elsif ($AP eq 'T'){
      my ($CM,$FE,$OR,$SF,$FN)=@SPCC;
      $CM=$CM/$RAD;
      $OR=$OR/$RAD;
      $SF=1-1/$SF;

      $SF=1.0 if ($zone eq 'HI 5');

       my ($EPS,$R,$SO,$V0,$V2,$V4,$V6) =tconpc($SF,$OR,$ER,$ESQ);
        
       foreach my $x (@X) {
           my $y=shift (@Y);
           my ($lat,$lon,$CONV,$KP) = tmgeod($y,$x,$EPS,$CM,$FE,$SF,$SO,$R,$V0,$V2,$V4,$V6,$FN,$ER,$ESQ);
           push @LAT, $lat*$RAD;
           push @LON, $lon*$RAD;
       }


   }else{
     print "AP =  $AP not ready yet sp2geo\n";
     sleep(100); 
     die;
   }


    if ($isarray){
	    return (\@LON,\@LAT);
    }else{
	    return ($LON[0],$LAT[0]);
    }


}# end sp2geo

# returns easting,northing in meters
sub geo2sp{
   my ($lonref,$latref,$zone)=@_;

   my @X;
   my @Y;
   my @LON;
   my @LAT;

   my $PI=3.1415926535897932;
   my $RAD=180.0/$PI;
   my $ER=6378137.0;
   my $RF=298.2572221010;
   my $F=1.0/$RF;
   my $ESQ=($F+$F-$F*$F);
   my $E=$ESQ**0.5;
  
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



   # get zone constants
   my $AP = get_AP($zone);
   my @SPCC = get_SPCC($zone);
  
   if ($AP eq 'L'){
      my ($CM,$EO,$NB,$FIS,$FIN,$FIB)=@SPCC;
      $CM=$CM/$RAD;
      $FIS=$FIS/$RAD;
      $FIN=$FIN/$RAD;
      $FIB=$FIB/$RAD;

      # get constants
      my ($SINFO,$RB,$K,$KO,$NO,$G)=lconst($ER,$RF,$FIS,$FIN,$FIB,$ESQ,$NB);


      my $jkk=0;
      foreach my $lon (@LON) {
          my $lat=$LAT[$jkk];
          my $FI=$lat/$RAD;
          my $LAM=$lon/$RAD;
  
          my $KP;
          ($Y[$jkk],$X[$jkk],$KP)=lamd1($FI,$LAM,$CM,$SINFO,$ER,$ESQ,$EO,$NB,$RB,$E,$K);
          $jkk++;

      }

   }else{
     print "AP =  $AP not ready yet geo2sp\n";
     sleep(100); 
     die;
   } 


    if ($isarray){
	    return (\@X,\@Y);
    }else{
	    return ($X[0],$Y[0]);
    }



}#end geo2sp



sub tconpc{

# C     SccsID = "@(#)tconpc.for	1.2	01/28/02"
#function [EPS,R,SO,V0,V2,V4,V6] = tconpc(SF,OR,ER,ESQ)
#
# ***          TRANSVERSE MERCATOR PROJECTION               ***
# *** CONVERSION OF GRID COORDS TO GEODETIC COORDS
# *** REVISED SUBROUTINE OF T. VINCENTY  FEB. 25, 1985
# ************** SYMBOLS AND DEFINITIONS ***********************
# *** ER IS THE SEMI-MAJOR AXIS FOR GRS-80
# *** SF IS THE SCALE FACTOR AT THE CM
# *** SO IS THE MERIDIANAL DISTANCE (TIMES THE SF) FROM THE
# ***       EQUATOR TO SOUTHERNMOST PARALLEL OF LAT. FOR THE ZONE
# *** R IS THE RADIUS OF THE RECTIFYING SPHERE
# *** U0,U2,U4,U6,V0,V2,V4,V6 ARE PRECOMPUTED CONSTANTS FOR
# ***   DETERMINATION OF MERIDIANAL DIST. FROM LATITUDE
# *** OR IS THE SOUTHERNMOST PARALLEL OF LATITUDE FOR WHICH THE
# ***       NORTHING COORD IS ZERO AT THE CM
# **************************************************************
#
#       IMPLICIT DOUBLE PRECISION(A-H,O-Z)

my ($SF,$OR,$ER,$ESQ)=@_;



my $F     =1.0/298.2572221010;
my $EPS   =$ESQ/(1.0-$ESQ);
my $PR    =(1.0-$F)*$ER;
my $EN    =($ER-$PR)/($ER+$PR);
my $EN2   =$EN*$EN;
my $EN3   =$EN*$EN*$EN;
my $EN4   =$EN2*$EN2;

my $C2    =-3.0*$EN/2.0+9.0*$EN3/16.0;
my $C4    =15.0*$EN2/16.0-15.0*$EN4/32.0;
my $C6    =-35.0*$EN3/48.0;
my $C8    =315.0*$EN4/512.0;
my $U0    =2.0*($C2-2.0*$C4+3.0*$C6-4.0*$C8);
my $U2    =8.0*($C4-4.0*$C6+10.0*$C8);
my $U4    =32.0*($C6-6.0*$C8);
my $U6    =128.0*$C8;

 $C2    =3.0*$EN/2.0-27.0*$EN3/32.0;
 $C4    =21.0*$EN2/16.0-55.0*$EN4/32.0;
 $C6    =151.0*$EN3/96.0;
 $C8    =1097.0*$EN4/512.0;
my $V0    =2.0*($C2-2.0*$C4+3.0*$C6-4.0*$C8);
my $V2    =8.0*($C4-4.0*$C6+10.0*$C8);
my $V4    =32.0*($C6-6.0*$C8);
my $V6    =128.0*$C8;

my $R     =$ER*(1.0-$EN)*(1.0-$EN*$EN)*(1.0+2.250*$EN*$EN+(225.0/64.0)*$EN4);
my $COSOR =cos($OR);
my $OMO   =$OR+sin($OR)*$COSOR*($U0+$U2*$COSOR*$COSOR+$U4*$COSOR**4+$U6*$COSOR**6);
my $SO    =$SF*$R*$OMO;

return ($EPS,$R,$SO,$V0,$V2,$V4,$V6)

}



sub tmgeod{
# my ($lat,$lon,$CONV,$KP) = tmgeod($y,$x,$EPS,$CM,$FE,$SF,$SO,$R,$V0,$V2,$V4,$V6,$FN,$ER,$ESQ);
# C     SccsID = "@(#)tmgeod.for	1.2	01/28/02"
#function [LAT,LON,CONV,KP] = ...
#    tmgeod(N,E,EPS,CM,FE,SF,SO,R,V0,V2,V4,V6,FN,ER,ESQ)
#
# ***          TRANSVERSE MERCATOR PROJECTION               ***
# *** CONVERSION OF GRID COORDS TO GEODETIC COORDS
# *** REVISED SUBROUTINE OF T. VINCENTY  FEB. 25, 1985
# ************** SYMBOLS AND DEFINITIONS ***********************
# *** LATITUDE POSITIVE NORTH, LONGITUDE POSITIVE WEST.  ALL
# ***          ANGLES ARE IN RADIAN MEASURE.
# *** LAT,LON ARE LAT. AND LONG. RESPECTIVELY
# *** N,E ARE NORTHING AND EASTING COORDINATES RESPECTIVELY
# *** K IS POINT SCALE FACTOR
# *** ER IS THE SEMI-MAJOR AXIS FOR GRS-80
# *** ESQ IS THE SQUARE OF THE 1ST ECCENTRICITY
# *** E IS THE 1ST ECCENTRICITY
# *** CM IS THE CENTRAL MERIDIAN OF THE PROJECTION ZONE
# *** FE IS THE FALSE EASTING VALUE AT THE CM
# *** CONV IS CONVERGENCE
# *** EPS IS THE SQUARE OF THE 2ND ECCENTRICITY
# *** SF IS THE SCALE FACTOR AT THE CM
# *** SO IS THE MERIDIANAL DISTANCE (TIMES THE SF) FROM THE
# ***       EQUATOR TO SOUTHERNMOST PARALLEL OF LAT. FOR THE ZONE
# *** R IS THE RADIUS OF THE RECTIFYING SPHERE
# *** U0,U2,U4,U6,V0,V2,V4,V6 ARE PRECOMPUTED CONSTANTS FOR
# ***   DETERMINATION OF MERIDIANAL DIST. FROM LATITUDE
# ***
# *** THE FORMULA USED IN THIS SUBROUTINE GIVES GEODETIC ACCURACY
# *** WITHIN ZONES OF 7 DEGREES IN EAST-WEST EXTENT.  WITHIN STATE
# *** TRANSVERSE MERCATOR PROJECTION ZONES, SEVERAL MINOR TERMS OF
# *** THE EQUATIONS MAY BE OMMITTED (SEE A SEPARATE NGS PUBLICATION).
# *** IF PROGRAMMED IN FULL, THE SUBROUTINE CAN BE USED FOR
# *** COMPUTATIONS IN SURVEYS EXTENDING OVER TWO ZONES.
# ***********************************************************************
#
#       IMPLICIT DOUBLE PRECISION(A-H,K-Z)

my ($N,$E,$EPS,$CM,$FE,$SF,$SO,$R,$V0,$V2,$V4,$V6,$FN,$ER,$ESQ)=@_;

my $OM=($N-$FN+$SO)/($R*$SF);
my $COSOM=cos($OM);
my $FOOT=$OM+sin($OM)*$COSOM*($V0+$V2*$COSOM*$COSOM+$V4*$COSOM**4+$V6*$COSOM**6);
my $SINF=sin($FOOT);
my $COSF=cos($FOOT);
my $TN=$SINF/$COSF;
my $TS=$TN*$TN;
my $ETS=$EPS*$COSF*$COSF;
my $RN=$ER*$SF/sqrt(1.0-$ESQ*$SINF*$SINF);
my $Q=($E-$FE)/$RN;
my $QS=$Q*$Q;
my $B2=-$TN*(1.0+$ETS)/2.0;
my $B4=-(5.0+3.0*$TS+$ETS*(1.0-9.0*$TS)-4.0*$ETS*$ETS)/12.0;
my $B6=(61.0+45.0*$TS*(2.0+$TS)+$ETS*(46.0-252.0*$TS-60.0*$TS*$TS))/360.0;
my $B1=1.0;
my $B3=-(1.0+$TS+$TS+$ETS)/6.0;
my $B5=(5.0+$TS*(28.0+24.0*$TS)+$ETS*(6.0+8.0*$TS))/120.0;
my $B7=-(61.0+662.0*$TS+1320.0*$TS*$TS+720.0*$TS**3)/5040.0;
my $LAT=$FOOT+$B2*$QS*(1.0+$QS*($B4+$B6*$QS));
my $L=$B1*$Q*(1.0+$QS*($B3+$QS*($B5+$B7*$QS)));
my $LON=-$L/$COSF+$CM;
# C*********************************************************************
# C     COMPUTE CONVERENCE AND SCALE FACTOR
my $FI=$LAT;
my $LAM = $LON;
my $SINFI=sin($FI);
my $COSFI=cos($FI);
my $L1=($LAM-$CM)*$COSFI;
my $LS=$L1*$L1;
# C
# C*** CONVERGENCE
my $C1=-$TN;
my $C3=(1.+3.*$ETS+2.*$ETS**2)/3;
my $C5=(2.-$TS)/15;
my $CONV=$C1*$L1*(1.+$LS*($C3+$C5*$LS));
# C
# C*** POINT SCALE FACTOR
my $F2=(1.+$ETS)/2;
my $F4=(5.-4.*$TS+$ETS*( 9.-24.*$TS))/12;
my $KP=$SF*(1.+$F2*$LS*(1.+$F4*$LS));

return ($LAT,$LON,$CONV,$KP);

}







sub lamd1{
#function [NORTH,EAST,KP]=lamd1(FI,LAM,CM,SINFO,ER,ESQ,EO,NB,RB,E,K)
#C     SccsID = "@(#)lamd1.for	1.2	01/28/02"  
#*********************************************************************
#C
#      SUBROUTINE LAMD1 (FI,LAM,NORTH,EAST,CONV,KP,ER,ESQ,E,CM,EO,
#     &                  NB,SINFO,RB,K)
#      IMPLICIT DOUBLE PRECISION(A-H,K-Z)
#C
#C*****  LAMBERT CONFORMAL CONIC PROJECTION, 2 STANDARD PARALLELS  *****
#C       CONVERSION OF GEODETIC COORDINATES TO GRID COORDINATES
#C*****  Programmed by T. Vincenty in July 1984.
#C************************ SYMBOLS AND DEFINITIONS *********************
#C       Latitude positive north, longitude positive west.  All angles
#C         are in radian measure.
#C       FI, LAM are latitude and longitude respectively.
#C       NORTH, EAST are northing and easting coordinates respectively.
#C       NORTH EQUALS Y PLANE AND EAST EQUALS THE X PLANE.
#C       CONV is convergence.
#C       KP is point scale factor.
#C       ER is equatorial radius of the ellipsoid (= major semiaxis).
#C       ESQ is the square of first eccentricity of the ellipsoid.
#C       E is first eccentricity.
#C       CM is the central meridian of the projection zone.
#C       EO is false easting value at the central meridian.
#C       NB is false northing for the southernmost parallel of the
#C           projection, usually zero.
#C       SINFO = SIN(FO), where FO is the central parallel.  This is a
#C         precomputed value.
#C       RB is mapping radius at the southernmost latitude. This is a
#C         precomputed value.
#C       K is mapping radius at the equator.  This is a precomputed
#C         value.
#C
#C***********************************************************************
#C
    my ($FI,$LAM,$CM,$SINFO,$ER,$ESQ,$EO,$NB,$RB,$E,$K)=@_;
 
      my $SINLAT=sin($FI);
      my $COSLAT=cos($FI);
      my $CONV=($CM-$LAM)*$SINFO;

      my $Q=(log((1+$SINLAT)/(1-$SINLAT))-$E*log((1+$E*$SINLAT)/(1-$E*$SINLAT)))/2.;
      my $RPT=$K/exp($SINFO*$Q);
      my $NORTH=$NB+$RB-$RPT*cos($CONV);
      my $EAST=$EO+$RPT*sin($CONV);
      my $WP=(1.-$ESQ*$SINLAT**2)**0.5;
      my $KP=$WP*$SINFO*$RPT/($ER*$COSLAT);

      return ($NORTH,$EAST,$KP);
}


sub lconst{
#C     SccsID = "@(#)lconst.for	1.2	01/28/02"  
   #*********************************************************************
   #      SUBROUTINE LCONST(ER,RF,FIS,FIN,FIB,ESQ,E,SINFO,RB,K,KO,NO,
   #     &            G,NB)
   #      IMPLICIT DOUBLE PRECISION(A-H,K-Z)
   #      Q(E,S)=(LOG((1+S)/(1-S))-E*LOG((1+E*S)/(1-E*S)))/2.
   #C
   #C*****  LAMBERT CONFORMAL CONIC PROJECTION, 2 STANDARD PARALLELS  *****
   #C        PRECOMPUTATION OF CONSTANTS
   #C*****  Programmed by T. Vincenty in July 1984.
   #C************************ SYMBOLS AND DEFINITIONS *********************
   #C       Latitude positive north, in radian measure.
   #C       ER is equatorial radius of the ellipsoid (= major semiaxis).   input
   #C       RF is reciprocal of flattening of the ellipsoid.               input
   #C       FIS, FIN, FIB are respecitvely the latitudes of the south      input
   #C         standard parallel, the north standard parallel, and the
   #C         southernmost parallel.
   #C       ESQ is the square of first eccentricity of the ellipsoid.      input
   #C       E is first eccentricity.                                       output
   #C       SINFO = SIN(FO), where FO is the central parallel.             output
   #C       RB is mapping radius at the southernmost latitude.             output
   #C       K is mapping radius at the equator.                            output
   #C       NB is false northing for the southernmost parallel.            input
   #C       KO is scale factor at the central parallel.                    output
   #C       NO is northing of intersection of central meridian and parallel. output
   #C       G is a constant for computing chord-to-arc corrections.          output
   #C**********************************************************************   
   my ($ER,$RF,$FIS,$FIN,$FIB,$ESQ,$NB)=@_;

      my $F=1./$RF;
      $ESQ=$F+$F-$F**2;
      my $E=$ESQ**0.5;
      my $SINFS=sin($FIS);
      my $COSFS=cos($FIS);
      my $SINFN=sin($FIN);
      my $COSFN=cos($FIN);
      my $SINFB=sin($FIB);

      my $QS=Q($E,$SINFS);
      my $QN=Q($E,$SINFN);
      my $QB=Q($E,$SINFB);
      my $W1=(1.-$ESQ*$SINFS**2)**0.5;
      my $W2=(1.-$ESQ*$SINFN**2)**0.5;
      my $SINFO=log($W2*$COSFS/($W1*$COSFN))/($QN-$QS);
      my $K=$ER*$COSFS*exp($QS*$SINFO)/($W1*$SINFO);
      my $RB=$K/exp($QB*$SINFO);
      my $QO=Q($E,$SINFO);
      my $RO=$K/exp($QO*$SINFO);
      my $COSFO=(1.-$SINFO**2)**0.5;
      my $KO=(1.-$ESQ*$SINFO**2)**0.5*($SINFO/$COSFO)*$RO/$ER;
      my $NO=$RB+$NB-$RO;
      my $G=(1-$ESQ*$SINFO**2)**2/(2*($ER*$KO)**2)*(1-$ESQ);

      return ($SINFO,$RB,$K,$KO,$NO,$G);
}


sub Q{
   my ($E,$S)=@_;
   my $q=(log((1+$S)/(1-$S))-$E*log((1+$E*$S)/(1-$E*$S)))/2.;
   return $q;
}


sub lamr1{
#function   [LON,LAT,CONV,E,KP]=lamr1(NORTH,EAST,CM,EO,NB,SINFO,RB,K,ER,ESQ)
#C     SccsID = "@(#)lamr1.for	1.2	01/28/02" #
#      SUBROUTINE LAMR1(NORTH,EAST,LAT,LON,CM,EO,NB,SINFO,RB,K,ER,ESQ,CONV,KP)
#*** LAMBERT CONFORMAL CONIC PROJECTION, 2 STD PARALLELS
#*** CONVERSION OF GRID COORDINATES TO GEODETIC COORDINATES
#*** REVISED SUBROUTINE OF T. VINCENTY -- FEB.25, 1985
#************** SYMBOLS AND DEFINITIONS ********************
#*** LATITUDE POSITIVE NORTH, LONGITUDE POSITIVE WEST.  ALL
#***          ANGLES ARE IN RADIAN MEASURE.
#*** FI,LAM ARE LAT. AND LONG. RESPECTIVELY                        output
#*** NORTH,EAST ARE NORTHING AND EASTING COORDINATES RESPECTIVELY  input
#*** CONV IS CONVERGENCE                                           output
#*** KP IS POINT SCALE FACTOR                                      output
#*** ER IS THE SEMI-MAJOR AXIS FOR GRS-80                          input 
#*** ESQ IS THE SQUARE OF THE 1ST ECCENTRICITY                     input
#*** E IS THE 1ST ECCENTRICITY                                     output
#*** CM IS THE CENTRAL MERIDIAN OF THE PROJECTION ZONE             input
#*** EO IS THE FALSE EASTING VALUE AT THE CM                       input
#*** NB IS THE FALSE NORTHING FOR THE SOUTHERNMOST                 input
#***       PARALLEL OF THE PROJECTION ZONE
#*** SINFO = SIN(FO)=> WHERE FO IS THE CENTRAL PARALLEL            input
#*** RB IS THE MAPPING RADIUS AT THE SOUTHERNMOST PARALLEL         input
#*** K IS MAPPING RADIUS AT THE EQUATOR                            input    
#*************************************************************

#      IMPLICIT DOUBLE PRECISION(A-H,K-Z)
    my ($NORTH,$EAST,$CM,$EO,$NB,$SINFO,$RB,$K,$ER,$ESQ)=@_;

    my  $E=($ESQ)**0.5;
    my  $NPR=$RB-$NORTH+$NB;
    my  $EPR=$EAST-$EO;
    my  $GAM=atan($EPR/$NPR);
    my  $LON=$CM-($GAM/$SINFO);
    my  $RPT=($NPR*$NPR+$EPR*$EPR)**0.5;
    my  $Q=log($K/$RPT)/$SINFO;
    my  $TEMP=exp($Q+$Q);
    my  $SINE=($TEMP-1.0)/($TEMP+1.0);

    foreach my $I (1..3){
      my $F1=(log((1.0+$SINE)/(1.0-$SINE))-$E*log((1.0+$E*$SINE)/(1.0-$E*$SINE)))/2.0-$Q;
      my $F2=1.0/(1.0-$SINE*$SINE)-$ESQ/(1.0-$ESQ*$SINE*$SINE);
      $SINE=$SINE-$F1/$F2;
    }
    my $LAT=asin($SINE);
#*********************************************************************
#C
      my $FI = $LAT;
      my $LAM = $LON;
      my $SINLAT=sin($FI);
      my $COSLAT=cos($FI);
      my $CONV=($CM-$LAM)*$SINFO;
#C
       $Q=(log((1+$SINLAT)/(1-$SINLAT))-$E*log((1+$E*$SINLAT)/(1-$E*$SINLAT)))/2.;
      $RPT=$K/exp($SINFO*$Q);
      my $WP=(1.-$ESQ*$SINLAT**2)**0.5;
      my $KP=$WP*$SINFO*$RPT/($ER*$COSLAT);

      return ($LON,$LAT,$CONV,$E,$KP);
}



sub get_AP{
   my $zone=uc($_[0]);
   my %AP;
   $AP{'AL E'}='T';
   $AP{'AL W'}='T';
   $AP{'AK 1'}='O';
   $AP{'AK 2'}='T';
   $AP{'AK 3'}='T';
   $AP{'AK 4'}='T';
   $AP{'AK 5'}='T';
   $AP{'AK 6'}='T';
   $AP{'AK 7'}='T';
   $AP{'AK 8'}='T';
   $AP{'AK 9'}='T';
   $AP{'AK10'}='L';
   $AP{'AZ E'}='T';
   $AP{'AZ C'}='T';
   $AP{'AZ W'}='T';
   $AP{'AR N'}='L';
   $AP{'AR S'}='L';
   $AP{'CA 1'}='L';
   $AP{'CA 2'}='L';
   $AP{'CA 3'}='L';
   $AP{'CA 4'}='L';
   $AP{'CA 5'}='L';
   $AP{'CA 6'}='L';
   $AP{'CO N'}='L';
   $AP{'CO C'}='L';
   $AP{'CO S'}='L';
   $AP{'CT'}='L';
   $AP{'DE'}='T';
   $AP{'FL E'}='T';
   $AP{'FL W'}='T';
   $AP{'FL N'}='L';
   $AP{'GA E'}='T';
   $AP{'GA W'}='T';
   $AP{'HI 1'}='T';
   $AP{'HI 2'}='T';
   $AP{'HI 3'}='T';
   $AP{'HI 4'}='T';
   $AP{'HI 5'}='T';
   $AP{'ID E'}='T';
   $AP{'ID C'}='T';
   $AP{'ID W'}='T';
   $AP{'IL E'}='T';
   $AP{'IL W'}='T';
   $AP{'IN E'}='T';
   $AP{'IN W'}='T';
   $AP{'IA N'}='L';
   $AP{'IA S'}='L';
   $AP{'KS N'}='L';
   $AP{'KS S'}='L';
   $AP{'KY N'}='L';
   $AP{'KY S'}='L';
   $AP{'LA N'}='L';
   $AP{'LA S'}='L';
   $AP{'LASH'}='L';
   $AP{'ME E'}='T';
   $AP{'ME W'}='T';
   $AP{'MD'}='L';
   $AP{'MA M'}='L';
   $AP{'MA I'}='L';
   $AP{'MI N'}='N';
   $AP{'MI C'}='N';
   $AP{'MI S'}='N';
   $AP{'MI N'}='L';
   $AP{'MI C'}='L';
   $AP{'MI S'}='L';
   $AP{'MN N'}='L';
   $AP{'MN C'}='L';
   $AP{'MN S'}='L';
   $AP{'MS E'}='T';
   $AP{'MS W'}='T';
   $AP{'MO E'}='T';
   $AP{'MO C'}='T';
   $AP{'MO W'}='T';
   $AP{'MT'}='L';
   $AP{'MT'}='N';
   $AP{'MT'}='N';
   $AP{'NE'}='L';
   $AP{'NE'}='N';
   $AP{'NV E'}='T';
   $AP{'NV C'}='T';
   $AP{'NV W'}='T';
   $AP{'NH'}='T';
   $AP{'NJ'}='T';
   $AP{'NM E'}='T';
   $AP{'NM C'}='T';
   $AP{'NM W'}='T';
   $AP{'NY E'}='T';
   $AP{'NY C'}='T';
   $AP{'NY W'}='T';
   $AP{'NY L'}='L';
   $AP{'NC'}='L';
   $AP{'ND N'}='L';
   $AP{'ND S'}='L';
   $AP{'OH N'}='L';
   $AP{'OH S'}='L';
   $AP{'OK N'}='L';
   $AP{'OK S'}='L';
   $AP{'OR N'}='L';
   $AP{'OR S'}='L';
   $AP{'PA N'}='L';
   $AP{'PA S'}='L';
   $AP{'RI'}='T';
   $AP{'SC'}='L';
   $AP{'SD N'}='L';
   $AP{'SD S'}='L';
   $AP{'TN'}='L';
   $AP{'TX N'}='L';
   $AP{'TXNC'}='L';
   $AP{'TX C'}='L';
   $AP{'TXSC'}='L';
   $AP{'TX S'}='L';
   $AP{'UT N'}='L';
   $AP{'UT C'}='L';
   $AP{'UT S'}='L';
   $AP{'VT'}='T';
   $AP{'VA N'}='L';
   $AP{'VA S'}='L';
   $AP{'WA N'}='L';
   $AP{'WA S'}='L';
   $AP{'WV N'}='L';
   $AP{'WV S'}='L';
   $AP{'WI N'}='L';
   $AP{'WI C'}='L';
   $AP{'WI S'}='L';
   $AP{'WY E'}='T';
   $AP{'WYEC'}='T';
   $AP{'WYWC'}='T';
   $AP{'WY W'}='T';
   $AP{'PRVI'}='L';
   $AP{'VIZ1'}='N';
   $AP{'VISX'}='N';
   $AP{'AS'}='N';
   $AP{'GU'}='T';
   $AP{'KY1Z'}='L';
   $AP{'GU'}='T';
   return $AP{$zone};
}


sub get_SPCC{
   my $zone=uc($_[0]);
  #print " ljklj;kjklj;kj;kj; zone $zone\n";
   my %SPCC;
   $SPCC{'AL E'}[1]= 8.58333333333333290000E+01;
   $SPCC{'AL E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'AL E'}[3]= 3.05000000000000000000E+01;
   $SPCC{'AL E'}[4]= 2.50000000000000000000E+04;
   $SPCC{'AL E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AL E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AL W'}[1]= 8.75000000000000000000E+01;
   $SPCC{'AL W'}[2]= 6.00000000000000000000E+05;
   $SPCC{'AL W'}[3]= 3.00000000000000000000E+01;
   $SPCC{'AL W'}[4]= 1.50000000000000000000E+04;
   $SPCC{'AL W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AL W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 1'}[1]= 1.33666666666666660000E+02;
   $SPCC{'AK 1'}[2]= 5.00000000000000000000E+06;
   $SPCC{'AK 1'}[3]= -5.00000000000000000000E+06;
   $SPCC{'AK 1'}[4]= -6.43501108793284370000E-01;
   $SPCC{'AK 1'}[5]= 5.70000000000000000000E+01;
   $SPCC{'AK 1'}[6]= 1.00000000000000000000E+04;
   $SPCC{'AK 2'}[1]= 1.42000000000000000000E+02;
   $SPCC{'AK 2'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 2'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 2'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 2'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 2'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 3'}[1]= 1.46000000000000000000E+02;
   $SPCC{'AK 3'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 3'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 3'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 3'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 3'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 4'}[1]= 1.50000000000000000000E+02;
   $SPCC{'AK 4'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 4'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 4'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 4'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 4'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 5'}[1]= 1.54000000000000000000E+02;
   $SPCC{'AK 5'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 5'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 5'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 5'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 5'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 6'}[1]= 1.58000000000000000000E+02;
   $SPCC{'AK 6'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 6'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 6'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 6'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 6'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 7'}[1]= 1.62000000000000000000E+02;
   $SPCC{'AK 7'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 7'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 7'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 7'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 7'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 8'}[1]= 1.66000000000000000000E+02;
   $SPCC{'AK 8'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 8'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 8'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 8'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 8'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK 9'}[1]= 1.70000000000000000000E+02;
   $SPCC{'AK 9'}[2]= 5.00000000000000000000E+05;
   $SPCC{'AK 9'}[3]= 5.40000000000000000000E+01;
   $SPCC{'AK 9'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AK 9'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AK 9'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AK10'}[1]= 1.76000000000000000000E+02;
   $SPCC{'AK10'}[2]= 1.00000000000000000000E+06;
   $SPCC{'AK10'}[3]= 0.00000000000000000000E+00;
   $SPCC{'AK10'}[4]= 5.18333333333333360000E+01;
   $SPCC{'AK10'}[5]= 5.38333333333333360000E+01;
   $SPCC{'AK10'}[6]= 5.10000000000000000000E+01;
   $SPCC{'AZ E'}[1]= 1.10166666666666670000E+02;
   $SPCC{'AZ E'}[2]= 2.13360000000000000000E+05;
   $SPCC{'AZ E'}[3]= 3.10000000000000000000E+01;
   $SPCC{'AZ E'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AZ E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AZ E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AZ C'}[1]= 1.11916666666666670000E+02;
   $SPCC{'AZ C'}[2]= 2.13360000000000000000E+05;
   $SPCC{'AZ C'}[3]= 3.10000000000000000000E+01;
   $SPCC{'AZ C'}[4]= 1.00000000000000000000E+04;
   $SPCC{'AZ C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AZ C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AZ W'}[1]= 1.13750000000000000000E+02;
   $SPCC{'AZ W'}[2]= 2.13360000000000000000E+05;
   $SPCC{'AZ W'}[3]= 3.10000000000000000000E+01;
   $SPCC{'AZ W'}[4]= 1.50000000000000000000E+04;
   $SPCC{'AZ W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AZ W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AR N'}[1]= 9.20000000000000000000E+01;
   $SPCC{'AR N'}[2]= 4.00000000000000000000E+05;
   $SPCC{'AR N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'AR N'}[4]= 3.49333333333333300000E+01;
   $SPCC{'AR N'}[5]= 3.62333333333333340000E+01;
   $SPCC{'AR N'}[6]= 3.43333333333333360000E+01;
   $SPCC{'AR S'}[1]= 9.20000000000000000000E+01;
   $SPCC{'AR S'}[2]= 4.00000000000000000000E+05;
   $SPCC{'AR S'}[3]= 4.00000000000000000000E+05;
   $SPCC{'AR S'}[4]= 3.32999999999999970000E+01;
   $SPCC{'AR S'}[5]= 3.47666666666666660000E+01;
   $SPCC{'AR S'}[6]= 3.26666666666666640000E+01;
   $SPCC{'CA 1'}[1]= 1.22000000000000000000E+02;
   $SPCC{'CA 1'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 1'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 1'}[4]= 4.00000000000000000000E+01;
   $SPCC{'CA 1'}[5]= 4.16666666666666640000E+01;
   $SPCC{'CA 1'}[6]= 3.93333333333333360000E+01;
   $SPCC{'CA 2'}[1]= 1.22000000000000000000E+02;
   $SPCC{'CA 2'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 2'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 2'}[4]= 3.83333333333333360000E+01;
   $SPCC{'CA 2'}[5]= 3.98333333333333360000E+01;
   $SPCC{'CA 2'}[6]= 3.76666666666666640000E+01;
   $SPCC{'CA 3'}[1]= 1.20500000000000000000E+02;
   $SPCC{'CA 3'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 3'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 3'}[4]= 3.70666666666666700000E+01;
   $SPCC{'CA 3'}[5]= 3.84333333333333300000E+01;
   $SPCC{'CA 3'}[6]= 3.65000000000000000000E+01;
   $SPCC{'CA 4'}[1]= 1.19000000000000000000E+02;
   $SPCC{'CA 4'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 4'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 4'}[4]= 3.60000000000000000000E+01;
   $SPCC{'CA 4'}[5]= 3.72500000000000000000E+01;
   $SPCC{'CA 4'}[6]= 3.53333333333333360000E+01;
   $SPCC{'CA 5'}[1]= 1.18000000000000000000E+02;
   $SPCC{'CA 5'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 5'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 5'}[4]= 3.40333333333333310000E+01;
   $SPCC{'CA 5'}[5]= 3.54666666666666690000E+01;
   $SPCC{'CA 5'}[6]= 3.35000000000000000000E+01;
   $SPCC{'CA 6'}[1]= 1.16250000000000000000E+02;
   $SPCC{'CA 6'}[2]= 2.00000000000000000000E+06;
   $SPCC{'CA 6'}[3]= 5.00000000000000000000E+05;
   $SPCC{'CA 6'}[4]= 3.27833333333333310000E+01;
   $SPCC{'CA 6'}[5]= 3.38833333333333330000E+01;
   $SPCC{'CA 6'}[6]= 3.21666666666666640000E+01;
   $SPCC{'CO N'}[1]= 1.05500000000000000000E+02;
   $SPCC{'CO N'}[2]= 9.14401828899999960000E+05;
   $SPCC{'CO N'}[3]= 3.04800609600000030000E+05;
   $SPCC{'CO N'}[4]= 3.97166666666666690000E+01;
   $SPCC{'CO N'}[5]= 4.07833333333333310000E+01;
   $SPCC{'CO N'}[6]= 3.93333333333333360000E+01;
   $SPCC{'CO C'}[1]= 1.05500000000000000000E+02;
   $SPCC{'CO C'}[2]= 9.14401828899999960000E+05;
   $SPCC{'CO C'}[3]= 3.04800609600000030000E+05;
   $SPCC{'CO C'}[4]= 3.84500000000000030000E+01;
   $SPCC{'CO C'}[5]= 3.97500000000000000000E+01;
   $SPCC{'CO C'}[6]= 3.78333333333333360000E+01;
   $SPCC{'CO S'}[1]= 1.05500000000000000000E+02;
   $SPCC{'CO S'}[2]= 9.14401828899999960000E+05;
   $SPCC{'CO S'}[3]= 3.04800609600000030000E+05;
   $SPCC{'CO S'}[4]= 3.72333333333333340000E+01;
   $SPCC{'CO S'}[5]= 3.84333333333333300000E+01;
   $SPCC{'CO S'}[6]= 3.66666666666666640000E+01;
   $SPCC{'CT'}[1]= 7.27500000000000000000E+01;
   $SPCC{'CT'}[2]= 3.04800609600000030000E+05;
   $SPCC{'CT'}[3]= 1.52400304800000010000E+05;
   $SPCC{'CT'}[4]= 4.12000000000000030000E+01;
   $SPCC{'CT'}[5]= 4.18666666666666670000E+01;
   $SPCC{'CT'}[6]= 4.08333333333333360000E+01;
   $SPCC{'DE'}[1]= 7.54166666666666710000E+01;
   $SPCC{'DE'}[2]= 2.00000000000000000000E+05;
   $SPCC{'DE'}[3]= 3.80000000000000000000E+01;
   $SPCC{'DE'}[4]= 2.00000000000000000000E+05;
   $SPCC{'DE'}[5]= 0.00000000000000000000E+00;
   $SPCC{'DE'}[6]= 0.00000000000000000000E+00;
   $SPCC{'FL E'}[1]= 8.10000000000000000000E+01;
   $SPCC{'FL E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'FL E'}[3]= 2.43333333333333320000E+01;
   $SPCC{'FL E'}[4]= 1.70000000000000000000E+04;
   $SPCC{'FL E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'FL E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'FL W'}[1]= 8.20000000000000000000E+01;
   $SPCC{'FL W'}[2]= 2.00000000000000000000E+05;
   $SPCC{'FL W'}[3]= 2.43333333333333320000E+01;
   $SPCC{'FL W'}[4]= 1.70000000000000000000E+04;
   $SPCC{'FL W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'FL W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'FL N'}[1]= 8.45000000000000000000E+01;
   $SPCC{'FL N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'FL N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'FL N'}[4]= 2.95833333333333320000E+01;
   $SPCC{'FL N'}[5]= 3.07500000000000000000E+01;
   $SPCC{'FL N'}[6]= 2.90000000000000000000E+01;
   $SPCC{'GA E'}[1]= 8.21666666666666710000E+01;
   $SPCC{'GA E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'GA E'}[3]= 3.00000000000000000000E+01;
   $SPCC{'GA E'}[4]= 1.00000000000000000000E+04;
   $SPCC{'GA E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'GA E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'GA W'}[1]= 8.41666666666666710000E+01;
   $SPCC{'GA W'}[2]= 7.00000000000000000000E+05;
   $SPCC{'GA W'}[3]= 3.00000000000000000000E+01;
   $SPCC{'GA W'}[4]= 1.00000000000000000000E+04;
   $SPCC{'GA W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'GA W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'HI 1'}[1]= 1.55500000000000000000E+02;
   $SPCC{'HI 1'}[2]= 5.00000000000000000000E+05;
   $SPCC{'HI 1'}[3]= 1.88333333333333320000E+01;
   $SPCC{'HI 1'}[4]= 3.00000000000000000000E+04;
   $SPCC{'HI 1'}[5]= 0.00000000000000000000E+00;
   $SPCC{'HI 1'}[6]= 0.00000000000000000000E+00;
   $SPCC{'HI 2'}[1]= 1.56666666666666660000E+02;
   $SPCC{'HI 2'}[2]= 5.00000000000000000000E+05;
   $SPCC{'HI 2'}[3]= 2.03333333333333320000E+01;
   $SPCC{'HI 2'}[4]= 3.00000000000000000000E+04;
   $SPCC{'HI 2'}[5]= 0.00000000000000000000E+00;
   $SPCC{'HI 2'}[6]= 0.00000000000000000000E+00;
   $SPCC{'HI 3'}[1]= 1.58000000000000000000E+02;
   $SPCC{'HI 3'}[2]= 5.00000000000000000000E+05;
   $SPCC{'HI 3'}[3]= 2.11666666666666680000E+01;
   $SPCC{'HI 3'}[4]= 1.00000000000000000000E+05;
   $SPCC{'HI 3'}[5]= 0.00000000000000000000E+00;
   $SPCC{'HI 3'}[6]= 0.00000000000000000000E+00;
   $SPCC{'HI 4'}[1]= 1.59500000000000000000E+02;
   $SPCC{'HI 4'}[2]= 5.00000000000000000000E+05;
   $SPCC{'HI 4'}[3]= 2.18333333333333320000E+01;
   $SPCC{'HI 4'}[4]= 1.00000000000000000000E+05;
   $SPCC{'HI 4'}[5]= 0.00000000000000000000E+00;
   $SPCC{'HI 4'}[6]= 0.00000000000000000000E+00;
   $SPCC{'HI 5'}[1]= 1.60166666666666660000E+02;
   $SPCC{'HI 5'}[2]= 5.00000000000000000000E+05;
   $SPCC{'HI 5'}[3]= 2.16666666666666680000E+01;
   $SPCC{'HI 5'}[4]= 1.00000000000000000000E+00;
   $SPCC{'HI 5'}[5]= 0.00000000000000000000E+00;
   $SPCC{'HI 5'}[6]= 0.00000000000000000000E+00;
   $SPCC{'ID E'}[1]= 1.12166666666666670000E+02;
   $SPCC{'ID E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'ID E'}[3]= 4.16666666666666640000E+01;
   $SPCC{'ID E'}[4]= 1.90000000000000000000E+04;
   $SPCC{'ID E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'ID E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'ID C'}[1]= 1.14000000000000000000E+02;
   $SPCC{'ID C'}[2]= 5.00000000000000000000E+05;
   $SPCC{'ID C'}[3]= 4.16666666666666640000E+01;
   $SPCC{'ID C'}[4]= 1.90000000000000000000E+04;
   $SPCC{'ID C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'ID C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'ID W'}[1]= 1.15750000000000000000E+02;
   $SPCC{'ID W'}[2]= 8.00000000000000000000E+05;
   $SPCC{'ID W'}[3]= 4.16666666666666640000E+01;
   $SPCC{'ID W'}[4]= 1.50000000000000000000E+04;
   $SPCC{'ID W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'ID W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'IL E'}[1]= 8.83333333333333290000E+01;
   $SPCC{'IL E'}[2]= 3.00000000000000000000E+05;
   $SPCC{'IL E'}[3]= 3.66666666666666640000E+01;
   $SPCC{'IL E'}[4]= 4.00000000000000000000E+04;
   $SPCC{'IL E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'IL E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'IL W'}[1]= 9.01666666666666710000E+01;
   $SPCC{'IL W'}[2]= 7.00000000000000000000E+05;
   $SPCC{'IL W'}[3]= 3.66666666666666640000E+01;
   $SPCC{'IL W'}[4]= 1.70000000000000000000E+04;
   $SPCC{'IL W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'IL W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'IN E'}[1]= 8.56666666666666710000E+01;
   $SPCC{'IN E'}[2]= 1.00000000000000000000E+05;
   $SPCC{'IN E'}[3]= 3.75000000000000000000E+01;
   $SPCC{'IN E'}[4]= 3.00000000000000000000E+04;
   $SPCC{'IN E'}[5]= 2.50000000000000000000E+05;
   $SPCC{'IN E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'IN W'}[1]= 8.70833333333333290000E+01;
   $SPCC{'IN W'}[2]= 9.00000000000000000000E+05;
   $SPCC{'IN W'}[3]= 3.75000000000000000000E+01;
   $SPCC{'IN W'}[4]= 3.00000000000000000000E+04;
   $SPCC{'IN W'}[5]= 2.50000000000000000000E+05;
   $SPCC{'IN W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'IA N'}[1]= 9.35000000000000000000E+01;
   $SPCC{'IA N'}[2]= 1.50000000000000000000E+06;
   $SPCC{'IA N'}[3]= 1.00000000000000000000E+06;
   $SPCC{'IA N'}[4]= 4.20666666666666700000E+01;
   $SPCC{'IA N'}[5]= 4.32666666666666660000E+01;
   $SPCC{'IA N'}[6]= 4.15000000000000000000E+01;
   $SPCC{'IA S'}[1]= 9.35000000000000000000E+01;
   $SPCC{'IA S'}[2]= 5.00000000000000000000E+05;
   $SPCC{'IA S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'IA S'}[4]= 4.06166666666666670000E+01;
   $SPCC{'IA S'}[5]= 4.17833333333333310000E+01;
   $SPCC{'IA S'}[6]= 4.00000000000000000000E+01;
   $SPCC{'KS N'}[1]= 9.80000000000000000000E+01;
   $SPCC{'KS N'}[2]= 4.00000000000000000000E+05;
   $SPCC{'KS N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'KS N'}[4]= 3.87166666666666690000E+01;
   $SPCC{'KS N'}[5]= 3.97833333333333310000E+01;
   $SPCC{'KS N'}[6]= 3.83333333333333360000E+01;
   $SPCC{'KS S'}[1]= 9.85000000000000000000E+01;
   $SPCC{'KS S'}[2]= 4.00000000000000000000E+05;
   $SPCC{'KS S'}[3]= 4.00000000000000000000E+05;
   $SPCC{'KS S'}[4]= 3.72666666666666660000E+01;
   $SPCC{'KS S'}[5]= 3.85666666666666700000E+01;
   $SPCC{'KS S'}[6]= 3.66666666666666640000E+01;
   $SPCC{'KY N'}[1]= 8.42500000000000000000E+01;
   $SPCC{'KY N'}[2]= 5.00000000000000000000E+05;
   $SPCC{'KY N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'KY N'}[4]= 3.79666666666666690000E+01;
   $SPCC{'KY N'}[5]= 3.89666666666666690000E+01;
   $SPCC{'KY N'}[6]= 3.75000000000000000000E+01;
   $SPCC{'KY S'}[1]= 8.57500000000000000000E+01;
   $SPCC{'KY S'}[2]= 5.00000000000000000000E+05;
   $SPCC{'KY S'}[3]= 5.00000000000000000000E+05;
   $SPCC{'KY S'}[4]= 3.67333333333333340000E+01;
   $SPCC{'KY S'}[5]= 3.79333333333333300000E+01;
   $SPCC{'KY S'}[6]= 3.63333333333333360000E+01;
   $SPCC{'LA N'}[1]= 9.25000000000000000000E+01;
   $SPCC{'LA N'}[2]= 1.00000000000000000000E+06;
   $SPCC{'LA N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'LA N'}[4]= 3.11666666666666680000E+01;
   $SPCC{'LA N'}[5]= 3.26666666666666640000E+01;
   $SPCC{'LA N'}[6]= 3.05000000000000000000E+01;
   $SPCC{'LA S'}[1]= 9.13333333333333290000E+01;
   $SPCC{'LA S'}[2]= 1.00000000000000000000E+06;
   $SPCC{'LA S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'LA S'}[4]= 2.93000000000000010000E+01;
   $SPCC{'LA S'}[5]= 3.06999999999999990000E+01;
   $SPCC{'LA S'}[6]= 2.85000000000000000000E+01;
   $SPCC{'LASH'}[1]= 9.13333333333333290000E+01;
   $SPCC{'LASH'}[2]= 1.00000000000000000000E+06;
   $SPCC{'LASH'}[3]= 0.00000000000000000000E+00;
   $SPCC{'LASH'}[4]= 2.61666666666666680000E+01;
   $SPCC{'LASH'}[5]= 2.78333333333333320000E+01;
   $SPCC{'LASH'}[6]= 2.55000000000000000000E+01;
   $SPCC{'ME E'}[1]= 6.85000000000000000000E+01;
   $SPCC{'ME E'}[2]= 3.00000000000000000000E+05;
   $SPCC{'ME E'}[3]= 4.36666666666666640000E+01;
   $SPCC{'ME E'}[4]= 1.00000000000000000000E+04;
   $SPCC{'ME E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'ME E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'ME W'}[1]= 7.01666666666666710000E+01;
   $SPCC{'ME W'}[2]= 9.00000000000000000000E+05;
   $SPCC{'ME W'}[3]= 4.28333333333333360000E+01;
   $SPCC{'ME W'}[4]= 3.00000000000000000000E+04;
   $SPCC{'ME W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'ME W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MD'}[1]= 7.70000000000000000000E+01;
   $SPCC{'MD'}[2]= 4.00000000000000000000E+05;
   $SPCC{'MD'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MD'}[4]= 3.82999999999999970000E+01;
   $SPCC{'MD'}[5]= 3.94500000000000030000E+01;
   $SPCC{'MD'}[6]= 3.76666666666666640000E+01;
   $SPCC{'MA M'}[1]= 7.15000000000000000000E+01;
   $SPCC{'MA M'}[2]= 2.00000000000000000000E+05;
   $SPCC{'MA M'}[3]= 7.50000000000000000000E+05;
   $SPCC{'MA M'}[4]= 4.17166666666666690000E+01;
   $SPCC{'MA M'}[5]= 4.26833333333333300000E+01;
   $SPCC{'MA M'}[6]= 4.10000000000000000000E+01;
   $SPCC{'MA I'}[1]= 7.05000000000000000000E+01;
   $SPCC{'MA I'}[2]= 5.00000000000000000000E+05;
   $SPCC{'MA I'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MA I'}[4]= 4.12833333333333310000E+01;
   $SPCC{'MA I'}[5]= 4.14833333333333340000E+01;
   $SPCC{'MA I'}[6]= 4.10000000000000000000E+01;
   $SPCC{'MI N'}[1]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[2]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[4]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[1]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[2]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[4]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[1]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[2]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[4]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[1]= 8.70000000000000000000E+01;
   $SPCC{'MI N'}[2]= 8.00000000000000000000E+06;
   $SPCC{'MI N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI N'}[4]= 4.54833333333333340000E+01;
   $SPCC{'MI N'}[5]= 4.70833333333333360000E+01;
   $SPCC{'MI N'}[6]= 4.47833333333333310000E+01;
   $SPCC{'MI C'}[1]= 8.43666666666666600000E+01;
   $SPCC{'MI C'}[2]= 6.00000000000000000000E+06;
   $SPCC{'MI C'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI C'}[4]= 4.41833333333333300000E+01;
   $SPCC{'MI C'}[5]= 4.57000000000000030000E+01;
   $SPCC{'MI C'}[6]= 4.33166666666666700000E+01;
   $SPCC{'MI S'}[1]= 8.43666666666666600000E+01;
   $SPCC{'MI S'}[2]= 4.00000000000000000000E+06;
   $SPCC{'MI S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MI S'}[4]= 4.21000000000000010000E+01;
   $SPCC{'MI S'}[5]= 4.36666666666666640000E+01;
   $SPCC{'MI S'}[6]= 4.15000000000000000000E+01;
   $SPCC{'MN N'}[1]= 9.30999999999999940000E+01;
   $SPCC{'MN N'}[2]= 8.00000000000000000000E+05;
   $SPCC{'MN N'}[3]= 1.00000000000000000000E+05;
   $SPCC{'MN N'}[4]= 4.70333333333333310000E+01;
   $SPCC{'MN N'}[5]= 4.86333333333333330000E+01;
   $SPCC{'MN N'}[6]= 4.65000000000000000000E+01;
   $SPCC{'MN C'}[1]= 9.42500000000000000000E+01;
   $SPCC{'MN C'}[2]= 8.00000000000000000000E+05;
   $SPCC{'MN C'}[3]= 1.00000000000000000000E+05;
   $SPCC{'MN C'}[4]= 4.56166666666666670000E+01;
   $SPCC{'MN C'}[5]= 4.70499999999999970000E+01;
   $SPCC{'MN C'}[6]= 4.50000000000000000000E+01;
   $SPCC{'MN S'}[1]= 9.40000000000000000000E+01;
   $SPCC{'MN S'}[2]= 8.00000000000000000000E+05;
   $SPCC{'MN S'}[3]= 1.00000000000000000000E+05;
   $SPCC{'MN S'}[4]= 4.37833333333333310000E+01;
   $SPCC{'MN S'}[5]= 4.52166666666666690000E+01;
   $SPCC{'MN S'}[6]= 4.30000000000000000000E+01;
   $SPCC{'MS E'}[1]= 8.88333333333333290000E+01;
   $SPCC{'MS E'}[2]= 3.00000000000000000000E+05;
   $SPCC{'MS E'}[3]= 2.95000000000000000000E+01;
   $SPCC{'MS E'}[4]= 2.00000000000000000000E+04;
   $SPCC{'MS E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MS E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MS W'}[1]= 9.03333333333333290000E+01;
   $SPCC{'MS W'}[2]= 7.00000000000000000000E+05;
   $SPCC{'MS W'}[3]= 2.95000000000000000000E+01;
   $SPCC{'MS W'}[4]= 2.00000000000000000000E+04;
   $SPCC{'MS W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MS W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MO E'}[1]= 9.05000000000000000000E+01;
   $SPCC{'MO E'}[2]= 2.50000000000000000000E+05;
   $SPCC{'MO E'}[3]= 3.58333333333333360000E+01;
   $SPCC{'MO E'}[4]= 1.50000000000000000000E+04;
   $SPCC{'MO E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MO E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MO C'}[1]= 9.25000000000000000000E+01;
   $SPCC{'MO C'}[2]= 5.00000000000000000000E+05;
   $SPCC{'MO C'}[3]= 3.58333333333333360000E+01;
   $SPCC{'MO C'}[4]= 1.50000000000000000000E+04;
   $SPCC{'MO C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MO C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MO W'}[1]= 9.45000000000000000000E+01;
   $SPCC{'MO W'}[2]= 8.50000000000000000000E+05;
   $SPCC{'MO W'}[3]= 3.61666666666666640000E+01;
   $SPCC{'MO W'}[4]= 1.70000000000000000000E+04;
   $SPCC{'MO W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MO W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[1]= 1.09500000000000000000E+02;
   $SPCC{'MT'}[2]= 6.00000000000000000000E+05;
   $SPCC{'MT'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[4]= 4.50000000000000000000E+01;
   $SPCC{'MT'}[5]= 4.90000000000000000000E+01;
   $SPCC{'MT'}[6]= 4.42500000000000000000E+01;
   $SPCC{'MT'}[1]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[2]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[4]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[6]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[1]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[2]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[3]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[4]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[5]= 0.00000000000000000000E+00;
   $SPCC{'MT'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[1]= 1.00000000000000000000E+02;
   $SPCC{'NE'}[2]= 5.00000000000000000000E+05;
   $SPCC{'NE'}[3]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[4]= 4.00000000000000000000E+01;
   $SPCC{'NE'}[5]= 4.30000000000000000000E+01;
   $SPCC{'NE'}[6]= 3.98333333333333360000E+01;
   $SPCC{'NE'}[1]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[2]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[3]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[4]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NE'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NV E'}[1]= 1.15583333333333330000E+02;
   $SPCC{'NV E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'NV E'}[3]= 3.47500000000000000000E+01;
   $SPCC{'NV E'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NV E'}[5]= 8.00000000000000000000E+06;
   $SPCC{'NV E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NV C'}[1]= 1.16666666666666670000E+02;
   $SPCC{'NV C'}[2]= 5.00000000000000000000E+05;
   $SPCC{'NV C'}[3]= 3.47500000000000000000E+01;
   $SPCC{'NV C'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NV C'}[5]= 6.00000000000000000000E+06;
   $SPCC{'NV C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NV W'}[1]= 1.18583333333333330000E+02;
   $SPCC{'NV W'}[2]= 8.00000000000000000000E+05;
   $SPCC{'NV W'}[3]= 3.47500000000000000000E+01;
   $SPCC{'NV W'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NV W'}[5]= 4.00000000000000000000E+06;
   $SPCC{'NV W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NH'}[1]= 7.16666666666666710000E+01;
   $SPCC{'NH'}[2]= 3.00000000000000000000E+05;
   $SPCC{'NH'}[3]= 4.25000000000000000000E+01;
   $SPCC{'NH'}[4]= 3.00000000000000000000E+04;
   $SPCC{'NH'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NH'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NJ'}[1]= 7.45000000000000000000E+01;
   $SPCC{'NJ'}[2]= 1.50000000000000000000E+05;
   $SPCC{'NJ'}[3]= 3.88333333333333360000E+01;
   $SPCC{'NJ'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NJ'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NJ'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NM E'}[1]= 1.04333333333333330000E+02;
   $SPCC{'NM E'}[2]= 1.65000000000000000000E+05;
   $SPCC{'NM E'}[3]= 3.10000000000000000000E+01;
   $SPCC{'NM E'}[4]= 1.10000000000000000000E+04;
   $SPCC{'NM E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NM E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NM C'}[1]= 1.06250000000000000000E+02;
   $SPCC{'NM C'}[2]= 5.00000000000000000000E+05;
   $SPCC{'NM C'}[3]= 3.10000000000000000000E+01;
   $SPCC{'NM C'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NM C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NM C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NM W'}[1]= 1.07833333333333330000E+02;
   $SPCC{'NM W'}[2]= 8.30000000000000000000E+05;
   $SPCC{'NM W'}[3]= 3.10000000000000000000E+01;
   $SPCC{'NM W'}[4]= 1.20000000000000000000E+04;
   $SPCC{'NM W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NM W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NY E'}[1]= 7.45000000000000000000E+01;
   $SPCC{'NY E'}[2]= 1.50000000000000000000E+05;
   $SPCC{'NY E'}[3]= 3.88333333333333360000E+01;
   $SPCC{'NY E'}[4]= 1.00000000000000000000E+04;
   $SPCC{'NY E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NY E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NY C'}[1]= 7.65833333333333290000E+01;
   $SPCC{'NY C'}[2]= 2.50000000000000000000E+05;
   $SPCC{'NY C'}[3]= 4.00000000000000000000E+01;
   $SPCC{'NY C'}[4]= 1.60000000000000000000E+04;
   $SPCC{'NY C'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NY C'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NY W'}[1]= 7.85833333333333290000E+01;
   $SPCC{'NY W'}[2]= 3.50000000000000000000E+05;
   $SPCC{'NY W'}[3]= 4.00000000000000000000E+01;
   $SPCC{'NY W'}[4]= 1.60000000000000000000E+04;
   $SPCC{'NY W'}[5]= 0.00000000000000000000E+00;
   $SPCC{'NY W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'NY L'}[1]= 7.40000000000000000000E+01;
   $SPCC{'NY L'}[2]= 3.00000000000000000000E+05;
   $SPCC{'NY L'}[3]= 0.00000000000000000000E+00;
   $SPCC{'NY L'}[4]= 4.06666666666666640000E+01;
   $SPCC{'NY L'}[5]= 4.10333333333333310000E+01;
   $SPCC{'NY L'}[6]= 4.01666666666666640000E+01;
   $SPCC{'NC'}[1]= 7.90000000000000000000E+01;
   $SPCC{'NC'}[2]= 6.09601219999999970000E+05;
   $SPCC{'NC'}[3]= 0.00000000000000000000E+00;
   $SPCC{'NC'}[4]= 3.43333333333333360000E+01;
   $SPCC{'NC'}[5]= 3.61666666666666640000E+01;
   $SPCC{'NC'}[6]= 3.37500000000000000000E+01;
   $SPCC{'ND N'}[1]= 1.00500000000000000000E+02;
   $SPCC{'ND N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'ND N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'ND N'}[4]= 4.74333333333333300000E+01;
   $SPCC{'ND N'}[5]= 4.87333333333333340000E+01;
   $SPCC{'ND N'}[6]= 4.70000000000000000000E+01;
   $SPCC{'ND S'}[1]= 1.00500000000000000000E+02;
   $SPCC{'ND S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'ND S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'ND S'}[4]= 4.61833333333333300000E+01;
   $SPCC{'ND S'}[5]= 4.74833333333333340000E+01;
   $SPCC{'ND S'}[6]= 4.56666666666666640000E+01;
   $SPCC{'OH N'}[1]= 8.25000000000000000000E+01;
   $SPCC{'OH N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'OH N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OH N'}[4]= 4.04333333333333300000E+01;
   $SPCC{'OH N'}[5]= 4.17000000000000030000E+01;
   $SPCC{'OH N'}[6]= 3.96666666666666640000E+01;
   $SPCC{'OH S'}[1]= 8.25000000000000000000E+01;
   $SPCC{'OH S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'OH S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OH S'}[4]= 3.87333333333333340000E+01;
   $SPCC{'OH S'}[5]= 4.00333333333333310000E+01;
   $SPCC{'OH S'}[6]= 3.80000000000000000000E+01;
   $SPCC{'OK N'}[1]= 9.80000000000000000000E+01;
   $SPCC{'OK N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'OK N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OK N'}[4]= 3.55666666666666700000E+01;
   $SPCC{'OK N'}[5]= 3.67666666666666660000E+01;
   $SPCC{'OK N'}[6]= 3.50000000000000000000E+01;
   $SPCC{'OK S'}[1]= 9.80000000000000000000E+01;
   $SPCC{'OK S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'OK S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OK S'}[4]= 3.39333333333333300000E+01;
   $SPCC{'OK S'}[5]= 3.52333333333333340000E+01;
   $SPCC{'OK S'}[6]= 3.33333333333333360000E+01;
   $SPCC{'OR N'}[1]= 1.20500000000000000000E+02;
   $SPCC{'OR N'}[2]= 2.50000000000000000000E+06;
   $SPCC{'OR N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OR N'}[4]= 4.43333333333333360000E+01;
   $SPCC{'OR N'}[5]= 4.60000000000000000000E+01;
   $SPCC{'OR N'}[6]= 4.36666666666666640000E+01;
   $SPCC{'OR S'}[1]= 1.20500000000000000000E+02;
   $SPCC{'OR S'}[2]= 1.50000000000000000000E+06;
   $SPCC{'OR S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'OR S'}[4]= 4.23333333333333360000E+01;
   $SPCC{'OR S'}[5]= 4.40000000000000000000E+01;
   $SPCC{'OR S'}[6]= 4.16666666666666640000E+01;
   $SPCC{'PA N'}[1]= 7.77500000000000000000E+01;
   $SPCC{'PA N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'PA N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'PA N'}[4]= 4.08833333333333330000E+01;
   $SPCC{'PA N'}[5]= 4.19500000000000030000E+01;
   $SPCC{'PA N'}[6]= 4.01666666666666640000E+01;
   $SPCC{'PA S'}[1]= 7.77500000000000000000E+01;
   $SPCC{'PA S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'PA S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'PA S'}[4]= 3.99333333333333300000E+01;
   $SPCC{'PA S'}[5]= 4.09666666666666690000E+01;
   $SPCC{'PA S'}[6]= 3.93333333333333360000E+01;
   $SPCC{'RI'}[1]= 7.15000000000000000000E+01;
   $SPCC{'RI'}[2]= 1.00000000000000000000E+05;
   $SPCC{'RI'}[3]= 4.10833333333333360000E+01;
   $SPCC{'RI'}[4]= 1.60000000000000000000E+05;
   $SPCC{'RI'}[5]= 0.00000000000000000000E+00;
   $SPCC{'RI'}[6]= 0.00000000000000000000E+00;
   $SPCC{'SC'}[1]= 8.10000000000000000000E+01;
   $SPCC{'SC'}[2]= 6.09600000000000000000E+05;
   $SPCC{'SC'}[3]= 0.00000000000000000000E+00;
   $SPCC{'SC'}[4]= 3.25000000000000000000E+01;
   $SPCC{'SC'}[5]= 3.48333333333333360000E+01;
   $SPCC{'SC'}[6]= 3.18333333333333320000E+01;
   $SPCC{'SD N'}[1]= 1.00000000000000000000E+02;
   $SPCC{'SD N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'SD N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'SD N'}[4]= 4.44166666666666640000E+01;
   $SPCC{'SD N'}[5]= 4.56833333333333300000E+01;
   $SPCC{'SD N'}[6]= 4.38333333333333360000E+01;
   $SPCC{'SD S'}[1]= 1.00333333333333330000E+02;
   $SPCC{'SD S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'SD S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'SD S'}[4]= 4.28333333333333360000E+01;
   $SPCC{'SD S'}[5]= 4.43999999999999990000E+01;
   $SPCC{'SD S'}[6]= 4.23333333333333360000E+01;
   $SPCC{'TN'}[1]= 8.60000000000000000000E+01;
   $SPCC{'TN'}[2]= 6.00000000000000000000E+05;
   $SPCC{'TN'}[3]= 0.00000000000000000000E+00;
   $SPCC{'TN'}[4]= 3.52500000000000000000E+01;
   $SPCC{'TN'}[5]= 3.64166666666666640000E+01;
   $SPCC{'TN'}[6]= 3.43333333333333360000E+01;
   $SPCC{'TX N'}[1]= 1.01500000000000000000E+02;
   $SPCC{'TX N'}[2]= 2.00000000000000000000E+05;
   $SPCC{'TX N'}[3]= 1.00000000000000000000E+06;
   $SPCC{'TX N'}[4]= 3.46499999999999990000E+01;
   $SPCC{'TX N'}[5]= 3.61833333333333300000E+01;
   $SPCC{'TX N'}[6]= 3.40000000000000000000E+01;
   $SPCC{'TXNC'}[1]= 9.85000000000000000000E+01;
   $SPCC{'TXNC'}[2]= 6.00000000000000000000E+05;
   $SPCC{'TXNC'}[3]= 2.00000000000000000000E+06;
   $SPCC{'TXNC'}[4]= 3.21333333333333330000E+01;
   $SPCC{'TXNC'}[5]= 3.39666666666666690000E+01;
   $SPCC{'TXNC'}[6]= 3.16666666666666680000E+01;
   $SPCC{'TX C'}[1]= 1.00333333333333330000E+02;
   $SPCC{'TX C'}[2]= 7.00000000000000000000E+05;
   $SPCC{'TX C'}[3]= 3.00000000000000000000E+06;
   $SPCC{'TX C'}[4]= 3.01166666666666670000E+01;
   $SPCC{'TX C'}[5]= 3.18833333333333330000E+01;
   $SPCC{'TX C'}[6]= 2.96666666666666680000E+01;
   $SPCC{'TXSC'}[1]= 9.90000000000000000000E+01;
   $SPCC{'TXSC'}[2]= 6.00000000000000000000E+05;
   $SPCC{'TXSC'}[3]= 4.00000000000000000000E+06;
   $SPCC{'TXSC'}[4]= 2.83833333333333330000E+01;
   $SPCC{'TXSC'}[5]= 3.02833333333333350000E+01;
   $SPCC{'TXSC'}[6]= 2.78333333333333320000E+01;
   $SPCC{'TX S'}[1]= 9.85000000000000000000E+01;
   $SPCC{'TX S'}[2]= 3.00000000000000000000E+05;
   $SPCC{'TX S'}[3]= 5.00000000000000000000E+06;
   $SPCC{'TX S'}[4]= 2.61666666666666680000E+01;
   $SPCC{'TX S'}[5]= 2.78333333333333320000E+01;
   $SPCC{'TX S'}[6]= 2.56666666666666680000E+01;
   $SPCC{'UT N'}[1]= 1.11500000000000000000E+02;
   $SPCC{'UT N'}[2]= 5.00000000000000000000E+05;
   $SPCC{'UT N'}[3]= 1.00000000000000000000E+06;
   $SPCC{'UT N'}[4]= 4.07166666666666690000E+01;
   $SPCC{'UT N'}[5]= 4.17833333333333310000E+01;
   $SPCC{'UT N'}[6]= 4.03333333333333360000E+01;
   $SPCC{'UT C'}[1]= 1.11500000000000000000E+02;
   $SPCC{'UT C'}[2]= 5.00000000000000000000E+05;
   $SPCC{'UT C'}[3]= 2.00000000000000000000E+06;
   $SPCC{'UT C'}[4]= 3.90166666666666660000E+01;
   $SPCC{'UT C'}[5]= 4.06499999999999990000E+01;
   $SPCC{'UT C'}[6]= 3.83333333333333360000E+01;
   $SPCC{'UT S'}[1]= 1.11500000000000000000E+02;
   $SPCC{'UT S'}[2]= 5.00000000000000000000E+05;
   $SPCC{'UT S'}[3]= 3.00000000000000000000E+06;
   $SPCC{'UT S'}[4]= 3.72166666666666690000E+01;
   $SPCC{'UT S'}[5]= 3.83500000000000010000E+01;
   $SPCC{'UT S'}[6]= 3.66666666666666640000E+01;
   $SPCC{'VT'}[1]= 7.25000000000000000000E+01;
   $SPCC{'VT'}[2]= 5.00000000000000000000E+05;
   $SPCC{'VT'}[3]= 4.25000000000000000000E+01;
   $SPCC{'VT'}[4]= 2.80000000000000000000E+04;
   $SPCC{'VT'}[5]= 0.00000000000000000000E+00;
   $SPCC{'VT'}[6]= 0.00000000000000000000E+00;
   $SPCC{'VA N'}[1]= 7.85000000000000000000E+01;
   $SPCC{'VA N'}[2]= 3.50000000000000000000E+06;
   $SPCC{'VA N'}[3]= 2.00000000000000000000E+06;
   $SPCC{'VA N'}[4]= 3.80333333333333310000E+01;
   $SPCC{'VA N'}[5]= 3.92000000000000030000E+01;
   $SPCC{'VA N'}[6]= 3.76666666666666640000E+01;
   $SPCC{'VA S'}[1]= 7.85000000000000000000E+01;
   $SPCC{'VA S'}[2]= 3.50000000000000000000E+06;
   $SPCC{'VA S'}[3]= 1.00000000000000000000E+06;
   $SPCC{'VA S'}[4]= 3.67666666666666660000E+01;
   $SPCC{'VA S'}[5]= 3.79666666666666690000E+01;
   $SPCC{'VA S'}[6]= 3.63333333333333360000E+01;
   $SPCC{'WA N'}[1]= 1.20833333333333330000E+02;
   $SPCC{'WA N'}[2]= 5.00000000000000000000E+05;
   $SPCC{'WA N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WA N'}[4]= 4.75000000000000000000E+01;
   $SPCC{'WA N'}[5]= 4.87333333333333340000E+01;
   $SPCC{'WA N'}[6]= 4.70000000000000000000E+01;
   $SPCC{'WA S'}[1]= 1.20500000000000000000E+02;
   $SPCC{'WA S'}[2]= 5.00000000000000000000E+05;
   $SPCC{'WA S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WA S'}[4]= 4.58333333333333360000E+01;
   $SPCC{'WA S'}[5]= 4.73333333333333360000E+01;
   $SPCC{'WA S'}[6]= 4.53333333333333360000E+01;
   $SPCC{'WV N'}[1]= 7.95000000000000000000E+01;
   $SPCC{'WV N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WV N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WV N'}[4]= 3.90000000000000000000E+01;
   $SPCC{'WV N'}[5]= 4.02500000000000000000E+01;
   $SPCC{'WV N'}[6]= 3.85000000000000000000E+01;
   $SPCC{'WV S'}[1]= 8.10000000000000000000E+01;
   $SPCC{'WV S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WV S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WV S'}[4]= 3.74833333333333340000E+01;
   $SPCC{'WV S'}[5]= 3.88833333333333330000E+01;
   $SPCC{'WV S'}[6]= 3.70000000000000000000E+01;
   $SPCC{'WI N'}[1]= 9.00000000000000000000E+01;
   $SPCC{'WI N'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WI N'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WI N'}[4]= 4.55666666666666700000E+01;
   $SPCC{'WI N'}[5]= 4.67666666666666660000E+01;
   $SPCC{'WI N'}[6]= 4.51666666666666640000E+01;
   $SPCC{'WI C'}[1]= 9.00000000000000000000E+01;
   $SPCC{'WI C'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WI C'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WI C'}[4]= 4.42500000000000000000E+01;
   $SPCC{'WI C'}[5]= 4.55000000000000000000E+01;
   $SPCC{'WI C'}[6]= 4.38333333333333360000E+01;
   $SPCC{'WI S'}[1]= 9.00000000000000000000E+01;
   $SPCC{'WI S'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WI S'}[3]= 0.00000000000000000000E+00;
   $SPCC{'WI S'}[4]= 4.27333333333333340000E+01;
   $SPCC{'WI S'}[5]= 4.40666666666666700000E+01;
   $SPCC{'WI S'}[6]= 4.20000000000000000000E+01;
   $SPCC{'WY E'}[1]= 1.05166666666666670000E+02;
   $SPCC{'WY E'}[2]= 2.00000000000000000000E+05;
   $SPCC{'WY E'}[3]= 4.05000000000000000000E+01;
   $SPCC{'WY E'}[4]= 1.60000000000000000000E+04;
   $SPCC{'WY E'}[5]= 0.00000000000000000000E+00;
   $SPCC{'WY E'}[6]= 0.00000000000000000000E+00;
   $SPCC{'WYEC'}[1]= 1.07333333333333330000E+02;
   $SPCC{'WYEC'}[2]= 4.00000000000000000000E+05;
   $SPCC{'WYEC'}[3]= 4.05000000000000000000E+01;
   $SPCC{'WYEC'}[4]= 1.60000000000000000000E+04;
   $SPCC{'WYEC'}[5]= 1.00000000000000000000E+05;
   $SPCC{'WYEC'}[6]= 0.00000000000000000000E+00;
   $SPCC{'WYWC'}[1]= 1.08750000000000000000E+02;
   $SPCC{'WYWC'}[2]= 6.00000000000000000000E+05;
   $SPCC{'WYWC'}[3]= 4.05000000000000000000E+01;
   $SPCC{'WYWC'}[4]= 1.60000000000000000000E+04;
   $SPCC{'WYWC'}[5]= 0.00000000000000000000E+00;
   $SPCC{'WYWC'}[6]= 0.00000000000000000000E+00;
   $SPCC{'WY W'}[1]= 1.10083333333333330000E+02;
   $SPCC{'WY W'}[2]= 8.00000000000000000000E+05;
   $SPCC{'WY W'}[3]= 4.05000000000000000000E+01;
   $SPCC{'WY W'}[4]= 1.60000000000000000000E+04;
   $SPCC{'WY W'}[5]= 1.00000000000000000000E+05;
   $SPCC{'WY W'}[6]= 0.00000000000000000000E+00;
   $SPCC{'PRVI'}[1]= 6.64333333333333370000E+01;
   $SPCC{'PRVI'}[2]= 2.00000000000000000000E+05;
   $SPCC{'PRVI'}[3]= 2.00000000000000000000E+05;
   $SPCC{'PRVI'}[4]= 1.80333333333333350000E+01;
   $SPCC{'PRVI'}[5]= 1.84333333333333340000E+01;
   $SPCC{'PRVI'}[6]= 1.78333333333333320000E+01;
   $SPCC{'VIZ1'}[1]= 0.00000000000000000000E+00;
   $SPCC{'VIZ1'}[2]= 0.00000000000000000000E+00;
   $SPCC{'VIZ1'}[3]= 0.00000000000000000000E+00;
   $SPCC{'VIZ1'}[4]= 0.00000000000000000000E+00;
   $SPCC{'VIZ1'}[5]= 0.00000000000000000000E+00;
   $SPCC{'VIZ1'}[6]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[1]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[2]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[3]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[4]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[5]= 0.00000000000000000000E+00;
   $SPCC{'VISX'}[6]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[1]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[2]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[3]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[4]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[5]= 0.00000000000000000000E+00;
   $SPCC{'AS'}[6]= 0.00000000000000000000E+00;
   $SPCC{'GU'}[1]= 2.13000000000000000000E+02;
   $SPCC{'GU'}[2]= 5.00000000000000000000E+05;
   $SPCC{'GU'}[3]= 0.00000000000000000000E+00;
   $SPCC{'GU'}[4]= 2.50000000000000000000E+03;
   $SPCC{'GU'}[5]= 0.00000000000000000000E+00;
   $SPCC{'GU'}[6]= 0.00000000000000000000E+00;
   $SPCC{'KY1Z'}[1]= 8.57500000000000000000E+01;
   $SPCC{'KY1Z'}[2]= 1.50000000000000000000E+06;
   $SPCC{'KY1Z'}[3]= 1.00000000000000000000E+06;
   $SPCC{'KY1Z'}[4]= 3.70833333333333360000E+01;
   $SPCC{'KY1Z'}[5]= 3.86666666666666640000E+01;
   $SPCC{'KY1Z'}[6]= 3.63333333333333360000E+01;
   $SPCC{'GU'}[1]= 2.15250000000000000000E+02;
   $SPCC{'GU'}[2]= 2.00000000000000000000E+05;
   $SPCC{'GU'}[3]= 1.35000000000000000000E+01;
   $SPCC{'GU'}[4]= 1.00000000000000000000E+00;
   $SPCC{'GU'}[5]= 1.00000000000000000000E+05;
   $SPCC{'GU'}[6]= 0.00000000000000000000E+00; 

  # print " yyyyyyyyyyyyyyyyyyyyy @{$SPCC{$zone}}\n";

   return ($SPCC{$zone}[1],
           $SPCC{$zone}[2],
           $SPCC{$zone}[3],
           $SPCC{$zone}[4],
           $SPCC{$zone}[5],
           $SPCC{$zone}[6]);
}




1;
#$#$#$#$#$#$#$#$#$#


