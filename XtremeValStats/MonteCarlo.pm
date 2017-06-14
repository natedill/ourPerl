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





1;
