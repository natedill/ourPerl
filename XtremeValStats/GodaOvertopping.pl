#!/usr/bin/env perl
use strict;
use warnings;
use Math::Trig;

# example script to calculate mean wave overtopping rate for 
# smooth inclined and vertical structures using Goda's
# unified formulas.

# Reference: "Random Seas and Design of Maritime Structures" 3rd Edition, 
#             by Yoshimi Goda (Advanced Series on Ocean Engineering - Vol.33

# applicable slope is from vertical to 1:7 (V:H)
# applicable depth at toe to Hs at toe ratio is 0 to 6  (greater depth ratios are similar to 6)
 

my $Hs=1.5;
my $hc=1.3;
my $h=6;
my $cotAlpha=.2;
my $s=1/30;
my $g=32.2;
my $report=1;

my ($q,$qmin,$qmax,$reportString)=qover($Hs,$hc,$h,$cotAlpha,$s,$g,$report);



####################################################
# sub qover
#
#  my ($q,$qmin,$qmax,$reportString)=qover($Hs,$hc,$h,$cotAlpha,$s,$g,$report);
#
#  $Hs - Sig. Wave Height at toe
#  $hc - freeboard (crest minus mean water level)
#  $h - $depth at toe
#  $cotAlpha - $structure slope (valid range is vertical to 1:7 (V:H)
#  $s - seabed slope (V/H)
#  $g - acceleration due to gravity
#  $report  -  also return report string if defined
#
# Calculate mean wave overtopping rate for 
# smooth inclined and vertical structures using Goda's
# unified formulas.

# Reference: "Random Seas and Design of Maritime Structures" 3rd Edition, 
#             by Yoshimi Goda (Advanced Series on Ocean Engineering - Vol.33
sub qover {

   my ($Hs,$hc,$h,$cotAlpha,$s,$g,$report)=@_;


   my $A0=3.4 - 0.734*$cotAlpha + 0.239*$cotAlpha**2 - 0.0162*$cotAlpha**3;
   my $B0=2.3 - 0.5*$cotAlpha +0.15*$cotAlpha**2 - 0.011*$cotAlpha**3;
   my $A=$A0*tanh( (0.956 + 4.44*$s) * ($h/$Hs + 1.242 - 2.032*$s**0.25)   );
   my $B=$B0*tanh( (0.822 - 2.22*$s) * ($h/$Hs + 0.578 + 2.22*$s) );

   my $qstar=exp (-1*($A +$B * $hc/$Hs));
   my $q=sqrt($g * $Hs**3) * $qstar ;

   my $qmin;
   my $qmax;
   if ($cotAlpha < 0.0001){
      $qmin=$q* $qstar**(1/3);
      $qmax=$q* $qstar**(-1/4);
   }else{
      $qmin=$q* $qstar**(2/5);
      $qmax=$q* $qstar**(-1/3);
   }

   return ($q,$qmin,$qmax) unless (defined $report);
  
   my $unit = 'm';
   $unit = 'ft' if $g > 10;   

   my $q_=sprintf('%0.4f',$q);
   my $qmin_=sprintf('%0.4f',$qmin);
   my $qmax_=sprintf('%0.4f',$qmax);
   my $Hs_=sprintf('%0.4f',$Hs);
   my $hc_=sprintf('%0.4f',$hc);
   my $h_=sprintf('%0.4f',$h);
   my $s_=sprintf('%0.4f',$s);
   my $cotAlpha_=sprintf('%0.4f',$cotAlpha);
   my $g_=sprintf('%0.2f',$g);

   my $str=
"____________________________________________________________________________\n
Calculation of mean wave overtopping rate by \"new\" unified formulas
         for smooth inclined or vertical structures\n
Reference: 'Random Seas and Design of Maritime Structures' 3rd Edition,
                          Yoshimin Goda 
              Advanced Series on Ocean Engineering - Vol.33

$report

_____________________________________________________________________________\n
          I N P U T S:
          ------------
  Hs   = $Hs_ $unit   - significant wave height at toe of structure
  hc   = $hc_ $unit   - freeboard
  h    = $h_ $unit   - depth at Toe
  cotA = $cotAlpha_     - cotangent of structure slope
  s    = $s_     - seabed slope
  g    = $g_ $unit^2/s - acceleration due to gravity\n
          E Q U A T I O N S:
          ------------------
   A0=3.4 - 0.734*cotA + 0.239*cotA**2 - 0.0162*cotA**3
   B0=2.3 - 0.500*cotA + 0.150*cotA**2 - 0.0110*cotA**3
              A0 = $A0
              B0 = $B0\n
   A=A0*tanh( (0.956 + 4.44*s) * (h/Hs + 1.242 - 2.032*s**0.25) )
   B=B0*tanh( (0.822 - 2.22*s) * (h/Hs + 0.578 + 2.22*s) )
              A = $A
              B = $B\n
   qstar = exp (-1*(A +B * hc/Hs))
   q=sqrt(g * Hs**3) * qstar
              qstar = $qstar
              q = $q\n";

   if ($cotAlpha < 0.0001){
      $str.="
   qmin=q* qstar**(1/3)  = $qmin
   qmax=q* qstat**(-1/4) = $qmax\n";
   }else{
      $str.="
   qmin=q* qstar**(2/5) =  $qmin
   qmax=q* qstat**(-1/3) = $qmax\n";
   }

$str.="
           R E S U L T S:
           --------------\n
   q = $q_ $unit^3/s/$unit\n";

 if ($cotAlpha < 0.0001){
      $str.="\n
   Reliable range for vertical wall\n 
   $qmin_ <-- $q_ --> $qmax_  $unit^3/s/$unit\n";
   }else{
      $str.="\n
   Reliable range for sloped wall\n 
   $qmin_ <-- $q_ --> $qmax_  $unit^3/s/$unit\n";
   }

   print "$str\n";
  
   return ($q,$qmin,$qmax,$str);
}




# Matlab style
#Hs=1 % Significant wave height at toe
#h=0  % depth at toe
#
#s=1/10   % seabed slope rise/run
#alpha=0  % cotangent of structure slope (e.g. 0 is vertical) 
#
#A0=3.4 - 0.734*alpha + 0.239*alpha^2 - 0.0162*alpha^3
#B0=2.3 - 0.5*alpha +0.15*alpha^2 - 0.011*alpha^3
#
#A=A0*tanh( (0.956 + 4.44*s) * (h/Hs + 1.242 - 2.032*s^0.25)   )
#
#B=B0*tanh( (0.822 - 2.22*s) * (h/Hs + 0.578 + 2.22*s) )
