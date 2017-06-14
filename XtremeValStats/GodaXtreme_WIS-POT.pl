#!/usr/bin/env perl
#  This script performs a Peaks Over Threshold analysis 
#  on WIS wave data (provided in the "oneline" file format
#
#  It uses the POT method described Yoshimi Goda, 2010, 
#  "Random Seas and Design of Maritime Structures"  3rd edition.
#  Chapter 13 Statistical analysis of Extreme waves, and implemented
#  in the GodaXtreme.pm package
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
use lib 'c:\ourPerl';
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



















