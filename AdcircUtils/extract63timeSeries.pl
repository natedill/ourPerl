#!/usr/bin/env perl
#
#  a script to extract time series from a fort.63 style adcirc file
#
#
use strict;
use warnings;

use lib 'c:\ourPerl'; # this is the directory where you store the AdcircUtils perl packages
use AdcircUtils::AdcGrid;
use AdcircUtils::ElementQuadTree;


##########################################################
# configure the script
#
my $gridFile='fort.14';
my $fullDomainOutput='fort.63';
my $stationsFile='C:\0_PROJECTS\171.06055-Wells-FEMA\Modeling\Validation\ET_TimeSeries\elev_stat.151';
my $outputCSVfile='stationsOutput.csv';
my $fort61out="fort-63-.61";

## end configuration




# enter a list of stations
# each element in the @Stations list is
# an array reference that points to 
# an array containing the longitude and latitude of the station 
#my @Stations= ([-68.773769,  44.785305],
#              [-69.097893,  44.104457],
#               [-68.204332,  44.393686]
#              );
my @Stations=();

open IN, "<$stationsFile";
my $line=<IN>;
chomp $line;
$line =~ s/^\s+//;
my ($nstae)=split(/\s+/,$line);
foreach my $n (1..$nstae){
   my $line=<IN>;
   chomp $line;
   $line =~ s/^\s+//;
   my ($x,$y)=split(/\s+/,$line);
   push @Stations,[$x, $y];
print "xy is $x, $y\n";
}
close (IN);



# get to work


# create the AdcGrid object and load the grid
my $adcGrid=AdcGrid->new($gridFile);

# get the number of elements in the grid to estimate how elements we wan to use for maxelems in the quadtree
my $ne=$adcGrid->getVar('NE');
my $np=$adcGrid->getVar('NP');
my $maxelems=$ne/40;            # using a smaller value for $maxelems will take longer to build the tree, but will interpolate more quickly

# create a ElementQuadTree object from the grid
my $tree = ElementQuadTree->new_from_adcGrid(   -MAXELEMS => $maxelems,  # maximum number of elements per tree node
                                                -ADCGRID=>$adcGrid       # and adcGrid objecvt
#
#                                               -NORTH=>$north,          # the region for the tree, to only look at a portion of the grid (optional)
#                                               -SOUTH=>$south,
#                                               -EAST =>$east,
#                                               -WEST =>$west,
                                            );
print "done building ElementQuadTree\n";

# loop through the stations and get the intepolant
my @Interpolants=();
my @X=();
my @Y=();
foreach my $station (@Stations){
   my ($x,$y)=@{$station};  # dereference the station coordinates array reference 
   push @X,$x;
   push @Y,$y;   

   my $interp=$tree->getInterpolant( -XX => $x,
                                     -YY => $y  
                                   );
    
   push @Interpolants, $interp;
}



#  write the station locations to the output file
open OUT, ">$outputCSVfile"  or die "cant open $outputCSVfile\n";
$line=join (',',('Longitude',@X));
print OUT "$line\n";
$line=join (',',('Latitude',@Y));
print OUT "$line\n";

open OUT61, ">$fort61out";



# now open the fort.63 and read through it and write out the time series
open F63, "<$fullDomainOutput" or die "cant open $fullDomainOutput\n";

# skip the first line
$line=<F63>;
chomp $line;
print OUT61 "$line\n"; 
# read the number of nodes from the second line
$line=<F63>;
$line =~ s/^\s+//;              # remove leading white space
my @data=split(/\s+/,$line);    # split on white space
my $np_ = $data[1];             # the number of nodes should be the 2nd element in the @data list

# make 2nd line for fort.61 (change np to nstae)
$data[1]=$nstae;
$line=join(" ",@data);
print OUT61 "$line\n";

#check if the grid and fort.63 match 
die "grid number of nodes $np does not match fulldomain output number of nodes $np_\n" unless ($np == $np_);

# now get on with it


while (<F63>){
    chomp;
    print OUT61 "$_\n";
    $_ =~ s/^\s+//;              # remove leading white space
    $_ =~ s/\s+$//;              # remove trailing white space
    
    # get the time
    my ($time, $it)=split (/\s+/,$_);
    my @FullDomainData=();
    print "interpolating timestep $it:  ";

    #read the full domain scalar data
    foreach my $nid (1..$np){
       my $line=<F63>;
       $line =~ s/^\s+//;              # remove leading white space
       $line =~ s/\s+$//;              # remove trailing white space
       my ($n,$wse)=split(/\s+/,$line);
       $FullDomainData[$n]=$wse;       # remember AdcGrid expects nothing at index 0
    }   
       
    # interpolate at the stations
    my @Wse_Station=();
    my $k=1;
    foreach my $interp (@Interpolants){
        my $wse= $tree->interpValue ( -ZDATA => \@FullDomainData,
                                      -INTERPOLANT => $interp );
        push @Wse_Station, $wse;
        print OUT61 "$k $wse\n";
        $k++;

    } 
    # write this time snap to the output file
    my $str=join(',',($time,@Wse_Station));
    print "$str\n";
    print OUT "$str\n";
}

close (F63);
close (OUT);
close (OUT61);




  







    







 






