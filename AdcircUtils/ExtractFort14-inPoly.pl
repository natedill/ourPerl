#!/usr/bin/env perl
use strict;
use warnings;
use lib 'c:\ourPerl';
use AdcircUtils::AdcGrid;
use Geometry::PolyTools;


########################################################################
# config

my $gridfile='fort.14';
my $searchPoly='searchPoly.kml';
my $outGrid='cropped-fort.14';

# end config
######################################################################


# load the grid
my $adcGrid = AdcGrid->new($gridfile);


# read the polygon
my ($pxref,$pyref)=PolyTools::readKmlPoly($searchPoly);


# crop the grid
my ($ne,$np,@foundNodes)=$adcGrid->cropGrid($pxref,$pyref,$outGrid);

