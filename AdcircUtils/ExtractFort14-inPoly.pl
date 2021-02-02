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



my ($line1,$line2,$line3);


# load the grid
my $adcGrid = AdcGrid->new($gridfile);
my $pnp=$adcGrid->getVar('NP');


# read the polygon
my ($pxref,$pyref)=PolyTools::readKmlPoly($searchPoly);


# crop the grid
my ($ne,$np,@foundNodes)=$adcGrid->cropGrid($pxref,$pyref,$outGrid);

