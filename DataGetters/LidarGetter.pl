#!/usr/bin/env perl
#
# get some lidar data !
#
#

use strict;
use warnings;
use Net::FTP;
use File::Path qw(make_path);
use Getopt::Long;


use lib 'C:/ourPerl/';
use Geometry::PolyTools;


####################################################################
#
# input section
#
#####################################################################

my $kmlFile;   # kml file with a polygon to search for lidar data
my $ftpsite;   # ftp site that houses the lidar data 
my $ftpDataDir;                   # directory on ftp that has the laz files and csv index file with their ranges
my $localDataDir;                 # a local directory where you want download the laz files
my $usecsv;                     # set to zero if you'd rather scan laz headers to get the range data (slow but definitive)

GetOptions ("kmlfile=s"  => \$kmlFile,
            "ftpsite=s"  => \$ftpsite,
            "ftpdir=s"   => \$ftpDataDir,
            "localdir=s" => \$localDataDir,
            "usecsv=s"   => \$usecsv);

# enter the name of kml file with polygon of interest
#my $kmlFile='Knox.kml';

unless (defined $kmlFile) {
   print "you didn't specify a --kmlfile argument\n";
   print "enter the name of a kml file with a search polygon in it:\n";
   $kmlFile=<>;
   chomp($kmlFile);
}
unless (defined $ftpsite) {
   print "you didn't specify a --ftpsite argument\n";
   print "enter the name of the ftpsite you want to search for laz data:\n";
   print "e.g. --ftpsite ftp.csc.noaa.gov\n";
   $ftpsite=<>;
   chomp($ftpsite);
}
unless (defined $ftpDataDir) {
   print "you didn't specify a --ftpdir argument\n";
   print "enter the ftp directory you want to scan for laz files:\n";
   $ftpDataDir=<>;
   chomp $ftpDataDir;
}
unless (defined $localDataDir) {
   print "you didn't specify a --localdir argument\n";
   print "enter the name of a local directory to store the laz files:\n";
   $localDataDir=<>;
   chomp $localDataDir;
}
unless (defined $usecsv) {
   print "you didn't specify a --usecsv argument\n";
   print "if there is a csv index file in the ftpdir do you want to use it?\n";
   print "otherwise we'll scan the laz headers for range info (can be slower). yes or no?:\n";
   $usecsv=<>;
   chomp $usecsv;
}


# enter the ftp server and ftp directory containing the data
# get a lidar dataset directory containing laz files (see the csc data access viewer)
#my $ftpsite='ftp.csc.noaa.gov';
#my $ftpDataDir='/pub/DigitalCoast/lidar1_z/geoid12a/data/2524/';

# enter a local directory where you data to be mirrored (so we only download it once)
#my $localDataDir='H:/Lidar/DigitalCoast/lidar1_z/geoid12a/data/2524/'; #try to mirror the csc data


######################################################################



# make local data directory if it doesn't exist
unless (-d $localDataDir){
   make_path($localDataDir);
}

# read the kml polygon of interest
my ($pxref,$pyref)=PolyTools::readKmlPoly($kmlFile);
print "polyX: @{$pxref}\n";
print "PolyY: @{$pyref}\n";


# connect to ftp server
print "Connecting to $ftpsite\n";
my $ftp = Net::FTP->new($ftpsite, Debug => 0) or die "cannot connect to $ftpsite $@\n";


# login to ftp server
print "Logging in to $ftpsite\n";
my $loginSuccess = $ftp->login("anonymous","-anonymous@") or die "cannot login", $ftp->message;

# change to data directory
print "cd to $ftpDataDir\n";
my $cdSuccess = $ftp->cwd($ftpDataDir) or die "cwd failed", $ftp->message;

#set transfer to binary mode
$ftp->binary; 


# get list of files
my @files=$ftp->ls;

my @lazList; # list to hold files we need to process locally
my @downloadList; # list of files we need to download


# check for a minmax.csv file
# if they have one we'll assume its correct and use it instead of scanning headers
my $haveCSV=0;

if ($usecsv eq 'yes'){

my $localCSV;
foreach my $file (@files){
  if ($file =~ /.+minmax\.csv$/){
     $localCSV= "$localDataDir"."$file";
     print " getting $localCSV\n"; 
     $ftp->get($file,$localCSV) or die "get failed", $ftp->message;
     $haveCSV=1;
     
     open CSVFILE, "<$localCSV" or die "cant open $localCSV";
     <CSVFILE>; # skip the first line
     while (<CSVFILE>){
         chomp;
	 $_=~ s/^\s+//;
         my ($fname,$xmin,$xmax,$ymin,$ymax)=split(/,/,$_);
	 print "$fname,$xmin,$xmax,$ymin,$ymax\n";

         $fname =~ s/\.\///;
	
         # skip this file if none of the corner points are in the polygon of interest
         # or vice-versa
         my $inpoly;
         my $addfile=0;

         #check to see if file header is in polygon
         #my ($xmax,$xmin,$ymax,$ymin,$zmax,$zmin)=LasReader::getHeaderRange("$pathToLas/$file");
         my $bxInPoly=PolyTools::boxInPoly($xmin,$ymin,$xmax,$ymax,$pxref,$pyref);
         my $polyInBox=PolyTools::polyInBox($xmin,$ymin,$xmax,$ymax,$pxref,$pyref);
         print "rrange: $xmin,$xmax,$ymin,$ymax\n";
         print "bx in poly $bxInPoly\n";
         print "poly in bx $polyInBox\n";
         $addfile=1 if ($bxInPoly or $polyInBox);

         # see if we already have this file, and if it is the same size. if so don't read it off the ftpsite
         my $haveit=0;
         my $localLaz= "$localDataDir"."$fname";
	 $haveit=1 if (-f $localLaz);
         if ($haveit==1 and $addfile==1) {
            my $sizeOnDisk= -s "$localLaz";
            my $sizeOnFtp=$ftp->size($fname);
            $haveit=0 unless ($sizeOnDisk == $sizeOnFtp);
            print "we have $fname, $sizeOnDisk bytes, but its $sizeOnFtp bytes on ftp\n"  if ($haveit==0);
            print "updating $fname\n" if ($haveit==0);
         }

         # if its in the area and we already have it add the file to the lazList
         # if its in the area and we dont have it, download it first then add it to the list
         if ($addfile) {
             unless ($haveit) {
		 my $size=$ftp->size($fname);
		 print "downloading $fname $size bytes\n";
                 print "|------------|------------|------------|------------|\n";
		 my $sharpSize=int($size/54);
		 $ftp->hash(\*STDOUT,$sharpSize);
		 $ftp->get($fname,$localLaz) or die "get failed", $ftp->message;
		 print "\n";
             }
	     push (@lazList,$localLaz);
	     print "adding $localLaz\n"
         }
       
      } # end while csv
     last;   
   } #end if csv file 

} # end loop over files

# now let's just check to see if there are any laz files on the ftp that weren't on the ftp, 
# then get them if they overlap the area of interest


} # end if usecsv

# if we didn't have the csv file, scan the headers
unless ($haveCSV){
foreach my $file (@files){
    my $buf;
    my $haveit=0;

    # move on if it's not a laz file
    next unless( $file =~ /.+\.laz$/);
   
    # see if we already have this file. if so don't read it off the ftpsite
    my $localLaz= "$localDataDir"."$file";
   
    if (-f "$localLaz") {
        open FH, "<$localLaz";
        binmode(FH);
	read(FH,$buf,375);
	close(FH);
	$haveit=1;
    }
          	   

    # we did't already have it, so read the header through the ftp connection
   if ($haveit==0) {
        my $ntries=0;
        while (1==1){
            my $dataConn=$ftp->retr($file);
            $ntries++;
            if (defined $dataConn) { 
                $dataConn->read($buf, 375);
	        $dataConn->close;
                last;
            }else{
                print "undef dataConn on file $file\nwaiting a few seconds...";
                sleep (3);
            }
            if ($ntries>9) {
                print "failed 10 tries reading header from $file, giving up\n";
                last;
            }
        }
    }
    unless (defined $buf) {
        print "empty buffer, skipping $file\n";
        next;
    }   

    # las 1.4 header is 375 bytes
    # min/max xyz data are total of 48 bytes starting at offset 179
    my $range=substr($buf,179,48);
    
    my (@data)=unpack("d6",$range);   # read 3 doubles
    printf "Range [max min] for $file:\n".	    
           "   X_range = %g %g\n".
	   "   Y_range = %g %g\n".
	   "   Z_range = %g %g\n",@data;
    my ($xmin,$xmax,$ymin,$ymax,$zmin,$zmax)=@data;

    # skip this file if none of the corner points are in the polygon of interest
    # or vice-versa
    my $inpoly;
    my $addfile=0;

    #check to see if file header is in polygon
    #my ($xmax,$xmin,$ymax,$ymin,$zmax,$zmin)=LasReader::getHeaderRange("$pathToLas/$file");
    my $bxInPoly=PolyTools::boxInPoly($xmin,$ymin,$xmax,$ymax,$pxref,$pyref);
    my $polyInBox=PolyTools::polyInBox($xmin,$ymin,$xmax,$ymax,$pxref,$pyref);
    print "rrange: $xmin,$xmax,$ymin,$ymax\n";
    print "bx in poly $bxInPoly\n";
    print "poly in bx $polyInBox\n";
    $addfile=1 if ($bxInPoly or $polyInBox);


     # if its in the area and we already have it add the file to the lazList
     # if its in the area and we dont have it, download it first then add it to the list
    if ($addfile) {
        
       # if we already have this file, but its not the same size download a new one
       if ($haveit==1) {
           my $localLaz= "$localDataDir"."$file";
           my $sizeOnDisk= -s "$localLaz";
           my $sizeOnFtp=$ftp->size($file);
           $haveit=0 unless ($sizeOnDisk == $sizeOnFtp);
           print "we have $file, $sizeOnDisk bytes, but its $sizeOnFtp bytes on ftp\n"  if ($haveit==0);
           print "updating $file\n" if ($haveit==0);
       }

       unless ($haveit) {
	   my $size=$ftp->size($file);
	   print "downloading $file $size bytes\n";
           print "|------------|------------|------------|------------|\n";
	   my $sharpSize=int($size/54);
	   $ftp->hash(\*STDOUT,$sharpSize);
	   $ftp->get($file,$localLaz) or die "get failed", $ftp->message;
	   print "\n";
        }
	push (@lazList,$localLaz);
    }

}
} #end unless haveCSV

$ftp->quit;

print "the following files were found in the polygon in $kmlFile:\n";
foreach my $lazFile (@lazList){
	print "$lazFile\n";
}









