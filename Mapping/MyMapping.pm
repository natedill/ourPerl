# myMapping.pm

# Copyleft (C) 2014-2016 Nate Dill
#
# contains subroutines for mapping and coordinate conversions
# just Albers equal area conic forward for now 
#

package myMapping;

use strict;
use warnings;


# create a new mapping object (its hash ref)
sub new {
    my $class=shift;
    my $obj = {};
    bless $obj, $class;
    return $obj;
}


# set the ellipsoid and calculate some parameters
# sub $obj->setEllipsoid ( -A=>$semiMajorAxis
#                          -F=>$flattening);

sub setEllipsoid # 
{
   my $obj=shift;
   my %args=@_;
   my $a=$args{-A};
   my $f=$args{-F};

   $obj->{A}=$a;   # semi-major axis
  
   $obj->{F}=$f;   # flattening

   
   my $b=$a*(1.0-$obj->{F});      # semi-minor axis
 
   my $e=(1-($b**2/$a**2))**0.5;  # eccentricity

   $obj->{E}=$e;   # eccentricity
   $obj->{EE}=$e**2.0;
   $obj->{OMEE}=1-$obj->{EE};
   $obj->{OO2E}=1.0/2.0/$e;
}


# set the Albers equal area conic parameters
#
# $obj->setAlbers ( -PHI0=>$phi0   # angles in radians
#                   -LAM0=>$lamda0
#                   -PHI1=>$phi1
#                   -PHI2=>$phi2
#
# 
sub setAlbers
{
   my $obj=shift;
   my %args=@_;
   
   my $phi0=$args{-PHI0};
   my $phi1=$args{-PHI1};
   my $phi2=$args{-PHI2};
   my $lam0=$args{-LAM0};
   
   my $a=$obj->{A};
   my $e=$obj->{E};
   my $omesq=$obj->{OMEE};
   my $oo2e=$obj->{OO2E};

   my $esinphi0=$e*sin($phi0);
   my $esinphi1=$e*sin($phi1);
   my $esinphi2=$e*sin($phi2);

   my $esinphi0_sq=$esinphi0**2.0;
   my $esinphi1_sq=$esinphi1**2.0;
   my $esinphi2_sq=$esinphi2**2.0;

   my $q0=$omesq * ( sin($phi0)/(1.-$esinphi0_sq) - $oo2e*log((1.-$esinphi0)/(1.+$esinphi0)));
   my $q1=$omesq * ( sin($phi1)/(1.-$esinphi1_sq) - $oo2e*log((1.-$esinphi1)/(1.+$esinphi1)));
   my $q2=$omesq * ( sin($phi2)/(1.-$esinphi2_sq) - $oo2e*log((1.-$esinphi2)/(1.+$esinphi2)));

   my $m1=cos($phi1)/(1-$esinphi1_sq)**0.5;
   my $m2=cos($phi2)/(1-$esinphi2_sq)**0.5;

   my $n=($m1**2.0-$m2**2)/($q2-$q1);
   my $C=$m1**2.0+$n*$q1;
   my $rho0=$a*(($C-$n*$q0)**0.5)/$n;

   # these parameters will be needed for forward calculations
   $obj->{LAM0}=$lam0;
   $obj->{C}=$C;
   $obj->{RHO0}=$rho0;
   $obj->{N}=$n;
}

# forward conversion from geographic to x,y
#
# $obj->albersForward ( -PHI=>$phi  # latitude  in radians
#                       -LAM=>$lamda) # longitude
#
sub albersForward 
{
   my $obj=shift;
   my %args=@_;
	
   my $phi=$args{-PHI};
   my $lamda=$args{-LAM};
   
   
   my $omesq=$obj->{OMEE};
   my $e=$obj->{E};
   my $oo2e=$obj->{OO2E};
   my $n=$obj->{N};
   my $C=$obj->{C};
   my $a=$obj->{A};
   my $lamda0=$obj->{LAM0};
   my $rho0=$obj->{RHO0};

   my $esinphi=$e*sin($phi);
   my $esinphi_sq=$esinphi**2.0;
  
   my $q =$omesq * ( sin($phi )/(1.-$esinphi_sq ) - $oo2e*log((1.-$esinphi)/(1.+$esinphi)));

   my $theta=$n*($lamda-$lamda0);
   my $rho=$a*(($C-$n*$q)**0.5)/$n;

   my $x=$rho*sin($theta);
   my $y=$rho0-$rho*cos($theta);

   return ($x,$y);
}





1;
