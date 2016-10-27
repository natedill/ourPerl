#!/usr/bin/perl
###################################################################################################
# getPWSData.pl
###################################################################################################
# 
# Gets a sequence of daily data from www.wunderground.com for the PWS
# in csv format for each day between BEGINDATE and ENDDATE.  The data are
# concatenated and writen to a file.
#
# useful for getting long term records of met data
#
# 
# 
###################################################################################################
# usage: 
#
#  PWSData.pl -PWS PWS -begin BEGINDATE -end ENDDATE -outfile OUTFILENAME
#
#  or run interactively
#
#  PWSData.pl
#
#  
#  PWS = WunderGround ID for Personal Weather Station
#  BEGINDATE = date you want to start retrieving data in yyyy/mm/dd format
#  ENDDATE = date you want to end retrieving date in yyyy/mm/dd format
#  OUTFILENAME = this is the name of the output csv file that will contain all the concatenated data
#
###################################################################################################
#  Copyright (C) 2015 Austin Hart
#  Copyright (C) 2015-2016 Nate Dill
#
#  This code is free software: you can redistribute it and/or modify it under the terms of the 
#  GNU General Public License as published by the Free Software Foundation, either version 3 of
#  the license, or (at your option) any later version.
#
#  This code is provided in the hope that it will be useful, but WITHOUT ANY WARRANTY; without 
#  even the impied warranty of MERCHANTABILITY of FITNESS FOR A PARTICULAR PURPOSE.  See the 
#  GNU General Public License forr more details.
#
#  You should have received a copy of the GNU General Public License along with this code.   
#  If not, see <http://www.gnu.org/licenses/>
#
###################################################################################################
use strict;
use warnings;
use LWP::UserAgent;
use Getopt::Long;
use HTTP::Request::Common  qw(POST GET PUT);
use HTTP::Cookies;

my $PWS;
my $beginDate;
my $endDate;
my $outFileName;
my $url;
my $baseStr1="http://www.wunderground.com/weatherstation/WXDailyHistory.asp?ID=";
my $baseStrDay="&day=";
my $baseStrMonth="&month=";
my $baseStrYear="&year=";
my $baseStr2="&graphspan=day&format=1";
my $data;
my $req;
my $res;
my $l;
my $today;


# get comand line options
GetOptions('PWS:s' => \$PWS,
       	   'begin:s' => \$beginDate,
           'end:s' => \$endDate,
           'outfile:s' => \$outFileName); #perl getPWSData(PWS: KNHALEXA3, begin: 2015/07/21, end: 2015/07/28, outfile: KNHALEXA3_jul2115_jul2815)

# if any options weren't specified get them from user input
unless ($PWS) {
	print "** Specify Personal Weather Station (i.e. -PWS KNHALEXA3)\n";
	print "  please enter PWS Code:  ";
        $PWS =<>;
	chomp($PWS);
	print "\n";
	}	
unless ($beginDate) {
	print "** Specify BEGINDATE (i.e. -begin 1980/01/01)\n";
	print "  please enter BEGINDATE in yyyy/mm/dd format:  ";
        $beginDate =<>;
	chomp($beginDate);
	print "\n";
}
unless ($endDate) {
	print "** Specify ENDDATE (i.e. -end 2011/10/15): \n";
	print "  please enter ENDDATE in yyyy/mm/dd format:  ";
        $endDate =<>;
	chomp($endDate);
	print "\n";
}
unless ($outFileName) {
	print "** Specify Output File Name (i.e. -outfile data.csv)\n";
	print "  please enter an output file name:  ";
        $outFileName =<>;
	chomp($outFileName);
	print "\n";
}
#initialize today index
$today=$beginDate;

# create a user agent
my $ua = LWP::UserAgent->new;

# clear the output file, create it if it doesn't exist
open FILE, ">$outFileName" or die "***ERROR*** can't open $outFileName\n";

# get data for each day and append it to the output file
my $looping=1;
while ($looping==1){
 
  #extract year, month, day for url	
  my @ymd=split(/\//,$today);
  my $year=$ymd[0];
  my $month=$ymd[1];
  my $day=$ymd[2];	
  $url="$baseStr1$PWS$baseStrDay$day$baseStrMonth$month$baseStrYear$year$baseStr2";
  print "$url\n";
 
  $req = POST "$url", [format => '1'];

  $res = $ua->request($req);  # response object

  $data = $res->content;

  my @lines=split(/<br>\n/,$data);

  #print header
  if ($today eq $beginDate) {
	my $headerline=$lines[0];
  	print FILE "$headerline\n";
  }

  shift(@lines);

  foreach $l (@lines) {
    print FILE "$l";
  }

  $today=&advanceDay($today);

  if ($today eq $endDate) {  
	$looping=0;
  }



}
close(FILE);




#################################################
# subroutine to advance the date to the next day 
# input and output are both in yyyy/mm/dd format
#################################################
sub advanceDay { # adds one day to yyyy/mm/dd
 my @ymd=split(/\//,$_[0]);
 my $yyyy=$ymd[0];
 my $mm=$ymd[1];
 my $dd=$ymd[2];
 my $febDays=28;
# is it a leap year?
 if (($yyyy-1900)/4 == int(($yyyy-1900)/4)){
     $febDays=29;
     }

 $dd=$dd+1;

 if (($mm == 1) && ($dd>31)){  # end of January
	 $mm=2;
	 $dd=1;
 }
 if (($mm == 2) && ($dd>$febDays)){ # end of Feb
	 $mm=3;
	 $dd=1;
 }
 if (($mm == 3) && ($dd>31)){
	 $mm=4;
	 $dd=1;
 }
 if (($mm == 4) && ($dd>30)){
	 $mm=5;
	 $dd=1;
 }
 if (($mm == 5) && ($dd>31)){
	 $mm=6;
	 $dd=1;
 }
 if (($mm == 5) && ($dd>31)){
	 $mm=6;
	 $dd=1;
 }
 if (($mm == 6) && ($dd>30)){
	 $mm=7;
	 $dd=1;
 }
 if (($mm == 7) && ($dd>31)){
	 $mm=8;
	 $dd=1;
 }
 if (($mm == 8) && ($dd>31)){
	 $mm=9;
	 $dd=1;
 }
 if (($mm == 9) && ($dd>30)){
	 $mm=10;
	 $dd=1;
 }
 if (($mm == 10) && ($dd>31)){
	 $mm=11;
	 $dd=1;
 }
 if (($mm == 11) && ($dd>30)){
	 $mm=12;
	 $dd=1;
 }
 if (($mm == 12) && ($dd>31)){
	 $mm=1;
	 $dd=1;
	 $yyyy=$yyyy+1;
 }

 my $output=sprintf("%04i/%02i/%02i",$yyyy,$mm,$dd);
}


