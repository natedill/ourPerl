#!/usr/bin/perl
###################################################################################################
# getWundergroundData.pl
###################################################################################################
# 
# Gets a sequence of daily data from www.wunderground.com for the AIRPORT
# in csv format for each day between BEGINDATE and ENDDATE.  The data are
# concatenated and writen to a file.
#
# usefull for getting long term records of met data
#
# note: data from www.wunderground.com is primarily derived from the METAR data from airports
# 
###################################################################################################
# usage: 
#
#  getWundergroundData.pl -airport AIRPORT -begin BEGINDATE -end ENDDATE -outfile OUTFILENAME
#
#  or in abreviated form:
#
#  getWundergroundData.pl -a AIRPORT -b BEGINDATE -e ENDDATE -o OUTFILENAME
#
#  or run interactively
#
#  getWundergroundData.pl
#
#  
#  AIRPORT = 4 character ICAO code for the airport i.e. KBOS for Boston's Logan Airport
#  BEGINDATE = date you want to start retreving data in yyyy/mm/dd format
#  ENDDATE = date you want to end retreving date in yyyy/mm/dd format
#  OUTFILENAME = this is the name of the output csv file that will contain all the concatenated data
#
###################################################################################################
#  Copyright (C) 2011-2016 Nate Dill
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

my $airport;
my $beginDate;
my $endDate;
my $outFileName;
my $url;
my $baseStr1="https://www.wunderground.com/history/airport/";
my $baseStr2="/DailyHistory.html";
my $data;
my $req;
my $res;
my $l;


# get comand line options
GetOptions('airport:s' => \$airport,
       	   'begin:s' => \$beginDate,
           'end:s' => \$endDate,
           'outfile:s' => \$outFileName);

# if any options weren't specified get them from user input
unless ($airport) {
	print "** No AIRPORT was specified (i.e. -airport KPVC)\n";
	print "  please enter airport ICAO Code:  ";
        $airport =<>;
	chomp($airport);
	print "\n";
	}	
unless ($beginDate) {
	print "** No BEGINDATE was specified (i.e. -begin 1980/01/01)\n";
	print "  please enter BEGINDATE in yyyy/mm/dd format:  ";
        $beginDate =<>;
	chomp($beginDate);
	print "\n";
}
unless ($endDate) {
	print "** NO ENDDATE was specified (i.e. -end 2011/10/15)\n";
	print "  please enter ENDDATE in yyyy/mm/dd format:  ";
        $endDate =<>;
	chomp($endDate);
	print "\n";
}
unless ($outFileName) {
	print "** No output file name was specified (i.e. -outfile data.csv)\n";
	print "  please enter an output file name:  ";
        $outFileName =<>;
	chomp($outFileName);
	print "\n";
}

# create cookie jar
my $cookie_jar = HTTP::Cookies->new(
    file => "lwp_cookies.dat",
    autosave => 1,
);


# create a user agent
my $ua = LWP::UserAgent->new;

# supply the cookie jar
$ua->cookie_jar($cookie_jar);

# get the cookie we need to get the METARS
my $url2='https://www.wunderground.com/cgi-bin/findweather/getForecast'; #?setpref=SHOWMETAR&value=0
$req = POST "$url2", [setpref=>'SHOWMETAR',value=>'1'];
$res = $ua->request($req);  # response object


# clear the output file, create it if it doesn't exist
open FILE, ">$outFileName" or die "***ERROR*** can't open $outFileName\n";

my $today=$beginDate;

#get the headerline from the html response from the first dat
  $url="$baseStr1$airport/$today$baseStr2";
  $req = POST "$url", [format => '1'];
  $res = $ua->request($req);
  $data = $res->content;
  # print "$data";
  my @lines=split(/<br \/>\n/,$data);
  my $headerline=$lines[0];
  print "$headerline\n";
  print FILE "$headerline\n";


# get data for each day and append it to the output file
my $looping=1;
while ($looping==1){

  $url="$baseStr1$airport/$today$baseStr2";
  print "$url\n";
 
  $req = POST "$url", [format => '1'];

  $res = $ua->request($req);  # response object


  $data = $res->content;

  my @lines=split(/<br \/>\n/,$data);
  shift(@lines);
  shift(@lines);
  pop(@lines);

  foreach $l (@lines) {
    print FILE "$l\n";
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


