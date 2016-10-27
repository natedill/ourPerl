#!/usr/bin/env perl
#######################################################################
# getUSGSwaterdata.pl
#
# a script get data from the USGS water dat for the nation web service
#
# can be run interactively or with command line options
#
# e.g. 
#
#  getUSGSwaterdata.pl --site 07378500 --startDt 2016-08-10T00:00Z --endDt 2016-08-17T14:00Z --format rdb --parameterCd 00065
#  
####################################################################### 
# Author: Nate Dill, natedill@gmail.com
#
# Copyright (C) 2016 Nathan Dill
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
#######################################################################
use strict;
use warnings;

use LWP;
use Getopt::Long;
use URI;

my $interactive=1;  # set to 1 if you want the script to prompt for missing input
                    # if set to zero, some missing inputs will be fatal errors.


# declare some variables
my $site;       # ='07378500';  
my $startDt;    # ='2016-08-10T00:00Z'; 
my $endDt;      # ='2016-08-17T16:00Z';  
my $format;      # ='rdb';    
my $parameterCd; # ='00065';    

my $url = URI->new ('http://waterservices.usgs.gov/nwis/iv/');
my $data;
my $req;
my $res;
my $i;
my $outFileName;
my $line;
my $tomorrow;

# deal with the command line options

GetOptions('site:s'     => \$site,  
           'startDt:s'       => \$startDt,
           'endDt:s'         => \$endDt,
           'parameterCd:s'     => \$parameterCd,  # 00065 for stage
           'format:s'      => \$format,
           'outfile:s'     => \$outFileName);



# now check the input
unless ($site) {
	die  "ERROR: getCOOPSdata.pl: no station id given\n" unless ($interactive); 
	print "** No site was specified (e.g. -site 8536110)\n";
	print "  please enter site number:  ";
        $site =<>;
	chomp($site);
	print "\n";
}

unless ($startDt) {
   die " no startDt given\n" unless($interactive);
   print "** No start was specified (e.g. -startDt 2007-08-01T00:00Z)\n ";
   $startDt=<>;
   chomp $startDt;
}
unless ($endDt) {
   die " no endDt given\n" unless($interactive);
   print "** No endDt was specified (e.g. -endDt 2007-08-07T00:00Z)\n ";
  # print " leave blank to get up until latest measurement\n";
   $endDt=<>;
   chomp $endDt;
}
unless ($parameterCd) {
   die " no parameterCd/variable given\n" unless($interactive);
   print "** No parameterCd was specified (e.g. -parameterCd 00065)\n ";
   $parameterCd=<>;
   chomp $parameterCd;
}

#need to add more checking here...

# build the form for the querystring
my %form;
$form {'sites'}=$site;
$form {'startDt'} = $startDt;
$form {'endDt'} = $endDt if ($endDt);
$form {'parameterCd'}=$parameterCd;
$form {'format'}=$format;

# now get the data
$outFileName="$site"."_"."$parameterCd-$startDt-$endDt"."."."$format" unless (defined $outFileName);
$outFileName =~ s/://g;  # remove colons from time format since you cant use them in file names
$outFileName =~ s/\s//g;  # remove spaces too

open FILE, ">$outFileName" or die "can't open $outFileName\n";

  $url->query_form(%form);


  my $ua = LWP::UserAgent->new;


  my $response=$ua->get( $url );  # a HTTP::Response object

 my $success=$response->is_success;
  unless ($success) {
    my $slept=0;
    while ($slept < 4){ 
       print "no success, taking 5";
       sleep 5;
       $success=$response->is_success;
       last if ($success);
       $slept++;
     }
   }
  unless ($success){
     print "slept 4 times without success, now dying\n";
  }

  my $statusLine=$response->status_line;
   
  my $contentType=$response->content_type; 
   
  my $content=$response->content;
 # my @c=split(/\n/,$content);
 # shift @c if ($iter !=1 and lc($format) eq 'csv');  # throws away the headerline when appending csv
 #  $content=join("\n",@c);
  #$cntnt.="$content\n";
  if ( uc($outFileName) eq 'STDOUT'){
     print "$content\n";
  }else{  
     print FILE "$content\n";  
  }

 



#print FILE "$cntnt";
close FILE;



