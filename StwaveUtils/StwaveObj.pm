package StwaveObj;
use strict;
use warnings;
#use Mapping::UTMconvert;
#use Mapping::P_spcs83;
# $obj->{$listName}->{$parmo
our $pi=4*atan2(1,1);
our $deg2rad=$pi/180;
#our $ni;
#our $nj;
#our $theta;
#our $x0;
#our $y0;
#our $dx;
#our $dy;
#our $azimuth;



#######################################################
# create new stwave object from reading sim file
#
# e.g. my $stw=StwaveObj->newFromSim("simname.sim");
#
sub newFromSim {
   my $class =  shift;
   my $obj={};
   bless $obj, $class;
   my $simName=shift;
   my $projName=$simName;
    $projName =~ s/\.sim//;
   $obj->{proj}=$projName;
   # read the sim file
   open FILE, "<$simName" or die "cant open $simName\n";
   while (<FILE>) {
      chomp;   
      next if ($_ =~ m/^\s*$/);  # skip blank lines
      my $firstChar=substr($_,0,1);
      next if ($firstChar eq '#');
      my $listName;
      if (($firstChar eq '&') or ($firstChar eq '@') ) {
         $listName=$_;
         $listName =~ s/&//;
         $listName =~ s/@//;
         $listName =~ s/\s+$//;
      }
      my $isarray=0;
      $isarray=1 if ($firstChar eq '@');
      $listName=lc($listName);
      print "reading $listName namelist\n";
      $obj->{$listName}={};
      my $longString;
      while (<FILE>) {
         chomp;
         last if (substr($_,0,1) eq '/');
         $longString=$longString.$_;
      }
      my @KV=split(/,/,$longString);
      foreach my $kv (@KV){
          my ($key,$value)=split(/=/,$kv);
          $key=lc($key);
          $key=trimStr($key);
          # don't let keys have spaces
          $key=~s/\s+//g;
          $value=trimStr($value);
          if ($isarray) {          
             # separate the variable name from the index
             $key =~ m/^(.*)\((\d+)\)$/;
             $key = $1;
             $obj->{$listName}->{$key}=[] unless defined ($obj->{$listName}->{$key}); # create the empty anon arrays the first time
             push $obj->{$listName}->{$key}, [$2, $value]; # two element anon array, with the first value the array index.
          }else{
             $obj->{$listName}->{$key}=$value;
             print "$listName $key = $value\n";
          }
      }
#sleep(1);
   }
   #$obj->_setOurs();

   close(FILE);
   # read the dep file
   my $depFile=$obj->{input_files}->{dep};
   if (-e $depFile) {
      $obj->_readSpatialFile($depFile,"dep"); 
   }else{
      print "$depFile does not exist\n";
   }
   # read the wave output
#   my $waveFile=$obj->{output_files}->{wave};
#   if (-e $waveFile){
#      $obj->_readSpatialFile($waveFile,"wave"); 
#   }else{
#      print "$waveFile does not exist\n";
#   }
#   # read the 1/fma  output
#   my $tpFile=$obj->{output_files}->{tp};
#   if (-e $tpFile) {
#      $obj->_readSpatialFile($tpFile,"tp");  
#   }else{
#      print "$tpFile does not exist\n";
#   }

  #$obj->_setOurs();

  return $obj;
}


#######################################################
# sub loadSpatialData
#
# loads spatial data from spatial input and output files
# 
#  inputs can be:
#  SURGE,WIND,DEP,FRIC
#  
#  outputs can be:
#  WAVE,TP,BREAK,RADS
#
# e.g.
# 
#  $stw->loadSpatialData('SURGE'[,'surge.in'])
#
#  if no file name is specifiec it will attempt to
#  read the default name or the name given in the sim file
#
#######################################################


sub loadSpatialData{
   my $obj=shift;
   my $dataName=lc(shift);
   my $filename=shift;
   my $namelist='';
   if ( ($dataName eq 'surge') or  ($dataName eq 'wind') or ($dataName eq 'dep') or ($dataName eq 'fric') ){
      $namelist='input_files';
   }elsif ( ($dataName eq 'wave') or  ($dataName eq 'tp') or ($dataName eq 'break') or ($dataName eq 'rads') ){
      $namelist='input_files';
   }else{
      die "ERROR: StwaveObj.pm: invalid data type $dataName given for loadSpatialData\n";
   }
   $filename=$obj->{$namelist}->{$dataName} unless (defined $filename);
   if (-e $filename) {
      $obj->_readSpatialFile($filename,$dataName); 
   }else{
      print "Warning: StwaveObj.pm: $filename does not exist\n";
   }
};
 


#######################################################
# create new stwave object from scratch
#
# all hash keys are lowercase!
#
# e.g. my $st=SwtaveObj->new( 
#
#
#                          # &std_parms namelist 
#                            iplane=>0,    # 0 for half plane, 1 for full plane
#                            iprp=>0,      # 0 for propagation and wind-wave generation, 1 for prop only
#                            icur=>0,      # 0 no current, 1 current specified at each snap, 2 same current for all snaps
#                            ibreak=>1,    # 1 write breaking indicies, 0 don't, 2 priht dissipation in each cell
#                            irs=>0,       # 1 calculate rad stress, 0 don't
#                            nselct=>0,    # number of i,j output points for Hmo,Tp,and,Am (SELH), and spectra(OBSE) 
#                            nnest=>0,     # number of nest i,j, output points (NEST)
#                            nstations=>0, # number of x,y interpolated output points
#                            ibnd=>0,      # 0 single input spectra, 1, lineart interp, 2 morphic interp
#                            ifric=>0,    # 0 no fric, 1 const JONSWAP, 2 spatial vary JONSWAP, 3 const Manning, 4 spatial vary Manning
#                            isurge=>0,    # 0 const depth correction (const_surge namelist), 1 spatial vary depth (SURGE file)
#                            iwind=>1,     # 0 const wind (cost_wind namelist), 1 spatial vary wind (WIND file)
#                            idep_opt=>0,  # 0 red from DEP file, 1 plane sloping bottom
#                            i_bc1=>2,     # 0 for zero spectra, land or open boundary
#                            i_bc2=>0,     # 1 for const TMA spectrum
#                            i_bc3=>0,     # 2 for spectra from ENG file
#                            i_bc4=>0,     # 3 1-D transformed spectrum (for lateral bnds between 0,1,or 2), only for full plane
#
#                          # &run_parms namelist
#                            idd_spec_type=>4,  # 4 specified character snap idds, see manual for others
#                            numsteps=>1,       # number of snaps to process
#                            n_grd_part_i=>1,  # partitions in the i-direction
#                            n_grd_part_j=>1,  # partitions in j-direction
#                            n_init_iters=>20,  # initial iterations per idd, only used for full plane
#                            init_iters_stop_value=>0.1,      # convergence criteria for initial iterations, only used for full plane
#                            init_iters_stop_percent=>100.0,  # percentage of cells meeting init iters criteria, only used full plane
#                            n_final_iters=>20,               # number final iterations per idd
#                            final_iters_stop_value=>0.1,     # convergence criteria for final iterations, only Full plane
#                            final_iters_stop_percent=>100.0, # percentage of cells meting final convergence
#                            default_input_io_type=>1,        # 1 all ASCII, 0 all XMDF
#                            default_output_io_type=>1,       # 0 no output, 1 ASCII, 2 XMDF, 3 both
#
#                          # &spatial_grid_parms namelist - can be specified, but use set_spatial_grid_parms sub instead
#                            coord_sys => 'STATEPLANE',   # LOCAL, UTM, or STATEPLANE
#                            spzone => 1801,              # FIPS SP zone number or UTM ZONE
#                            x0=>0,     # origin of grid
#                            y0=>0,
#                            azimuth,   # azimuth of grid ccw from east, direction of i-axis
#                            dx=>0,    # cell spacing in i-direction
#                            dy=>0,    # cell spacing in j-direction dx=dy for halfplane
#                            n_cell_i=>0, # interger number of i cells
#                            n_cell_j=>0, # interger number of j cells
#                            
#                          # &input_files namelist     
#                            DEP=>    'project.dep.in',
#                            SURGE=>  'project.surge.in',
#                            SPEC=>   'project.eng.in',
#                            WIND=>   'project.wind.in',
#                            FRIC=>   'project.fric.in',
#                            io_type_dep =   1,
#                            io_type_surge = 1,
#                            io_type_wind =  1,
#                            io_type_spec =  1,
#                            io_type_fric =  1,
#
#                          # &output_files namelist        
#                            WAVE =>    "project.wave.out",
#                            OBSE =>    "project.obse.out",
#                            BREAK =>   "project.break.out",
#                            RADS =>    "project.rads.out",
#                            SELH =>    "project.selh.out",
#                            STATION => "project.station.out",
#                            NEST =>    "project.nest.out",
#                            LOGS =>    "project.log.out",
#                            TP =>      "project.Tp.out"
#                            io_type_tp =>      1,
#                            io_type_nest =>    1,
#                            io_type_selh =>    1,
#                            io_type_rads =>    1,
#                            io_type_break =>   1,
#                            io_type_obse =>    1,
#                            io_type_wave =>    1,
#                            io_type_station => 1,
#
#                          # time_parms name list - we're not using since its is only for IDD_SPEC_TYPE 2 or 3. we always use 4
#
#                          # &const_spec       # potentially optional (used when i_bc = 1, or all i_bc's =0 ), but order is fixed
#                            nfreq => 30,        # number of frequencies 
#                            na => 35,           # number of angles (typically 35 for half plane, 72 for full)
#                            f0 => 0.05,         # lowest frequency bin
#                            df_const => 0.02,   # constant frequency increment
#
#                          # &depth_fun        #  used for plane sloping bottom idep_opt= =1.  Not typically used
#                            dp_iside => 1,
#                            dp_d1 => 20.0,
#                            dp_slope => 0.10,
#                            
#                          # &const_fric       # used for ifric = 1 or 3, JONSWAP factor or Manning's
#                            cf_const => 0.01,  
#                            
#                          # @snap_idds      # used for idd_spec_type = 1,-2, -3,or 4 (we're using 4 mostly)
#                            idds => [ [1,'snap1'],  # ... to illustrate how array namelists are stored in this object
#                                      [2,'shap2'],  # the hash value at $obj->{namelist}->{datatype} is an reference
#                                    ],              # to an array of anonymous size 2 arrays.  each of these
#                                                    # contains the index value followed by the value for that array element
#
#                          # @select_pts
                                     #   array index, cell-i-value  
#                            iout => [ [   1        ,      1        ],  # point 1 i-value
#                                      [   2        ,      1        ]   # point 2 i-value
#                                    ],
#                            jout => [ [   1        ,      1        ],  # point 1 j-value
#                                      [   2        ,      2        ]   # point 2 j-value
#                                    ],
#
#                          # @nest_pts           # similar to select_pts
#                            inest => [ [1,1],
#                                       [2,1]  
#                                    ],
#                            jnest => [ [1,1],
#                                       [2,2]
#                                    ],
#
#                          # @station_locations       # example that outputs at points 50000,90000 and 50000,100000
#                            stat_xcoor =>  [ [1,50000],
#                                             [2,50000]  
#                                          ],
#                            stat_ycoor =>  [ [1,90000],
#                                             [2,100000]
#                                          ],
#               
#                          # @const_wind
#                                            #     snap , value
#                            umag_const_in => [ [ 1    , 10.0 ],    # snap 1 constant wind speed (m/s)
#                                               [ 2    , 12.0 ],    # snap 2 constant wind speed
#                            udir_const_in => [ [ 1    , 90   ],    # snap 1 constant wind direction (deg ccw from i-axis)
#                                               [ 2    , 45   ],    # snap 2 constant wind direction (i.e. added to azimuth)
#
# 
#
#                          # @const_surge
#                                            #     snap , value
#                            dadd_const_in => [ [ 1    , 3.05 ],    # snap 1 constant water level (m)
#                                               [ 2    , 3.45 ],    # snap 2 constant water level
#
##                          # @const_tma_spec
#                                            #     snap , value
#                            h_spec_in = >     [ [ 1    , 10.0 ],    # snap 1 constant wave height (m)
#                                                [ 2    , 12.0 ],    # snap 2 constant wave height
#                            tp_spec_in = >    [ [ 1    , 90   ],    # snap 1 constant wave period (s)
#                                                [ 2    , 45   ],    # snap 2 constant wave period 
#                            wvang_spec_in = > [ [ 1    , 90   ],    # snap 1 constant wave direction (deg ccw from i-axis)
#                                                [ 2    , 45   ],    # snap 2 constant wave direction (i.e. added to azimuth)
#
#                           )      
#
############################################################################################################################
sub new {
   my $class =  shift;
   my $obj={};
   bless $obj, $class;

   # set all the defaults
   #  &std_parms
   $obj->{'std_parms'}={
                            iplane=>0,    # 0 for half plane, 1 for full plane
                            iprp=>0,      # 0 for propagation and wind-wave generation, 1 for prop only
                            icur=>0,      # 0 no current, 1 current specified at each snap, 2 same current for all snaps
                            ibreak=>1,    # 1 write breaking indicies, 0 don't, 2 priht dissipation in each cell
                            irs=>0,       # 1 calculate rad stress, 0 don't
                            nselct=>0,    # number of i,j output points for Hmo,Tp,and,Am (SELH), and spectra(OBSE) 
                            nnest=>0,     # number of nest i,j, output points (NEST)
                            nstations=>0, # number of x,y interpolated output points
                            ibnd=>0,      # 0 single input spectra, 1, lineart interp, 2 morphic interp
                            ifric=>0,     # 0 no fric, 1 const JONSWAP, 2 spatial vary JONSWAP, 3 const Manning, 4 spatial var
                            isurge=>0,    # 0 const depth correction (const_surge namelist), 1 spatial vary depth (SURGE file)
                            iwind=>0,     # 0 const wind (cost_wind namelist), 1 spatial vary wind (WIND file)
                            idep_opt=>0,  # 0 red from DEP file, 1 plane sloping bottom
                            i_bc1=>2,     # 0 for zero spectra, land or open boundary
                            i_bc2=>3,     # 1 for const TMA spectrum
                            i_bc3=>0,     # 2 for spectra from ENG file
                            i_bc4=>3      # 3 1-D transformed spectrum (for lateral bnds between 0,1,or 2), only for full plane
                       };
   $obj->{'std_parms_keys'}= [
                                 'iplane'   ,
                                 'iprp'     ,
                                 'icur'     ,
                                 'ibreak'   ,
                                 'irs'      ,
                                 'nselct'   ,
                                 'nnest'    ,
                                 'nstations',
                                 'ibnd'     ,
                                 'ifric'   ,
                                 'isurge'   ,
                                 'iwind'    ,
                                 'idep_opt' ,
                                 'i_bc1'    ,
                                 'i_bc2'    ,
                                 'i_bc3'    ,
                                 'i_bc4'     ];                

   # &run_parms
   $obj->{'run_parms'}={
                            idd_spec_type=>4,  # 4 specified character snap idds, see manual for others                             
                            numsteps=>2,       # number of snaps to process                                                         
                            n_grd_part_i=>1,  # partitions in the i-direction                                                      
                            n_grd_part_j=>1,  # partitions in j-direction                                                          
                            n_init_iters=>20,  # initial iterations per idd, only used for full plane                               
                            init_iters_stop_value=>0.1,      # convergence criteria for initial iterations, only used for full plane
                            init_iters_stop_percent=>100.0,  # percentage of cells meeting init iters criteria, only used full plane
                            n_final_iters=>20,               # number final iterations per idd                                      
                            final_iters_stop_value=>0.1,     # convergence criteria for final iterations, only Full plane           
                            final_iters_stop_percent=>100.0, # percentage of cells meting final convergence                         
                            default_input_io_type=>1,        # 1 all ASCII, 0 all XMDF                                              
                            default_output_io_type=>1       # 0 no output, 1 ASCII, 2 XMDF, 3 both          
                        };
  $obj->{'run_parms_keys'}=[                            
                           'idd_spec_type'             ,
                           'numsteps'                  ,
                           'n_grd_part_i'             ,
                           'n_grd_part_j'             ,
                           'n_init_iters'              ,
                           'init_iters_stop_value'     ,
                           'init_iters_stop_percent'   ,
                           'n_final_iters'             ,
                           'final_iters_stop_value'    ,
                           'final_iters_stop_percent'  ,
                           'default_input_io_type'     ,
                           'default_output_io_type' 
                           ];                               


   # &spatial_grid_parms
   $obj->{spatial_grid_parms}={
                            coord_sys => "\'UTM\'",   # LOCAL, UTM, or STATEPLANE        
                            spzone => 19,              # FIPS SP zone number or UTM ZONE  
                            x0=>0,     # origin of grid                                     
                            y0=>0,                                                          
                            azimuth=>0,   # azimuth of grid ccw from east, direction of i-axis 
                            dx=>30,    # cell spacing in i-direction                         
                            dy=>30,    # cell spacing in j-direction dx=dy for halfplane     
                            n_cell_i=>100, # interger number of i cells                       
                            n_cell_j=>100 # interger number of j cells                       
                        };

   $obj->{spatial_grid_parms_keys}=[           
                            'coord_sys'  ,
                            'spzone'     ,
                            'x0'         ,
                            'y0'         ,
                            'azimuth'    ,
                            'dx'         ,
                            'dy'         ,
                            'n_cell_i'   ,
                            'n_cell_j'    
                            ];                

    
   # &input_files
   $obj->{'input_files'}={
                            dep=>    "\'project.dep.in\'",  
                            surge=>  "\'project.surge.in\'",
                            spec=>   "\'project.eng.in\'",  
                            wind=>   "\'project.wind.in\'", 
                            fric=>   "\'project.fric.in\'", 
                            io_type_dep =>   1,          
                            io_type_surge => 1,          
                            io_type_wind =>  1,          
                            io_type_spec =>  1,          
                            io_type_fric =>  1
                         };

   $obj->{'input_files_keys'}=[             
                            'dep'          ,
                            'surge'        ,
                            'spec'         ,
                            'wind'         ,
                            'fric'         ,
                            'io_type_dep'  ,
                            'io_type_surge',
                            'io_type_wind' ,
                            'io_type_spec' ,
                            'io_type_fric'  
                         ];                 


    # &output_files
    $obj->{'output_files'}={
                            wave =>    "\'project.wave.out\'",      
                            obse =>    "\'project.obse.out\'",      
                            break =>   "\'project.break.out\'",     
                            rads =>    "\'project.rads.out\'",      
                            selh =>    "\'project.selh.out\'",      
                            station => "\'project.station.out\'",   
                            nest =>    "\'project.nest.out\'",      
                            logs =>    "\'project.log.out\'",       
                            tp =>      "\'project.Tp.out\'",      
                            io_type_tp =>      1,               
                            io_type_nest =>    1,               
                            io_type_selh =>    1,               
                            io_type_rads =>    1,               
                            io_type_break =>   1,               
                            io_type_obse =>    1,               
                            io_type_wave =>    1,               
                            io_type_station => 1
                          };         
    $obj->{'output_files_keys'}=[            
                            'wave'         ,
                            'obse'         ,
                            'break'        , 
                            'rads'         ,
                            'selh'         ,
                            'station'      ,
                            'nest'         ,
                            'logs'         ,
                            'tp'           ,
                            'io_type_tp'   , 
                            'io_type_nest' , 
                            'io_type_selh' , 
                            'io_type_rads' , 
                            'io_type_break', 
                            'io_type_obse' , 
                            'io_type_wave' , 
                            'io_type_station'
                          ];                 


    # skip &time_parms  only for IDD_SPEC_TYPE 2 or 3. we always use 4
    $obj->{'time_parms'}=undef;
 
    # &const_spec  potentially optional (used when i_bc = 1, or all i_bc's =0 ), but order is fixed
    $obj->{'const_spec'}=undef; #{
                       #     nfreq => 30,        # number of frequencies                                         
                       #     na => 72,           # number of angles (typically 35 for half plane, 72 for full)   
                       #     f0 => 0.05,         # lowest frequency bin                                          
                       #     df_const => 0.02    # constant frequency increment         
                       #  };
    $obj->{'const_spec_keys'}=[             
                            'nfreq' ,
                            'na'     ,
                            'f0'      ,
                            'df_const' 
                         ];            

    # skip &depth_fun  used for plane sloping bottom idep_opt= =1.  Not typically used            
    $obj->{'depth_fun'}=undef;

    # &const_fric    used for ifric = 1 or 3, JONSWAP factor or Manning's
    $obj->{'const_fric'}={
                            cf_const => 0.012
                         };
    $obj->{'const_fric_keys'}=['cf_const'];
    
    # @snap_idds used for idd_spec_type = 1,-2, -3,or 4 (we're using 4 mostly) 
    $obj->{'snap_idds'}={
                            idds => [ [1,"\'shap1\'"],  # ... to illustrate how array namelists are stored in this object       
                                      [2,"\'shap2\'"]   # the hash value at $obj->{namelist}->{datatype} is an reference        
                                    ]               # to an array of anonymous size 2 arrays.  each of these                
                        };                          # contains the index value followed by the value for that array element 
    $obj->{'snap_idds_keys'}=['idds'];   
    # @select_pts
    $obj->{'select_pts'}=undef;  # none by default
    $obj->{'select_pts_keys'}=['iout','jout'];

    # @nest_pts
    $obj->{'nest_pts'}=undef;   # none by default
    $obj->{'nest_pts_keys'}=['inest','jnest'];
 
    # @station_locations
    $obj->{'station_locations'}=undef;  # nttone by default
    $obj->{'station_locations_keys'}=['stat_xcoor','stat_ycoor'];

    # @const_wind
    $obj->{'const_wind'}={
                                            #     snap , value                                                                 
                            umag_const_in => [ [ 1    , 10.0 ],    # snap 1 constant wind speed (m/s)                          
                                               [ 2    , 10.0 ]    # snap 2 constant wind speed   
                                                                ],                             
                            udir_const_in => [ [ 1    , 0   ],    # snap 1 constant wind direction (deg ccw from i-axis)      
                                               [ 2    , 15   ]    # snap 2 constant wind direction (i.e. added to azimuth)  
                                                                ]
                         };    
    $obj->{'const_wind_keys'}=['umag_const_in','udir_const_in'];
     
    # @const_surge
    $obj->{'const_surge'}={
                                            #     snap , value                                       
                            dadd_const_in => [ [ 1    , 3.0 ],    # snap 1 constant water level (m) 
                                               [ 2    , 3.0 ],     # snap 2 constant water level     
                                                                ]
                          };
    $obj->{'const_surge_keys'}=['dadd_const_in'];

    # @const_tma_spec
    $obj->{'const_tma_spec'}=undef;#{  SMS doesn't like this in a sim file
                       #                     #     snap, point, value                                                                  
                       #     h_spec_in =>     [  [ 1    ,1    , 2.20 ],    # snap 1 constant wave height (m)                           
                       #                         [ 2    ,1    , 3.0 ]    # snap 2 constant wave height    
                       #                                           ],                           
                       #     tp_spec_in =>    [  [ 1    ,1    , 10  ],    # snap 1 constant wave period (s)                           
                       #                         [ 2    ,1    , 12   ]    # snap 2 constant wave period                               
                       #                                           ],                           
                       #     wvang_spec_in => [  [ 1    ,1    , -15   ],    # snap 1 constant wave direction (deg ccw from i-axis)      
                       #                         [ 2    ,1    , 15   ]    # snap 2 constant wave direction (i.e. added to azimuth)    
                       #                                           ]            
                       #     };               
  
    $obj->{'const_tma_spec_keys'}=['h_spec_in','tp_spec_in','wvang_spec_in'];

 
   #$obj->_setOurs();  
   return $obj;

}


################################################
# sub _setOurs
#
# sets/resets shared variables
#
# run after initialization or setting parms
# to ensure shared variables are consistent
# 
# 
#################################################
#sub _setOurs{ 
#   my $obj=shift;
#   $theta=$obj->{spatial_grid_parms}->{azimuth}*$deg2rad;
#   $x0=$obj->{spatial_grid_parms}->{x0};
#   $y0=$obj->{spatial_grid_parms}->{y0};
#   $dx=$obj->{spatial_grid_parms}->{dx};
#   $dy=$obj->{spatial_grid_parms}->{dy};
#   $ni=$obj->{spatial_grid_parms}->{n_cell_i};
#   $nj=$obj->{spatial_grid_parms}->{n_cell_j};
#   $azimuth=$obj->{spatial_grid_parms}->{azimuth}*$deg2rad;
#}
   

############################################
#
# sub to get a value from the hash
#
############################################
#sub getVal {
#  my $obj=shift;
#  my @keys=@_;
#  my $key=lc(shift(@keys));  # alsays use lower case
#  my $val=$obj->{$key};
#  foreach $key (@keys) {
#     $key=lc($key);
#     $val=$val->{$key};
#  }
#  return ($val);
#}

###################################################################
#
# private subroutine for reading stwave spatial data files
#
# e.g. _readSpatialFile("projname.dep","DEP")
####################################################################
sub _readSpatialFile {
    my $obj=shift;
    my ($fileName,$dataName)=@_;
    $dataName=lc($dataName);
    $obj->{$dataName}={};

   my $dx=$obj->{spatial_grid_parms}->{dx};
   my $dy=$obj->{spatial_grid_parms}->{dy};
   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};

    # 
    open FILE, "<$fileName" or die "cant open $fileName\n";

    while (<FILE>) {
       chomp;   
       my $firstChar=substr($_,0,1);
       next if ($firstChar eq '#');
       my $listName;
       if (($firstChar eq '&') or ($firstChar eq '@') ) {
          $listName=$_;
          $listName =~ s/&//;
          $listName =~ s/\s+$//;
       }
      $listName=lc($listName);
      print "reading $listName namelist\n";
      $obj->{$dataName}->{$listName}={};
      my $longString;
      while (<FILE>) {
         chomp;
         last if (substr($_,0,1) eq '/');
         $longString=$longString.$_;
      }
      my @KV=split(/,/,$longString);
      foreach my $kv (@KV){
         my ($key,$value)=split(/=/,$kv);
         $key=lc($key);
         $key=trimStr($key);
         # don't let keys have spaces
         $key=~s/\s+//g;
         $value=trimStr($value);        
         $obj->{$dataName}->{$listName}->{$key}=$value;
         print "$listName $key = $value\n";
      }
      
      last if ($listName eq "dataset"  ); 
   }
   my $numFields=$obj->{$dataName}->{datadims}->{numflds};
   print "$dataName numFields is $numFields\n";
   my $numRecs=$obj->{$dataName}->{datadims}->{numrecs};
   print "$dataName numrecs is $numRecs\n";
   my $ni_=$obj->{$dataName}->{datadims}->{ni};
   print "$dataName ni is $ni_ should be $ni\n";
   unless ($ni_ == $ni) {die "ERROR!: StwaveObj.pm: spatial data in $fileName does not match global spatial_grid_params\n";} 
   my $nj_=$obj->{$dataName}->{datadims}->{nj};
   print "$dataName nj is $nj_ should be $nj\n";
   unless ($nj_ == $nj) {die "ERROR!: StwaveObj.pm: spatial data in $fileName does not match global spatial_grid_params\n";}
   my $dx_=$obj->{$dataName}->{datadims}->{dx};
   print "$dataName dx is $dx_ should be $dx\n";
   unless ($dx_ == $dx) {die "ERROR!: StwaveObj.pm: spatial data in $fileName does not match global spatial_grid_params\n";}
   my $dy_=$obj->{$dataName}->{datadims}->{dy};
   print "$dataName dy is $dy_ should be $dy\n";
   unless ($dy_ == $dy) {die "ERROR!: StwaveObj.pm: spatial data in $fileName does not match global spatial_grid_params\n";}

   

   #create some empty anonymous arrays to hold the data based on the field name
   $obj->{$dataName}->{fieldNames}=[];
   foreach my $field (1..$numFields){
       my $fieldName=$obj->{$dataName}->{dataset}->{"fldname("."$field".")"};
       print "fldname $fieldName\n";
       $fieldName=lc($fieldName);
       $obj->{$dataName}->{$fieldName}=[];
       push @{$obj->{$dataName}->{fieldNames}},$fieldName;
   }
   
   #create an array to hold the IDD's
   $obj->{$dataName}->{idds}=[];

   # now read the data
   my $numCells=$ni*$nj;
   for my $rec (1..$numRecs){
       my $line=<FILE>;
       chomp($line);
       push (@{$obj->{$dataName}->{idds}}, $line);
       for my $cell (1..$numCells){
          $line=<FILE>;
          chomp $line;
          $line=trimStr($line);
          my @data=split(/\s+/,$line);
          foreach my $field ( @{$obj->{$dataName}->{fieldNames}}){
             my $datum=shift(@data);
             push (@{$obj->{$dataName}->{$field}},$datum);
          }
       }
      

   }
    
   close(FILE);
}


#############################################################
# sub setNamelist
#
# e.g.
#
#    $stw->setNamelist($listName,%listHash)
# 
#  sets a whole name list
#
#############################################################
sub setnameList{
   my $obj=shift;
   my $listName=shift;
   my %args=shift;
   $obj->{lc($listName)}=\%args;
   #$obj->_setOurs();
}

############################################################
# sub setParm
# 
# e.g. 
#
#    $stw->setParm($parm,$value)
#
# sets invidual parameters
#
###########################################################
sub setParm {
    my $obj=shift;
    my $parm=shift;
    my $value=shift;  
    $parm = lc($parm);
   
    foreach my $listName (keys %{$obj}){
       next if $listName =~ m/_keys$/;
       next unless (ref ($obj->{$listName}) eq 'HASH');
       foreach my $parmName (keys %{$obj->{$listName}}){
            if ($parm eq $parmName){
                $obj->{$listName}->{$parm}=$value;
                print "INFO: StwaveObj.pm: setting namelist $listName, parm $parm, to $value\n";
                #$obj->_setOurs();
                return $obj;
            }
       }
    }
    print "Warning: StwaveObj.pm: setParm could not set parm $parm\n";
    return $obj;
}


############################################################
# sub setParms
# 
# e.g. 
#
#    $stw->setParms(%parms)
#
# sets a set of parms given in a hash
#
###########################################################

sub setParms{
    my $obj=shift;
    my %parms=@_;
    foreach my $parm (keys (%parms)){
        $obj->setParm($parm,$parms{$parm});
    }
}

 
############################################################
# sub getParm
# 
# e.g. 
#
#    my $value=$stw->getParm($parm)
#
#  gets invidual parameters
#
###########################################################
sub getParm {
    my $obj=shift;
    my $parm=shift;
   # my $value=shift;  
    $parm = lc($parm);
   
    foreach my $listName (keys %{$obj}){
       next if $listName =~ m/_keys$/;
       next unless (ref ($obj->{$listName}) eq 'HASH');
       foreach my $parmName (keys %{$obj->{$listName}}){
            if ($parm eq $parmName){
                print "INFO: StwaveObj.pm: getParm: listname $listName parm $parm is $obj->{$listName}->{$parm}\n";
                return $obj->{$listName}->{$parm};
            }
       }
    }
    print "Warning: StwaveObj.pm: setParm could not get parm $parm\n";
    return undef;
}




############################################################
# sub writeSimFile
#
# e.g. 
#      $stw->writeSimFile('project.sim');
#
#
###########################################################

sub writeSimFile{
  my $obj=shift;
  my $simName=shift;
  $simName='project.sim' unless defined ($simName);

  my @LISTS=(
              '&std_parms',
              '&run_parms',
              '&spatial_grid_parms',
              '&input_files',
              '&output_files',
              '&time_parms',
              '&const_spec',
              '&depth_fun',
              '&const_fric',
              '@snap_idds',
              '@select_pts',
              '@nest_pts',
              '@staton_locations',
              '@const_wind',
              '@const_surge',
              '@const_tma_spec'
            );
  my @LISTS_DESC=(
              'Standard Input',
              'Runtime Parameters',
              'Spatial Grid Parameters',
              'Input Files',
              'Output Files',
              'Time Parameters (only need for idd_spec_type +-2 or +-3)',
              'Constant Boundary Spectrum Info (used with i_bc=1 or all i_bc=0',
              'Depth Profile (for sloping bottom, only with idept_opt=1) ',
              'Spatially Constant Friction for ifric = 1 or 3, (JONSWAP or MANNING)',
              'Snaps',
              'Selected Points for output (by cell i,j)',
              'Points for nest output (by cell i,j)',
              'Coordinates for x,y station output',
              'Constant Wind',
              'Constant Water Level',
              'Constant Boundary TMA Spectrum'
            );

   my @isQuoted=('coord_sys','dep','surge','spec','wind','fric','wave','obse','break','rads',
                 'selh','station','nest','logs','tp','i_time_inc_units');

       

   open SIM, ">$simName" or die "ERROR: StwaveObj.pm: cant open $simName\n";
   print SIM "# STWAVE_SIM_FILE\n# Written by StwaveObj.pm\n#\n####################\n";

   foreach my $listName (@LISTS){    
       # write some beginning comments
       my $desc=shift @LISTS_DESC;
       print SIM "#_______________________________________________\n";
       print SIM "# $desc\n";
       print SIM "#-----------------------------------------------\n";

       # handle the first char in the listname
       my $isarray=0;
       $isarray=1 if (substr($listName,0,1) eq '@');
       my $listName=substr($listName,1);


       unless (defined ($obj->{$listName})){
          print SIM "\n";
          next;
       }

       unless  ($isarray){ # its a scalar
           print "writing \&$listName\n";
           print SIM '&'."$listName\n";
           
           my $numParms=@{$obj->{"$listName".'_keys'}};
           my $n=1;
           foreach my $parm (@{$obj->{"$listName".'_keys'}}){
               next unless defined ($obj->{$listName}->{$parm});
               my $val=$obj->{$listName}->{$parm};
               # check if should be qoted
               my $isq=0;
               foreach my $prm (@isQuoted){
                   if ($parm eq $prm){
                      $isq=1;
                      last;
                   }
               }
               if ($isq){
                  unless ($val =~ m/^(\'.+\'|\".+\")$/){
                      $val='"'."$val".'"';                      
                  }
               }

               print SIM "  $parm = $val";
               print SIM "," if ($n < $numParms);
               print SIM "\n";  
               $n++;             
           }
                 
       }else{ # an array
           print "writing \@$listName\n";
           print SIM '@'."$listName\n";

          # copy the arrays in order
          my @ARRS=();
          my @PARMS=();
          my $numRecs;
          my $numParms=0;
          foreach my $parm (@{$obj->{"$listName".'_keys'}}){
              next unless defined ($obj->{$listName}->{$parm});
              my @a=@{$obj->{$listName}->{$parm}};
              push @ARRS, \@a;
              $numRecs=$#a;
              push @PARMS, $parm;
              $numParms++;
          }
                   
          #my $numParms=@{$obj->{"$listName".'_keys'}};
          my $n=1;
          my $nn=$numParms*($numRecs+1);
          foreach my $rec (0..$numRecs){
              my $str='';
              foreach my $ar (@ARRS){
                    my $a=shift $ar;
                    my $parm=shift @PARMS;
                    push @PARMS, $parm;

                    
                    if ($listName eq 'const_tma_spec'){ 
                         $str .= " $parm($a->[0],$a->[1]) = $a->[2]";
                    }else{
                         $str .= "  $parm($a->[0]) = $a->[1]";
                    }
                    $str .= ',' if ($n<$nn);
                    $n++;
              }
              print SIM "$str\n";
          } 
       }

       print SIM "/\n";      
   }       
   close (SIM);
}


########################################################################
# sub interpDepFromScatter
# 
#  $stw->interpDepFromScatter(\@PX,\@PY,\@PZ);
#
########################################################################
sub interpDepFromScatter{
    my $obj=shift;
    my ($px,$py,$pz)=@_;
    my @PX=@$px;
    my @PY=@$py;
    my @PZ=@$pz;


    #my $x0=$obj->{spatial_grid_parms}->{x0};
    #my $y0=$obj->{spatial_grid_parms}->{y0};
    my $dx=$obj->{spatial_grid_parms}->{dx};
    my $dy=$obj->{spatial_grid_parms}->{dy};


    my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
    my $nj=$obj->{spatial_grid_parms}->{n_cell_j};

    my @DEP=();
    my @CNT=();
    my @HasData=();
    my $numCells=$ni*$nj;
    foreach my $n (0..$numCells-1){
       $DEP[$n]=0;
       $CNT[$n]=0;
       $HasData[$n]=0;

    }

    print "finding points on grid cells, numpoints is $#PX\n";
    foreach my $x (@PX){
        my $y=shift(@PY); #push @PY, $y;     
        my $z=shift(@PZ); #push @PZ, $z;     
        my ($i,$j)=$obj->getIj($x,$y);
        next unless defined ($i);

        my $n=$obj->getCellNumber($i,$j);  #cell numbers are zero indexed, but cell i,j are 1 indexed
        print "i=$i, j=$j, n DEP Z, $n, $DEP[$n] $z\n" unless (($n > 0) and ($n < $ni*$nj)); 
        $DEP[$n]=$DEP[$n]+$z;
        $CNT[$n]++;
        $HasData[$n]=1;

    } 
        
    # compute the cell average
    @PX=();
    @PY=();
    @PZ=();
    foreach my $n (0..$numCells-1){
       next unless ($HasData[$n]);
       $DEP[$n]=$DEP[$n]/$CNT[$n];
       my ($i,$j)=$obj->getIjFromCellNumber($n);
       push @PX,$i;
       push @PY,$j;
       push @PZ,$DEP[$n];


    }
 
    # now fill in the blank cells with a crude idw average among cells
    foreach my $n (0..$numCells-1){
       next if ($HasData[$n]);
       my ($i,$j)=$obj->getIjFromCellNumber($n);
       
       my $z = &idw($i,$j,\@PX,\@PY,\@PZ,12);
       print "idw for cell $n is $z\n";
       $DEP[$n]=$z;
    }
    

    # now put the DEP data into spatial dataset

    my $dataName='dep';
    $obj->{$dataName}={};
    $obj->{$dataName}->{datadims}={ 
                                    'datatype'=>0,
                                    'numrecs'=>1,
                                    'numflds'=>1,
                                    'ni'=>$ni,
                                    'nj'=>$nj,
                                    'dx'=>$dx,
                                    'dy'=>$dy,
                                    'gridname'=>'depthGrid'
                                  };
    $obj->{$dataName}->{datadims_keys}=['datatype','numrecs','numflds','ni','nj','dx','dy','gridname'];
    $obj->{$dataName}->{dataset}={
                                   'fldname(1)' =>  'depth' ,
                                   'fldunits(1)'=>  'm'    ,
                                   'recinc' => 1
                                 };
    $obj->{$dataName}->{dataset_keys}=['fldname(1)','fldunits(1)','recinc'];
 
    # now the data
    # one record
    # one field 
    my $field='depth';
    $obj->{$dataName}->{fieldNames}=[];
    push $obj->{$dataName}->{fieldNames},$field;
    $obj->{$dataName}->{$field}=\@DEP;
   
}


########################################################################
# sub writeDepFile
#
#  $stw->writeDepFile ('project.dep.in');
#
#
#
#
########################################################################
sub writeDepFile {
    my $obj=shift;
    my $fileName=shift;
    my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
    my $nj=$obj->{spatial_grid_parms}->{n_cell_j};

    unless ($fileName =~ m/^\'.+\'$/){
       $fileName="\'$fileName\'";
    }

    $fileName="\'project.dep.in\'" unless defined ($fileName);
  
    # set the filename in the global parameters
    $obj->{input_files}->{dep}=$fileName;

    my $dataName='dep';
    
    my $fname=$fileName;
    $fname =~ s/\'//g; 
   
    open DEP, ">$fname" or die "ERROR!: StwaveObj.pm:  cant open DEP file $fileName for writing\n"; 
    print "# DEP file\n";

    my @LISTS=( 'datadims','dataset');

    foreach my $listName (@LISTS){    
       # write some beginning comments
       print DEP "#\n";

       print "writing $listName\n";
       print DEP "\&$listName\n";
           
       my $numParms=@{$obj->{$dataName}->{"$listName".'_keys'}};
       my $n=1;
       foreach my $parm (@{$obj->{$dataName}->{"$listName".'_keys'}}){
           next unless defined ($obj->{$dataName}->{$listName}->{$parm});
           my $val= $obj->{$dataName}->{$listName}->{$parm};
           if ($val =~ m/[a-z]/i)   {      
              print DEP "  $parm = \'$val\'";
           }else{
              print DEP "  $parm = $val";
           }
           print DEP "," if ($n < $numParms);
           print DEP "\n";  
           $n++;             
       }
       print DEP "/\n";      
   }     
   # now the data
   #one record
   print DEP "IDD Constant_values\n";
   #loop over fields
   my @ALLFIELDS=();
   foreach my $field (@{$obj->{$dataName}->{fieldNames}}){
      push @ALLFIELDS,$obj->{$dataName}->{$field};
   }
   my $numCells=$ni*$nj;
   foreach my $n (0..$numCells-1){
      foreach my $f (0..$#ALLFIELDS){
         print DEP "$ALLFIELDS[$f][$n]\n";
      }
   }
  
   close (SIM);

}




#
#########################################################################   
# get spatial grid data by i,j values
#
# e.g. $data = $stw->getSpatialDataByIjRecField("DEP",$i,$j,1,"Depth");
#
# returns a list of valued from the selected grid cell
# one value for each IDD record
#########################################################################   
sub getSpatialDataByIjRecField {
   my $obj=shift;
   my ($dataName,$i,$j,$rec,$fieldName)=@_;
   $dataName=lc($dataName);
   my $ni=$obj->{$dataName}->{datadims}->{ni};
   my $nj=$obj->{$dataName}->{datadims}->{nj};
   my $cellNum=($i-1)+$ni*($nj-$j) + $ni*$nj*($rec-1);
   $fieldName=lc($fieldName);
  

   my $val=$obj->{$dataName}->{$fieldName}[$cellNum];
   return $val if (defined $val);
   return -99999;
}



#########################################################################   
# get spatial grid data by i,j values - ALL RECORDS All Fields
#
# e.g. my ($fieldNames,$idds,$data) = $stw->getSpatialDataByIjAllRecsAllFields("DEP",$i,$j);
#
# returns array references
# 
#   my @FIELDNAMES=@{$fieldNames};
#   my @IDDs=@{$idds};
#   my @DATA=@{$data};  # is an array of array refs
#
#   # to print it out as csv
#   my $fnames=join(',','IDD',@FIELDNAMES);
#    print "$fnames\n";
#    my $numFields=$#DATA;
#    my $numRecs=$#IDDs;
#    foreach my $rec (0..$numRecs){
#       print  "$IDDs[$rec]";
#       foreach my $fld (0..$numFields){
#           print  ",$DATA[$fld][$rec]";
#       }
#       print  "\n";
#    }      
#
#
#########################################################################   
sub getSpatialDataByIjAllRecsAllFields {
   my $obj=shift;
   my ($dataName,$i,$j)=@_;
   $dataName=lc($dataName);
   my $ni=$obj->{$dataName}->{datadims}->{ni};
   my $nj=$obj->{$dataName}->{datadims}->{nj};

   # if i,j is outside the domain get the closest cell
   $i=1 if ($i < 1 );
   $j=1 if ($j < 1 );
   $i=$ni if ($i > $ni);
   $j=$nj if ($j > $nj);
  
   #my $cellNum=($i-1)+$ni*($nj-$j) + $ni*$nj*($rec-1);
   # get all field names
   my @FIELDNAMES=@{$obj->{$dataName}->{fieldNames}};
   # get IDDs
   my @IDDs= @{$obj->{$dataName}->{idds}};
   # get number of records
   my $numRecs=$obj->{$dataName}->{datadims}->{numrecs};
  
   my @DATA=();
   foreach my $fieldName (@FIELDNAMES){
      my @THISFIELD=();
      my $cellNum=($i-1)+$ni*($nj-$j);
      foreach my $rec (1..$numRecs){
          push @THISFIELD,$obj->{$dataName}->{$fieldName}[$cellNum];
          $cellNum=$cellNum + $ni*$nj;
      }
      push @DATA,\@THISFIELD;
   }

 
   return \@FIELDNAMES,\@IDDs,\@DATA;
}


#########################################################################   
# get spatial grid data by x,y values
#
# e.g. $data = $stw->getSpatialDataByXyRecField("DEP",$x,$y,1,"Depth");
#
# returns a list of valued from the selected grid cell
# one value for each IDD recor 
#########################################################################   
sub getSpatialDataByXyRecField {  
   my $obj=shift;
   my ($dataName,$x,$y,$rec,$fieldName)=@_;
   $dataName=lc($dataName);
   my $theta=$obj->{spatial_grid_parms}->{azimuth};
   my $x0=$obj->{spatial_grid_parms}->{x0};
   my $y0=$obj->{spatial_grid_parms}->{y0};
   my $dx=$obj->{spatial_grid_parms}->{dx};
   my $dy=$obj->{spatial_grid_parms}->{dy};


   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};
 #  print "$nj $dx $dy\n";

   $theta =  $theta * $deg2rad;

   my $dxi=($x-$x0);
   my $dyi=($y0-$y);

   my $i=1 + int(($dxi*cos($theta) - $dyi*sin($theta))/$dx);
   return -99999 if (($i > $ni) or ($i < 1));
   my $j= 1 -  int(($dxi*sin($theta) + $dyi*cos($theta))/$dy)   ;
   return -99999 if (($j > $nj) or ($j < 1));
#   print "ij $i $j\n";
   
   my $data=$obj->getSpatialDataByIjRecField($dataName,$i,$j,$rec,$fieldName);
   return $data;
}

###################################################################
#
#  get i,j values for the cell that contains the a point
#
# e.g.  my $(i,j)=$stw->getIj($x,$y[,$dontLimitToInsideDomain]);
#
#       if optional $dontLimitToInsideDomain == 1
#       it will possibly return i,j values that are outside the
#       domain,   if its not provided, you'll get undef for points
#       that are outside the domain
#
#
####################################################################
sub getIj {  
   my $obj=shift;
   my ($x,$y)=@_;
   my ($dontLimitToInsideDomain)=shift;
   my $theta=$obj->{spatial_grid_parms}->{azimuth};
   my $x0=$obj->{spatial_grid_parms}->{x0};
   my $y0=$obj->{spatial_grid_parms}->{y0};
   my $dx=$obj->{spatial_grid_parms}->{dx};
   my $dy=$obj->{spatial_grid_parms}->{dy};

   $theta =  $theta * $deg2rad;

   my $dxi=($x-$x0);
   my $dyi=($y0-$y);

   my $i=1 + int(($dxi*cos($theta) - $dyi*sin($theta))/$dx);
   my $j= 1 -  int(($dxi*sin($theta) + $dyi*cos($theta))/$dy)   ;
  
   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};
 
   unless ( $dontLimitToInsideDomain ==1){
      return (undef,undef) if (($i > $ni) or ($i < 1));
      return (undef,undef) if (($j > $nj) or ($j < 1));
   }

   return ($i,$j);
}





#
###############################################
# get x,y value from the i,j values
###############################################
sub getXy{
    my $obj=shift;
    my ($i,$j)=@_;

    my $dx=$obj->{spatial_grid_parms}->{dx};
    my $dy=$obj->{spatial_grid_parms}->{dy};
    my $x0=$obj->{spatial_grid_parms}->{x0};
    my $y0=$obj->{spatial_grid_parms}->{y0};
    my $azimuth=$obj->{spatial_grid_parms}->{azimuth};
    
    my $theta = $azimuth * $deg2rad;

    my $dxni=$dx*($i-1);
    my $dynj=$dy*($j-1);
    #my $x=$x0+$dxni*cos($azimuth) - $dynj*sin($azimuth);
    #my $y=$y0+$dxni*sin($azimuth) + $dynj*cos($azimuth);
    my $x=$x0+$dxni*cos($theta) - $dynj*sin($theta);
    my $y=$y0+$dxni*sin($theta) + $dynj*cos($theta);
   
    return ($x,$y);
}




#################################################################
#
# get the corners and return north,south,east,west bounds
# and a polygon of the bounds
#
#  ($n,$e,$s,$w,$pxref,$pyref)=$stw->getBounds();
#
##################################################################

sub getBounds { 
    my $obj=shift;
    my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
    my $nj=$obj->{spatial_grid_parms}->{n_cell_j};
    


    #origin
    my $x0=$obj->{spatial_grid_parms}->{x0};
    my $y0=$obj->{spatial_grid_parms}->{y0};
    # far corner
    my ($x1,$y1)=$obj->getXy($ni,$nj);

    # bottom right 
    my ($x2,$y2)=$obj->getXy($ni,1);
  
    # bottom left

    my ($x3,$y3)=$obj->getXy(1,1);

    # upper left
    my ($x4,$y4)=$obj->getXy(1,$nj);

    my ($south,$north) = minmax($y0,$y1,$y2,$y3,$y4);
    my ($west,$east) = minmax($x0,$x1,$x2,$x3,$x4);
    
    my @PX=($x1,$x2,$x3,$x4);
    my @PY=($y1,$y2,$y3,$y4);


    return($north,$east,$south,$west,\@PX,\@PY) ; # never eat shredded wheat!
     
   
}


################################################
# get the corners of a cell
################################################
sub getCellCorners {
   my $obj=shift;
   my ($i,$j)=@_;

   my ($x1,$y1)=$obj->getXy($i-1.5,$j-1.5);
   my ($x2,$y2)=$obj->getXy($i-0.5,$j-1.5);
   my ($x3,$y3)=$obj->getXy($i-0.5,$j-0.5);
   my ($x4,$y4)=$obj->getXy($i-1.5,$j-0.5);
   
   return ($x1,$y1,$x2,$y2,$x3,$y3,$x4,$y4);
}   




##################################################
# get the ni, nj values
##################################################


sub getNiNj{
   my $obj=shift;
   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};

   return ($ni,$nj);
}

#########################################################
#
# $cellNum=getCellNumber($i,$j[,$rec]);
#
# returns the cell index for a cell (e.g. order in a dep file)
#
# $cellNum is zero referenced 
#
# $i,$j,$rec are assumed to start at 1 
#
#######################################################
sub getCellNumber{
   my $obj=shift; 
   my ($i,$j,$rec)=@_;
   
   $rec=1 unless (defined $rec);   

   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};
  
   my $cellNum=($i-1)+$ni*($nj-$j) + $ni*$nj*($rec-1);
   return ($cellNum);
}


sub getIjFromCellNumber {
   my $obj=shift;
   my $cellNum=shift;
   my $ni=$obj->{spatial_grid_parms}->{n_cell_i};
   my $nj=$obj->{spatial_grid_parms}->{n_cell_j};
   my $j=$nj-int($cellNum/$ni);
   my $i=$cellNum-$ni*($nj-$j)+1;
   return($i,$j);
}




#############################################
# return min and max values from an array
#############################################
sub minmax {
    my $min=$_[0];
    my $max=$_[0];
    foreach my $z (@_){
       $min=$z if ($z < $min);
       $max=$z if ($z > $max);
    }
    return ($min,$max);
}
   
 




######################################################################
sub trimStr 
{
   my $line=shift;
   $line=~ s/^\s+//;        
   $line=~ s/\s+$//; 
   $line=~ s/,//g;
   $line=~ s/"//g;
   $line=~ s/'//g;
   return ($line);
}


############################################################
# sub idw
#
# compute inverse distance weighted average at point $xp,$yp
# using set of points referenced by $Xref,$Yref,$Zref
#
# e.g.
# 
#  $zp = Interp::idw($xp,$yp,\@X,\@Y,\@Z,$power
#
#  $power is the power parameter for the weights
#
###########################################################
sub idw {
   my ($xp,$yp,$Xref,$Yref,$Zref,$power)=@_;;
   my @Y=@{$Yref};
   my @X=@{$Xref};
   my @Z=@{$Zref};
     $power=0.5*$power; 

   my $sumW=0;
   my $sum=0;
   #compute weights
   foreach my $n (0..$#Z) {
     
       my $w=1/(($X[$n]-$xp)**2.0 + ($Y[$n]-$yp)**2.0)**$power;
       $sum=$sum+$w*$Z[$n];
       $sumW=$sumW + $w;
   }

   my $result= $sum/$sumW;
   return $result;
}        






1;



