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

use strict;
use warnings;

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

   print "!--------------------------!\nINFO: GodaXtreme::reducedVariate:\n$log\n";

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
 print "w2 $w2\n";
      $sumw2y2+=$y*$y*$w2;
      $sumw2y+=$y*$w2;
      $sumw2x+=$x*$w2;
      $sumw2xy+=$x*$y*$w2;
      $sumw2+=$w2;
      $meanx+=$x;

   }
   $meanx=$meanx/$N;
print "meanx $meanx\n";  
print "sumwt $sumw2\n";
 
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
print "ss ex $ssTotal $ssResidue\n";	

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
#                     -MINEVENTDURATION => $minEventDuration        
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
     
    # ingest the oneline file 
    my @T;  
    my @HS;
    my @DIR;
    my @TP;

    open IN, "<$oneLine" or die "ERROR: GodaXtreme.pm:  fitWISoneLine: Cannot open oneline file $oneLine\n";
    
    my $station;
    my $lat;
    my $lon;

    while (<IN>){
       chomp;
       $_ =~ s/^\s+//g;
   
       my @data=split(/\s+/,$_);

       push @T, $data[0];
       my $hs = $data[9];
       my $dir = $data[15];
       my $tp= $data[11];
       $station = $data[1];
       $lat = $data[2];
       $lon = $data[3];
       if (defined $azimuth){
          $hs=0 if (( $dir >= $azimuth-$halfSectorWidth) and ($dir <= $azimuth+$halfSectorWidth));
       }
       push @HS, $hs;
       push @DIR, $dir;
       push @TP, $tp;
    }
    close(IN);
   
    print LOG "  Reading data from WIS \"one line\" file: $oneLine\n";
    print LOG "  INFO read from WIS one line file: $oneLine\n";
    print LOG "     WIS station:  $station\n";
    print LOG "     Latitude:     $lat\n";
    print LOG "     Longitude:    $lon\n";
 
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
    print LOG "#--- Events with peak significant wave height exceeding $threshold meters ---#\n";
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
       if ($hs > $threshold){      # up-crossing of threshold
          $peakHs=$hs;
          $peakT=$t;
          $peakHr=$hr;
          $upCross=$hr;
          $peakTp=$tp;
          $peakDIR=$dir;
          while (@HS){
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
                 push @PeakHours, $hr;
                 $peakCount++;
                 $str=sprintf("   %4d, %13s,%10d, %8d,  %4.2f,  %3d,  %5.2f",$peakCount,$peakT,$hr,$duration,$peakHs,$peakDIR,$peakTp);
                 #print LOG "peak $peakCount, time $peakT, record $hr, duration $duration, Hs= $peakHs, dir=$peakDIR, Tp=$peakTp \n";
                 print LOG "$str\n";
                 last;
              }    
          }
          unless (@HS){  # in case we end before a down-crossing
               push @PEAKS, $peakHs;
               push @PeakTimes, $peakT;
               $peakCount++;
              # print LOG "#-- peak $peakCount at time $peakT is $peakHs\n";
          }
       }
    }

    
    # check to see if we need to merge peaks
    if ($minEventDuration > 1){
      print LOG "#----------------------------------------------------------------------#\n";
      print LOG "Check if peaks are within minEventDuration $minEventDuration hours and should be merged\n";
      print LOG "#----------------------------------------------------------------------#\n";
      my $peakHs=shift @PEAKS; 
      my $peakT=shift @PeakTimes; 
      $upCross=shift @UpCrosses; 
      $downCross=shift @DownCrosses;
      my $peakTp=shift @TP_atPeak; 
      my $peakDIR=shift @DIR_atPeak; 
      my $duration=shift @Duration; 
      $hr=shift @PeakHours;  
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
           print LOG "*-- Merge Peaks $peakHs (at $t1) and $PEAKS[0] (at $t2)\n";
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
             print LOG "    keeping Higher peak of $peakHs (at $t2)\n";
           }else{ #keep n            push then shift
             push @PEAKS, $peakHs;
             push @PeakTimes, $peakT;
             push @UpCrosses, $upCross;
             push @DownCrosses, $downCross;
             push @TP_atPeak, $peakTp;
             push @DIR_atPeak, $peakDIR;
             push @Duration, $duration;
             push @PeakHours, $hr;
             print LOG "    keeping Higher peak of $peakHs (at $t1)\n";
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
        }else{
           push @PEAKS, $peakHs;
           push @PeakTimes, $peakT;
           push @UpCrosses, $upCross;
           push @DownCrosses, $downCross;
           push @TP_atPeak, $peakTp;
           push @DIR_atPeak, $peakDIR;
           push @Duration, $duration;
           push @PeakHours, $hr;
        }
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
      push @PEAKS, $peakHs;
      push @PeakTimes, $peakT;
      push @UpCrosses, $upCross;
      push @DownCrosses, $downCross;
      push @TP_atPeak, $peakTp;
      push @DIR_atPeak, $peakDIR;
      push @Duration, $duration;
      push @PeakHours, $hr;
      
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
           $minTimeBetweenPeaks=$dt if $dt < $minTimeBetweenPeaks;
           

       } 
    }  
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#-------- Sanity Check on Peak Durations and Time Between Peaks--------#\n";
    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "   Total Record Duration:  $totalDuration years\n";
    print LOG "   Average Rate (lambda):  $lambda events/year\n";
    print LOG "   Using POT method with Threshold:  $threshold; $npeaks peaks were found\n";  
    if (defined $azimuth) {
        print LOG "  *--------------\n";
        print LOG "  An Azimuth was defined. Only considering waves coming from $azimuth\n";
        print LOG "   degrees CW from North +- $halfSectorWidth degrees\n";
        print LOG "  *--------------\n";
    }
    my $minHrsBtwPeaks=$minTimeBetweenPeaks/$recsPerHour;
    print LOG "   Minimum Time Between Peaks:  $minHrsBtwPeaks hours\n";
    my $minDurHr=$minPeakDuration/$recsPerHour;
    print LOG "   Minimun Peak Duration: $minDurHr hours\n";
    my $maxDurHr=$maxPeakDuration/$recsPerHour;
    print LOG "   Maximum Peak Duration: $maxDurHr hours\n";

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




###############################################################
# sub fitDistributions
#
# e.g.   GodaXtreme::fitDistributions(\@Ordered,[10, 50, 100, 500],$lambda,$nu,$logFile);
#
#
#



sub fitDistributions{
    my ($oref,$rpRef,$lambda,$nu,$logFile)=@_;
    my @Ordered=@{$oref};
    my $N=$#Ordered+1;
    my @RP = @{$rpRef};     # return periods that you want values for
    open LOG, ">>$logFile" or die "ERROR:  GodaExtreme.pm:  fitDistributions:  cant open logfile $logFile for append\n";

    my @RSQ;
    my @MIR;
    my @SLOPE;  #a
    my @INTERCEPT; #b
    my @RV;  # holds ref to arrays of return values


    print LOG "#----------------------------------------------------------------------#\n";
    print LOG "#---------------------- Fit Distributions ------- ---------------------#\n";
    print LOG "#----------------------------------------------------------------------#\n";

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
       print LOG "#------------------------ Fitting $distType -------------------------------#\n";
       my @Y=@{$yref};
     
       print LOG "$log";
       

       #  least squares fit
       my ($a,$b,$rsq,$log2)=&leastSquares(\@Ordered,\@Y);
       print LOG "$log2";

       # return Values
       my ($rv,$log3)=GodaXtreme::returnValue(\@RP,$a,$b,$distType,$k,$lambda);
       print LOG "$log3";
 
       # MIR criteria
       my $mir=&MIR_criteria($N,$nu,$distType,$k,$rsq);
       
       push @MIR, $mir;


       push @RSQ,$rsq;
       push @SLOPE, $a;
       push @INTERCEPT, $b;
       push @RV, $rv;
    }

    print LOG "#-----------------------------------------------------------------------------------------------#\n";
    print LOG "#------------------------------------  Results Summary  ----------------------------------------#\n";
    # sort by best fit and write results
    my @Sorted = sort {$RSQ[$b] <=> $RSQ[$a]} (0..$#RSQ);
    my $str='';
    foreach my $rp (@RP){
       $str.=sprintf("| %5d-yr ",$rp);
    } 
    print LOG "#-----------|-------|---------|---------|---------|-----------|------------ RETURN VALUES ----------------#\n";
    print LOG "# Dist type |   k   |   r^2   |   MIR   |  Slope  | Intercept $str#\n";
    print LOG "#-----------|-------|---------|---------|---------|-----------|----------|----------|----------|----------#\n";

    foreach my $i (@Sorted){
         my @RV_=@{$RV[$i]};
         my $str='';
         foreach my $rv (@RV_){
              $str.=sprintf("| %8.2f ",$rv);
         }
          my $str2=sprintf("| %8s  | %5.2f | %7.3f | %7.3f | %7.3f | %7.3f   $str|", $DISTTYPE[$i],$K[$i],$RSQ[$i],$MIR[$i],$SLOPE[$i],$INTERCEPT[$i]);
         print LOG "$str2\n";

    }



    close (LOG);



}# end fitDistributions
 
########################
# sub MIR_criteria ()give delta_r_mean for MIR criteria eqn 13.38 (Table 13.5)
# e.g.
#       ($mir)=&MIR_criteria($N,$nu,$distType,$k,$rsq);
#    


sub MIR_criteria{
    my ($N,$nu,$distType,$k,$rsq)=@_;
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


   }else{
        die "ERROR:  GodaXtreme.pm:  Bad Dist type $distType for MIR\n";
   }
   

   my $rmean=exp( $a + $b* log($N) + $c*(log($N))**2);
   my $MIR=(1-$rsq)/$rmean;
   return ($MIR); 

}

1;
