#!/usr/bin/env perl

use strict;
use warnings;
use lib 'c:\myPerl';
use XtremeValStats::GodaXtreme;


my $oneLineFile='ST63020_v03.onlns';  # name of oneline file from WIS

my $threshold = 2.4;   # starting threshold value
my $nu=1;  # censoring parameter
my $minEventDuration = 48;  # merge peaks if closer together than this many hours

while ($threshold <= 6.0){

    my ($oref,$lambda,$logFile)=GodaXtreme::WISoneLinePOT( -ONELINE => $oneLineFile, -THRESHOLD => $threshold, -MINEVENTDURATION => $minEventDuration);
    GodaXtreme::fitDistributions($oref,[10,50,100,500],$lambda,$nu,$logFile);
    $threshold=$threshold+0.2;

}



















