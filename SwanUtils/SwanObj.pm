package SwanObj;
#######################################################################
#
#  An object oriented Perl package for SWAN Modeling
#
#---------------------------------------------------------------------
#  useful for SWAN model pre and post processing, extracting data
#  from model spatial files, model creation and manipulation.
#
#
#  Example Usage:
#
#  [ for now just read the example usage for the various subs below ]
#
#
#
#
####################################################################### 
# Author: Nathan Dill, natedill@gmail.com
#
# Copyright (C) 2021 Nathan Dill, Ransom Consulting, Inc.
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
use GD;
use Math::Trig;
use Cwd qw(cwd);

#######################################################
# create new SWAN object from reading INPUT file
#
# e.g. my $swn=SwanObj->newFromINPUT("simname.sim");
#
sub newFromINPUT {
    my $class = shift;
    my $obj={};
    bless $obj, $class; 
    $obj->{INPUT}=shift;
    open IN, "<$obj->{INPUT}" or die "ERROR: cant open INPUT file $obj-{INPUT}\n";

    # load the commands from the INPUT file
    $obj->{COMMANDS}=[];
    while ( <IN> ){
        chomp;
        my $cmd=$_;
        $cmd =~ s/^\s+//;
        $cmd =~ s/\s+$//;
        $cmd =~ s/!.*//; # ignore comments
        next unless $cmd;
        while ($cmd =~ m/&$/){ # cat lines that end with &
            my $l=<IN>;
            $l =~ s/^\s+//;
            $l =~ s/\s+$//;
            $l =~ s/!.*//; # ignore comments
            next unless $l;
            $cmd =~ s/\&//;
            $cmd="$cmd "."$l";
        }
        push @{$obj->{COMMANDS}},$cmd;
        print "$cmd\n";
    }
    close(IN);

    return $obj;
}



sub getCGRID {

    my $obj=shift;
    foreach my $cmd (@{$obj->{COMMANDS}}){
   
        next unless ($cmd =~ m/^CGRID/i);
        my @words=split(/\s+/,$cmd);
        shift @words;
        my $type=shift @words;
        if ($type =~ m/reg/i){
            $obj->{CGRIDTYPE}='REG';
        }elsif ($type =~ m/curv/i){
            $obj->{CGRIDTYPE}='CURV';
        }elsif ($type =~ m/UNSTRUC/i){
            $obj->{CGRIDTYPE}='UNSTRUCT';
        }else{
            unshift @words,$type;
            $obj->{CGRIDTYPE}='REG'; # default
        }
        if ($obj->{CGRIDTYPE}=~ m/REG/i){
           $obj->{xpc}=shift @words;
           $obj->{ypc}=shift @words;
           $obj->{alpc}=shift @words;
           $obj->{xlenc}=shift @words;
           $obj->{ylenc}=shift @words;
           $obj->{mxc}=shift @words;
           $obj->{myc}=shift @words;
        }else{
            print "SwanObj not ready for $obj->{CGRIDTYPE} type spatial grid\n";
            return;
        }
        $obj->{DGRIDTYPE}=shift @words;
        unless ($obj->{DGRIDTYPE} =~ m/CIR/i){
            print "SwanObj not ready for $obj->{DGRIDTYPE} type directional grid\n";
        }
        $obj->{mdc}=shift @words;
        $obj->{flow}=shift @words;
        $obj->{fhigh}=shift @words;
        $obj->{msc}=shift @words;

        print "CGRID type is $obj->{CGRIDTYPE}, $obj->{DGRIDTYPE}\n";

        foreach my $key ('xpc','ypc','alpc','xlenc','ylenc','mxc','myc','mdc','flow','fhigh','msc'){
            print "$key :: $obj->{$key}\n";
        }
        last;
    }
}


# at this point assumes spherical coords and just one point per output file
sub loadSpec2d{
    my $obj=shift;
    $obj->{nspec2d}=0;
    $obj->{SPEC2D}={};
    $obj->{SPEC2DFILES}=[];
    $obj->{SPEC2DSNAMES}=[];
    $obj->{FREQBINS}=[];
    $obj->{DIRBINS}=[];
    # go through the commands to see if spectral output was requested
    foreach my $cmd (@{$obj->{COMMANDS}}){
       next unless( $cmd =~ m/^SPEC/ );
       next unless( $cmd =~ m/SPEC2D/ );
       $obj->{nspec2d}++;
       my ($j1,$name,$j2,$abs_rel,$fname,$j3,$begtime,$out_dt,$tunit)=split(/\s+/,$cmd);
       $fname =~ s/'//g;
       push @{$obj->{SPEC2DFILES}},$fname;
       push @{$obj->{SPEC2DSNAMES}},$name;
    }
    # now read the spectra
    my @SNAMES=@{$obj->{SPEC2DSNAMES}};
    foreach my $fname (@{$obj->{SPEC2DFILES}}) {
         my $sname=shift(@SNAMES);
         $sname =~ s/'//g;
         print "Reading 2d spectrum for site $sname from file $fname\n";
         open IN, "<$fname" or die "cant open 2d spectrum output file $fname\n";
         my $ndir;
         my $nfreq;
         $obj->{SPEC2D}->{$sname}={};
         $obj->{SPEC2D}->{$sname}->{MAXENG}=0;
         while (my $ln = <IN>){ 
             chomp $ln;
             $ln =~ s/^\s+//;
             $ln =~ s/\s+$//;
print "::$ln\n";


             # get the coordinates
             if ($ln =~ /^LONLAT/){
                $ln =<IN>;
                $ln =~ s/^\s+//;
                $ln =~ s/\s+$//;
                $obj->{SPEC2D}->{$sname}->{COORDS}=$ln;
                next;
             }
             # get the FREQ bins
             if ($ln =~ /^AFREQ/){
                $ln=<IN>;
                $ln =~ s/^\s+//;
                $ln =~ s/\s+$//;
                ($nfreq)=split(/\s+/,$ln);
                print "AFREQ : $ln\n";
                #($obj->{NFREQ})=$nfreq;
                foreach my $n (1..$nfreq){
                   $ln=<IN>;
                   $ln =~ s/^\s+//;
                   $ln =~ s/\s+$//;
                   push @{$obj->{FREQBINS}}, $ln;
                }
                next;
             }
             # get the DIR bins
             if ($ln =~ /^CDIR/){
                $ln=<IN>;
                $ln =~ s/^\s+//;
                $ln =~ s/\s+$//;
                ($ndir)=split(/\s+/,$ln);
                #($obj->{NDIR})=$ndir;
                foreach my $n (1..$ndir){
                   $ln = <IN>;
                   $ln =~ s/^\s+//;
                   $ln =~ s/\s+$//;
                print "CDIR : $ln\n";
                   push @{$obj->{DIRBINS}}, $ln;
                }
                next;
             }
             # read the spectra
           if ($ndir){ 
             $obj->{SPEC2D}->{$sname}->{TIMES}=[];
             $obj->{SPEC2D}->{$sname}->{SPEC}={};
             print "nfrq is $nfreq ndir is $ndir\n";
             while($ln = <IN>){
                $ln =~ s/^\s+//;
                $ln =~ s/\s+$//;
                if ($ln =~ m/^(\d\d\d\d\d\d\d\d.\d\d\d\d\d\d)/){
                   my $time=$1;
                   push @{$obj->{SPEC2D}->{$sname}->{TIMES}},$time;
                   $obj->{SPEC2D}->{$sname}->{SPEC}->{$time}=[];
                   print "reading $sname time $time\n";
                   $ln = <IN>; # skip 'FFACTOR' line
                   $ln = <IN>;
                   $ln =~ s/^\s+//;
                   $ln =~ s/\s+$//;
                   my $ffactor=$ln;
                   #$ffactor=1;
                   foreach my $f (1..$nfreq){
                      $ln =  <IN>;
                      $ln =~ s/^\s+//;
                      $ln =~ s/\s+$//;
                      my (@data)=split(/\s+/,$ln);
                      foreach my $k (0..$#data){
                          $data[$k]=$data[$k]*$ffactor;
                          $obj->{SPEC2D}->{$sname}->{MAXENG}=$data[$k] if ($data[$k] > $obj->{SPEC2D}->{$sname}->{MAXENG});
                      }
                      push @{$obj->{SPEC2D}->{$sname}->{SPEC}->{$time}}, \@data;
                      print "data @data\n";
                   }
                }
             }
             last;
            } #if ndir
         } # big while loop over file
         close (IN);
    } # loop over spec files
}



# e.g. ($eng,$dir,$freq)=$obj->get2dEng('SITE1','19800101.100000',355,0.05);
# dir and freq returned will be the next highest bin if not an exact match
sub get2dENG{
    my $obj=shift;
    my $sname=shift;
    my $time=shift;
    my $dir=shift;
    my $freq=shift;
    #find index of the dir
    my $idir=0;
    foreach my $dbin (@{$obj->{DIRBINS}}){
       last if $dbin >= $dir;
       $idir++;
    }
    $dir=$obj->{DIRBINS}[$idir];
    my $ifreq=0;
    foreach my $fbin (@{$obj->{FREQBINS}}){
       last if $fbin >= $freq;
       $ifreq++;
    }
    $freq=$obj->{FREQBINS}[$ifreq];
    #my $eng=$obj->{SPEC2D}->{$sname}->{SPEC}->{$time}->[$ifreq][$idir];
    print "idir $idir, ifreq $ifreq\n";
    my $eng=$obj->{SPEC2D}->{$sname}->{SPEC}->{$time}->[$ifreq][$idir];
 
    return ($eng,$dir,$freq);
}




1;



