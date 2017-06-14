package Interp;

use warnings;
use strict;

############################################################
# sub idw
#
# compute inverse distance weighted average at point $xp,$yp
# using set of points referenced by $Xref,$Yref,$Zref
#
# e.g.
# 
#  $zp = Interp::idw($xp,$yp,\@X,\@Y,\@Z,$power
#
#  $power is the power parameter for the weights
#
###########################################################
sub idw {
   my ($xp,$yp,$Xref,$Yref,$Zref,$power)=@_;;
   my @Y=@{$Yref};
   my @X=@{$Xref};
   my @Z=@{$Zref};
     $power=0.5*$power; 

   my $sumW=0;
   my $sum=0;
   #compute weights
   foreach my $n (0..$#Z) {
     
       my $w=1/(($X[$n]-$xp)**2.0 + ($Y[$n]-$yp)**2.0)**$power;
       $sum=$sum+$w*$Z[$n];
       $sumW=$sumW + $w;
   }

   my $result= $sum/$sumW;
   return $result;
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
# 
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







sub idw_np {

   my ($xp, $yp, $xref,$yref,$zref,$power,$npoints)=@_;

   my @X=@{$xref};
   my @Y=@{$yref};
   my @Z=@{$zref};
   #my @SDS;  # sorted DS value   
   #my @SZ;   # sorted Z value
   my @DS;   
   $power=0.5*$power;

   # calculate diplacements
   foreach my $x (@X){
            my $y=shift (@Y);
     #       push @Y, $y;
            push @DS, ($xp-$x)**2 + ($yp-$y)**2  ;
    }    

   my $np=@X;
   $npoints = $np if ($npoints > $np);
   if ($npoints < $np){ #  need to sort things out
       my @I=(0..$#DS);
      my @SortedI = sort { $DS[$a] <=> $DS[$b] } @I;
       @DS=@DS[@SortedI];
       @Z=@Z[@SortedI];
   } 
   
   my $sumWeight=0;
   my $sumZ=0;
   foreach my $z (0..$npoints-1){
        my $ds=shift(@DS);
        my $z=shift(@Z);
        my $w=1/($ds**$power);
        $sumWeight=$sumWeight+$w;
        $sumZ=$sumZ+$w*$z;
   }
   my $mean =  $sumZ/$sumWeight;
   return $mean;
}   


# find the minimum and max of an array;
sub minmax{
  my $x=shift;
  my @X=@{$x};
  my $min=$X[0];
  my $max=$X[0];
  foreach my $x (@X){
     $min=$x if ($x < $min);
     $max=$x if ($x > $max);
  }
  return ($min,$max);
}

            
   
############################################
# cubic spline interpolation
#
#  my $y=Interp::cspline($x,\@PX,\@PY);
#
#  returns the value at point $x using cubic interpolation of the function approximated by @PX, @PY
#
#  if $x is outside interval $PX[0] to $PX[$#PX] it just extrapolates linearly from the ends,
#
#  @PX and @PY must have at least 4 points 
#  @PX must be increasing or you may have problems (e.g. divide by zero)
#  @PY is a single values function of PX
#
#
sub cspline{
 
   my ($x,$px,$py)=@_;
   
   my @PX=@{$px};
   my @PY=@{$py};
   
   if ($#PX < 3 or $#PY < 3 ){
      print "ERROR: Interp::cspline: not enough points in PX or PY\n";
      return undef;
   }    
   unless ($#PX == $#PY){
      print "ERROR: Interp::cspline: PX and PY are not the same length\n";
      return undef;
   }
   
   
   # deal with x outside of PX interval   

   # return undef if ($x > $PX[$#PX]) or ($x < $PX[0]);
   if ($x <= $PX[0]) {
       print "WARNING: Interp::cspline: x is outside PX interval\n";
print "X = $x, PX interval $PX[0] to $PX[$#PX]\n";
       my $m=($PY[1]-$PY[0])/($PX[1]-$PX[0]);
       my $y=$PY[0]-$m*($PX[0]-$x);
       return $y;
   }
   if ($x >= $PX[$#PX]) {
       print "WARNING: Interp::cspline: x is outside PX interval\n";
       my $m=($PY[$#PX]-$PY[$#PX-1])/($PX[$#PX]-$PX[$#PX-1]);
       my $y=$PY[$#PY]+$m*($x-$PX[$#PX]);
       return $y;
   }
 
  
   # find the interval x is on
   my $i=0;
   while (1==1){
      last if $x >= $PX[$i] and $x < $PX[$i+1];
      $i++;
      last if $i > $#PX;
   }

   # now $i is the index of the point just before x

   my $m0;
   #my $p0 = $PY[$i];
   my $m1;
   #my $p1  = $PY[$i+21];

   if ($i == 0) {
      $m0=($PY[1]-$PY[0])/($PX[1]-$PX[0]);
   }else{
      $m0=0.5* ( ($PY[$i+1]-$PY[$i])/($PX[$i+1]-$PX[$i]) + ($PY[$i]-$PY[$i-1])/($PX[$i]-$PX[$i-1]) )
   }

   if ($i == $#PX-1){
      $m1=($PY[$#PY]-$PY[$i])/($PX[$#PX]-$PX[$i]);
   }else{
      $m1=0.5* ( ($PY[$i+1]-$PY[$i])/($PX[$i+1]-$PX[$i]) + ($PY[$i+2]-$PY[$i+1])/($PX[$i+2]-$PX[$i+1]) )
   }

   # basis functions
   my $t=( $x-$PX[$i]) / ($PX[$i+1]-$PX[$i]);
   my $h00= (1+2*$t)*(1-$t)*(1-$t);
   my $h10= $t*(1-$t)*(1-$t);
   my $h01= $t*$t*(3-2*$t);
   my $h11= $t*$t*($t-1);

   return $h00*$PY[$i] + $h10*$m0 + $h01*$PY[$i+1]; + $h11*$m1;
              
   
}

############################################################
#
#  $y = Interp::bicubic($x,$y,\@PX,\@PY,\@Z)
#
#  returns the bicubic interpolated value from @Z at the point $x,y
#
#  @Z is list of data in a row major order from the top down
#  @Z has ($#PX+1)*($#PY+1) elements
#
#  assumes PY is decreasing values (from the top down)  
#
sub bicubic{
   my ($x,$y,$px,$py,$z)=@_;
   my @PX=@{$px};
   my @PY=@{$py};
   my @Z=@{$z};

   my $errLev=0;
   
   if (($y < $PY[$#PY-1]) or ($y > $PY[1]) or ($x < $PX[1]) or ($x > $PX[$#PX-1])){
     print "ERROR: Interp::bicubic: x or y is out of PX or PY range\n" if $errLev >0 ;
     return undef;
   }


   # find what row were on
   my $j=0;
   while (1==1){
      last if (($y <= $PY[$j]) and ($y > $PY[$j+1]));
      $j++;
   } 
   # find what col were on
   my $i=0;
   while (1==1){
      last if (($x <= $PX[$i+1]) and ($x > $PX[$i]));
      $i++;
   } 

#print "were on ij, $i, $j\n";
    
   # interpolate across rows
   my $ncols=$#PX+1;   
   my @ZZ=();
   my @YY=();
   foreach my $jj ($j-1..$j+2){
      my @Indices=($jj*$ncols .. $jj*$ncols+$#PX);
      my @ZZ_=@Z[@Indices];
      my $z0=&cspline($x,\@PX,\@ZZ_); 
#print "jj $jj z0 $z0\n";
      unshift @ZZ,$z0;             # reversing order here because cspline wants increasing x
      unshift @YY,$PY[$jj];
   }

   # interpolate down column
   return &cspline($y,\@YY,\@ZZ);


}

















1;
