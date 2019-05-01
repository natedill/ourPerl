#!/usr/bin/env perl
use strict;
use warnings;

# this script makes a basic STWAVE model given a kml file that defines the location
# of the model grid and a space delminted ASCII xyz file that contains the bathy data  

# it assumes z in the xyz file is elevation (i.e. positive up)

# the kml file can be easily made in google earth.  It should contain a single 
# kml "path" that is just a line segment with first point onshore and the second point
# offshore at the center of the desired domain. Within the description of the kml path
# you must specify the width of the domain and desired cell size as a semicolon delimited
# text string.
#
# e.g.  for a grid that is 25 kilometers wide with 100 meter cell size
# 
# width=50000;dx=100
#



use lib 'c:\ourPerl';
use StwaveUtils::StwaveObj;
use Mapping::UTMconvert;

################################################### config


my $kmlInput='GridInput.kml';



my $xyzfile='bathy.xyz';   # a space delimited file with xyz points




###################################################### end config

our $pi=4*atan2(1,1);
our $deg2rad=$pi/180;

#------------------------------------------------
# load xyz data

my @E;
my @N;
my @DEPTH;

# bathy
open IN, "<$xyzfile";
while (<IN>){
   chomp;
   my ($x, $y, $z)=split(/\s/,$_);
   push @E, $x;  
   push @N, $y;
   push @DEPTH, -$z;
}



# get grid input data and create grid parameters
# kml input contains a path with two points representing the center of the grid
# the first point is onshore and the second offshore at the open boundary
# read kml input
open KML, "<$kmlInput";
$/=undef;
my $slurp=<KML>;
close (KML);

# get the placemark
$slurp =~ m/<Placemark>(.*?)<\/Placemark>/s;
my $pm=$1;

#print "\n\n\n pmp\n\n$pm\n\n";

#get the coords
$pm =~ m/<coordinates>(.*?)<\/coordinates>/s;
my $coords = $1;
#print "\n\n\n coords\n\n$coords\n\n";
$coords =~ s/^\s+//;
$coords =~ s/\s+$//;
my @points=split(/\s+/,$coords);
my @LON_;
my @LAT_;
foreach my $p (@points){
  my ($x,$y,$z) = split(/,/,$p);
  push @LON_, $x;
  push @LAT_, $y;
}

print "LON: @LON_\nLAT: @LAT_\n";

# get the description
# store the data (width and dx in a hash)
$pm =~ m/<description>(.*?)<\/description>/s;
my $desc_str=$1;
$desc_str =~ s/\s+//;

my @desc_data=split(/;/,$desc_str);
my %desc;
foreach my $d (@desc_data){
my ($key,$value)=split(/=/,$d);
$desc{lc($key)}=$value;
}


my $width=$desc{width};
my $cellSize=$desc{dx};

my $halfwidth=$width/2;


print "width is $width\n";
print "cellSIze is $cellSize\n";


# assume the first point is onshore, and the 2nd offshore, the line segment defines the azimuth
# and i-dimension of the grid, and the width defines the j-dimension the line segment is in the 
# middle of the grid
my ($px,$py,$utmZone)=UTMconvert::deg2utm(\@LON_,\@LAT_);

print "zone is $utmZone->[0]\n";

my $dy=$py->[0]-$py->[1];
my $dx=$px->[0]-$px->[1];

print "dxdy $dx, $dy\n";
print "halfwidth $halfwidth\n";


my $azimuth=atan2($dy,$dx)/$deg2rad;

my $ds=( $dx**2.0 + $dy**2 )**0.5;

my $dsdy=$ds/$dy;
my $dsdx=$ds/$dx;

my $x0=$px->[1] + $halfwidth/$dsdy;
my $y0=$py->[1] - $halfwidth/$dsdx;

my ($lon0,$lat0)=UTMconvert::utm2deg($x0,$y0,$utmZone->[0]);

print "origin: $x0,$y0 :: $lon0,$lat0\n";
print "azimuth $azimuth\n";

# determine number of i and j cells
my $ncelli=int($ds/$cellSize);
my $ncellj=int($width/$cellSize);





#--------------------------------------------
# create the model sim and dep files
my $stw=StwaveObj->new();

$stw->setParm('x0',$x0);
$stw->setParm('y0',$y0);
$stw->setParm('azimuth',$azimuth);
$stw->setParm('n_cell_i',$ncelli);
$stw->setParm('n_cell_j',$ncellj);
$stw->setParm('dx',$cellSize);
$stw->setParm('dy',$cellSize);

my $numcells=$ncelli*$ncellj;
print "ni,nj, numcells, $ncelli, $ncellj, $numcells\n";
sleep(5); 


$stw->interpDepFromScatter(\@E,\@N,\@DEPTH);
$stw->writeDepFile('stwaveModel.dep');

$stw->writeSimFile('stwaveModel.sim')

