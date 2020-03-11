package WaveOvertop;
# package of functions for wave overtopping

use strict;
use warnings;
use Math::Trig;

####################################################
# sub GodaNewUnified
#
#  my ($q,$qmin,$qmax,$reportString)=GodaNewUnified($Hs,$hc,$h,$cotAlpha,$s,$g,$report);
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
sub GodaNewUnified {

   my ($Hs,$hc,$h,$cotAlpha,$s,$g,$report)=@_;

   # check for negtive freeboard
   # if it is, determine overtopping rate with zero freeboard and add 
   # critical flow for a broad crested weir 
   # i.e. assume flow goes through critical depth that is 2/3 the negative freeboard value
   my $qweir=0;
   my $isAddWeirFlow=0;
   my $cWeir=1.0;  # weir discharge coefficient
   my $hc_org=$hc;
   if ($hc < 0){
      my $hc_weir=-$hc;
      $hc=0;
      $qweir=$cWeir*(2/3)*$hc_weir*((2/3)*$hc_weir*$g)**0.5;
      $isAddWeirFlow++;
   }

   my ($q,$qmin,$qmax,$A0,$B0,$A,$B,$qstar)=(0,0,0,0,0,0,0,0);

   if ($Hs >0){
     $A0=3.4 - 0.734*$cotAlpha + 0.239*$cotAlpha**2 - 0.0162*$cotAlpha**3;
     $B0=2.3 - 0.5*$cotAlpha +0.15*$cotAlpha**2 - 0.011*$cotAlpha**3;
     $A=$A0*tanh( (0.956 + 4.44*$s) * ($h/$Hs + 1.242 - 2.032*$s**0.25)   );
     $B=$B0*tanh( (0.822 - 2.22*$s) * ($h/$Hs + 0.578 + 2.22*$s) );

     $qstar=exp (-1*($A +$B * $hc/$Hs));
     $q=sqrt($g * $Hs**3) * $qstar ;

     if ($cotAlpha < 0.0001){
        $qmin=$q* $qstar**(1/3);
        $qmax=$q* $qstar**(-1/4);
     }else{
        $qmin=$q* $qstar**(2/5);
        $qmax=$q* $qstar**(-1/3);
     }
   }


   if  ($isAddWeirFlow){
      $q+=$qweir;
      $qmax+=$qweir;
      $qmin+=$qweir;
   }

   return ($q,$qmin,$qmax) unless (defined $report);
  
   my $unit = 'm';
   $unit = 'ft' if $g > 10;   

   my $q_=sprintf('%0.4f',$q);
   my $qmin_=sprintf('%0.4f',$qmin);
   my $qmax_=sprintf('%0.4f',$qmax);
   my $Hs_=sprintf('%0.4f',$Hs);
   my $hc_=sprintf('%0.4f',$hc_org);
   my $h_=sprintf('%0.4f',$h);
   my $s_=sprintf('%0.4f',$s);
   my $cotAlpha_=sprintf('%0.4f',$cotAlpha);
   my $g_=sprintf('%0.2f',$g);

   my $str=
"____________________________________________________________________________\n
Calculation of mean wave overtopping rate by \"new\" unified formulas
         for smooth inclined or vertical structures\n
Reference: 'Random Seas and Design of Maritime Structures' 3rd Edition,
                          Yoshimi Goda 
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


 if ($isAddWeirFlow){
    $str .= "
!!!--  WARNING: Negative Freeboard  --!!!  
 q is estimated as sum of critical broad-crested weir flow and overtopping assuming zero freeboard\n
   qWeir=Cweir*(2/3)*hc*((2/3)*hc**g)**0.5;
   Cweir = $cWeir 
   qWier = $qweir
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" 

 }


 $str.="
           R E S U L T S:
           --------------\n
   q = $q_ $unit^3/s/$unit\n
 ";

 
 if ($cotAlpha < 0.0001){
      $str.="\n
   Reliable range for vertical wall\n 
   $qmin_ <-- $q_ --> $qmax_  $unit^3/s/$unit\n";
   }else{
      $str.="\n
   Reliable range for sloped wall\n 
   $qmin_ <-- $q_ --> $qmax_  $unit^3/s/$unit\n";
   }

  # print "$str\n";
  
   return ($q,$qmin,$qmax,$str);
}


# calculate vertical wall mean wave overtopping rate by the Franco and Franco method

sub Franco {
 my ($Hs,$hc,$g,$report)=@_;
 my $a=0.082;
 my $b=3.0;
 my $q=$a * exp (-$b*$hc/$Hs)  * ($g*$Hs**3)**0.5;
 return $q;
}





1;
