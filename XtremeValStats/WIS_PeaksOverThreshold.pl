#!/usr/bin/env perl
# a perl script to generate a list of significant waveheight
# ordered statistics from WIS wave data in a "oneline" file
#
#  e.g. 
#
#  perl WIS_PeaksOverThreshold.pl --oneline ST63020_v03.onlns --threshold 5.0 [--offshoredir 225.0 [--halfsector 90.0]]
#


use strict;
use warnings;
use Getopt::Long;

my $oneLine;
my $threshold;
my $azimuth;  # if this is defined only waves with a component from this direction will be used
              # i.e. this is the "offshore' direction (i.e. direction looking offshore in degrees clockwise from North)
              # waves traveling "offshore" will be ignored
my $halfSectorWidth=90;


GetOptions ( 
             "oneline=s" => \$oneLine,
             "threshold=s" => \$threshold,
             "offshoredirh=s" => \$azimuth,
             "halfsector=s"  => \$halfSectorWidth
                                         );

# check for input arguments
unless (defined $oneLine){
   print "You did not specify the oneline filename (e.g. --oneline ST63020_v03.onlns)\n";
   print "Please enter the name of the oneline file:\n";
   $oneLine=<>;
   chomp $oneLine;
}

unless (defined $threshold){
   print "You did not specify a threshold for the waveheight (e.g. --threshold 5.0)\n";
   print "Please enter the threshold value\n";
   $threshold =<>;
   chomp $threshold;
}

if (defined $azimuth) {
   print "INFO: WIS_PeaksOverThreshold.pl: azimuth defined: only considering waves coming from $azimuth degrees CW from North +- $halfSectorWidth degrees\n";
}

# ingest the oneline file
my @T;  
my @HS;
my @DIR;
my @TP;

open IN, "<$oneLine" or die "ERROR: WIS_PeaksOverThreshold.pl: Cannot open oneline file $oneLine\n";


while (<IN>){
   chomp;
   $_ =~ s/^\s+//g;
   
   my @data=split(/\s+/,$_);

   push @T, $data[0];
   my $hs = $data[9];
   my $dir = $data[15];
   my $tp= $data[11];
   if (defined $azimuth){
      $hs=0 if (( $dir >= $azimuth-$halfSectorWidth) and ($dir <= $azimuth+$halfSectorWidth));
   }
   push @HS, $hs;
   push @DIR, $dir;
   push @TP, $tp;
}
close(IN);


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
   #my $PEAKS[$peakCount]=[];
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
          if ($hs < $threshold){  # down-crossing of threshold
              $downCross=$hr;
              push @PEAKS, $peakHs;
              push @PeakTimes, $peakT;
              push @UpCrosses, $upCross;
              push @DownCrosses, $downCross;
              push @TP_atPeak, $peakTp;
              push @DIR_atPeak, $peakDIR;
              my $duration=$downCross-$upCross;
              push @Duration, $duration;
              $peakCount++;
              print "peak $peakCount at time $peakT hour $hr with duration $duration is $peakHs, dir=$peakDIR, Tp=$peakTp \n";
              last;
          }    
      }
      unless (@HS){  # in case we end before a down-crossing
           push @PEAKS, $peakHs;
           push @PeakTimes, $peakT;
           $peakCount++;
           print "peak $peakCount at time $peakT is $peakHs\n";
      }
   }
}

my $totalDuration=$hr/24/365.25;

# sort the data and write the orders statistics 
my @sorted_i = sort {$PEAKS[$b] <=> $PEAKS[$a]} (0..$#PEAKS);

my $outFile="$oneLine"."_POT-stats_threshold-$threshold.csv";

print "writing results to output $outFile\n";

open OUT, ">$outFile" or die "ERROR: WIS_PeaksOverThreshold.pl: Cannot open `$outFile for output\n";

print OUT "$totalDuration # totalDuration of time series in years\n"; 
print OUT "Peak Hs values over a threshold of $threshold from data in WIS oneline file $oneLine\n";
print OUT "rank,peak significant waveheight (m), time of Peak, upcross time, downcross time, duration of peak (hr),Direction,Peak Period\n";

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
  

   print OUT "$rank,$PEAKS[$i],$t,$uc,$dc,$Duration[$i],$DIR_atPeak[$i],$TP_atPeak[$i];\n";
   $rank++;
}
close (OUT);




   
 
           
    









