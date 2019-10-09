package GodaXtreme;
#
# Perl Package for fitting Extreme value distributions following 
#
# Yoshimi Goda, 2010, "Random Seas and Design of Maritime Structures" 
# 3rd edition. Chapter 13 Statistical analysis of Extreme waves.
#
# Distributions fit include:
#  Fisher-Tippet Type I (Gumbel) 
#  Fisher-Tippet Type II (Frechet) with shape parameters k = (2.5, 3.3, 5.0, 10.0)
#  (minimal) Weibull  with shape parameters k= (0.75, 1.0, 1.4, 2.0)
# 
#
#

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

use lib 'c:\ourPerl';   # only needed foro NOAA_gauge_POT
use Date::Pcalc;        # only needed foro NOAA_gauge_POT

#################################################################
# sub read_stats
#
# reads the ordered statistics and determines the sample size
#
# Input is csv file in the format produced by WIS_PeaksOverThreshold.pl
#
# e.g.
#
#  ($sref,$n,$lambda)=GodaXtreme::read_stats('ST63020_v03.onlns_POT-stats_threshold-3.75.csv')
#  @OrderedStats=@{$sref});
#
#  $sref   -  reference to a decreasing array of ordered peak wave heights (from POT)
#  $n      -  the number of samples
#  $lamda  -  the annual rate, based on the total time series duration given on the first line
#             in the input file 
#
sub read_stats{
   my $infile=shift;
   open IN, "<$infile" or die "ERROR:  GodaXtreme.pm:  Cant read $infile for input";
   my $line= <IN>;
   $line =~ s/^\s+//;
   my @data=split(/\s+/,$line);
   my $totalDuration=shift @data;
   <IN>;
   <IN>;
   my @OS=();
   while  (<IN>){
      chomp;
      @data=split(/,/,$_);
      push @OS, $data[1],
   }
   close (IN);
   my $N=$#OS+1;
  my $lambda = $N / $totalDuration;
   return (\@OS,$N,$lambda);
}

#################################################################
# sub reducedVariate
#
# determines reduced variate (eqn 13.35) based on 
# unbiased plotting position, eqn 13.28 
# 
#  e.g. my $rv_ref=GodaXtreme::reducedVariate(\@Ordered,$distType,$k,$nu);
#
# input is:
#    \@Ordered - reference to array of ordered statistics
#    distType - a string identifying the distribution type
#       (Gumbel or FT-I, Frechet or FT-II, Weibull, Normal, or Lognormal)
#    k - shape parameter, required for FT-II and Weibiull 
#    nu - censoring parameter, use 1 for uncensored data.
#         Note,  nu=N/Nt, where N is number of events in the sample and
#         Nt is total number of events that would have occured during the 
#         analysis period.
#
#
sub reducedVariate{
   my ($sref,$distType,$k,$nu)=@_;
   $distType=uc($distType);
   # dereference data
   my @Ordered=@{$sref};
   $k= 1 unless (defined $k);  # assume Gumbel if k is not given 

   # determine number of events in sampling period
   $nu = 1 unless (defined $nu);
   my $N=$#Ordered+1;
   my $Nt=$N/$nu;

   # get the constants
   my ($a,$b)=&getPPalphaBeta($distType,$k);
   
   # determine the plotting position values and reduced variate
   my @PP;
   my @Y;  # reduced variate
   my $m=1;
   while ($m <= $N){
      my $f=1 - ($m-$a)/($Nt-$b); # plotting position eqn 13.28;
      push @PP, $f;
      # reduced variate depending on distribution type eqn 13.35;
      my $y;
      if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
         $y = -1*log(-1*log($f)); 
      }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
         $y = $k * ( (-1*log($f))**(-1/$k) -1);     
       }elsif ($distType =~ m/WEIBULL/){
         $y = (-1*log (1-$f))**(1/$k); 
       }else{
           die "ERROR:  GodaXtreme.pm:  Bad distribution type for reducedVariate\n";
       }
       push @Y, $y;

      $m++;
   }
   
   my $astr=sprintf("%7.4f",$a);
   my $bstr=sprintf("%7.4f",$b);

   my $log="Determine Reduced Variate:\n".
           "   Distribution type  = $distType\n".
           "   Shape paramater, k = $k\n". 
           "   Censoring paramater, nu = $nu\n".
           "   Number of events in analysis, N = $N\n".
           "   Estimated number of events in sampling period, Nt = $Nt\n".
           "   Unbiased plotting position formula (eqn 13.28): F=1 - (m-alpha)/(Nt-beta)\n".
           "   Unbiased plotting position Constanst, alpha = $astr, beta = $bstr\n";
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
      $log.="   FT-I Reduced Variate (eqn 13.35): y = -1*log(-1*log(F))\n"; 
   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
      $log.="   FT-II Reduced Variate (eqn 13.35): y = k * ( -1*log(F)**(-1/k) -1)\n";       
   }elsif ($distType =~ m/WEIBULL/){
      $log.="   Minimal Weibull Reduced Variate (eqn 13.35): y = (-1*log (1-F))**(1/k)\n"; 
   }else{
           die "ERROR:  GodaXtreme.pm:  Bad distribution type for reducedVariate\n";
   }
  # $log.="#-----------------------------------------------------#\n";
   $log.="   Reduced Variate:\n  [";
   my $n=0;
   my @YTMP=@Y;
   while (@YTMP){
        my $ytmp=shift @YTMP;
        $log.=sprintf(" %7.3f,",$ytmp);
        $n++; 
        if ($n == 8){
           $n=0;
           $log.="\n   ";
        }
   } 
   
   $log.="]\n";

  # print "!--------------------------!\nINFO: GodaXtreme::reducedVariate:\n$log\n";

   return (\@Y,$log);
}


       



 
   


##################################################################
# sub getPPalphaBeta
#
# returns the alpha and beta constants for the unbiased
# plotting position formula given the distribution type
# and shape parameter (for Frechet and Weibull) 
#
# from Table 13.2
#
sub getPPalphaBeta{
   my ($distType,$k)=@_;
   $distType = uc ($distType);
   my $a;
   my $b;
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
       $a=0.44;
       $b=0.12;
   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
        $a=0.44+0.52/$k;
        $b=0.12-0.11/$k;
   }elsif ($distType =~ m/WEIBULL/){
        $a=0.20+0.27/$k**0.5;
        $b=0.20+0.23/$k**0.5;
   }elsif ($distType =~ m/NORMAL/){  # for both normal and lognormal distributions
        $a=0.375;
        $b=0.25;
   }else{
        die "ERROR:  GodaXtreme.pm:  Bad distribution type for getPPalphaBeta\n";
   }
   return ($a,$b);
} 


##########################################################
# sub leastSquares
#
# solution of equations 13.30 by substitution
#
#  e.g.   my ($A,$B,$rsq)=leastSquares(\@X,\@Y);
#
#  solves: x(m) = B + A*y(m)
#
#  $rsq is the coefficient of determination
#
#
sub leastSquares{
   my ($xref,$yref)=@_;

   my @X=@{$xref};
   my @Y=@{$yref};

   #calculate sums
   my $sumy2=0;
   my $sumy=0;
   my $sumxy=0;
   my $sumx=0;
   my $N=$#X+1;
   my $meanx=0;
   foreach my $n (1..$N){
      my $x=shift(@X);  push @X, $x;
      my $y=shift(@Y);  push @Y, $y;
      $sumy2=$sumy2+$y*$y;
      $sumy=$sumy+$y;
      $sumx=$sumx+$x;
      $sumxy=$sumxy+$x*$y;
      $meanx=$meanx+$x;
   }
   $meanx=$meanx/$N;

 
   # determine slope (a) and intercept (b)
   my $a = ($sumxy - ($sumx*$sumy)/$N  ) / ( $sumy2 - ($sumy*$sumy/$N ) ); 
   my $b = ($sumx - $a*$sumy) / $N;

   # rsq coefficient of determination
   my $ssTotal=0;
   my $ssResidue=0;
   foreach my $n (1..$N){
       $ssTotal=$ssTotal+($X[$n-1]-$meanx)**2.0;
       my $x_=$b + $a*$Y[$n-1];
       $ssResidue=$ssResidue+($x_-$X[$n-1])**2.0;
   }
   my $rsq=1-$ssResidue/$ssTotal;	
   
   my $slope=sprintf("%8.3f",$a);
   my $intercept=sprintf("%8.3f",$b);
   my $log="   Best Fit Line: X(m) = $intercept + $slope * Y(m)\n";
   $log .= "   Coefficient of Determination, r**2 =  $rsq\n";


   return ($a,$b,$rsq,$log);

}


#-!!! not sure about this one ????? weights seem to be backwards
##########################################################
# sub extendedLeastSquares
#
# solution of equations 13.31 by substitution
#
#  e.g.   my ($A,$B,$rsq)=extendedLeastSquares(\@X,\@Y,$distType,$k,$nu);
#
#  solves: x(m) = B + A*y(m)
#
#  distType,k,nu are same as for reducedVariate
#
#  $rsq is the coefficient of determination 
#  
#  Uses weights for Gumbel (eqn 13.32) and Weibull (eqn 13.33)
#
sub extendedLeastSquares{
   my ($xref,$yref,$distType,$k,$nu)=@_;

   my @X=@{$xref};
   my @Y=@{$yref};
   $distType=uc($distType);

   # get the constants
   my ($alpha,$beta)=&getPPalphaBeta($distType,$k);

   #calculate sums
   my $sumw2y2=0;
   my $sumw2y=0;
   my $sumw2xy=0;
   my $sumw2x=0;
   my $sumw2=0;
   my $N=$#X+1;
   my $meanx=0;
   my $Nt=$N/$nu;  # if data are censored Nt maybe > N
     
   foreach my $n (1..$N){
      my $x=shift(@X);  push @X, $x;
      my $y=shift(@Y);  push @Y, $y;
      my $m = $N-$n +1; 
      # get weights
      my $w2;
      if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
         $w2 = (($Nt+$alpha+$beta-$m)/($m-$alpha))*(log( ($Nt+$alpha+$beta-$m)/($m-$alpha)))**2.0
      }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
        $w2=1;  #effectively same as non-extended method       
      }elsif ($distType =~ m/WEIBULL/){
        $w2=( ($m-$alpha)/($Nt+$alpha+$beta-$m) )*(-1*log(($m-$alpha)/($Nt+$beta)))**(2*($k-1)/$k);
      }else{
           die "ERROR:  GodaXtreme.pm:  Bad distribution type for extendedLeastSquares\n";
      }
 #print "w2 $w2\n";
      $sumw2y2+=$y*$y*$w2;
      $sumw2y+=$y*$w2;
      $sumw2x+=$x*$w2;
      $sumw2xy+=$x*$y*$w2;
      $sumw2+=$w2;
      $meanx+=$x;

   }
   $meanx=$meanx/$N;
#print "meanx $meanx\n";  
#print "sumwt $sumw2\n";
 
   # determine slope (a) and intercept (b)
   my $a = ($sumw2xy - ($sumw2x*$sumw2y)/$sumw2  ) / ( $sumw2y2 - ($sumw2y*$sumw2y/$sumw2 ) ); 
   my $b = ($sumw2x - $a*$sumw2y) / $sumw2;
  
   # rsq coefficient of determination
   my $ssTotal=0;
   my $ssResidue=0;
   foreach my $n (1..$N){
       $ssTotal=$ssTotal+($X[$n-1]-$meanx)**2.0;
       my $x_=$b + $a*$Y[$n-1];
       $ssResidue=$ssResidue+($x_-$X[$n-1])**2.0;
   }
   my $rsq=1-$ssResidue/$ssTotal;
#print "ss ex $ssTotal $ssResidue\n";	

   return ($a,$b,$rsq);

}




###################################################
# sub returnValue
#
# e.g.  ($rv)=returnValue($returnPeriod,$a,$b,$distType,$k,$lambda)
#
# a,b are slope,intercept, for best fit line from leastSquares
# distType is same as used in reducedVariate
# k is shape parameter
# returnPeriod is a scalar return period or reference to array of return periods
# lambda is the mean rate in events per year
#
# rv is scalar or reference to return value computed from best fit line
#
sub returnValue{
   my ($rp_,$a,$b,$distType,$k,$lambda)=@_;
   $distType=uc($distType);
   my @RP;
   my @X;
   my $lam_str=sprintf("%8.4f",$lambda);
   if (ref($rp_) eq 'ARRAY'){
       @RP=@{$rp_};
   }else{
       $RP[0]=$rp_;
   }
   foreach my $rp (@RP){
      my $y;
      if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
         $y = -1*log(-1*log(1-1/($lambda*$rp)));
      }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
         $y = $k * ( (-1*log(1-1/($lambda*$rp)))**(-1/$k) -1);       
       }elsif ($distType =~ m/WEIBULL/){
         $y = (log ($lambda*$rp))**(1/$k); 
       }else{
           die "ERROR:  GodaXtreme.pm:  Bad distribution type for returnValue\n";
       }
       my $x=$a*$y+$b;
       push @X, $x;
   }
   my $log='   Reduced Variate: Y(rp) = ';
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
       $log.=" -1*log(-1*log(1-1/($lam_str*rp)))  (eqn 13.17)\n";
   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){
         $log.=" $k * ( (-1*log(1-1/($lam_str*rp)))**(-1/$k) -1)  (eqn 13.17)\n";       
   }elsif ($distType =~ m/WEIBULL/){
         $log.=" (log ($lam_str*rp))**(1/$k)  (eqn 13.17)\n";
   }else{
        die "ERROR:  GodaXtreme.pm:  Bad distribution type for returnValue\n";
   }

   my $rv;
   if (ref($rp_) eq 'ARRAY'){
       $rv=\@X;
       foreach my $n (0..$#X){
          $X[$n]=sprintf("%10.3f",$X[$n]);
          $RP[$n]=sprintf("%10d",$RP[$n]);
       }
          my $xstr=join(' , ',@X);
          my $rpstr=join(' , ',@RP);
       $log .=" Return Periods: $rpstr\n";
       $log .=" Return Values:  $xstr\n";
   }else{
       $rv=$X[0];
       $log .=" Return Periods: $RP[0]\n";
       $log .=" Return Values:  $rv\n";
   }
   
   
        



   return ($rv,$log);
}

#############################################################
# sub WISoneLinePOT
# 
# e.g. WISoneLinePOT(
#                     -ONELINE => $oneLineFile,
#                     -THRESHOLD => $threshold,
#                     -LOGFILE   => $logFile,
#                     -OFFSHOREDIR => $offShoreDir,
#                     -HALFSECTOR => $halfSectorWidth,
#                     -RECORDFREQ => $recsPerHour,
#                     -MINEVENTDURATION => $minEventDuration,
#                     -WINDORWAVE=>'wind'        
#                   )  
#

sub WISoneLinePOT{
    my %args=@_;
    my $oneLine=$args{-ONELINE};
    my $threshold=$args{-THRESHOLD};
    my $logFile="$oneLine"."_POT-stats_threshold-$threshold.log";
    $logFile=$args{-LOGFILE} if defined ($args{-LOGFILE});
    my $azimuth;
    $azimuth=$args{-OFFSHOREDIR} if defined ($args{-OFFSHOREDIR});
    my $halfSectorWidth=90;
    $halfSectorWidth=$args{-HALFSECTOR} if defined ($args{-HALFSECTOR});
    my $recsPerHour=1;
    $recsPerHour=$args{-RECORDFREQ} if defined ($args{-RECORDFREQ});
    my $minEventDuration = 1;
    $minEventDuration = $args{-MINEVENTDURATION} if defined ($args{-MINEVENTDURATION});
    $minEventDuration=$minEventDuration*$recsPerHour;
    
   
    my $windOrWave=lc($args{-WINDORWAVE});
    my $magIndex=9;  # these are defaults for wave analysis, wind spd and dir are 4,5, respectively
    my $dirIndex=15;
    if ($windOrWave =~ m/wind/){
       $magIndex=4;  
       $dirIndex=5;
    }
  

    open LOG, ">>$logFile" or die "ERROR:  GodaXtreme.pm:  fitWISoneLine:  cant open logfile $logFile for writing\n";
              #         1         2         3         4         5         6         7
              #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------- Statistical Analysis of Extreme Wave Heights ---------------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print LOG "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print LOG "#                                                                      #\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#                                                                      #\n";
          #123456789012345678901234567890123456789012345678901234567890123456789012
    print "\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#--------- Statistical Analysis of Extreme Wave Heights ---------------#\n";
    print  "#----------------------------------------------------------------------#\n";
    print  '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print  "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print  "#                                                                      #\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#                                                                      #\n";
     
    # say if this is wind or wave analysis
    if ($windOrWave =~ m/wind/){
        print LOG "#                   Analysis of Wind Speed                            #\n";   
        print LOG "# -where log reports Sig. Wave Ht. in meters replace with Wind Speed in meters/second #\n\n";   
           print  "#                   Analysis of Wind Speed                            #\n";   
           print  "# -where log reports Sig. Wave Ht. in meters replace with Wind Speed in meters/second #\n\n";   
    }else{
        print LOG "#       Analysis of Significant Wave Height                     #\n\n";   
           print  "#       Analysis of Significant Wave Height                     #\n\n";   
    }   

    # ingest the oneline file 
    my @T;  
    my @HS;
    my @DIR;
    my @TP;

    open IN, "<$oneLine" or die "ERROR: GodaXtreme.pm:  fitWISoneLine: Cannot open oneline file $oneLine\n";
    
    my $station;
    my $lat;
    my $lon;
    my $minDir=$azimuth-$halfSectorWidth;
    my $maxDir=$azimuth+$halfSectorWidth;

    while (<IN>){
       chomp;
       $_ =~ s/^\s+//g;
   
       my @data=split(/\s+/,$_);

       push @T, $data[0];
       my $hs = $data[$magIndex];
       my $dir = $data[$dirIndex];
       my $tp= $data[11];
       $station = $data[1];
       $lat = $data[2];
       $lon = $data[3];
       if (defined $azimuth){
          $hs=0 unless (( $dir >= $minDir) and ($dir <= $maxDir));
       }
       push @HS, $hs;
       push @DIR, $dir;
       push @TP, $tp;
    }
    close(IN);
   
    print LOG "  INFO read from WIS one line file: $oneLine\n";
    print LOG "     WIS station:  $station\n";
    print LOG "     Latitude:     $lat\n";
    print LOG "     Longitude:    $lon\n";
    print "  INFO read from WIS one line file: $oneLine\n";
    print "     WIS station:  $station\n";
    print "     Latitude:     $lat\n";
    print "     Longitude:    $lon\n";
  
 
    my $str=$T[0];
    $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    my $t = "$1-$2-$3 $4:$5";
    print LOG "     First Record:  $t\n";
    $str=$T[$#T];
    $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    $t = "$1-$2-$3 $4:$5";
    print LOG "     Last  Record: $t\n";
    my $nrecs=$#T+1;
    print LOG "     Number of Records: $nrecs\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------------------- Chronological peak data ------------------------#\n";
    print LOG "#                                                                      #\n";
    my $thres_=sprintf("%4.2f",$threshold);
    my $minD_=sprintf("%3d",$minDir);
    my $maxD_=sprintf("%3d",$maxDir);
    print LOG "#--- Events with peak significant wave height exceeding $thres_ meters ---#\n";
    print LOG "#---- and mean direction between $minD_ and $maxD_ degrees CW from North ----#\n" if defined $azimuth;
    print LOG "#                                                                      #\n";
    print LOG "   Peak,     Time      ,   Record , Duration,  Hsig,  Dir,   Tp  \n";     
   
    # now find the peaks over threshold
    my @PEAKS;
    my @TP_atPeak;
    my @DIR_atPeak;
    my $peakCount=0;
    my @PeakTimes;
    my $hr=-1;
    my @PeakHours;
    my $upCross;
    my $downCross;
    my @UpCrosses;
    my @DownCrosses;
    my @Duration;
    while (@HS){
       my $hs = shift(@HS);  my $t = shift (@T); push @T, $t; $hr++;
       my $tp=shift @TP; push @TP, $tp;
       my $dir=shift @DIR; push @DIR, $dir;
       my $peakHs=0;    my $peakT;
       my $peakHr;
       my $peakTp; my $peakDIR;
       if ($hs >= $threshold){      # up-crossing of threshold
          $peakHs=$hs;
          $peakT=$t;
          $peakHr=$hr;
          $upCross=$hr;
          $peakTp=$tp;
          $peakDIR=$dir;
          while (@HS){   # continue on to find down crossing.
              $hs = shift @HS; $t = shift @T; push @T, $t; $hr++;
              $tp=shift @TP; push @TP, $tp;
              $dir=shift @DIR; push @DIR, $dir;
              if ($hs > $peakHs){
                 $peakHs=$hs;
                 $peakT=$t;
                 $peakHr=$hr;
                 $peakTp=$tp;
                 $peakDIR=$dir;
              } 
              if ( $hs < $threshold ){  # down-crossing of threshold
              # if ($hs < $threshold  and ($hr-$upCross > $minEventDuration)){  # down-crossing of threshold
                 $downCross=$hr;
                 push @PEAKS, $peakHs;
                 push @PeakTimes, $peakT;
                 push @UpCrosses, $upCross;
                 push @DownCrosses, $downCross;
                 push @TP_atPeak, $peakTp;
                 push @DIR_atPeak, $peakDIR;
                 my $duration=$downCross-$upCross;
                 push @Duration, $duration;
                 push @PeakHours, $peakHr+1;
                 $peakCount++;
                 $str=sprintf("   %4d, %13s,%10d, %8d,  %4.2f,  %3d,  %5.2f",$peakCount,$peakT,$peakHr,$duration,$peakHs,$peakDIR,$peakTp);
                 #print LOG "peak $peakCount, time $peakT, record $hr, duration $duration, Hs= $peakHs, dir=$peakDIR, Tp=$peakTp \n";
                 print LOG "$str\n";
                 last;
              }    
          }
          unless (@HS){  # in case we end before a down-crossing
               push @PEAKS, $peakHs;
               push @PeakTimes, $peakT;
               push @UpCrosses, $upCross;
               $downCross=-999;
               push @DownCrosses, $downCross;
               push @TP_atPeak, $peakTp;
               push @DIR_atPeak, $peakDIR;
               my $duration=$downCross-$upCross;
               push @Duration, $duration;
               push @PeakHours, $peakHr+1;
               $peakCount++;

               print "e!!!!!!!!nded before down crossing\n";
               print LOG "e!!!!!!!!nded before down crossing\n";
              # print LOG "#-- peak $peakCount at time $peakT is $peakHs\n";
          }
       }
    }

    

    # check to see if we need to merge peaks
    if ($minEventDuration > 1){
      print LOG "#----------------------------------------------------------------------#\n";
      print LOG "Check if peaks are within minEventDuration $minEventDuration hours and should be merged\n";
      print LOG "#----------------------------------------------------------------------#\n";

      my $minT=-99999999;

      my $iter=0;
     
      while ($minT < $minEventDuration){
  
        $iter++;
        print LOG "Peak merging iteration: $iter\n";


        my $peakHs=shift @PEAKS; 
        my $peakT=shift @PeakTimes; 
        my $upCross=shift @UpCrosses; 
        my $downCross=shift @DownCrosses;
        my $peakTp=shift @TP_atPeak; 
        my $peakDIR=shift @DIR_atPeak; 
        my $duration=shift @Duration; 
        my $hr=shift @PeakHours;  
        my @NN=(0..$#PEAKS);
        while (@NN){
          my $dt_peaks=$PeakHours[0]-$hr;
          if ($dt_peaks < $minEventDuration) {
             $str=$peakT;
             $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
             my $t1 = "$1-$2-$3 $4:$5";
             $str=$PeakTimes[0];
             $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
             my $t2 = "$1-$2-$3 $4:$5";
             print LOG "*-- Merge Peaks iter: $iter, $peakHs (at $t1) and $PEAKS[0] (at $t2)\n";
             if ($PEAKS[0] > $peakHs){  # keep n+1, shift then push, keep first upcross
               $peakHs=shift @PEAKS; 
               $peakT=shift @PeakTimes; 
               $upCross=shift @UpCrosses; 
               $downCross=shift @DownCrosses;
               $peakTp=shift @TP_atPeak; 
               $peakDIR=shift @DIR_atPeak; 
               $duration=shift @Duration; 
               $hr=shift @PeakHours;  
               shift @NN;
               push @PEAKS, $peakHs;
               push @PeakTimes, $peakT;
               push @UpCrosses, $upCross;
               push @DownCrosses, $downCross;
               push @TP_atPeak, $peakTp;
               push @DIR_atPeak, $peakDIR;
               push @Duration, $duration;
               push @PeakHours, $hr;
               print LOG "    keeping Higher Later peak of $peakHs at hour $hr (at $t2)\n";
             }else{ #keep n            push then shift
               push @PEAKS, $peakHs;
               push @PeakTimes, $peakT;
               push @UpCrosses, $upCross;
               push @DownCrosses, $downCross;
               push @TP_atPeak, $peakTp;
               push @DIR_atPeak, $peakDIR;
               push @Duration, $duration;
               push @PeakHours, $hr;
               print LOG "    keeping Higher Earlier peak of $peakHs at hour $hr (at $t1)\n";
               $peakHs=shift @PEAKS; 
               $peakT=shift @PeakTimes; 
               $upCross=shift @UpCrosses; 
               $downCross=shift @DownCrosses;
               $peakTp=shift @TP_atPeak; 
               $peakDIR=shift @DIR_atPeak; 
               $duration=shift @Duration; 
               $hr=shift @PeakHours;  
               shift @NN;
            }
            last unless (@NN);   # to correct for pathology that occurs if merging last two peaks.
          }else{
             push @PEAKS, $peakHs;
             push @PeakTimes, $peakT;
             push @UpCrosses, $upCross;
             push @DownCrosses, $downCross;
             push @TP_atPeak, $peakTp;
             push @DIR_atPeak, $peakDIR;
             push @Duration, $duration;
             push @PeakHours, $hr;
          }  # not less than min duration
          $peakHs=shift @PEAKS; 
          $peakT=shift @PeakTimes; 
          $upCross=shift @UpCrosses; 
          $downCross=shift @DownCrosses;
          $peakTp=shift @TP_atPeak; 
          $peakDIR=shift @DIR_atPeak; 
          $duration=shift @Duration; 
          $hr=shift @PeakHours;  
          shift @NN;
          # if last one, and not less than min duration, we need to push it back on 
          unless (@NN){
             push @PEAKS, $peakHs;
             push @PeakTimes, $peakT;
             push @UpCrosses, $upCross;
             push @DownCrosses, $downCross;
             push @TP_atPeak, $peakTp;
             push @DIR_atPeak, $peakDIR;
             push @Duration, $duration;
             push @PeakHours, $hr;
         }

        } #end NN loop
      
        $minT=9999999;       
        foreach my $n (0..$#PEAKS-1){
          my $dt=$PeakHours[$n+1]-$PeakHours[$n];
          $minT=$dt if $dt < $minT;
        } 
        print LOG "Iteration: $iter, Minimum time between peaks is: $minT hours\n";

      } #end iterative megring while loop
      
    }# end if checking need to merge peaks


    # calculate some stats as a sanity check on the peak duration and time between peaks
    my $totalDuration=$nrecs/24/365.25/$recsPerHour;
    my $minTimeBetweenPeaks=99999999;
    my $minPeakDuration=999999999;
    my $maxPeakDuration=0;
    my $npeaks=$#PEAKS+1;
    my $lambda=$npeaks/$totalDuration;
    foreach my $n (0..$npeaks-1){
       $minPeakDuration=$Duration[$n] if ($Duration[$n] < $minPeakDuration);
       $maxPeakDuration=$Duration[$n] if ($Duration[$n] > $maxPeakDuration);

       if ($n < $npeaks-1){
           my $dt=$PeakHours[$n+1]-$PeakHours[$n];
           if ($dt < 0)  {
           }
 
           $minTimeBetweenPeaks=$dt if $dt < $minTimeBetweenPeaks;
           

       } 
    }  
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#-------- Sanity Check on Peak Durations and Time Between Peaks--------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "   Total Record Duration:  $totalDuration years\n";
    print LOG "   Using POT method with Threshold:  $threshold; $npeaks peaks were found\n";  
    if (defined $azimuth) {
        print LOG "  *--------------\n";
        print LOG "   Only considering waves coming from $azimuth\n";
        print LOG "   degrees CW from North +- $halfSectorWidth degrees\n";
        print LOG "  *--------------\n";
    }
    print LOG "   Average Rate (lambda):  $lambda events/year\n";
    print LOG "   Peaks with less than $minEventDuration hours between are consider a single event and merged\n";
    my $minHrsBtwPeaks=$minTimeBetweenPeaks/$recsPerHour;
    print LOG "   Minimum Time Between Peaks:  $minHrsBtwPeaks hours\n";
    my $minDurHr=$minPeakDuration/$recsPerHour;
    print LOG "   Minimun Peak Duration: $minDurHr hours\n";
    my $maxDurHr=$maxPeakDuration/$recsPerHour;
    print LOG "   Maximum Peak Duration: $maxDurHr hours\n";

    print "#----------------------------------------------------------------------#\n";
    print "#-------- Sanity Check on Peak Durations and Time Between Peaks--------#\n";
    print "#----------------------------------------------------------------------#\n";
    print "   Total Record Duration:  $totalDuration years\n";
    print  "   Using POT method with Threshold:  $threshold; $npeaks peaks were found\n";  
    if (defined $azimuth) {
        print  "  *--------------\n";
        print  "  Only considering waves coming from $azimuth\n";
        print  "   degrees CW from North +- $halfSectorWidth degrees\n";
        print  "  *--------------\n";
    }
    print  "   Average Rate (lambda):  $lambda events/year\n";
    print  "   Peaks with less than $minEventDuration hours between are consider a single event and merged\n";
    print  "   Minimum Time Between Peaks:  $minHrsBtwPeaks hours\n";
    print  "   Minimun Peak Duration: $minDurHr hours\n";
    print  "   Maximum Peak Duration: $maxDurHr hours\n";




    # sort the data and write the orders statistics 
    my @sorted_i = sort {$PEAKS[$b] <=> $PEAKS[$a]} (0..$#PEAKS);

               #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#------------------------------- Rank Ordered Peak Values ------------------------------------#\n";
    print LOG "Rank, Hsig (m),     Time of Peak ,     Upcross Time ,   Downcross Time , Duration,   Dir,    Tp\n";

    my $rank=1;
    foreach my $i (@sorted_i){
       my $str=$PeakTimes[$i];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $t = "$1-$2-$3 $4:$5";
   
       $str=$T[$UpCrosses[$i]];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $uc="$1-$2-$3 $4:$5";
   
       $str=$T[$DownCrosses[$i]];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $dc="$1-$2-$3 $4:$5";
  
       $str=sprintf("%4d,%9.3f,  %16s,  %16s,  %16s,%9.1f, %5.1f, %5.2f",$rank,$PEAKS[$i],$t,$uc,$dc,$Duration[$i],$DIR_atPeak[$i],$TP_atPeak[$i]);
       print LOG "$str\n";
       #print OUT "$rank,$PEAKS[$i],$t,$uc,$dc,$Duration[$i],$DIR_atPeak[$i],$TP_atPeak[$i];\n";
       $rank++; 
    }
    my @Ordered=@PEAKS[@sorted_i];
    close (LOG);

    return (\@Ordered,$lambda,$logFile);

} # end WISoneLinePOT




#############################################################
# sub NOAA_gauge_POT
# 
# e.g. NOAA_gauge_POT(
#                     -STATIONID => $stationID,    # NOAA station ID number
#                     -BEGINDATE => $beginDate,    # yyyymmdd
#                     -ENDDATE   => $endDate,      # yyyymmdd
#                     -PRODUCT   => $product,      # e.g. hourly_height, water_level, wind  
#                     -DATUM     => $datum,        # e.g. MHHW,MHW,DTL,MTL,MSL,MLW,MLLW,GT,MN,DHQ,DLQ,NAVD
#                     -UNITS     => $units,        # e.g. metric or english
#                     -THRESHOLD => $threshold,    # threshold value for POT
#                     -LOGFILE   => $logFile,      # optional name of logfile
#                     -RECORDFREQ => $recsPerHour, # e.g. 10 for 6 minute "water_level",  1 for hourly_height
#                     -MINEVENTDURATION => $minEventDuration,    # optional, event duration in hours,  default is 24 hours    
#                     -COOPSFILE => $coopsFile     # optional name of file downloaded with getCOOPS.pl with time series data
#                   )                              # specify this if you have already dowlnoaded the data from CO-OPS 
#

sub NOAA_gauge_POT{
    my %args=@_;
    my $stationID=$args{-STATIONID};
    my $beginDate=$args{-BEGINDATE};
    my $endDate = $args{-ENDDATE};
    my $product = $args{-PRODUCT};
    my $datum   = $args{-DATUM};
    my $units   = $args{-UNITS};
    my $threshold=$args{-THRESHOLD};
    my $logFile="station-$stationID-begin-$beginDate-end-$endDate-$product-$units-$datum-threshold-$threshold-POT_stats.log";
    $logFile=$args{-LOGFILE} if defined ($args{-LOGFILE});
    my $recsPerHour=1;
    $recsPerHour=10 if ($product =~ m/water_level/i); 
    $recsPerHour=$args{-RECORDFREQ} if defined ($args{-RECORDFREQ});
    my $minEventDuration = 24;  # hours
    $minEventDuration = $args{-MINEVENTDURATION} if defined ($args{-MINEVENTDURATION});
    $minEventDuration=$minEventDuration*$recsPerHour;
    my $coopsFile= 0;
    $coopsFile = $args{-COOPSFILE} if defined ($args{-COOPSFILE});
    my $pathToDataGetter='c:/ourPerl/DataGetters';
    $pathToDataGetter=$args{-PATHTODATAGETTER} if defined $args{-PATHTODATAGETTER};

  
    open LOG, ">>$logFile" or die "ERROR:  GodaXtreme.pm:  fitWISoneLine:  cant open logfile $logFile for writing\n";
              #         1         2         3         4         5         6         7
              #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------- Statistical Analysis of Extreme $product --------------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print LOG "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print LOG "#                                                                      #\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#                                                                      #\n";
          #123456789012345678901234567890123456789012345678901234567890123456789012
    print "\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#--------- Statistical Analysis of Extreme $product ---------------#\n";
    print  "#----------------------------------------------------------------------#\n";
    print  '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print  "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print  "#                                                                      #\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#                                                                      #\n";
     
    # get the COOPS data if we don't have it already
    unless ($coopsFile){
       $coopsFile="$stationID-$product-$datum-$units-$beginDate-$endDate".'.csv';
       my $cmdstr="$pathToDataGetter/getCoopsdata.pl --station $stationID --begin $beginDate --end $endDate --product $product --datum $datum --units $units --timezone GMT --format CSV --outfile $coopsFile";
       print "Getting COOPS data with command: $cmdstr\n";
       system($cmdstr);
    }
    
    # ingest the COOPS data
    open IN, "<$coopsFile" or die "Cant open $coopsFile";
    <IN>; #skip headerline
    my @WSE;
    my @HR;
    my @T;
    my $firstline=1;
    my ($yyyy0,$mm0,$dd0,$HH0,$MM0);
    while(<IN>){
       chomp;
       $_.=',';
       next unless ( $_ =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d),(.+?),/);
       my $yyyy=$1;
       my $mm=$2;
       my $dd=$3;
       my $HH=$4;
       my $MM=$5;
       my $wse=$6;
       if ($firstline){
          ($yyyy0,$mm0,$dd0,$HH0,$MM0)= ($yyyy,$mm,$dd,$HH,$MM);
       }
       my ($D_d, $Dh,$Dm,$Ds) = Date::Pcalc::Delta_DHMS($yyyy0,$mm0,$dd0,$HH0,$MM0,0,
                                                       $yyyy ,$mm ,$dd ,$HH ,$MM ,0);
       my $hr=$D_d*24+$Dh+$Dm/60 + $Ds/3600;
       push @HR,$hr;
       push @T,"$yyyy"."$mm"."$dd"."$HH"."$MM".'00';
       push @WSE,$wse;   
       $firstline=0;
    }
    close(IN);
   
    print LOG "  INFO read from COOPS file: $coopsFile\n";
    print LOG "     NOAA station:  $stationID\n";
    print "  INFO read from COOPS file: $coopsFile\n";
    print "     NOAA station:  $stationID\n";
  
 
    my $str=$T[0];
    $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    my $t = "$1-$2-$3 $4:$5";
    print LOG "     First Record:  $t\n";
    $str=$T[$#T];
    $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
    $t = "$1-$2-$3 $4:$5";
    print LOG "     Last  Record: $t\n";
    my $nrecs=$#T+1;
    print LOG "     Number of Records: $nrecs\n";
    # check for missing data
    # fill in holes with dummy data below threshold
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------------------- Check for misssing data ------------------------#\n";
    print LOG "#                                                                      #\n";
    my $dt0=1/$recsPerHour;
    my $k=0;
    my $nt=$#T;
    while ($k < $nt-1){
       my $hr=shift(@HR); push @HR,$hr;
       my $wse=shift(@WSE); push @WSE, $wse;
       my $t=shift(@T); push @T, $t;
       my $dh= $HR[0] - $hr;
       if ( $dh > 1.0000000001*$dt0 ){
          my $dx=$dh/24;
          my $str=sprintf("%7.2f",$dx);
          print LOG "Missing data $str days between $t and $T[0]\n";
          $hr=$hr+$dt0;
          while ($hr<$HR[0]){
              push @HR,$hr;
              push @T,'0000-00-00';
              push @WSE,$threshold-100;
              $hr=$hr+$dt0;
          }
          
       }
       $k++;
    }
  
    open TMP,">dummiesFilledIn.csv";
    foreach my $k (0..$#WSE){
       print TMP "$T[$k],$HR[$k],$WSE[$k]\n";
    }
    close (TMP);


    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------------------- Chronological peak data ------------------------#\n";
    print LOG "#                                                                      #\n";
    my $thres_=sprintf("%4.2f",$threshold);
    print LOG "#--- Events with peak $product exceeding $thres_ $units ---#\n";
    print LOG "#                                                                      #\n";
    print LOG "   Peak,     Time      ,   Record , Duration,  value \n";     
   
    # now find the peaks over threshold
    my @PEAKS;
    my $peakCount=0;
    my @PeakTimes;
    my $hr=-1;
    my @PeakHours;
    my $upCross;
    my $downCross;
    my @UpCrosses;
    my @DownCrosses;
    my @Duration;
    while (@WSE){
       my $wse = shift(@WSE);  my $t = shift (@T); push @T, $t; $hr+=1/$recsPerHour;
       my $peakWse=0;    my $peakT;
       my $peakHr;
     #  my $peakTp; my $peakDIR;
       if ($wse >= $threshold){      # up-crossing of threshold
          $peakWse=$wse;
          $peakT=$t;
          $peakHr=$hr;
          $upCross=$hr;
         # $peakTp=$tp;
         # $peakDIR=$dir;
          while (@WSE){
              $wse = shift @WSE; $t = shift @T; push @T, $t; $hr+=1/$recsPerHour;
             # $tp=shift @TP; push @TP, $tp;
             # $dir=shift @DIR; push @DIR, $dir;
              if ($wse > $peakWse){
                 $peakWse=$wse;
                 $peakT=$t;
                 $peakHr=$hr;
                # $peakTp=$tp;
                # $peakDIR=$dir;
              } 
              if ( $wse < $threshold ){  # down-crossing of threshold
                 $downCross=$hr;
                 push @PEAKS, $peakWse;
                 push @PeakTimes, $peakT;
                 push @UpCrosses, $upCross;
                 push @DownCrosses, $downCross;
               #  push @TP_atPeak, $peakTp;
               #  push @DIR_atPeak, $peakDIR;
                 my $duration=$downCross-$upCross;
                 push @Duration, $duration;
                 push @PeakHours, $peakHr;
                 $peakCount++;
                 $str=sprintf("   %4d, %13s,%10d, %8.1f,  %4.2f",$peakCount,$peakT,$peakHr,$duration,$peakWse);
                 #print LOG "peak $peakCount, time $peakT, record $hr, duration $duration, Hs= $peakHs, dir=$peakDIR, Tp=$peakTp \n";
                 print LOG "$str\n";
                 last;
              }    
          }
          unless (@WSE){  # in case we end before a down-crossing
               push @PEAKS, $peakWse;
               push @PeakTimes, $peakT;
               $peakCount++;

               print "e!!!!!!!!nded before down crossing\n";
               print LOG "e!!!!!!!!nded before down crossing\n";
              # print LOG "#-- peak $peakCount at time $peakT is $peakHs\n";
          }
       }
    }

    

    # check to see if we need to merge peaks
    if ($minEventDuration > 1/$recsPerHour){
      print LOG "#----------------------------------------------------------------------#\n";
      print LOG "Check if peaks are within minEventDuration $minEventDuration hours and should be merged\n";
      print LOG "#----------------------------------------------------------------------#\n";

      my $minT=-99999999;

      my $iter=0;
     
      while ($minT < $minEventDuration){
  
        $iter++;
        print LOG "Peak merging iteration: $iter\n";


        my $peakWse=shift @PEAKS; 
        my $peakT=shift @PeakTimes; 
        my $upCross=shift @UpCrosses; 
        my $downCross=shift @DownCrosses;
        my $duration=shift @Duration; 
        my $hr=shift @PeakHours;  
        my @NN=(0..$#PEAKS);
        while (@NN){
          my $dt_peaks=$PeakHours[0]-$hr;
          if ($dt_peaks < $minEventDuration) {
             $str=$peakT;
             $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
             my $t1 = "$1-$2-$3 $4:$5";
             $str=$PeakTimes[0];
             $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
             my $t2 = "$1-$2-$3 $4:$5";
             print LOG "*-- Merge Peaks iter: $iter, $peakWse (at $t1) and $PEAKS[0] (at $t2)\n";
             if ($PEAKS[0] > $peakWse){  # keep n+1, shift then push, keep first upcross
               $peakWse=shift @PEAKS; 
               $peakT=shift @PeakTimes; 
               $upCross=shift @UpCrosses; 
               $downCross=shift @DownCrosses;
               $duration=shift @Duration; 
               $hr=shift @PeakHours;  
               shift @NN;
               push @PEAKS, $peakWse;
               push @PeakTimes, $peakT;
               push @UpCrosses, $upCross;
               push @DownCrosses, $downCross;
               push @Duration, $duration;
               push @PeakHours, $hr;
               print LOG "    keeping Higher Later peak of $peakWse at hour $hr (at $t2)\n";
             }else{ #keep n            push then shift
               push @PEAKS, $peakWse;
               push @PeakTimes, $peakT;
               push @UpCrosses, $upCross;
               push @DownCrosses, $downCross;
               push @Duration, $duration;
               push @PeakHours, $hr;
               print LOG "    keeping Higher Earlier peak of $peakWse at hour $hr (at $t1)\n";
               $peakWse=shift @PEAKS; 
               $peakT=shift @PeakTimes; 
               $upCross=shift @UpCrosses; 
               $downCross=shift @DownCrosses;
               $duration=shift @Duration; 
               $hr=shift @PeakHours;  
               shift @NN;
            }
          }else{
             push @PEAKS, $peakWse;
             push @PeakTimes, $peakT;
             push @UpCrosses, $upCross;
             push @DownCrosses, $downCross;
             push @Duration, $duration;
             push @PeakHours, $hr;
          }  # not less than min duration
          $peakWse=shift @PEAKS; 
          $peakT=shift @PeakTimes; 
          $upCross=shift @UpCrosses; 
          $downCross=shift @DownCrosses;
          $duration=shift @Duration; 
          $hr=shift @PeakHours;  
          shift @NN;
          # if this is the last one, and not less than min duration, we need to push it back on 
          unless (@NN){
             push @PEAKS, $peakWse;
             push @PeakTimes, $peakT;
             push @UpCrosses, $upCross;
             push @DownCrosses, $downCross;
             push @Duration, $duration;
             push @PeakHours, $hr;
          }
        } #end NN loop
     
     
 
        $minT=9999999;       
        foreach my $n (0..$#PEAKS-1){
          my $dt=$PeakHours[$n+1]-$PeakHours[$n];
          $minT=$dt if $dt < $minT;
        } 
        print LOG "Iteration: $iter, Minimum time between peaks is: $minT hours\n";

      } #end iterative megring while loop
      
    }# end if checking need to merge peaks


    # calculate some stats as a sanity check on the peak duration and time between peaks
    my $totalDuration=$nrecs/24/365.25/$recsPerHour;
    my $minTimeBetweenPeaks=99999999;
    my $minPeakDuration=999999999;
    my $maxPeakDuration=0;
    my $npeaks=$#PEAKS+1;
    my $lambda=$npeaks/$totalDuration;
    foreach my $n (0..$npeaks-1){
       $minPeakDuration=$Duration[$n] if ($Duration[$n] < $minPeakDuration);
       $maxPeakDuration=$Duration[$n] if ($Duration[$n] > $maxPeakDuration);

       if ($n < $npeaks-1){
           my $dt=$PeakHours[$n+1]-$PeakHours[$n];
           if ($dt < 0)  {
           }
 
           $minTimeBetweenPeaks=$dt if $dt < $minTimeBetweenPeaks;
           

       } 
    }  
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#-------- Sanity Check on Peak Durations and Time Between Peaks--------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "   Total Record Duration:  $totalDuration years\n";
    print LOG "   Using POT method with Threshold:  $threshold; $npeaks peaks were found\n";  
    print LOG "   Average Rate (lambda):  $lambda events/year\n";
    print LOG "   Peaks with less than $minEventDuration hours between are consider a single event and merged\n";
    my $minHrsBtwPeaks=$minTimeBetweenPeaks/$recsPerHour;
    print LOG "   Minimum Time Between Peaks:  $minHrsBtwPeaks hours\n";
    my $minDurHr=$minPeakDuration/$recsPerHour;
    print LOG "   Minimun Peak Duration: $minDurHr hours\n";
    my $maxDurHr=$maxPeakDuration/$recsPerHour;
    print LOG "   Maximum Peak Duration: $maxDurHr hours\n";

    print "#----------------------------------------------------------------------#\n";
    print "#-------- Sanity Check on Peak Durations and Time Between Peaks--------#\n";
    print "#----------------------------------------------------------------------#\n";
    print "   Total Record Duration:  $totalDuration years\n";
    print  "   Using POT method with Threshold:  $threshold; $npeaks peaks were found\n";  
    print  "   Average Rate (lambda):  $lambda events/year\n";
    print  "   Peaks with less than $minEventDuration hours between are consider a single event and merged\n";
    print  "   Minimum Time Between Peaks:  $minHrsBtwPeaks hours\n";
    print  "   Minimun Peak Duration: $minDurHr hours\n";
    print  "   Maximum Peak Duration: $maxDurHr hours\n";




    # sort the data and write the orders statistics 
    my @sorted_i = sort {$PEAKS[$b] <=> $PEAKS[$a]} (0..$#PEAKS);

               #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#------------------------------- Rank Ordered Peak Values ------------------------------------#\n";
    print LOG "Rank, $product ($units),  Time of Peak ,     Upcross Time ,   Downcross Time , Duration\n";

    my $rank=1;
    foreach my $i (@sorted_i){
       my $str=$PeakTimes[$i];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $t = "$1-$2-$3 $4:$5";
   
       $str=$T[$UpCrosses[$i]];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $uc="$1-$2-$3 $4:$5";
   
       $str=$T[$DownCrosses[$i]];
       $str =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
       my $dc="$1-$2-$3 $4:$5";
  
       $str=sprintf("%4d,%9.3f,  %16s,  %16s,  %16s,%9.1f",$rank,$PEAKS[$i],$t,$uc,$dc,$Duration[$i]);
       print LOG "$str\n";
       #print OUT "$rank,$PEAKS[$i],$t,$uc,$dc,$Duration[$i],$DIR_atPeak[$i],$TP_atPeak[$i];\n";
       $rank++; 
    }
    my @Ordered=@PEAKS[@sorted_i];
    close (LOG);

    return (\@Ordered,$lambda,$logFile);

} # end NOAA_gauge_POT



#############################################################
# sub NOAA_gauge_AnnualMax
# 
# e.g. NOAA_gauge_AnnualMax(
#                     -STATIONID => $stationID,    # NOAA station ID number
#                     -BEGINDATE => $beginDate,    # yyyymmdd
#                     -ENDDATE   => $endDate,      # yyyymmdd
#                     -PRODUCT   => $product,      # e.g. hourly_height, water_level, wind  
#                     -DATUM     => $datum,        # e.g. MHHW,MHW,DTL,MTL,MSL,MLW,MLLW,GT,MN,DHQ,DLQ,NAVD
#                     -UNITS     => $units,        # e.g. metric or english
#                     -LOGFILE   => $logFile,      # optional name of logfile
#                     -RECORDFREQ => $recsPerHour, # e.g. 10 for 6 minute "water_level",  1 for hourly_height
#                     -COOPSFILE => $coopsFile     # optional name of file downloaded with getCOOPS.pl with time series data
#                   )                              # specify this if you have already dowlnoaded the data from CO-OPS 
#

sub NOAA_gauge_AnnualMax{
    my %args=@_;
    my $stationID=$args{-STATIONID};
    my $beginDate=$args{-BEGINDATE};
    my $endDate = $args{-ENDDATE};
    my $product = $args{-PRODUCT};
    my $datum   = $args{-DATUM};
    my $units   = $args{-UNITS};
    my $fracNeed=0.80;  # need at least this much fraction of a year for it to be counted 
    $fracNeed=$args{-FRACNEED} if defined ($args{-FRACNEED});
    my $logFile="station-$stationID-begin-$beginDate-end-$endDate-$product-$units-$datum-AnnualMax_stats.log";
    $logFile=$args{-LOGFILE} if defined ($args{-LOGFILE});
    my $recsPerHour=1;
    $recsPerHour=10 if ($product =~ m/water_level/i); 
    $recsPerHour=$args{-RECORDFREQ} if defined ($args{-RECORDFREQ});
    my $coopsFile= 0;
    $coopsFile = $args{-COOPSFILE} if defined ($args{-COOPSFILE});

  
    open LOG, ">>$logFile" or die "ERROR:  GodaXtreme.pm:  fitWISoneLine:  cant open logfile $logFile for writing\n";
              #         1         2         3         4         5         6         7
              #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#--------- Statistical Analysis of Extreme $product --------------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print LOG "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print LOG "#                                                                      #\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#                                                                      #\n";
          #123456789012345678901234567890123456789012345678901234567890123456789012
    print "\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#--------- Statistical Analysis of Extreme $product ---------------#\n";
    print  "#----------------------------------------------------------------------#\n";
    print  '  Reference:  Yoshimi Goda, 2010, "Random Seas and Design of Maritime ',"\n";
    print  "              Structures\", 3rd edition. Chapter 13.                   \n";  
    print  "#                                                                      #\n";
    print  "#----------------------------------------------------------------------#\n";
    print  "#                                                                      #\n";
     
    # get the COOPS data if we don't have it already
    unless ($coopsFile){
       $coopsFile="$stationID-$product-$datum-$units-$beginDate-$endDate".'.csv';
       my $cmdstr="perl getCoopsdata.pl --station $stationID --begin $beginDate --end $endDate --product $product --datum $datum --units $units --timezone GMT --format CSV --outfile $coopsFile";
       print "Getting COOPS data with command: $cmdstr\n";
       system($cmdstr);
    }
    
    # ingest the COOPS data
    # record the max from each year
    # count the number of records in each year
    open IN, "<$coopsFile" or die "Cant open $coopsFile";
    <IN>; #skip headerline
    my %WSE;
    my %NRECS;
    my %PEAK_TIME;
    while(<IN>){
       next unless ( $_ =~ m/(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d),(.+?),/);
       my $yyyy=$1;
       my $mm=$2;
       my $dd=$3;
       my $HH=$4;
       my $MM=$5;
       my $wse=$6;
       if (defined $WSE{$yyyy}){
           if ($wse > $WSE{$yyyy}){
              $WSE{$yyyy}=$wse;
              $PEAK_TIME{$yyyy}="$yyyy-$mm-$dd $HH:$MM";
           }
           $NRECS{$yyyy}++;
       }else{
           $WSE{$yyyy}=$wse;
           $PEAK_TIME{$yyyy}="$yyyy-$mm-$dd $HH:$MM";
           $NRECS{$yyyy}=1;
       }
    }
    close(IN);
  
    # figure out the years that have enough data
    my %FRACHAVE;
    my $recsPerYear=$recsPerHour*24*365;
   
    foreach my $yyyy (keys %WSE){
        $FRACHAVE{$yyyy}=$NRECS{$yyyy}/$recsPerYear;
    }    


    my @YRS=();
    my @PEAKS=();
    foreach my $yyyy (keys %WSE){
       if ($FRACHAVE{$yyyy} >= $fracNeed){
          push @YRS,$yyyy;
          push @PEAKS,$WSE{$yyyy};
       }
    }
    my $nyears=$#YRS+1;


    # sort the data and write the orders statistics 
    my @sorted_i = sort {$PEAKS[$b] <=> $PEAKS[$a]} (0..$#PEAKS);

               #123456789012345678901234567890123456789012345678901234567890123456789012
    print LOG "#---------------------------- Rank Ordered Annual Maximums ---------------------------------#\n";
    my $daysNeed=365*$fracNeed;
    print LOG "-FRACNEED = $fracNeed;  Only including years that have at least $daysNeed days of records\n";
    print LOG "Rank, $product ($units),  year, days counted, peak datetime\n";

    my $rank=1;
    foreach my $i (@sorted_i){  
       my $daysCounted=365*$FRACHAVE{$YRS[$i]};
       my $str=sprintf("%4d,              %7.2f   ,  %4d,     %6.1f,   %s",$rank,$PEAKS[$i],$YRS[$i],$daysCounted,$PEAK_TIME{$YRS[$i]});
       print LOG "$str\n";
       $rank++; 
    }
    my @Ordered=@PEAKS[@sorted_i];
    close (LOG);
    my $lambda=1; # for annual max data

    return (\@Ordered,$lambda,$logFile);

} # end NOAA_gauge_AnnualMax










###############################################################
# sub fitDistributions
#
# e.g.   GodaXtreme::fitDistributions(\@Ordered,[10, 50, 100, 500],$lambda,$nu,$logFile,$threshold);
#
#
#



sub fitDistributions{
    my ($oref,$rpRef,$lambda,$nu,$logFile,$threshold)=@_;
    my @Ordered=@{$oref};
    # sort Ordered in case it is not already
    my @sorted = sort {$b <=> $a} (@Ordered);
    @Ordered=@sorted;
    $threshold = $Ordered[$#Ordered] unless ( defined $threshold);
    my $N=$#Ordered+1;
    my @RP = @{$rpRef};     # return periods that you want values for
    my $NOLOG=0;
    if (defined $logFile){
       $NOLOG=1 if (uc($logFile) eq 'NOLOG');
    }else{
       $NOLOG=1;  # in the case that no logfile is given
    } 
    
    open LOG, ">>$logFile" or die "ERROR:  GodaExtreme.pm:  fitDistributions:  cant open logfile $logFile for append\n"  unless ($NOLOG);

    my @RSQ;
    my @MIR;
    my @DOL;
    my @REC;
    my @SLOPE;  #a
    my @INTERCEPT; #b
    my @RV;  # holds ref to arrays of return values

    unless ($NOLOG){
      print LOG "#----------------------------------------------------------------------#\n"; 
      print LOG "#---------------------- Fit Distributions ------- ---------------------#\n";
      print LOG "#----------------------------------------------------------------------#\n";
    }

    my @DISTTYPE=('GUMBEL',
                  'FRECHET','FRECHET','FRECHET','FRECHET',
                  'WEIBULL','WEIBULL','WEIBULL','WEIBULL'
                 );
     my @K=(0,                    # dummmy for Gumbel
            2.5, 3.33, 5.0, 10.0,  # Frechet shape parameters
            0.75, 1.0, 1.4, 2.0    # Wiebull shape parameters
           );
    
    foreach my $k (@K){
       my $distType = shift @DISTTYPE; push @DISTTYPE, $distType;

       # reduced variate
       my ($yref,$log)=&reducedVariate(\@Ordered,$distType,$k,$nu);
       print LOG "#------------------------ Fitting $distType -------------------------------#\n"  unless ($NOLOG);
       my @Y=@{$yref};
     
       print LOG "$log" unless ($NOLOG);
       

       #  least squares fit
       my ($a,$b,$rsq,$log2)=&leastSquares(\@Ordered,\@Y);
       print LOG "$log2"  unless ($NOLOG);

       # return Values
       my ($rv,$log3)=GodaXtreme::returnValue(\@RP,$a,$b,$distType,$k,$lambda);
       print LOG "$log3" unless ($NOLOG);
 
       # MIR criteria and REC criteria
       my ($mir,$rec_,$dr,$dr_95)=&MIR_REC_criteria($N,$nu,$distType,$k,$rsq);
       my $rec='Keep';
       $rec='Reject' unless ($rec_);
       push @MIR, $mir;
       unless ($NOLOG){
         print LOG "   MIR:  MInimum Ration of residual correlation coefficient, MIR = $mir\n";
         print LOG "   REC:  Residue of correlation Coefficient, dr = $dr, dr_95 = $dr_95\n";
         print LOG "   REC:  Rejected\n" unless ($rec_);
         print LOG "   REC:  Not Rejected\n" if ($rec_);
       }
       push @REC, $rec;

       # DOL criteria
       my ($keep,$xi,$xi5,$xi95)=&DOL_criteria($oref,$nu,$distType,$k);
       my $keepOrReject='Keep';
       $keepOrReject='Reject' unless ($keep);
       unless ($NOLOG){
         print LOG "   DOL:  Dimensionless Deviation of Maximum, Xi = $xi\n";
         print LOG "   DOL:  Confidence intevals: Xi_5 = $xi5, Xi_95 = $xi95\n";
         print LOG "   DOL:  Rejected\n" unless ($keep);
         print LOG "   DOL:  Not Rejected\n" if ($keep);
       }
       push @DOL, $keepOrReject;      
       


       push @RSQ,$rsq;
       push @SLOPE, $a;
       push @INTERCEPT, $b;
       push @RV, $rv;
    }

    unless ($NOLOG){
      print LOG "#-------------------------------------------------------------------------------------------------------------#\n";
      print LOG "#---------------------------------------  Results Summary  ---------------------------------------------------#\n";
      print LOG "  threshold = $threshold,  number of samples = $N,  annual rate =  $lambda, censoring parameter =  $nu\n";  
      print "#-------------------------------------------------------------------------------------------------------------#\n";
      print "#---------------------------------------  Results Summary  ---------------------------------------------------#\n";
      print "  threshold = $threshold,  number of samples = $N,  annual rate =  $lambda, censoring parameter =  $nu\n";  
    }
    # sort by best fit and write results
    my @Sorted = sort {$MIR[$a] <=> $MIR[$b]} (0..$#MIR);
    my $str='';
    foreach my $rp (@RP){
       $str.=sprintf("|%5d-yr ",$rp);
    } 
    unless ($NOLOG){
      print LOG "#---------|-------|-------|-------|--------|--------|-------|--------|---------- RETURN VALUES --------------#\n";
      print LOG "# DisType |   k   |  r^2  |  MIR  |   DOL  |  REC   | Slope | Intcpt $str#\n";
      print LOG "#---------|-------|-------|-------|--------|--------|-------|--------|---------|---------|---------|---------#\n";
      print "#---------|-------|-------|-------|--------|--------|-------|--------|---------- RETURN VALUES --------------#\n";
      print "# DisType |   k   |  r^2  |  MIR  |   DOL  |  REC   | Slope | Intcpt $str#\n";
      print "#---------|-------|-------|-------|--------|--------|-------|--------|---------|---------|---------|---------#\n";
    }
    foreach my $i (@Sorted){
         my @RV_=@{$RV[$i]};
         my $str='';
         foreach my $rv (@RV_){
              $str.=sprintf("|%8.2f ",$rv);
         }
          my $str2=sprintf("|%8s | %5.2f |%6.3f |%6.3f |%7s |%7s |%6.3f |%6.3f  $str|", $DISTTYPE[$i],$K[$i],$RSQ[$i],$MIR[$i],$DOL[$i],$REC[$i],$SLOPE[$i],$INTERCEPT[$i]);
         print LOG "$str2\n" unless ($NOLOG);
         print "$str2\n" unless ($NOLOG);

    }

    # sort the fit parameters by MIR
    @DISTTYPE=@DISTTYPE[@Sorted];
    @K=@K[@Sorted];
    @RSQ=@RSQ[@Sorted];
    @MIR=@MIR[@Sorted];
    @DOL=@DOL[@Sorted];
    @REC=@REC[@Sorted];
    @SLOPE=@SLOPE[@Sorted];
    @INTERCEPT=@INTERCEPT[@Sorted];
    @RV=@RV[@Sorted];
   
    # now cycle through them and shift/push the values until both DOL and REC are met
    # the first set of parameters will be the one with the best fit
    foreach my $i (0..$#K){
       last if ($DOL[0] eq 'Keep' and $REC[0] eq 'Keep');
       my $a=shift @DISTTYPE; push @DISTTYPE, $a;
       $a=shift @K; push @K, $a;
       $a=shift @RSQ; push @RSQ, $a;
       $a=shift @MIR; push @MIR, $a;
       $a=shift @DOL; push @DOL, $a;
       $a=shift @REC; push @REC, $a;
       $a=shift @SLOPE; push @SLOPE, $a;
       $a=shift @INTERCEPT; push @INTERCEPT, $a;
       $a=shift @RV; push @RV, $a;
    }

    close (LOG)  unless ($NOLOG);
    return (\@Ordered,\@DISTTYPE,\@K,\@RSQ,\@MIR,\@DOL,\@REC,\@SLOPE,\@INTERCEPT,\@RP,\@RV);
    



}# end fitDistributions
 
########################
# sub MIR_REC_criteria give delta_r_mean for MIR criteria eqn 13.38 (Table 13.5)
#                      and r_95 for REC criteria Table 13.8 
# section 13.2.3
# e.g.
#       ($mir,$keep,$dr,$dr_95)=&MIR_criteria($N,$nu,$distType,$k,$rsq);
#
# identify best fitting distribution by
# MInimum Ratio (MIR) of residual correlation coefficient
#
# best distribution will have smallest MIR
#    
# MIR accounts for the fact that samples from broader distributions
# tend to have less correlation than samples from narrower 
# distributions.  Thus it is better than just looking at 
# RSQ
#

sub MIR_REC_criteria{
    my ($N,$nu,$distType,$k,$rsq)=@_;
  
   # coefficients from Table 13.5 for rMean
   my ($a,$b,$c) = (0,0,0);
    
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
      $a = -2.364 + 0.54*$nu**(5/2);          
      $b = -0.2665 - 0.0457*$nu**(5/2);
      $c = -0.044;
 

   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){  
       if ($k == 2.5){
           $a = -2.47 + 0.015*$nu**(3/2);
           $b = -0.153 - 0.0052*$nu**(5/2);     
           $c = 0;

       }elsif ($k == 3.33){
           $a = -2.462 - 0.009*$nu**2;
           $b = -0.1933 - 0.0037*$nu**(5/2);     
           $c = -0.007;
 
       }elsif ($k == 5.0){
           $a = -2.463;
           $b = -0.211 - 0.0131*$nu**(5/2);
           $c = -0.019;

       }elsif ($k == 10.0){
           $a = -2.437 + 0.028*$nu**(5/2);
           $b = -0.2280 - 0.0300*$nu**(5/2);
           $c = -0.033;

       }else{
          print "bad k value $distType, k = $k\n";
       }


  
   }elsif ($distType =~ m/WEIBULL/){

       if ($k == 0.75){
           $a = -2.435 - 0.168*$nu**(0.5);
           $b = -0.2083 + 0.1074*$nu**(0.5);
           $c = -0.047;

       }elsif ($k == 1.0){
           $a=-2.355;
           $b=-0.2612;
           $c=-0.043;

       }elsif ($k == 1.4){
           $a=-2.277 + 0.056*$nu**(0.5);
           $b=-0.3169-0.0499*$nu;
           $c = -0.044;
       }elsif ($k == 2.0){
           $a=-2.16 + 0.113*$nu;
           $b=-0.3788-0.0979*$nu;
           $c=-0.041;

       }else{
          print "bad k value $distType, k = $k\n";
       }
   }elsif ($distType =~ m/LOGNORMAL/){
        $a= -2.153 + 0.059*$nu**2; 
        $b= -0.2627 - 0.1716*$nu**(1/4); 
        $c = -0.045;

   }else{
        die "ERROR:  GodaXtreme.pm:  Bad Dist type $distType for MIR\n";
   }
   

   my $rmean=exp( $a + $b* log($N) + $c*(log($N))**2);
   my $MIR=(1-$rsq**0.5)/$rmean;

   # determine r_95 Table 13.8 equation 13.42
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
      $a = -1.444;
      $b = -0.2733-0.414*$nu**2.5;
      $c = -0.045
 

   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){  
       if ($k == 2.5){
           $a = -1.122-0.037*$nu;
           $b = -0.3298 + 0.0105*$nu**0.25;
           $c = 0.016;

       }elsif ($k == 3.33){
           $a = -1.306-0.105*$nu**1.5;
           $b = -0.3001 + 0.0404*$nu**0.5;
           $c=0;
 
       }elsif ($k == 5.0){
           $a =-1.463-0.107*$nu**1.5;
           $b= -0.2716 + 0.0517*$nu**0.25;
           $c= -0.018;

       }elsif ($k == 10.0){
           $a = -1.490-0.073*$nu;
           $b= -0.2299-0.0099*$nu**2.5;
           $c= -0.034;

       }else{
          print "bad k value $distType, k = $k\n";
       }


  
   }elsif ($distType =~ m/WEIBULL/){

       if ($k == 0.75){
           $a = -1.473-0.049*$nu**2;
           $b= -0.2181 + 0.0505*$nu**2;
           $c= -0.041;

       }elsif ($k == 1.0){
           $a=-1.433;
           $b= -0.2679;
           $c= -0.044;

       }elsif ($k == 1.4){
           $a=-1.312;
           $b=-0.3356-0.0449*$nu;
           $c= -0.045;

       }elsif ($k == 2.0){
           $a=-1.188 + 0.073*$nu**0.5;
           $b=-0.4401-0.0846*$nu**1.5;
           $c= -0.039;

       }else{
          print "bad k value $distType, k = $k\n";
       }
   }elsif ($distType =~ m/LOGNORMAL/){
        $a= -1.362 + 0.360*$nu**0.5;
        $b= -0.3439-0.2185*$nu**0.5;
        $c= -0.035;

   }else{
        die "ERROR:  GodaXtreme.pm:  Bad Dist type $distType for MIR\n";
   }
   
   my $dr_95=exp( $a + $b* log($N) + $c*(log($N))**2);
   my $dr=1-$rsq**0.5;
   my $keep=0;
   $keep = 1 if $dr < $dr_95;

   return ($MIR,$keep,$dr,$dr_95); 

}


###################################################################
# sub DOL_criteria    section 13.2.4
#
#  reject distribution based on Deviation of outlier of maximum value
#
#  if E < E5 or E> E95 reject distribution
#
#  e.g.  my ($keep,$xi,$xi5,$xi95)=&DOL_criteria($oref,$nu,$distType,$k);
#
#


sub DOL_criteria {
   my ($oref,$nu,$distType,$k)=@_;
   my ($a,$b,$c);
   
   my @Ordered=@{$oref};
   my $N=$#Ordered+1;

   #mean
   my $meanX=0; # mean
   foreach my $x (@Ordered){
     $meanX+=$x;
   }
   $meanX=$meanX/$N;

   #standard deviation
   my $stdX=0;  
   foreach my $x (@Ordered){
      $stdX+=($x-$meanX)**2;
   }   
   $stdX=($stdX/$N)**0.5;
   
   # Dimensionless Deviation for max value
   my $Xi=($Ordered[0]-$meanX)/$stdX;
  

   # 95%  Table 13.6
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
       $a= -0.579 + 0.468*$nu;  
       $b= 1.496 - 0.227*$nu**2;
       $c = -0.038;
 

   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){  
       if ($k == 2.5){
         $a= 4.653 - 1.076*$nu**0.5;
         $b= -2.047 + 0.307*$nu**0.5;
         $c= 0.635;

       }elsif ($k == 3.33){
         $a= 3.217 - 1.216*$nu**0.25;
         $b= -0.903 + 0.294*$nu**0.25;
         $c= 0.427;
 
       }elsif ($k == 5.0){
         $a= 0.599 - 0.038*$nu**2;
         $b= 0.518 - 0.045*$nu**2;
         $c= 0.210;

       }elsif ($k == 10.0){
         $a= -0.371 + 0.171*$nu**2;
         $b= 1.283 - 0.133*$nu**2;
         $c= 0.045;

       }else{
          print "bad k value $distType, k = $k\n";
       }


  
   }elsif ($distType =~ m/WEIBULL/){

       if ($k == 0.75){
          $a= -0.256 - 0.632*$nu**2;
          $b= 1.269 + 0.254*$nu**2;
          $c= 0.037;

       }elsif ($k == 1.0){
          $a= -0.682;
          $b= 1.600;
          $c= -0.045;

       }elsif ($k == 1.4){
          $a= -0.548 + 0.452*$nu**0.5;
          $b= 1.521 - 0.184*$nu;
          $c= -0.065

       }elsif ($k == 2.0){
          $a= -0.322 + 0.641*$nu**0.5;
          $b= 1.414 - 0.326*$nu;
          $c= -0.069;

       }else{
          print "bad k value $distType, k = $k DOL95\n";
       }
   }elsif ($distType =~ m/LOGNORMAL/){
        $a=0.178 + 0.740*$nu;
        $b= 1.148 - 0.480*$nu**1.5;
        $c= -0.035;

   }else{
        die "ERROR:  GodaXtreme.pm:  Bad Dist type $distType for DOL95\n";
   }
   

  
   my $Xi95=$a + $b*log($N) + $c*(log($N))**2;

 # 5% Table 13.7
   if (($distType =~ /GUMBEL/) or ($distType eq 'FT-I')){
       $a= 0.257 + 0.133*$nu**2;
       $b= 0.452 - 0.118*$nu**2;
       $c= 0.032;
 

   }elsif (($distType =~ m/FRECHET/) or ($distType eq 'FT-II')){  
       if ($k == 2.5){
         $a= 1.481 - 0.126*$nu**0.25;
         $b= -0.331 - 0.031*$nu**2;
         $c= 0.192;

       }elsif ($k == 3.33){
         $a= 1.025;
         $b= -0.077 - 0.050*$nu**2;
         $c= 0.143
 
       }elsif ($k == 5.0){
         $a= 0.700 + 0.060*$nu**2;
         $b= 0.139 - 0.076*$nu**2;
         $c= 0.100;

       }elsif ($k == 10.0){
         $a= 0.424 + 0.088*$nu**2;
         $b= 0.329 - 0.094*$nu**2;
         $c= 0.061;

       }else{
          print "bad k value $distType, k = $k\n";
       }


  
   }elsif ($distType =~ m/WEIBULL/){

       if ($k == 0.75){
          $a= 0.534 - 0.162*$nu;
          $b= 0.277 + 0.095*$nu;
          $c= 0.065;

       }elsif ($k == 1.0){
          $a= 0.308;
          $b= 0.423;
          $c= 0.037;

       }elsif ($k == 1.4){
          $a= 0.192 + 0.126*$nu**1.5;
          $b= 0.501 - 0.081*$nu**1.5;
          $c= 0.018;

       }elsif ($k == 2.0){
          $a= 0.050 + 0.182*$nu**1.5;
          $b= 0.592 - 0.139*$nu**1.5;
          $c= 0;

       }else{
          print "bad k value $distType, k = $k DOL95\n";
       }
   }elsif ($distType =~ m/LOGNORMAL/){
        $a= 0.042 + 0.270*$nu;
        $b= 0.581 - 0.217*$nu**1.5;
        $c= 0;

   }else{
        die "ERROR:  GodaXtreme.pm:  Bad Dist type $distType for DOL95\n";
   }
   

  
   my $Xi5=$a + $b*log($N) + $c*(log($N))**2;

  my $keep=1;
  $keep=0 if (($Xi < $Xi5) or ($Xi > $Xi95));

  return ($keep,$Xi,$Xi5,$Xi95);


}   
   

###############################################################
# sub fitGumbel
#
# e.g.   GodaXtreme::fitGumbel(\@Ordered,[10, 50, 100, 500],$lambda,$nu);
#
#  $lambda - annual rate
#  $nu - censoring parameter
#
#   @Ordered does not have to be sorted
# 
#    returns (\@RP,\@RV,$a,$b,$rsq,$mir,$rec_,$dol);
sub fitGumbel{
    my ($oref,$rpRef,$lambda,$nu)=@_;
    my @Ordered=@{$oref};
    # sort Ordered in case it is not already
    my @sorted = sort {$b <=> $a} (@Ordered);
    @Ordered=@sorted;
    my $N=$#Ordered+1;
    my @RP = @{$rpRef};     # return periods that you want values for
    my @RV;  # holds ref to arrays of return values
    my $k=0;
    my $distType='GUMBEL';
    # reduced variate
    my ($yref,$log)=&reducedVariate(\@Ordered,$distType,$k,$nu);
    my @Y=@{$yref};
     
    #  least squares fit
    my ($a,$b,$rsq,$log2)=&leastSquares(\@Ordered,\@Y);

    # return Values
    my ($rv,$log3)=GodaXtreme::returnValue(\@RP,$a,$b,$distType,$k,$lambda);

    # MIR criteria and REC criteria
    my ($mir,$rec_,$dr,$dr_95)=&MIR_REC_criteria($N,$nu,$distType,$k,$rsq);
    my $rec='Keep';
    $rec='Reject' unless ($rec_);

    my ($keep,$xi,$xi5,$xi95)=&DOL_criteria($oref,$nu,$distType,$k);
    my $dol='Keep';
    $dol='Reject' unless ($keep);
   
    return ($rv,$a,$b,$rsq,$mir,$rec_,$dol);
}# end fitGumbel





 

1;
