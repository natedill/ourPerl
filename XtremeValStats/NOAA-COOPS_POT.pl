#!/usr/bin/env perl
#
# a perl script to perform peaks over threshold extreme value analysis 
# for NOAA COOPS tide data 
# 
# uses Goda's method based on GEV distributions. see GodaXtreme.pm for details
#
use strict;
use warnings;
use lib 'c:\ourPerl';

use XtremeValStats::GodaXtreme;


my $stationID='8418150';
my $beginDate=19500101;
my $endDate=20150101;
my $product='hourly_height';
my $datum='navd';
my $units='english';
my $recsPerHour=1;
my $minEventDuration=24; # merge peaks together if less than this apart
#my $coopsFile='8418150_hourly_height-19500101-20150101.CSV';  

my $threshold = 6;   # starting threshold value
my $nu=1;  # censoring parameter

while ($threshold <= 8){

   my ($oref,$lambda,$logFile)=GodaXtreme::NOAA_gauge_POT(
                     -STATIONID => $stationID,    # NOAA station ID number
                     -BEGINDATE => $beginDate,    # yyyymmdd
                     -ENDDATE   => $endDate,      # yyyymmdd
                     -PRODUCT   => $product,      # e.g. hourly_height, water_level, wind  
                     -DATUM     => $datum,        # e.g. MHHW,MHW,DTL,MTL,MSL,MLW,MLLW,GT,MN,DHQ,DLQ,NAVD
                     -UNITS     => $units,        # e.g. metric or english
                     -THRESHOLD => $threshold,    # threshold value for POT
                 #    -LOGFILE   => $logFile,      # optional name of logfile
                     -RECORDFREQ => $recsPerHour, # e.g. 10 for 6 minute "water_level",  1 for hourly_height
                     -MINEVENTDURATION => $minEventDuration,    # optional, event duration in hours,  default is 24 hours    
                   #  -COOPSFILE => $coopsFile     # optional name of file downloaded with getCOOPS.pl with time series data
                   )    ;                          # specify this if you have already dowlnoaded the data from CO-OPS 

    GodaXtreme::fitDistributions($oref,[10,50,100,500],$lambda,$nu,$logFile);
    $threshold=$threshold+0.1;

}


