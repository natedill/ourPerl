package MonteCarlo;
# contains some hoagies and grinders for 
# getting random values from different distributions
# and possibly more
#########################################################
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
#######################################################################7

use strict;
use warnings;


###################################################################
# sub getRandFromCCDF
#
# my $valref=MonteCarlo::getRandFromCCDF(\@ARI,\@RV,$nVals)
#
#  @ARI is an array of average recurrence intervals (return periods) in increasing order
#  @RV is the array of associated exceedence values
#  $nVals (optional) is the number of random values that will be returned
#
#  for $nVals==1  it returns the random value
#  for $nVals > 1 it returns a reference to an array of random values
#  
#  
#
# get a random value from a distribution that is 
# described as a series of return periods or average Recurrence Intervals (ARI)
# and exceedence values (RV)
# technically this is a complementary cumulative distribution function
sub getRandFromCCDF{
  my ($ari,$rv,$nVals)=@_;
  my @ARI= @{$ari};
  my @RV= @{$rv};
  $nVals=1 unless defined ($nVals);


  # get the probability of non-exceedence
  # 1/ari is interpreted as the probability that there will be one exceedence in a year
  # of the value rv in a unit of time (i.e year)
  my @CDF=();  # this will hold the CDF, i.e. the probability of having 
 
  # Assume this is a poisson process, so we need to consider the combined probability of having 1 or more exceedences
  # one minus that combined probability is the probability of non-exceedence, which desdribes the CDF
  # foreach my $ari (@ARI){
  #    my $p = 0;
  #    foreach my $n (1..10){  # this gets asymtotic, so adding upto 10 non-exceedences is practically enough
  #       $p = $p + &Poisson(1/$ari,1,$n);
  #    }
  #    push @CDF, 1-$p;
  #}
  #my @CDF2=();

  # or rather consider the probability of having exactly zero occurances in a year
  # this is much less computationally demanding and gives the same result.
  foreach my $ari (@ARI){
      my $p = &Poisson(1/$ari,1,0);
      push @CDF, $p;
  }

  unshift @CDF, 0;
  unshift @RV, $RV[0];
  push @CDF, 1;
  push @RV, $RV[$#RV];
  
  
  # now that we have the CDF, get a random value from it
  my @R=();
  foreach my $n (1..$nVals){
     my $r=rand();
     push @R, $r;
  }

  my $valsref = &interp1 (\@CDF,\@RV,\@R);
  if ($nVals==1){
     return $valsref->[0];
  }else{
    return $valsref;
  }



}


###########################################################
# sub Poisson(mu,t,r)
#
#   my $p=MonteCarlo::Poisson($rate,$t,$n)
#
#  $rate = counting rate  (average rate of event occurence)
#  $t =  time period of interest
#  $n =  number of occurences
# 
#  gives probability of observing exactly n occurences
#  in the time period t, with the average rate of 
#  occurence, rate. 
#
#  note, if you want r or more occurences use a different function
#  or compute a sum.
#
sub Poisson{

   my ($rate,$t,$n)=@_;
#print "rate t n $rate, $t, $n\n";
   my $p=(($rate*$t)**$n*exp(-$rate*$t) )/&factorial($n);
   return ($p);

};





#######################################################
# sub factorial
# 
# my $f=MonteCarlo::factorial($n)
#  
# returns the factorial of $n (n!)
sub factorial {
   my $n=shift;
   return 1 if ($n==0);
   my $f=$n;
   while ($n>1){
     $n--;
     $f *= $n;
   }
   return $f;
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



sub ltqnorm ($) {
    #
    # Lower tail quantile for standard normal distribution function.
    #
    # This function returns an approximation of the inverse cumulative
    # standard normal distribution function.  I.e., given P, it returns
    # an approximation to the X satisfying P = Pr{Z <= X} where Z is a
    # random variable from the standard normal distribution.
    #
    # The algorithm uses a minimax approximation by rational functions
    # and the result has a relative error whose absolute value is less
    # than 1.15e-9.
    #
    # Author:      Peter J. Acklam
    # Time-stamp:  2000-07-19 18:26:14
    # E-mail:      pjacklam@online.no
    # WWW URL:     http://home.online.no/~pjacklam

    my $p = shift;
    die "input argument must be in (0,1)\n" unless 0 < $p && $p < 1;

    # Coefficients in rational approximations.
    my @a = (-3.969683028665376e+01,  2.209460984245205e+02,
             -2.759285104469687e+02,  1.383577518672690e+02,
             -3.066479806614716e+01,  2.506628277459239e+00);
    my @b = (-5.447609879822406e+01,  1.615858368580409e+02,
             -1.556989798598866e+02,  6.680131188771972e+01,
             -1.328068155288572e+01 );
    my @c = (-7.784894002430293e-03, -3.223964580411365e-01,
             -2.400758277161838e+00, -2.549732539343734e+00,
              4.374664141464968e+00,  2.938163982698783e+00);
    my @d = ( 7.784695709041462e-03,  3.224671290700398e-01,
              2.445134137142996e+00,  3.754408661907416e+00);

    # Define break-points.
    my $plow  = 0.02425;
    my $phigh = 1 - $plow;

    # Rational approximation for lower region:
    if ( $p < $plow ) {
       my $q  = sqrt(-2*log($p));
       return ((((($c[0]*$q+$c[1])*$q+$c[2])*$q+$c[3])*$q+$c[4])*$q+$c[5]) /
               (((($d[0]*$q+$d[1])*$q+$d[2])*$q+$d[3])*$q+1);
    }

    # Rational approximation for upper region:
    if ( $phigh < $p ) {
       my $q  = sqrt(-2*log(1-$p));
       return -((((($c[0]*$q+$c[1])*$q+$c[2])*$q+$c[3])*$q+$c[4])*$q+$c[5]) /
                (((($d[0]*$q+$d[1])*$q+$d[2])*$q+$d[3])*$q+1);
    }

    # Rational approximation for central region:
    my $q = $p - 0.5;
    my $r = $q*$q;
    return ((((($a[0]*$r+$a[1])*$r+$a[2])*$r+$a[3])*$r+$a[4])*$r+$a[5])*$q /
           ((((($b[0]*$r+$b[1])*$r+$b[2])*$r+$b[3])*$r+$b[4])*$r+1);
}




1;
