#!/usr/bin/env perl
##################################################################################
# prep26obc_constant.pl
#
# A script to prep the open boundary input for padcswan/punswan
#
# usage: (run in root directory of simulation after running adcprep)
#
# perl prep26obc_constant.pl --np 36 --command "BOU SIDE 1 CCW FILE 'bound_sp' 1"
#
# You must include a line in your fort.26 file that starts with the string 
# '$%%BOUNDSPEC%%' (without the quotes) where the swan boundary 
# commands should go (typically following all the READinp commands) 
# 
#
# np is the number of subdomains you preped for.  If you specify
# --np 1, then it assumes you are doing a serial run and does
# not try to enter into PE directories
# 
#
# The script goes through all the PE* directories and reads the grid
# file to see if it has open boundaries. If the subdomain has an open 
# boundary it inserts the appropriate commands into the fort.26 file 
# in that PE directory. It assumes there is only one open boundary in each 
# subdomain, and will die if it finds NOPE > 1 
#
# 
#--------------------------------------------------------------------
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
#----------------------------------------------------------------------                                       

# assumed BOU SHAP command...
#my $boundShapespec='BOUnd SHAPespec MEAN DSPR DEGRees';  assumes you use default
use strict;
use warnings;

use lib '/home/nate/ourPerl';
use AdcircUtils::AdcGrid;
use Getopt::Long;

# some default settings
my $command='';
my $fort26out="fort.26";
my $np=1;
# get the command line options
GetOptions ( "np=i" => \$np,
             "command=s" => \$command
           );


#---------------------------------------------------------
# loop over the subdirectories, read the grid, write the fort.26 and tpar files
foreach my $pe (0..$np-1){
print "INFO: prep26obc.pl: IN SUBDOMAIN $pe\n";
   my $pedir=sprintf("PE%04d/",$pe);
   $pedir='' if ($np==1); 
   my $fort14="$pedir".'fort.14';
   my $adcGrid=AdcGrid->new();
   $adcGrid->loadGrid($fort14);

   # how many open boundaries are there?
   my $nope=$adcGrid->getNOPE();
   next if ($nope==0);
   die "ERROR: prep26obc.pl: subdomain $pedir has $nope open boundaries, it can only handle one\n" if ($nope >1);  
  
 
   # write the insert for the fort.26;
   my $fort26str='';
  # $fort26str .= "$boundShapespec\n\$\n";
   $fort26str .= "$command\n";

   #slurp the fort.26 file
   my $fort26="$pedir".'fort.26';
   my @LINES=();
   open F26, "<$fort26" or die "ERROR: prep26obc.pl: cant open $fort26 fir reading\n";
   while (<F26>){
      chomp;
      push @LINES, $_;
   }
   close(F26);
   #delete it
   unlink $fort26; # careful there
   open F26, ">$fort26" or die "ERROR: prep26obc.pl: cant open $fort26 for writing\n";
   foreach my $line (@LINES){
     if ($line =~ m/^\$%%BOUNDSPEC%%/){
        print F26 "$fort26str";
     }else{
        print F26 "$line\n";
     }
   }
   close(F26);


} #end loop over PE dirs

