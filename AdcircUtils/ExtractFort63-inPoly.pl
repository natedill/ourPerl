#!/usr/bin/env perl
use strict;
use warnings;
use lib 'c:\ourPerl';
use AdcircUtils::AdcGrid;
use IO::Zlib;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Geometry::PolyTools;


########################################################################
# config

my $gridfile='C:\0_PROJECTS\191.06004-FairInsRatesMonroe-Appeal\Modeling\ADCIRC-Model-exploration\Grid-to-kmz\southfl_v11-1_final.grd';
my $searchPoly='KeyWest-searchPoly.kml';
my $outGrid='KeyWest-cropped.14';

# first 200 storms on drive 1
my $basePath1='I:\SFLSSS_SurgeFiles_Drive1\ProductionRuns_Storms1to200\storm-%%%\fort.63.gz';
# rest of storms from drive 2
my $basePath2='H:\SFLSSS_SurgeFiles_Drive2\ProductionRuns_Part2\Storms_201to392\storm-%%%\maxele_400sec.63.gz';
 

#my @PATHS=($basePath1,$basePath2);
my @PATHS=($basePath1,$basePath2);
my @StartStorm=(1,201);
my @EndStorm=(1,392);


# end config
######################################################################



my ($line1,$line2,$line3);


# load the grid
my $adcGrid = AdcGrid->new($gridfile);
my $pnp=$adcGrid->getVar('NP');


# read the polygon
my ($pxref,$pyref)=PolyTools::readKmlPoly($searchPoly);


# crop the grid
my ($ne,$np,@foundNodes)=$adcGrid->cropGrid($pxref,$pyref,$outGrid);

# to keep track of max of maxes.
my @MOM=();
foreach my $n (1..$np){
  $MOM[$n]=-99999;
}

# now write cropped maxeles
foreach my $basePath (@PATHS){
 my $start=shift @StartStorm;
 my $end=shift @EndStorm;

 foreach my $storm ($start..$end){
   print "storm $storm\n";
  
   my $gzfile=$basePath;
   $gzfile =~ s/%%%/$storm/;
   
   # read beginning
   my $fh= new IO::Zlib;  # read gzip
   unless ($fh->open("$gzfile","rb")) {die "cant open $storm\n";}   # read from gzip file
   
   # read bz2  - Doesn't seem to work?
   #my $fh = new IO::Uncompress::Bunzip2 $gzfile or die  "IO::Uncompress::Bunzip2 failed: $Bunzip2Error\n";

   $line1=<$fh>;
   chomp $line1;
   $line2=<$fh>;
   chomp $line2;
   $line2 =~ s/^\s+//;
   my ($nset,$pnp,$dt,$nspool,$irtype)=split(/\s+/,$line2);
   $irtype=1 unless (defined $irtype);
   

   #write beginning  
   open OUT, ">cropped-fort-$storm.63";
   print OUT "cropped $line1\n";
   print OUT "$nset $np $dt $nspool $irtype\n";


   # loop through sets read, crop, and write
   foreach my $k (1..$nset){
     print "storm $storm set $k of $nset\n";
      $line3=<$fh>;
      chomp $line3;
      $line3 =~ s/^\s+//;
      my ($t1, $t2, $nnd, $default)=split('\s+',$line3); # this is for sparse ASCII format

      $nnd=$pnp unless (defined $nnd);   # hopefully this should allow it to handle non-sparse format as well
      $default=-99999 unless (defined $default);
         
      # because the data are sparse, initialize the WSE with default
      my @WSE=();
      foreach my $n (1..$pnp){
          $WSE[$n]=$default;
      }
      
      foreach my $n (1..$nnd){
         my $line=<$fh>;
         $line =~ s/^\s+//;
         my ($kk,$wse)=split(/\s+/,$line);
         $WSE[$kk]=$wse;
      }

      # write it
      print OUT "$line3\n";
      my $n=0;
      foreach my $pnid (@foundNodes){
         $n++; 
         print OUT "$n $WSE[$pnid]\n";
         $MOM[$n]=$WSE[$pnid] if ($WSE[$pnid] > $MOM[$n]);
      }
   }
   close OUT;
 }
} # end loop over paths


# print the MOM
open OUT, ">cropped-MOM.63";
print OUT "cropped $line1\n";
print OUT "1 $np 1 1 1\n";
print OUT "1 1\n";
foreach my $n (1..$np){
   print OUT "$n $MOM[$n]\n";
}
close OUT;
