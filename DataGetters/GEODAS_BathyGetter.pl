#!/usr/bin/env perl
#
#
#  Get some Bathy data!
#
#

use strict;
use warnings;
use LWP::Simple ;
use File::Path qw(make_path);
use HTML::TableExtract;


# a file produced by the geodas arcgis web map giving some summary data
# for datasets found in a search area.
#  http://maps.ngdc.noaa.gov/viewers/bathymetry/
#
# the input if a file that lists datasets like this:
#
#  H07772 (1949)
#  H07150 (1946)
#  H07152 (1946)
#  H07054 (1945)
#
#
################################################################
# my $datasetList='DigitalSoundingDataBathy.txt';
print "Enter the name of dataset list file\n";
my $datasetList=<>;
chomp $datasetList;

#print "Enter a directory where you want to mirror the GEODAS data\n";
my $prefix='NOS/coast/';

# the url where the list of data set parent directories are held
my $baseUrl="http://surveys.ngdc.noaa.gov/mgg/NOS/coast/";


# loop through the datasets and download the data
open FILE, "<$datasetList" or die " cant open $datasetList\n";

my $lastline;

while (<FILE>){
   chomp;
   if ($_ =~ m/([A-Z]\d\d\d\d\d)/) {
      my $id=$1;
      print "id $id\n";
      #sleep(5);
      my $letter=substr($id,0,1);
      my $setNumber=substr($id,1,5);
      print "letter number $letter $setNumber\n";


      # find the name of the directory that has this data set
      # each directory has 2000 potential date sets
      # they are named e.g. /H12001-H14000, which contains H12477
      my $num=0;
      my $parentDir;
      while ($num < 18000) {
	     my $nump1=$num+1;
	     my $num2=$num+2000;
	      if (($setNumber >= $num+1) and ($setNumber <=$num+2000)){
		 $parentDir=sprintf("%s%05d-%s%05d/",$letter,$nump1,$letter,$num2);
		 print "parentDir $parentDir\n";
              }
	      $num=$num2;
       }

       my $localPath1="$prefix"."$parentDir"."$id";
       print "localpath1 $localPath1\n";
       make_path($localPath1) unless (-d $localPath1);



      # write out this portion of the summary file
      
      #my $sumfile="$localPath1/$id"."_summary.txt";
      #print "sumfile $sumfile\n";
      #open SUM, ">$sumfile";
      #print SUM "$lastline\n";
      #print SUM "$_\n";
      #my $line=<FILE>;
      #print SUM "$line";
      #$line=<FILE>;
       #print SUM "$line";
      #$line=<FILE>;
       #print SUM "$line";
      #   close(SUM);


      # get the html directory listing of the directory for this dataset
      # and store it in a temporary file for parsing
      my $url="$baseUrl"."$parentDir"."$id";
      print "URL $url\n";
      # sleep(5);
      my $tmpfile="tmp_$id.html";
      getstore($url,"$localPath1/$tmpfile");
 
      next unless (-f "$localPath1/$tmpfile");

      my @subdirs=(); # build a list of subdirs to process

      # parse the html to get a list of subdirectories and their urls
      # slurp the tmpfile
      #$/=undef;
      #open TMP, "<$tmpfile" or die "can't open $tmpfile\n";
      #my $htmlstring=<TMP>;
      #close (TMP);
     
      my @headers=("Name");
      my $te= HTML::TableExtract->new ( headers=> [qw(Name)]);
      $te->parse_file("$localPath1/$tmpfile");
      my $table=$te->tables;

      # foreach my $ts ($te->tables) {
      #  print "Table (", join(',', $ts->coords), "):\n";
      my $ts=$te->first_table_found();
      my @rows=$ts->rows;
      foreach my $row (@rows){
	   my @cols=@$row;
	   foreach my $col (@cols){
              next unless (defined $col);
              if ($col =~ m/\/$/) {
                print "$col\n";
	        push (@subdirs, $col);
	      }
	   }
      } 


      # go into each subdir, parse html to get list of files, download the files
      foreach my $subdir  (@subdirs){

         # limit to just GEODAS folders 
         next unless ($subdir =~ m/GEODAS/);

         my $url2="$url/$subdir";
	 my $localPath2="$localPath1/$subdir";
	 print "localpath2 $localPath2\n";
	 make_path($localPath2) unless (-d $localPath2);
         print "$url2\n";
         getstore($url2,"tmpfile");


	  my @headers2=("Name");
          my $te2= HTML::TableExtract->new ( headers=> [qw(Name)]);
          $te2->parse_file("tmpfile");
          my $table2=$te2->tables;

          my $ts2=$te2->first_table_found();
          my @rows2=$ts2->rows;
          foreach my $row2 (@rows2){
	      my @cols2=@$row2;
              foreach my $col (@cols2){
              next unless (defined $col);
	      next if ($col =~ /Parent/);
	      my $localFile="$localPath2"."$col";
	      my $url3="$url2"."$col";
	      print "\ngetting: $url3\nstoring:  $localFile\n";
	      getstore($url3,$localFile);

	      }
           } 


	
      }


     

      }
   $lastline=$_;

}
close(FILE);

