#!/usr/bin/perl
#######################################################################
#
# a Perl script to make a fort.13 (nodal attribute) file for ADCIRC
#
#----------------------------------------------------------------------
# Borrows concepts and data from numerous Fortran utility programs
# that have been provided over the years by other ADCIRC users found
# here: http://adcirc.org/home/related-software/adcirc-utility-programs/
# Additional references are given in the comments down below.
#
# There is a somewhat lengthy configuration section in this script
# where you must specify a bunch of parameters and input files. see
# below.
#
# This script depends on the following modules which you can get from
# github: https://github.com/natedill/myPerl
#
# Mapping::MyMapping;
# AdcircUtils::AdcGrid;
# Geometry::PolyTools;
#
# It will generate a fort.13 with the following nodal attributes:
#
# mannings_n_at_sea_floor - derived from land cover, and with optional
#                           defaults set by user defined kml polygons
#
# surface_canopy_coefficient - derived from land cover
#
# surface_directional_effective_roughness_length - derived from land cover
#
# surface_submergence_state - aka "startDry", set based on user
#                                    provided kml polygon files 
#
# average_horizontal_eddy_viscosity_in_sea_water_wrt_depth -
#                                set based on element size and depth 
#
# primitive_weighting_in_continuity_equation - for typical Tau0=-3
#                       configuration, based on element size and depth
#
# elemental_slope_limiter - sets user specified default only
#
#
# sea_surface_height_above_geoid - sets user specified default only
#
#
#  !------------------------------------------------------------------!
#  !!!!!!!!!!!!!!!!!!!!!!!!!!! LOOK HERE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  !------------------------------------------------------------------!
#  THE NODAL ATTRIBUTE FILE FOR ADCIRC IS VERY MODEL SPECIFIC.  IT WILL
#  MOST LIKELY TAKE A CONSIDERABLE AMOUNT OF EFFORT TO GATHER ALL THE
#  NECESSARY DATA AND CONFIGURE THIS SCRIPT TO GET IT TO FUNCTION
#  PROPERLY AND GENERATE A NODAL ATTRIBUTE (FORT.13) FILE. EVEN IF YOU
#  GET A CORRECTLY FORMATTED FORT.13, THE MANY ASSUMPTIONS MADE IN THE 
#  CONFIGURATION AND GENERATION OF THE FORT.13 BY THIS SCRIPT MAY 
#  LEAD TO ERRONEOUS MODEL RESULTS OR AN UNSTABLE MODEL THAT WILL NOT
#  RUN. PLEASE KNOW WHAT YOUR ARE DOING AND DON'T ASSUME THAT ANY OF
#  THE DEFAULT CONFIGURATION OPTIONS IN THIS SCRIPT ARE APPROPRIATE,
#  OR WILL EVEN WORK FOR YOUR ADCIRC MODEL.

####################################################################### 
# Author: Nathan Dill, natedill(AT)gmail.com
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
use lib 'C:\ourPerl'; # this may be different for you

use Mapping::MyMapping;
use AdcircUtils::AdcGrid;
use Geometry::PolyTools;

#----------------------------------------------------------------------#
# switches to select which nodal attributes you want in your fort.13
# set to 1 (true) if you want them, zero (false) otherwise

my $mannings_n_at_sea_floor = 1; 
my $surface_canopy_coefficient = 0;
my $surface_directional_effective_roughness_length = 0; 
my $surface_submergence_state = 0; 
my $average_horizontal_eddy_viscosity_in_sea_water_wrt_depth  = 0;
my $primitive_weighting_in_continuity_equation = 1;
my $elemental_slope_limiter = 1;
my $sea_surface_height_above_geoid = 0;
my $advection_state = 1;

#######################################################################
#
#  some configuration - You will have to make some changes here!
#
#######################################################################
# - begin soft settings

# ---------------  grid and nodal attribute file----------------------#

my $gridFile="PenBay_v8.14";  # ADCIRC grid file - this is input
my $fort13="PenBay_v8.13";    # nodal attribute file name - this is output


# ---------------------land cover data files -------------------------#
#
# land cover data are used to specify non-default Manning's n values,
# vCanopy (where wind is zeroed out), and surface directional wind
# roughness  
#
# can be in GridFloat format including a .flt file and a .hdr file
# Alternatively, data can be provided in a geoTiff (new feature)
#
# currently the projetion data is hard-coded for albers equal area
# conic projection GRS 80 spheroid, WGS 84 datum
#
# land cover data typically come from CCAP or NLCD in the Erdas img format.
# I use ESRI's ArcMAP to convert to GridFloat. 
# I'm sure there are other tools that would work as well.
#
# ccap data can be found here:  https://coast.noaa.gov/ccapftp/#/
#
# nlcd data an be found here:  http://www.mrlc.gov/
#
#
# seems like these data now come in ERDAS img format, which can
# be easily converted to geoTiff using gdal_translate http://www.gdal.org/gdal_translate.html
#
# see "semi-soft" settings below to set specific roughness by land cover class 

my $dataSource = 'ccap';   # uncomment if using ccap data
#my $dataSource = 'nlcd';  # uncomment if using nlcd data

my $flt_or_tif='tif';    # uncomment if geoTiff
#my $flt_or_tif='flt';   # uncomment if gridFloat

# needs to be defined but not used if using gridFloat format
my $tifFile='C:\0_PROJECTS\151.06112-Islesboro\modeling\NodalAttributes\me_2010_ccap_land_cover.tif';

# these need to be defined, but not used if using a geoTiff
my $hdrFile=''; # grid float header file
my $fltFile=''; # grid float flt file contains binary land cover data  
my $prjFile=''; # not used at this point 




# --------------- Default Manning's ----------------------------------#
my $ManningDefault=0.02;  # the ultimate default value


# ------------ Depth based Manning's in specific polygons ------------#
# The following hashes allow you to specify Manning's n by depth in 
# specific areas. hash keys in ManningsByDepthPolygons are names of kml 
# files that contain a kml polygon, hash values are references to 
# another hash that gives the parameters for determining the 
# Manning's n based on the depth, and whether or not this value takes
# precedence over the land cover based value
#
# if you have no special polygons for specifying Manning's n just use an 
# empty hash on the following line and comment out the rest of the lines
# in this section
my %ManningsByDepthPolygons; 
# 
# If you want to use polygon based Manning's by depth continue reading.
# 
# The Manning's n by depth hashes use a simple bin based approach
# where you specify the bin as a hash key (e.g. ['99999.99:0' => 0.02] 
# would apply a Manning's n of 0.02 to nodes with depths >= 0 and < 99999.99 ) 
# you also specify ['precedence' => 1] to indicate this takes precedence
# over land cover based values or ['precedence' => 0] if land 
# cover values take precedence  
# 
# the ultimate ManningDefault will be applied to any value not in a bin
#
# depth is the DP value in the fort.14, not the dynamic depth during a model run
#
#  create some polygon "bin" hashes for the different polygons

my %BinsForArea1=('9999999999:-999999999'  => 0.095959595,     # use constant for all values
                   'precedence' => 1                 );  # do take presedence over land cover

my %BinsForArea1_=('9999999999:-999999999'  => 0.05,     # use constant for all values
                   'precedence' => 1                 );  # do take presedence over land cover

my %BinsForArea2=('9999999999:200'  => 0.01,  # applies 0.01 to depth >= 200 meters 
                  '200:50'          => 0.013,    # applies 0.013 to depth >= 50 and < 200 meters
                  '50:-3'         => 0.018,    # applies 0.18 to depth >= -3 meters < 50 
                  '-3:-999999999' => 0.106,    # applies 0.106 to dapth < -3
                  'precedence'    => 0      );  # dont take presedence over land cover




#%ManningsByDepthPolygons= ( );
%ManningsByDepthPolygons= ( 'mannings_area1.kml' => \%BinsForArea1,
                            'mannings_area2.kml' => \%BinsForArea1_  );


# ------------------surface directional roughness length----------------#
#
# These parameters control how far up wind to "look" to consider
# the land cover in the directional roughness reduction for each node,
# and shape of the radial gaussian weighting function applied
# http://www.unc.edu/ims/adcirc/utility_programs/surf_rough.in suggests
# values of 10,000 and 3,000 meters for sectorRadius and sigma, respectively.
# Does anybody know where these numbers came from? any justificaiton for them?
#
# the weighting factor gets computed as exp(-$r**2.0/(2.0*$sigma**2.0))
#
# Other than the suggested values above, I'm not really aware of any good
# guidance for selecting these numbers, at some point beyond the sigma distance 
# the weight gets pretty small, so it may not make sense to have a sectorRadius
# that is more than a factor of 2 or 3 greater than sigma. larger sectorRadius
# values will require larger run times. SkipCells > 1 will downsample the raster
# and speed up the run time for large sectorRadius. 
# 
my $sectorRadius=5000;  # how far out to look in each direction (in meters) 
my $sigma=2000;  # controls gaussian radial distance based weights  

# note: this script can be a huge memory hog and run very slowly if you use a 
#    large sector radius.  The parameters below can help reduce the memory
#    footprint and speed things up if you are in a hurry. 
#
#    skipCells - controls downsampling of the land cover data
#               ideally set to 1, but increase to speed things up.
#
#    halfSectorAngle - sets the width of directional sectors data are drawn from.
#               ideally this would be 15 for a 30 degree sector, but decreasing
#               to narrower value can speed things up.
#
#    the script outputs a file called KernelSectors.txt, which shows contains
#    a simpls ASCII representation of the directional sectors and pixels
#    that data are drawn from. 
#
my $skipCells=2; # skipCells=1 use all pixels, 2 use every other pixel, 3-every third...
my $halfSectorAngle=15; # a value less than 15 will narrow the search sectors




#--------------------- surface_submergence_state -----------------------#
# 
# you can provide a list of kml polygon files that each contain one
# polygon within which all nodes will be specified to startDry 

my @StartDry_kmlPolygons=();
#my @StartDry_kmlPolygons=('startdry_area1.kml'
#                          ,'startdry_area2.kml'
                         #,'startdry_area3.kml'
#                          );


#--------------------- advection_state -----------------------#
# 
# you can provide a list of kml polygon files that each contain one
# polygon within which all nodes will be specified to turn NOLICA/NOLICAT off 

my @AdvectionState_kmlPolygons=('Advection_off.kml');
#my @AdvectionState_kmlPolygons=('advectionoff_area1.kml'
#                          ,'advectionoff_area2.kml'
                         #,'advectionoff_area3.kml'
#                          );

#------- average_horizontal_eddy_viscosity_in_sea_water_wrt_depth ------#
#
# sets ESLM nodal attribute to the non-default value for a node if the
# average distance to neighbors is less than $maxEleSize_ESLM or 
# the depth at the node is greater than $minDepth_ESLM
#
my $default_ESLM = 40.0;  # the default value
my $small_ESLM= 4.0;      # non-default value
my $maxEleSize_ESLM=60;   # smaller elements get non-default
my $minDepth_ESLM = 3.0;  # deeper elements get non-default


#---------------------- elemental_slope_limiter -------------------------#
my $ESL_default=-0.23;


#------------------------sea_surface_height_above_geoid------------------#
my $geoidOffset=0.0;


#---------------------- VCANOPY wind cutoff depth------------------------#
my $windCutoffDepth=-1; # VCANOPY set to zero for DP < $windCutoffDepth
                        # The idea it to prevent wind from blowing around
                        # thin layers of water and causing instabilities.                         

#------------------------------------------------------------------------#
# semi-soft settings 
# 
# this is where the roughness values are set based on land cover class
#
# ----------------- set roughness values, etc. --------------------------#
#
# the values provide below seem to be pretty standard
# based on the success of a number of FEMA studies
# and large scale ADCIRC storm surge modeling efforts
# 
# note: You can undef a value (or comment it out) to have it apply defaults
#       or not take precedence over a polygon set value. e.g. if you 
#       are using ccap and want to use depth based mannings for an area
#       of open water set $MANNING[21]=undef and apply the polygon or
#       ultimate default value you want.
# 
#
# copied nlcd values from mannings_n_finder_v10.f
# http://www.unc.edu/ims/adcirc/utility_programs/mannings_n_finder_v10.f
#
# ccap values from
# https://www.earthsystemcog.org/site_media/projects/umac_model_advisory/HSSOFS_Development_Evaluation_20150410.pdf
#
my @MANNING;
my @Z0;
my @VCANOPY;



if ($dataSource eq 'nlcd'){                  # values for nlcd data
                         #       type, manning, z0, Vcannopy
$MANNING[11]  = 0.020;    #  11 Open Water 0.02 0.001 1                              
$MANNING[12]  = 0.010;    #  12 Perennial Snow/Ice 0.01 0.012 1                      
$MANNING[21]  = 0.020;    #  21 Developed, Open Space 0.02 0.1 1                     
$MANNING[22]  = 0.050;    #  22 Developed, Low Intensity 0.05 0.3 1                  
$MANNING[23]  = 0.100;    #  23 Developed, Medium Intensity 0.1 0.4 1                
$MANNING[24]  = 0.150;    #  24 Developed, High Intensity 0.15 0.55 1                
$MANNING[31]  = 0.090;    #  31 Barren Land 0.09 0.04 1                              
$MANNING[32]  = 0.040;    #  32 Unconsolidated Shore 0.04 0.09 1                     
$MANNING[41]  = 0.100;    #  41 Deciduous Forest 0.1 0.65 0                          
$MANNING[42]  = 0.110;    #  42 Evergreen Forest 0.11 0.72 0                         
$MANNING[43]  = 0.100;    #  43 Mixed Forest 0.1 0.71 0                              
$MANNING[51]  = 0.040;    #  51 Dwarf Scrub 0.04 0.1 1                               
$MANNING[52]  = 0.050;    #  52 Shrub/Scrub 0.05 0.12 1                              
$MANNING[71]  = 0.034;    #  71 Herbaceous 0.034 0.04 1                              
$MANNING[72]  = 0.030;    #  72 Sedge/Herbaceous 0.03 0.03 1                         
$MANNING[73]  = 0.027;    #  73 Lichens 0.027 0.025 1                                
$MANNING[74]  = 0.025;    #  74 Moss 0.025 0.02 1                                    
$MANNING[81]  = 0.033;    #  81 Hay/Pasture 0.033 0.06 1                             
$MANNING[82]  = 0.037;    #  82 Cultivated Crops 0.037 0.06 1                        
$MANNING[90]  = 0.100;    #  90 Woody Wetlands 0.1 0.55 0                            
$MANNING[91]  = 0.100;    #  91 Palustrine Forested Wetland 0.1 0.55 0               
$MANNING[92]  = 0.048;    #  92 Palustrine Scrub/Shrub Wetland 0.048 0.12 0          
$MANNING[93]  = 0.100;    #  93 Estuarine Forested Wetland 0.1 0.55 0                
$MANNING[94]  = 0.048;    #  94 Estuarine Scrub/Shrub Wetland 0.048 0.12 1           
$MANNING[95]  = 0.045;    #  95 Emergent Herbaceous Wetlands 0.045 0.11 1            
$MANNING[96]  = 0.045;    #  96 Palustrine Emergent Wetland (Persistent) 0.045 0.11 1
$MANNING[97]  = 0.045;    #  97 Estuarine Emergent Wetland 0.045 0.11 1              
$MANNING[98]  = 0.015;    #  98 Palustrine Aquatic Bed 0.015 0.03 1                  
$MANNING[99]  = 0.015;    #  99 Estuarine Aquatic Bed 0.015 0.03 1                   
$MANNING[127] = 0.020;           # Missing - usually water boundaries  

$Z0[11]  = 0.001;    #  11 Open Water                                                          
$Z0[12]  = 0.012;    #  12 Perennial Snow/Ice                                           
$Z0[21]  = 0.100;    #  21 Developed, Open Space                                       
$Z0[22]  = 0.300;    #  22 Developed, Low Intensity                                 
$Z0[23]  = 0.400;    #  23 Developed, Medium Intensity                            
$Z0[24]  = 0.550;    #  24 Developed, High Intensity                              
$Z0[31]  = 0.040;    #  31 Barren Land                                                          
$Z0[32]  = 0.090;    #  32 Unconsolidated Shore                                        
$Z0[41]  = 0.650;    #  41 Deciduous Forest                                                 
$Z0[42]  = 0.720;    #  42 Evergreen Forest                                                
$Z0[43]  = 0.710;    #  43 Mixed Forest                                                         
$Z0[51]  = 0.100;    #  51 Dwarf Scrub                                                           
$Z0[52]  = 0.120;    #  52 Shrub/Scrub                                                          
$Z0[71]  = 0.040;    #  71 Herbaceous                                                           
$Z0[72]  = 0.030;    #  72 Sedge/Herbaceous                                                
$Z0[73]  = 0.025;    #  73 Lichens                                                                
$Z0[74]  = 0.020;    #  74 Moss                                                                       
$Z0[81]  = 0.060;    #  81 Hay/Pasture                                                         
$Z0[82]  = 0.060;    #  82 Cultivated Crops                                               
$Z0[90]  = 0.550;    #  90 Woody Wetlands                                                     
$Z0[91]  = 0.550;    #  91 Palustrine Forested Wetland                           
$Z0[92]  = 0.120;    #  92 Palustrine Scrub/Shrub Wetland                   
$Z0[93]  = 0.550;    #  93 Estuarine Forested Wetland                             
$Z0[94]  = 0.120;    #  94 Estuarine Scrub/Shrub Wetland                     
$Z0[95]  = 0.110;    #  95 Emergent Herbaceous Wetlands                       
$Z0[96]  = 0.110;    #  96 Palustrine Emergent Wetland (Persistent) 
$Z0[97]  = 0.110;    #  97 Estuarine Emergent Wetland                           
$Z0[98]  = 0.030;    #  98 Palustrine Aquatic Bed                                   
$Z0[99]  = 0.030;    #  99 Estuarine Aquatic Bed                                     
$Z0[127] = 0.030;           # Missing - usually water boundaries    

$VCANOPY[11]  = 1;    #  11 Open Water                                                           
$VCANOPY[12]  = 1;    #  12 Perennial Snow/Ice                                           
$VCANOPY[21]  = 1;    #  21 Developed, Open Space                                       
$VCANOPY[22]  = 1;    #  22 Developed, Low Intensity                                 
$VCANOPY[23]  = 1;    #  23 Developed, Medium Intensity                            
$VCANOPY[24]  = 1;    #  24 Developed, High Intensity                              
$VCANOPY[31]  = 1;    #  31 Barren Land                                                          
$VCANOPY[32]  = 1;    #  32 Unconsolidated Shore                                        
$VCANOPY[41]  = 0;    #  41 Deciduous Forest                                                 
$VCANOPY[42]  = 0;    #  42 Evergreen Forest                                                
$VCANOPY[43]  = 0;    #  43 Mixed Forest                                                         
$VCANOPY[51]  = 1;    #  51 Dwarf Scrub                                                           
$VCANOPY[52]  = 1;    #  52 Shrub/Scrub                                                          
$VCANOPY[71]  = 1;    #  71 Herbaceous                                                           
$VCANOPY[72]  = 1;    #  72 Sedge/Herbaceous                                                
$VCANOPY[73]  = 1;    #  73 Lichens                                                                
$VCANOPY[74]  = 1;    #  74 Moss                                                                       
$VCANOPY[81]  = 1;    #  81 Hay/Pasture                                                         
$VCANOPY[82]  = 1;    #  82 Cultivated Crops                                               
$VCANOPY[90]  = 0;    #  90 Woody Wetlands                                                     
$VCANOPY[91]  = 0;    #  91 Palustrine Forested Wetland                           
$VCANOPY[92]  = 0;    #  92 Palustrine Scrub/Shrub Wetland                   
$VCANOPY[93]  = 0;    #  93 Estuarine Forested Wetland                             
$VCANOPY[94]  = 1;    #  94 Estuarine Scrub/Shrub Wetland                     
$VCANOPY[95]  = 1;    #  95 Emergent Herbaceous Wetlands                       
$VCANOPY[96]  = 1;    #  96 Palustrine Emergent Wetland (Persistent)
$VCANOPY[97]  = 1;    #  97 Estuarine Emergent Wetland                           
$VCANOPY[98]  = 1;    #  98 Palustrine Aquatic Bed                                   
$VCANOPY[99]  = 1;    #  99 Estuarine Aquatic Bed                                     
$VCANOPY[127] = 1;           # Missing - usually water boundaries   


}

if ($dataSource eq 'ccap'){ # https://www.earthsystemcog.org/site_media/projects/umac_model_advisory/HSSOFS_Development_Evaluation_20150410.pdf
                              # type, manning, z0, Vcannopy
$MANNING[2] = 0.120;   # High Intensity Developed        0.120 0.300 1
$MANNING[3] = 0.120;   # Medium Intensity Developed      0.120 0.300 1
$MANNING[4] = 0.070;   # Low Intensity Developed         0.070 0.300 1
$MANNING[5] = 0.035;   # Developed Open Space            0.035 0.300 1
$MANNING[6] = 0.100;   # Cultivated Land                 0.100 0.060 1
$MANNING[7] = 0.055;   # Pasture/Hay                     0.055 0.060 1
$MANNING[8] = 0.035;   # Grassland                       0.035 0.040 1
$MANNING[9] = 0.160;   # Deciduous Forest                0.160 0.650 0
$MANNING[10]= 0.180;   # Evergreen Forest                0.180 0.720 0
$MANNING[11]= 0.170;   # Mixed Forest                    0.170 0.710 0
$MANNING[12]= 0.080;   # Scrub/Shrub                     0.080 0.120 1
$MANNING[13]= 0.200;   # Palustrine Forested Wetland     0.200 0.600 0
$MANNING[14]= 0.075;   # Palustrine Scrub/Shrub Wetlands 0.075 0.110 1
$MANNING[15]= 0.070;   # Palustrine Emergent Wetland     0.070 0.300 1
$MANNING[16]= 0.150;   # Estuarine Forested Wetland      0.150 0.550 0
$MANNING[17]= 0.070;   # Estuarine Scrub/Shrub Wetland   0.070 0.120 1
$MANNING[18]= 0.050;   # Estuarine Emergent Wetland      0.050 0.300 1
$MANNING[19]= 0.030;   # Unconsolidated Shore            0.030 0.090 1
$MANNING[20]= 0.030;   # Bare Land                       0.030 0.050 1
$MANNING[21]= 0.025;   # Open Water                      0.020 0.001 1
$MANNING[22]= 0.035;   # Palustrine Aquatic Bed          0.035 0.040 1
$MANNING[23]= 0.030;   # Estuarine Aquatic Bed           0.030 0.040 1

$Z0[2] = 0.300;   # High Intensity Developed   0.120 0.300 1
$Z0[3] = 0.300;   # Medium Intensity Developed 0.120 0.300 1
$Z0[4] = 0.300;   # Low Intensity Developed 0.070 0.300 1
$Z0[5] = 0.300;   # Developed Open Space 0.035 0.300 1
$Z0[6] = 0.060;   # Cultivated Land 0.100 0.060 1
$Z0[7] = 0.060;   # Pasture/Hay 0.055 0.060 1
$Z0[8] = 0.040;   # Grassland 0.035 0.040 1
$Z0[9] = 0.650;   # Deciduous Forest 0.160 0.650 0
$Z0[10]= 0.720;   # Evergreen Forest 0.180 0.720 0
$Z0[11]= 0.710;   # Mixed Forest 0.170 0.710 0
$Z0[12]= 0.120;   # Scrub/Shrub 0.080 0.120 1
$Z0[13]= 0.600;   # Palustrine Forested Wetland 0.200 0.600 0
$Z0[14]= 0.110;   # Palustrine Scrub/Shrub Wetlands 0.075 0.110 1
$Z0[15]= 0.300;   # Palustrine Emergent Wetland 0.070 0.300 1
$Z0[16]= 0.550;   # Estuarine Forested Wetland 0.150 0.550 0
$Z0[17]= 0.120;   # Estuarine Scrub/Shrub Wetland 0.070 0.120 1
$Z0[18]= 0.300;   # Estuarine Emergent Wetland 0.050 0.300 1
$Z0[19]= 0.090;   # Unconsolidated Shore 0.030 0.090 1
$Z0[20]= 0.050;   # Bare Land 0.030 0.050 1
$Z0[21]= 0.001;   # Open Water 0.020 0.001 1
$Z0[22]= 0.040;   # Palustrine Aquatic Bed 0.035 0.040 1
$Z0[23]= 0.040;   # Estuarine Aquatic Bed 0.030 0.040 1

$VCANOPY[2] = 1;   # High Intensity Developed   0.120 0.300 1
$VCANOPY[3] = 1;   # Medium Intensity Developed 0.120 0.300 1
$VCANOPY[4] = 1;   # Low Intensity Developed 0.070 0.300 1
$VCANOPY[5] = 1;   # Developed Open Space 0.035 0.300 1
$VCANOPY[6] = 1;   # Cultivated Land 0.100 0.060 1
$VCANOPY[7] = 1;   # Pasture/Hay 0.055 0.060 1
$VCANOPY[8] = 1;   # Grassland 0.035 0.040 1
$VCANOPY[9] = 0;   # Deciduous Forest 0.160 0.650 0
$VCANOPY[10]= 0;   # Evergreen Forest 0.180 0.720 0
$VCANOPY[11]= 0;   # Mixed Forest 0.170 0.710 0
$VCANOPY[12]= 1;   # Scrub/Shrub 0.080 0.120 1
$VCANOPY[13]= 0;   # Palustrine Forested Wetland 0.200 0.600 0
$VCANOPY[14]= 1;   # Palustrine Scrub/Shrub Wetlands 0.075 0.110 1
$VCANOPY[15]= 1;   # Palustrine Emergent Wetland 0.070 0.300 1
$VCANOPY[16]= 0;   # Estuarine Forested Wetland 0.150 0.550 0
$VCANOPY[17]= 1;   # Estuarine Scrub/Shrub Wetland 0.070 0.120 1
$VCANOPY[18]= 1;   # Estuarine Emergent Wetland 0.050 0.300 1
$VCANOPY[19]= 1;   # Unconsolidated Shore 0.030 0.090 1
$VCANOPY[20]= 1;   # Bare Land 0.030 0.050 1
$VCANOPY[21]= 1;   # Open Water 0.020 0.001 1
$VCANOPY[22]= 1;   # Palustrine Aquatic Bed 0.035 0.040 1
$VCANOPY[23]= 1;   # Estuarine Aquatic Bed 0.030 0.040 1


}




#---------------------------------------------------------------------
# --- end soft settings 
#  hopefully you won't have to do much below, it gets ugly down there
######################################################################





##########################################
# semi-hard settings for the projection
#
# as far as I know both ccap and nlcd
# use Albers equal area conic GRS 80 
#
#
my $pi=2.*atan2(1.0,0);
my $deg2rad=$pi/180.0;
 # hard-coded projection data from prj file
my $phi0 =    23 * $deg2rad;    # origin latitude   
my $lamda0 = -96 * $deg2rad;    # central meridian
my $phi1 =    29.5 * $deg2rad;  # 1st standard parallel
my $phi2 =    45.5 * $deg2rad;  # 2nd standard parallel
#  These are for the GRS80 spheroid
my $a=6378137.000000; # semi-major axis in meters
my $denflat=298.2572221; # denominator of flattening
my $f=1.0/$denflat;

######################################################
# create new mapping object
# set the ellipsoid and projection
my $map=myMapping->new;
$map->setEllipsoid(-A=>$a,-F=>$f);

$map->setAlbers(-PHI0=>$phi0,
	           -LAM0=>$lamda0,
		   -PHI1=>$phi1,
		   -PHI2=>$phi2);




#########################################################
# Read Land Cover data 
# read header

my ($ncols,$nrows,$dx,$xll,$yll,$yul,$xur,$cellSize,$binstring);

if ($mannings_n_at_sea_floor or 
    $surface_canopy_coefficient or 
    $surface_directional_effective_roughness_length){ # we need to read land cover data

   if ($flt_or_tif eq 'flt'){ # gridFloat format
      ($ncols,$nrows,$dx,$xll,$yll,$yul,$xur,$cellSize,$binstring)=&readGridFloat($hdrFile,$fltFile);

   }elsif ($flt_or_tif eq 'tif'){  # reading geotiff
       ($ncols,$nrows,$dx,$xll,$yll,$yul,$xur,$cellSize,$binstring)=&readGeoTiff($tifFile);
   }
print "Done reading land cover data\n";

}# end if we need to read land cover data
###################################################################

###################################################
#
# load the ADCIRC grid
#
my $adcGrid=AdcGrid->new();
$adcGrid->loadGrid($gridFile);
my $np=$adcGrid->getVar('NP');
print "NP $np \n";
my @NIDS=(0..$np);

my ($xr,$yr,$zr)=$adcGrid->getNode(\@NIDS);
my @X=@{$xr};
my @Y=@{$yr};
my @Z=@{$zr};


#######################################################
# set the Manning's n value
#
# and the Vcanopy
# 
if ($mannings_n_at_sea_floor){ 

# get the inshore manning poly
my @PXM;
my @PYM;
my @BIN_DATA;
my @KMLNAMES;
foreach my $kmlFile (keys (%ManningsByDepthPolygons)){
   print "getting Manning's n polygon from $kmlFile\n";
   my ($pxm,$pym)=PolyTools::readKmlPoly($kmlFile);
   push @PXM, $pxm;
   push @PYM, $pym;
   push @BIN_DATA, $ManningsByDepthPolygons{$kmlFile};
   push @KMLNAMES, $kmlFile;
}


my @VC=();
my @VC_NDF=();
my @OutLines;
my @NotDefault;

foreach my $nid  (1..$np) {
   my ($lam,$phi,$z)=$adcGrid->getNode($nid);
   my $man=0;
   my $poly_precedence=0;

   my $k=0;
   foreach my $pxm (@PXM){
       my $pym = $PYM[$k];
       my $inpoly=PolyTools::pointInPoly($lam,$phi,$pxm,$pym);
       unless ($inpoly) {$k++; next;} ;  # not in this polygon, go to the next one
       my $binref=$BIN_DATA[$k];
       my %bins=%{$binref};
       foreach my $bin (keys %bins){
           if ($bin eq 'precedence'){
               next;
           }
           my ($z1,$z2)=split(/\:/,$bin);
           my $nVal=$bins{$bin};
           if ( ($z<$z1) and ($z>=$z2) ){
                $man=$nVal; 
                $poly_precedence=$bins{'precedence'};
                last; # go with the first matching bin encountered
           }
       }
       $k++;
       last unless ($man == 0); # go with the first poly that sets to something other than zero
   }
        
   if ($man and $poly_precedence){   # we're setting it based on depth criteria and in polygon, no need to go further
      $OutLines[$nid]="$nid";
      $OutLines[$nid]=sprintf ("%s %7.4f",$OutLines[$nid],$man);
      push (@NotDefault,$nid);
      next; #$nid
   }

   my $man_from_poly=$man;

   $lam=$lam*$deg2rad;
   $phi=$phi*$deg2rad;
   my ($x, $y)=$map->albersForward (-PHI=>$phi, -LAM=>$lam);
   
   # skip this one if its outside the area
   if ( ($x > $xur-$cellSize) or
        ($x < $xll+$cellSize) or 
        ($y > $yul-$cellSize) or 
        ($y < $yll+$cellSize) ){
      if ($man_from_poly){
          $man = $man_from_poly;
      }else{
          $man = $ManningDefault;
      }
      $OutLines[$nid]="$nid";
      $OutLines[$nid]=sprintf ("%s %7.4f",$OutLines[$nid],$man);
      push (@NotDefault,$nid);
      next;
   }
   
   # get the index values
   my $i0 = int (($x-$xll)/$dx);
   my $j0 = int (($yul-$y)/$dx);
   my $z_tot=0;
   my $w_tot=0;
   my $vc=1;  # the vcanopy value
   # get an average value
   foreach my $ii (-1,0,1){             # 9 cell average
      foreach my $jj (-1,0,1){
	   my $w=1;
	   $w=5 if ($ii==0 and $jj==0);
           my $position=$ncols*$j0+$jj + $i0+$ii;
           my $class=unpack('C',substr($binstring,$position,1));  # using 8-bit unsigned char now
           my $z0=$MANNING[$class];
           next unless (defined $z0);
           $z_tot=$z0*$w+$z_tot;
	   $w_tot=$w_tot+$w;
           if ($ii == 0 and $jj == 0){
              $vc=$VCANOPY[$class] if (defined($VCANOPY[$class]));
           }
      }
   }
   if ($w_tot ==0){
      $z_tot=$ManningDefault;
      $z_tot=$man_from_poly if ($man_from_poly);
      $w_tot =1;
   }

   my $zz=$z_tot/$w_tot;

   $vc=0 if ($z < $windCutoffDepth); 


   push @VC, 0 if ($vc==0);
   push @VC_NDF, $nid if ($vc==0);

   next if ($zz == $ManningDefault);

   $OutLines[$nid]="$nid";
   $OutLines[$nid]=sprintf ("%s %7.4f",$OutLines[$nid],$zz);
   push (@NotDefault,$nid);

}


# add Mannings to the grid object
print "setting Manning's N values\n";
my @defVal=$ManningDefault;
$adcGrid->addNodalAttribute('mannings_n_at_sea_floor','na',1,\@defVal);

my @NNDF;
my @VALS;
foreach my $line (@OutLines){
  next unless (defined $line);
  my ($n,$val)=split(/\s+/,$line);
  push @NNDF, $n;
  push @VALS, $val;

}

$adcGrid->setNodalAttributeValue('mannings_n_at_sea_floor',1,\@NNDF,\@VALS);

# add vcanopy to the grid object
if ($surface_canopy_coefficient){
  print "setting Vcanopy\n";  
  @defVal=1.0;
  $adcGrid->addNodalAttribute('surface_canopy_coefficient','na',1,\@defVal);
  $adcGrid->setNodalAttributeValue('surface_canopy_coefficient',1,\@VC_NDF,\@VC);
} #end if surface canopy coef

} # end if $mannings_n_at_sea_floor


############################################################################
# surface directional roughness
#
#
######################################################################
if  ($surface_directional_effective_roughness_length){
# make a kernel.  
# i.e. sector based lists or i,j offsets from a central cell at 0,0
#
# set some data for the interpolation
my $sigma2_sq=2*$sigma*$sigma;

# note: this is the "from" wind direction. We are looking
# upwind for roughness elements.  The first sector is for
# westerly winds (winds blowing toward the east) following
# sectors follow anti-clociwise. angles are defined with
# trigonometric convention (e.g. 0 points east, 90 points north)
my @Azimuths=(-180,-150,-120,-90,-60,-30,0,30,60,90,120,150);

my %kernel;
$kernel{I}={};  # kernel is a hash of sector based lists of indices
$kernel{J}={};  # (0,0 indexed), that contain relative i,j offsets 
$kernel{R}={};  # to cells found within sectorRadius of a given cell

# figure out how far we have to go
my $maxS= int($sectorRadius/$cellSize);
print "\nBuilding interpolation kernel\n"; 
print "sectors will extend $maxS cells ($sectorRadius meters) from the center\n\n";

$maxS++;

my $i=-1*$maxS;
while ($i<=$maxS){
      my $j=$maxS;
      while($j>=(-1*$maxS)){
         my $r=$cellSize*($i**2.0+$j**2.0)**0.5;
         my $theta=atan2(-$j,$i);                         # $j is negative b/c positive direction is south
         # special treatment for the sector centered on -180
         $theta=$theta-2*$pi if ( $theta > ((180-$halfSectorAngle)*$deg2rad) ) ; 
	 # find which sector we're in
	 my $ia=0;
         foreach my $azimuth (@Azimuths) {
             my $lowerA=$deg2rad*($azimuth-$halfSectorAngle);
	     my $upperA=$deg2rad*($azimuth+$halfSectorAngle);
	     if ($theta > $lowerA) {
                 if ($theta <= $upperA) {
                     push (@{$kernel{I}->{$azimuth}}, $i) if $r<=$sectorRadius;
                     push (@{$kernel{J}->{$azimuth}}, $j) if $r<=$sectorRadius;
                     push (@{$kernel{R}->{$azimuth}}, $r) if $r<=$sectorRadius;
		     my $w = exp(-$r**2.0/($sigma2_sq));
                     push (@{$kernel{W}->{$azimuth}}, $w) if $r<=$sectorRadius;

                     last;
		 }
	     }    
             $ia++; 
         }

         $j=$j-$skipCells;
      }
      $i=$i+$skipCells;
}
print "done building kernel\n\n";
######################################################




# output kernel sectors in  text file 
# just as a check
#my @letters=qw(A B C D E F G H I J K L);
my @letters=qw(0 1 2 3 4 5 6 7 8 9 A B);
my $ib=0;
my @out=();    # intialize with blanks
$i=2*$maxS;
while ($i--){
   my $j=0;
   while($j<2*$maxS){
     $out[$i][$j]=" ";
     $j++;
   }
}
foreach my $letter (@letters) {
	my @Is=@{$kernel{I}->{$Azimuths[$ib]}};
	my @Js=@{$kernel{J}->{$Azimuths[$ib]}};
	my @Rs=@{$kernel{R}->{$Azimuths[$ib]}};
	my $ic=0;
	foreach my  $is (@Is) {
	       $out[$is+$maxS][$maxS-$Js[$ic]]=$letter;
               $ic++;
        }
$ib++;
}
open OUTF, ">kernelSectors.txt";
my $j=2*$maxS;
while ($j--){
   my $i=0;
   while($i<2*$maxS){
      print OUTF "$out[$i][$j]";
      print "$out[$i][$j]";
      $i++;
   }
   print OUTF "\n";
   print "\n";
}
close(OUTF);
print "done building kernel\n\n";
######################################################


#######################################################
# now read the grid and compute the surface directional 
# roughness length node by node

my @OutLines=();
my @NotDefault=();

foreach my $nid  (1..$np) {
   my ($lam,$phi,$z)=$adcGrid->getNode($nid);
   $lam=$lam*$deg2rad;
   $phi=$phi*$deg2rad;
   my ($x, $y)=$map->albersForward (-PHI=>$phi, -LAM=>$lam);
   print "computing directional z0 for node: $nid, \n"; 
   # skip this one if its outside the area
   if ( ($x > $xur-$sectorRadius) or
        ($x < $xll+$sectorRadius) or
        ($y > $yul-$sectorRadius) or
        ($y < $yll+$sectorRadius) ){
        if ($z > 0){
            next;
        }else{
            $OutLines[$nid]="$nid 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3"; # default for land outside dataset area
            next;
        }
   }

   $OutLines[$nid]="$nid";
   
   # get the index values
   my $i0 = int (($x-$xll)/$dx);
   my $j0 = int (($yul-$y)/$dx);
   foreach my $azimuth (@Azimuths){	
      my $w_tot=0;
      my $z_tot=0;

      my $ic=0;
      foreach my $iis (@{$kernel{I}->{$azimuth}}) {   # there's gotta be a way to speed this up 
         my $js=${$kernel{J}->{$azimuth}}[$ic]+ $j0;
	 my $is=$iis + $i0;
	 my $w=${$kernel{W}->{$azimuth}}[$ic];
         my $position=$ncols*$js + $is;
         my $class=unpack('C',substr($binstring,$position,1));
	 my $z0=$Z0[$class];
	 unless (defined $z0){   # we're in an area covered by the data set, witn no data
            $z0=0;   # don't include it in the average
            $w=0;          
            # if ($z >= 0){
            #    $z0 =0.0001;  # use 0.001 for upwind points with open water
            # }else{
            #    $z0 =0.3;    # assume everything above zero is marsh
            # }
         }     
	 $w_tot=$w_tot + $w;
	 $z_tot=$z_tot + $z0*$w;
         $ic++;
      }
      my $zz=0;
      $zz=$z_tot/$w_tot unless ($w_tot == 0);
      $OutLines[$nid]=sprintf ("%s %9.6f",$OutLines[$nid],$zz);
   }
   push (@NotDefault,$nid);
}

# add directional Z0 to the grid object
my @defVal=(0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.);
$adcGrid->addNodalAttribute('surface_directional_effective_roughness_length','meter',12,\@defVal);

foreach my $sector (1..12){
   my @VALS=();
   my @NNDF=();
   foreach my $line (@OutLines){
     next unless (defined $line);
     my @data=split(/\s+/,$line);
     push @NNDF, $data[0];
     push @VALS, $data[$sector];
   }
   $adcGrid->setNodalAttributeValue('surface_directional_effective_roughness_length',$sector,\@NNDF,\@VALS);
}

} # end if $surface_directional_effective_roughness_length

#########################################################################
# surface_submergence_state
if ($surface_submergence_state){

print "determining StartDry\n";

my @PX=();
my @PY=();
foreach my $kmlFile (@StartDry_kmlPolygons){
    my ($px,$py)=PolyTools::readKmlPoly("$kmlFile");
    push @PX, $px;
    push @PY, $py;
};


my @StartDry=();
my @StartDry_Nids=();

foreach my $n (1..$np){
   my $k=0;
   foreach my $px (@PX){
        my $py=$PY[$k];
        my $inpoly=PolyTools::pointInPoly($X[$n],$Y[$n],$px,$py);
        if ($inpoly) {
            push @StartDry, 1;
            push @StartDry_Nids, $n;
            last;
        }
        $k++;
   }  
}
my @defVal=0;
$adcGrid->addNodalAttribute('surface_submergence_state','na',1,\@defVal);
$adcGrid->setNodalAttributeValue('surface_submergence_state',1,\@StartDry_Nids,\@StartDry);

} # end if $surface_submergence_state


#########################################################################
# advection_state
if ($advection_state){

print "determining advection_state\n";

my @PX=();
my @PY=();
foreach my $kmlFile (@AdvectionState_kmlPolygons){
    my ($px,$py)=PolyTools::readKmlPoly("$kmlFile");
    push @PX, $px;
    push @PY, $py;
};

my @defVal=0;
$adcGrid->addNodalAttribute('advection_state','na',1,\@defVal);

my @AdvectionOff=();
my @AdvectionOff_Nids=();
my @AdvectionState_Vals=();
my $advection_state_val;
my @AdvectionState_Nids=(1..$np);

foreach my $n (1..$np){
   my $k=0;
   foreach my $px (@PX){
        my $py=$PY[$k];
        my $inpoly=PolyTools::pointInPoly($X[$n],$Y[$n],$px,$py);
        if ($inpoly) {
            push @AdvectionOff, 1;
            push @AdvectionOff_Nids, $n;
	    $advection_state_val = @Z[$n]-1;
	    push @AdvectionState_Vals, $advection_state_val;
	    #$adcGrid->setNodalAttributeValue('advection_state',$advection_state_val
            
        }else{
	    $advection_state_val = @Z[$n]+1;
	    push @AdvectionState_Vals, $advection_state_val;
	    last;
        }
        $k++;
   }  
}

$adcGrid->setNodalAttributeValue('advection_state',1,\@AdvectionState_Nids,\@AdvectionState_Vals);

} # end if advection_state


###############################################################################
#  average_horizontal_eddy_viscosity_in_sea_water_wrt_depth


my @DS=();

if ($average_horizontal_eddy_viscosity_in_sea_water_wrt_depth or
    $primitive_weighting_in_continuity_equation){
  # calculate minimum edge sizes
  my $nt=$adcGrid->genNeighborTables;
  my @NT=@{$nt};
  my $n;
  foreach $n (1..$np){
     my @Neighs=@{$NT[$n]};
     my $ds=99999999;
     foreach my $nn (@Neighs){
        my $ds_=&cppdist($X[$nn], $Y[$nn], $X[$n],$Y[$n]);
        $ds=$ds_ if ($ds_ < $ds);
     }
     $DS[$n]=$ds;
  }
} # end if we need DS

if ($average_horizontal_eddy_viscosity_in_sea_water_wrt_depth){
print "processing Eddy Viscosity\n";


my @EDDY=();
my @EDDY_NIDS=();
   
foreach my $n (1..$np){
   if ($Z[$n] > $minDepth_ESLM  || $DS[$n] < $maxEleSize_ESLM){
      push @EDDY, $small_ESLM;
      push @EDDY_NIDS, $n;
   }
}

my @defVal=$default_ESLM;
$adcGrid->addNodalAttribute('average_horizontal_eddy_viscosity_in_sea_water_wrt_depth','sqMeterPerSec',1,\@defVal);
$adcGrid->setNodalAttributeValue('average_horizontal_eddy_viscosity_in_sea_water_wrt_depth',1,\@EDDY_NIDS,\@EDDY);

} # end if $average_horizontal_eddy_viscosity_in_sea_water_wrt_depth

#################################################################################
# primitive_weighting_in_continuity_equation
# using Tau0 =-3
# for Tau0base
# default = 0.03
# use default for small elements, ds <= 1750  regardless of depth
# use 0.005 for deep water > 10 m
# use 0.02  for large shallow elements, ds > 1750 and depth < 10
if ($primitive_weighting_in_continuity_equation){

print "setting Tau0base\n";
my @TAU0=();
my @TAU0_NIDS=();
foreach my $n (1..$np){
   next if $DS[$n] <= 1750;
   if ($Z[$n] < 10){
       push @TAU0, 0.02;
   }else{
       push @TAU0, 0.005;
   }
   push @TAU0_NIDS, $n;
}


my @defVal=0.03;
$adcGrid->addNodalAttribute('primitive_weighting_in_continuity_equation','na',1,\@defVal);
$adcGrid->setNodalAttributeValue('primitive_weighting_in_continuity_equation',1,\@TAU0_NIDS,\@TAU0);

} # end if $primitive_weighting_in_continuity_equation


# elemental_slope_limiter
if ($elemental_slope_limiter){
print "setting elemental slope limiter\n";
my @defVal=$ESL_default;
$adcGrid->addNodalAttribute('elemental_slope_limiter','na',1,\@defVal);
} # end if $elemental_slopeLimiter 


if ($sea_surface_height_above_geoid){
print "sea_surface_height_above_geoid\n";
my @defVal=$geoidOffset;
$adcGrid->addNodalAttribute('sea_surface_height_above_geoid','meters',1,\@defVal);
} # end if $sea_surface_height_above_geoid 



# write the fort.13 file !
$adcGrid->writeFort13($fort13);





####################################################
#
# subroutines below

#############################################################
# sub to compute distance in meters between two
# points in geographic coordinates using CPP projection
#
############################################################# 
sub cppdist { # lat lon lat0 lon0
 my $twoPiOver360=4*atan2(1,1)/360.;
 my $R=6378206.4;
 my $lat=$_[0]*$twoPiOver360;
 my $lon=$_[1]*$twoPiOver360;
 my $lat0=$_[2]*$twoPiOver360;
 my $lon0=$_[3]*$twoPiOver360;

 my $x=$R*($lon-$lon0)*cos($lat0);
 my $y=($lat-$lat0)*$R;

 my $ds=( $x**2.0 + $y**2) **0.5
}



##############################################################
# sub to read gridFloat
#
##############################################################
sub readGridFloat{
   my ($hdrFile,$fltFile) = @_;

   print "\nReading land cover data from: $hdrFile and $fltFile\n";
   open HDR, "<$hdrFile" or die "cannot open $hdrFile";
   my %hdrData;
   while (<HDR>){
      chomp;
      $_=~ s/^\s+//;
      $_=~ s/\s+$//;
      my ($key,$value)=split(/\s+/,$_);
      $hdrData{lc $key}= lc $value;
   }
   my $ncols=$hdrData{'ncols'};
   my $nrows=$hdrData{'nrows'};
   my $lsb=0;
   $lsb=1 if $hdrData{'byteorder'} =~ m/lsbfirst/;
   my $dx=$hdrData{'cellsize'};
   my $xll=$hdrData{'xllcorner'};
   my $yll=$hdrData{'yllcorner'};
   my $nodata=$hdrData{'nodata_value'};
   my $yul=$yll+$dx*($nrows-1); # this is the lower left corner of the upper left cell
   close(HDR);

   my $xur=$xll+$dx*($ncols-1);

   print "Grid Fload Header Info:\n";
   print "  ncols $ncols\n";
   print "  nrows $nrows\n";
   print "  xll $xll\n";
   print "  yll $yll\n";
   print "  nodata $nodata\n";
   print "  lsb $lsb\n";
   print "  dx $dx\n";

   my $cellSize=$dx;

   # now read the data
   my $binstring;
   {
   local $/=undef;
   open FLT, "<$fltFile" or die "cannot open $fltFile\n";
   binmode(FLT);
   $binstring=<FLT>;
   #print "$binstring\n";
   # unpack and repack as string of 8-bit unsigned chars
   my @data=unpack("f<[$nrows*$ncols]",$binstring);
   $binstring=pack("C[$nrows*$ncols]",@data);

   close FLT;
   }
   return ($ncols,$nrows,$dx,$xll,$yll,$yul,$xur,$cellSize,$binstring);
}


#################################################################3
# sub to read geoTIFF
#
##################################################################
sub readGeoTiff {
   my $tifFile=shift;
   
   open FILE, "<$tifFile" or die "can't open $tifFile\n";;
   binmode FILE;

   my $buf;
   my @data;
   my $addr;
   my $recSize;

   ###########################
   # read header  
   #
   # get byteorder
   $addr=0;
   $recSize=2;
   sysseek(FILE, $addr,0);
   sysread(FILE, $buf, $recSize);
   my $byteorder=unpack("A2",$buf);  # II for intel little-endian, MM for motorola big-endian
   print "byteorder $byteorder\n";

   my $endian;
   $endian="<" if ($byteorder eq "II");
   $endian=">" if ($byteorder eq "MM");

   # get the "42" answer to the universe;
   $addr=$addr+$recSize;
   $recSize=2;
   sysread(FILE, $buf, $recSize);
   my $fortyTwo=unpack("S",$buf);
   print "fortyTwo $fortyTwo\n";

   # get the ifd offset
   $addr=$addr+$recSize;
   $recSize=4;
   sysread(FILE, $buf, $recSize);
   my $ifdOffset=unpack("L$endian",$buf);
   print "ifdOffset $ifdOffset\n";

   # seek to the 1st ifd
   sysseek(FILE, $ifdOffset,0);

   # get the number of entries (unsigned 16 bit integer)
   $recSize=2;
   sysread(FILE, $buf, $recSize);
   my $numEntries=unpack("S$endian",$buf);
   print "first ifd numEntries $numEntries\n";

   my @bytesPerValue; # depending on the type of entry see baseline tiff 6.0 specification
   $bytesPerValue[0]=0;
   $bytesPerValue[1]=1;
   $bytesPerValue[2]=1;
   $bytesPerValue[3]=2;
   $bytesPerValue[4]=4;
   $bytesPerValue[5]=8;
   $bytesPerValue[6]=1;
   $bytesPerValue[7]=1;
   $bytesPerValue[8]=2;
   $bytesPerValue[9]=4;
   $bytesPerValue[10]=8;
   $bytesPerValue[11]=4;
   $bytesPerValue[12]=8;

   my %tags; # a hash to hold the tag data

   foreach my $entry (1..$numEntries){
   #seek to entry
   sysseek(FILE, $ifdOffset+($entry-1)*12+2,0);

   $recSize=8;
   sysread(FILE, $buf, $recSize);
   my ($tag,$type,$count)=unpack("S$endian S$endian L$endian",$buf);
   my $twoCount=2*$count;
   # determine how many bytes in the value

   my $numBytes= $count * $bytesPerValue[$type];

   # read the offset/value into the buffer
   # # this will be either the offset if the value is more than 4 bytes, or the value itself
   $recSize=4;
   sysread(FILE, $buf, $recSize);   
   my $buf2=$buf;
  
   if ( $numBytes > 4 ) {  # in this buf contains an offset to the data, go there and get the data
      my $offset=unpack("L$endian",$buf);
      sysseek(FILE, $offset,0);
      sysread(FILE, $buf2, $numBytes);
   }

   my @values;
   if ( $type==1 or $type==6 or $type==7)  { @values=unpack("C[$count]",$buf2);}
   elsif ($type==2) { @values=unpack("A[$count]",$buf2);}
   elsif ($type==3 or $type==8) { @values=unpack("S$endian"."[$count]",$buf2);}
   elsif ($type==4 or $type==9) { @values=unpack("L$endian"."[$count]",$buf2);}
   elsif ($type==5 or $type==10) { @values=unpack("L$endian"."[$twoCount]",$buf2);}
   elsif ($type==11) { @values=unpack("f$endian"."[$count]",$buf2);}
   elsif ($type==12) { @values=unpack("d$endian"."[$count]",$buf2);}

   $tags{$tag}->{TYPE}=$type;
   $tags{$tag}->{COUNT}=$count;
   $tags{$tag}->{VALUES}=\@values;
#   print "entry $entry - tag,type,count : values: $tag,$type,$count : @values \n";
   }

  # foreach my $key (keys %tags){
#	print "tag $key\n";
#        print "        TYPE $tags{$key}->{TYPE}\n";
#        print "        COUNT $tags{$key}->{COUNT}\n";
#        print "        VALUES @{$tags{$key}->{VALUES}}\n";
#   }


   #get photometric interpretataion (tag 262)
   my $photometricInterpretation="BlackIsZero" if (${$tags{262}->{VALUES}}[0]==1);
   $photometricInterpretation="WhiteIsZero" if (${$tags{262}->{VALUES}}[0]==0);
   print "\nphotometricIntrepretation $photometricInterpretation\n";

   #get compression (tag 259)
   my $compression= ${$tags{259}->{VALUES}}[0];
   print "no compression\n" if ($compression == 1) ;
   print "CCITT Group 3 1D compression\n" if ($compression == 2);
   print "PackBits Compression\n" if ($compression == 32773) ;

   # number of rows (tag 257)
   my $nrows= ${$tags{257}->{VALUES}}[0];
   # number of columns (tag 256)
   my $ncols= ${$tags{256}->{VALUES}}[0];
   print "nrows,ncols $nrows,$ncols\n";

   #resolution unit (tag 296)
   my $resUnit=2;
   $resUnit=  ${$tags{296}->{VALUES}}[0] if (defined  ${$tags{296}->{VALUES}}[0]);
   print "ResolutionUnit = none\n" if ($resUnit==1);
   print "ResolutionUnit = inch\n" if ($resUnit==2);
   print "resolutionUnit = centimeter\n" if ($resUnit==3);

   # location of data

   my $rowsPerStrip=$nrows;
   $rowsPerStrip =  ${$tags{278}->{VALUES}}[0] if (defined ${$tags{278}->{VALUES}}[0]);
   my @stripOffsets =  @{$tags{273}->{VALUES}} ;
   my @stripByteCounts =  @{$tags{279}->{VALUES}} ;

   print "RowsPerStrip $rowsPerStrip\n";
   #print "StripOffsets @stripOffsets\n";
   #print "StripByteCounts @stripByteCounts\n";

   # bits per sample
   my $bitsPerSample =  ${$tags{258}->{VALUES}}[0] ;
   print "BitsPerSample $bitsPerSample\n";
   #SamplesPerPixel
   my $samplesPerPixel=  ${$tags{277}->{VALUES}}[0] ;
   print "samplePerPixel =  $samplesPerPixel\n";

   #colormap
   my $colormap=  ${$tags{320}->{VALUES}}[0] ;
   my $colormap_count=  $tags{320}->{COUNT};
   print "colormap =  $colormap $colormap_count\n";


   # get the geo referencing information (tag 33922 has i,j,k,x,y,z tiepoints)
   my ($gi,$gj,$gk,$gx,$gy,$gz)=@{$tags{33922}->{VALUES}};
   print "gijk: $gi, $gj, $gk\n";
   # tag 33550 has the x,y scale info 
   my %modelPixelScaleTag=%{$tags{33550}};
   my ($scaleX,$scaleY,$scaleZ)=@{$modelPixelScaleTag{VALUES}};
   print "scale tag $scaleX,$scaleY,$scaleZ\n";

   my $dx=$scaleX;
   my $dy=$scaleY;
   my $yul=$gy;
   my $xul=$gx;
   my $xll=$gx;
   my $yll=$gy-$dy*($nrows-1);
   my $xur=$gx+$dx*($ncols-1);

   # there is potentially a lot more in tag 34735 - e.g. projection info 
   # geoKeyDirectoryTag  see http://duff.ess.washington.edu/data/raster/drg/docs/geotiff.txt for more info
   my %geoKey=%{$tags{34735}};
   foreach my $gk (keys (%geoKey)){
      print "gk $gk, val $geoKey{$gk}\n";
    }
    my @VALS=@{$geoKey{VALUES}};
    my $KeyDirVer=shift @VALS;
    print "KeyDirctoryVersion : $KeyDirVer\n";
    my $KeyRev=shift @VALS;
    print "Key revision : $KeyRev\n";
    my $MinorKeyRev=shift @VALS;
    print "minor key revision : $MinorKeyRev\n";
    my $numKeys=shift @VALS;
    print "number of keys : $numKeys\n";
    print "#   , keyID, tagLoc, count, valueOffset\n";
 #   foreach my $key (1..$numKeys){
 #      my $d1=shift @VALS;
 #      my $d2=shift @VALS;
 #      my $d3=shift @VALS;
 #      my $d4=shift @VALS;
 #      print "key $key -- $d1, $d2, $d3, $d4\n";
 #   }

   open OUT, ">xyzclass.dump" or die "cant open xyacump";
   my $binstring='';
   # read the data one row atitime
   foreach my $offset (@stripOffsets){
      sysseek(FILE, $offset,0);
      my $j=0;
      my $jj=0;

      foreach my $row (1..$rowsPerStrip){
         sysread(FILE, $buf,$ncols);  # pixels are each 8-bits
         $binstring=$binstring.$buf;  # no need to reorder just concatenate row by row 8 bit values.
         my $i=0;
         my $n=$gy-($j*$dy);
         foreach  my $pix (@data){
	     if ($jj==97) {
	  #       print OUT "$i,$j,$pix\n";
		 my $e=$gx+($i*$dx);
	         printf OUT ("%i %i %6.2f\n",$e,$n,$pix);
		 	 	 $jj=0;
         }
		 $jj++;
          $i++;
          }
    #print "$j\n";

      $j++;
      last if ($j>$nrows);
      }
  
    } 
    close(FILE);
    close OUT;
    my $cellSize=$dx;
    return ($ncols,$nrows,$dx,$xll,$yll,$yul,$xur,$cellSize,$binstring);
}

