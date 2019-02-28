#!/usr/bin/env perl
use strict;
use warnings;

# based on Goda, 2012 Random Seas and Design of Maritime Structures
# JONSWAP frequency spectrum, with Mitsuyasu type directional distribution
my $dir0=-70;        # mean angle of spectrum, note 0 is the direction of STWAVE i axis, + is CW

my $pi=4*atan2(1,1);
my $deg2rad=$pi/180;
my $g=9.81;

my $hs=6.29/3.28083;  # significant wave height, meters
my $tp=4.88;  # peak period, seconds

my $gamma=3.3; # peak enhancement factor, 
               # use appoximately 1 - 7 bigger gamma means sharper peak
               # 3.3 is north sea mean, 
               # 1 jonswap reduces to modified Bretschneider-Mitsuyasu spectrum

my $smax=10;   # spreading parameter for Mitsuyasu type directional spreading
               # smax=10  wind waves               - more spreading
               # smax=25  swell with short decay
               # smax=75  swell with long decay    - less spreading

my $numFreqs=30;

my $numAngles=35;  # use 35 for half plane

# same params as in sim file
my $x=512362.624762708;
my $y=4886014.80561003;
my $wse=3.0;
my $umag=25.1;
my $udir=0.0;
my $snapID='snap1';
my $azimuth=-110.323957632935;

my $engFile='project.eng.in';

# calculate smax from wind speed and peak period eqn 2.26 - or just set smax directly above
# $smax=11.5*(2*$pi*(1/$tp)*$umag/$g)**-2.5;



#                           done config
#
##############################################################################
##############################################################################




# determine frequency bins
my $fp=1/$tp;
my $startFreq=$fp/2;
my $endFreq=2*$fp;
my $df=($endFreq-$startFreq)/($numFreqs-1);
my @Freq=( );
my $f=$startFreq;
#push @Freq, $f;
while ($f < $endFreq){
   my $f_=sprintf('%0.14e',$f);
   push @Freq, $f_;
   $f=$f+$df;
}
push @Freq, $endFreq if $#Freq+1 < $numFreqs;
print "start F = $startFreq, end F = $endFreq\n";
print "FREQ @Freq\n";

my $nf2=$#Freq+1;
die "NUMFREQ id $numFreqs, but determined $nf2 frequencies\n" unless ($nf2 == $numFreqs);



# set directional bins
my @DIR=();
my $startDir=-85;   # this is for half-plane
my $endDir=85;
my $dir=$startDir;
push @DIR, $dir*$deg2rad;
while ($dir < $endDir){
   $dir+=5;
   push @DIR, $dir*$deg2rad;
}
print "DIR @DIR\n";

my $dRads=$DIR[1]-$DIR[0];
print "drads $dRads\n";
$dir0=$dir0*$deg2rad;

my $betaj=(0.0624/(0.23+0.0336*$gamma-0.185/(1.9+$gamma)))*(1.094-0.01915*log($gamma));

# determine energy density
my @ENG=();
foreach my $freq (@Freq){
     my $sigma=0.07 if ($freq <= $fp);
     $sigma=0.09 if ($freq > $fp);

     # total JONSWAP energy in this frequency bin eqn. 2.12
     my $S=$betaj*$hs**2*$tp**-4*$freq**-5*exp(-1.25*($tp*$freq)**-4)*$gamma**(exp(-1*($tp*$freq-1)**2/(2*$sigma**2)));

     # determine s and G0
     my $s=($freq/$fp)**5 * $smax if ($f <= $fp);
     $s=($freq/$fp)**-2.5 * $smax if ($f > $fp);
     my $G0=0;
     foreach my $n (0..$#DIR-1){
     #foreach my $dir (@DIR){
           $G0+=$dRads* ( (cos(($DIR[$n]-$dir0)/2))**(2*$s)  + (cos(($DIR[$n+1]-$dir0)/2))**(2*$s) )/2;
     }
     $G0=1/$G0;
     foreach my $dir (@DIR){
         my $G=$G0*(cos(($dir-$dir0)/2))**(2*$s);
         my $eng=$S*$G;
         $eng=sprintf('%0.14e',$eng);
         push @ENG, $eng;
         print "S $S, G, $G\n";
         
     }
}

my $total=0;
foreach my $eng (@ENG){
   $total+=$eng;
   print "eng $eng, total $total\n";
}


# now right the eng file
open OUT, ">$engFile";

print OUT "#STWAVE_SPECTRAL_DATASET,\n";
print OUT "# JONSWAP with Mitsuyasu type spreading\n";
print OUT "#  Hsig = $hs, Tpeak = $tp, Gamma peak enhancement = $gamma, Smax spreading parameter = $smax\n";
print OUT "&datadims\n";
print OUT " numrecs = 1,\n";
print OUT " numfreq = $numFreqs,\n";
print OUT " numangle = $numAngles,\n";
print OUT " numpoints = 1,\n";
$azimuth=sprintf('%f',$azimuth);
print OUT " azimuth = $azimuth,\n";
print OUT " coord_sys = \"UTM\",\n";
print OUT " spzone = 19\n";
print OUT "/\n";
print OUT "#Frequencies\n";
print OUT "@Freq\n";
print OUT "#  Mitsuyasu smax is $smax\n";  # need a line here
my $str=sprintf("%f %f $f %f %f %f %f",$umag,$udir,$fp,$wse,$x,$y);
#print OUT "$snapID $umag $udir $fp $wse $x $y\n";
print OUT "$snapID $str\n";
foreach my $eng (@ENG){
  print OUT "$eng\n";
}
close OUT;
