#!usr/bin/env perl

use warnings;
use strict;
use GD;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Path;


print "enter name of xyz file:\n";
my $xyzFile='elev_stat.151';
chomp $xyzFile;  #remove newline character

print "enter number of headerlines to skip in $xyzFile\n";
my $headerlines=1;
chomp $headerlines;

print "enter name of kml polygon file for selecting points (blank if no polygon):\n";
my $polygonFile='';
chomp $polygonFile;

print "enter name for output kmz file:\n";
my $outkmz='elev_stat.kmz';
chomp $outkmz;
my $outkml=$outkmz;
$outkml =~ s/\.kmz$/\.kml/;

#print "enter z value for lower color limit:";
#my $cll=<>;
#chomp $cll;
#print "enter z value for upper color limit:";
#my $cul=<>;
#chomp $cul;




# make the icon png files
mkdir "Files";
&makeColorDots;


# read the polygon 
my $havePoly=0;
my $pxref;
my $pyref;
unless ($polygonFile eq ''){
   $havePoly=1;
   ($pxref,$pyref)=&readKmlPoly($polygonFile);
}
      

# get min and max for color limits
open FILE1, "<$xyzFile" or die "cant open $xyzFile\n";
my $cnt=$headerlines;
while ($cnt--){
  <FILE1>;
}
my $cll=99e99;
my $cul=-99e99;


# also read and store all the data in the polygon 
my @Lines;

while (<FILE1>){
 
   chomp ($_);
   $_=~ s/^\s+//;          # remove leading  whitespace
   $_ =~ s/\s+$//;    
   my @data = split(/\s+|,/,$_); # split on whitespace or comma
   my ($x,$y,$desc)=@data;
  
   my $inpoly=1;
   if ($havePoly){
       $inpoly=&pointInPoly($x,$y,$pxref,$pyref);
   }
   next unless ($inpoly);

   #$cll=$z if ( $z < $cll);
   #$cul=$z if ( $z > $cul);
   push @Lines, $_;

} 
close (FILE1);



#open FILE, "<$xyzFile" or die "cant open $xyzFile\n";
open OUT, ">$outkml" or die "cant open $outkml\n";


#write initilization in kml
print OUT '<?xml version="1.0" encoding="UTF-8"?>'."\n";
print OUT '<kml xmlns="http://www.opengis.net/kml/2.2">'."\n";
print OUT "   <Document>\n";

#write styles
my $color=0;
while ($color<=255) {	 
  my $style="Style$color";  
  my $pngFile="$color.png";
  print OUT "    <Style id=\"$style\">\n";
  print OUT "      <IconStyle>\n";
  print OUT "         <Icon><href>Files/$pngFile</href></Icon>\n";
  print OUT "         <scale>0.5</scale>\n";
  print OUT "      </IconStyle>\n";
  print OUT "      <BalloonStyle>\n";
  print OUT '         <text>$[description]</text>\n';
  print OUT "      </BalloonStyle>\n";
  print OUT "    </Style>\n";
  $color++;
}



# loop through points in xyz file
#while ($headerlines--){
#  my $line= <FILE>;
#  
#}

#while (<FILE>){
my $n=0;
foreach my $line (@Lines){
   $n++;
   my @data = split(/\s+|,/,$line); # split on whitespace or comma
   my ($x,$y)=@data;
 my $z=0;
   # figure out whats left on the line and put it in the description
   my $desc=$line;
   $desc =~ s/^$x//;
   $desc =~ s/^\s*,//;
   $desc =~ s/^$y//;
   $desc =~ s/^\s*,//;
   $desc =~ s/^$z//;
   $desc =~ s/\s+//;

   $desc='' unless defined ($desc);

   my $inpoly=1;
   if ($havePoly){
       $inpoly=&pointInPoly($x,$y,$pxref,$pyref);
   }

   next unless ($inpoly);

   my $style=1;
   $style = 255 if ($style > 255);
   $style = 1   if ($style <1) ; 
   print OUT "     <Placemark>\n";
   print OUT "        <name></name>\n";
   print OUT "        <styleUrl>#Style$style</styleUrl>\n";
   print OUT "        <description>\n";
   print OUT "         <p><b>$n - $desc</b></p>\n";
   my $elevstring=sprintf ("%7.3f",$z);
   print OUT "         <p><b>Z value: </b><br/>$elevstring</p>\n";
   print OUT "        </description>\n";
   print OUT "        <Point>\n ";
   print OUT "          <coordinates>$x,$y,$z</coordinates>\n";
   print OUT "        </Point>\n";
   print OUT "     </Placemark>\n";

}

print OUT " </Document>\n";
print OUT "</kml>\n";


#close (FILE);
close (OUT);

my $zip = Archive::Zip->new();

 # add the Files Dir
 my $dir_member = $zip->addTree( 'Files', 'Files' );

 # add the doc.file
 my $file_member = $zip->addFile($outkml);

 # write it
   unless ( $zip->writeToFileNamed($outkmz) == AZ_OK ) {
       die 'write error';
   }
 


unlink ($outkml);
 rmtree("Files");

##################################################################################


















sub pointInPoly {  # $x $y \@px \@py    note: polygon described by vectors px,py must be closed 
   
   my $crs;
   my $inPoly=0;
	
   my $x = $_[0];
   my $y = $_[1];
   my @px = @{$_[2]}; # dereference to get arrays from argument
   my @py = @{$_[3]};
   
   my $nsegs=@px;

   my $wn=0;   # the winding number

   my $i=0;
   while ($i<$nsegs-1) {
        
     # test if at least one vertex is right of the point
     if ( ($px[$i] > $x) ||  ($px[$i+1] > $x) ) {

	 if (     ($py[$i] < $y) && ($py[$i+1] > $y) ) {  # this one crosses
            $crs= ($px[$i]-$x)*($py[$i+1]-$y) - ($px[$i+1]-$x)*($py[$i]-$y) ;
	    $wn++ if ($crs > 0) ; # upward cross on the right
         }elsif (($py[$i] > $y) && ($py[$i+1] < $y) ) {
            $crs= ($px[$i]-$x)*($py[$i+1]-$y) - ($px[$i+1]-$x)*($py[$i]-$y) ;
	    $wn-- if ($crs < 0); #downward cross on the right
         }
      }
      $i++;
   }
   $inPoly=1 if ($wn !=  0);

   return $inPoly;

}



#########################################################




sub readKmlPoly { 

   my $polygonFile=shift;
   my @px;           # dereference to access arrays
   my @py;

   open PFILE, "<$polygonFile"  or die "cannot open $polygonFile\n";

   # read the data, assume first point in repeated as last

   my $inCoord=0;
   my $coordString='';

   # try to parse the coordinates data from the kml file

   while (<PFILE>) {
      chomp;
      $_ =~ s/^\s+//;
      $_ =~ s/\s+$//;
      if   ($_ =~ /<coordinates>/) {
         $inCoord=1;
      }
      if ($inCoord==1) {
	   $coordString="$coordString"." $_";
	   if ($_ =~ /<\/coordinates>/) {
		   $inCoord=2;
           }
      }
      last if ($inCoord==2);
   #   print "$coordString\n";
   #   sleep(1);
   }

   # remove the tags from the string
   $coordString =~ /<coordinates>(.*)<\/coordinates>/; 
   $coordString = $1;
   $coordString =~ s/^\s+//;
   $coordString =~ s/\s+$//;

   my @data=split(/\s+/,$coordString);

   foreach my $coord (@data) {
        my ($x,$y,$z)=split(/,/,$coord);
        push (@px,$x);
        push (@py,$y);
   }     

   close PFILE;
   return (\@px,\@py);
} # end readKMLPoly






####################################################
# sub makeColorDots()
#
# this subroutine makes a bunch of png files with color dots
#
################################################ 

sub makeColorDots {

  my $xpix=64;
  my $ypix=64;
  my $imid=$xpix/2;
  my $jmid=$ypix/2;

  my $color=255;

  while ($color>0) {

     my $im = new GD::Image($xpix,$ypix);
        &setColors($im);	 
      
	
        my $i;
        my $j =  0;
        my $cnt = 0;	
	while ($j<$ypix) {
	      $i=0;	
              while ($i<$xpix) {
                    my $r = sqrt(($i-$imid)**2 + ($j-$jmid)**2);
		     
		    if ($r<$imid) {
                       $im->setPixel($i,$j,$color);   #set the pixel color based on the map
	            }else{
                       $im->setPixel($i,$j,0);   #set the pixel color based on the map
	            }
		  $i++;
	      }
	      $j++;
        }

        # now write the png file
	my $pngFile= "Files/$color.png";
	open FILE2, ">$pngFile";
	binmode FILE2;
	print FILE2 $im->png;
	close(FILE2);
        $im=undef;

	$color--;
  }

}



#####################################################
# sub setColors() 
#
# used by _makePNG to allocate the color map for png files
####################################################
sub setColors {
      my($im) = shift;
      my @color;
      my $alpha=0;
      $color[0] = $im->colorAllocateAlpha(0,0,131,127);
      $color[1] = $im->colorAllocateAlpha(0,0,135,$alpha);
      $color[2] = $im->colorAllocateAlpha(0,0,139,$alpha);
      $color[3] = $im->colorAllocateAlpha(0,0,143,$alpha);
      $color[4] = $im->colorAllocateAlpha(0,0,147,$alpha);
      $color[5] = $im->colorAllocateAlpha(0,0,151,$alpha);
      $color[6] = $im->colorAllocateAlpha(0,0,155,$alpha);
      $color[7] = $im->colorAllocateAlpha(0,0,159,$alpha);
      $color[8] = $im->colorAllocateAlpha(0,0,163,$alpha);
      $color[9] = $im->colorAllocateAlpha(0,0,167,$alpha);
      $color[10] = $im->colorAllocateAlpha(0,0,171,$alpha);
      $color[11] = $im->colorAllocateAlpha(0,0,175,$alpha);
      $color[12] = $im->colorAllocateAlpha(0,0,179,$alpha);
      $color[13] = $im->colorAllocateAlpha(0,0,183,$alpha);
      $color[14] = $im->colorAllocateAlpha(0,0,187,$alpha);
      $color[15] = $im->colorAllocateAlpha(0,0,191,$alpha);
      $color[16] = $im->colorAllocateAlpha(0,0,195,$alpha);
      $color[17] = $im->colorAllocateAlpha(0,0,199,$alpha);
      $color[18] = $im->colorAllocateAlpha(0,0,203,$alpha);
      $color[19] = $im->colorAllocateAlpha(0,0,207,$alpha);
      $color[20] = $im->colorAllocateAlpha(0,0,211,$alpha);
      $color[21] = $im->colorAllocateAlpha(0,0,215,$alpha);
      $color[22] = $im->colorAllocateAlpha(0,0,219,$alpha);
      $color[23] = $im->colorAllocateAlpha(0,0,223,$alpha);
      $color[24] = $im->colorAllocateAlpha(0,0,227,$alpha);
      $color[25] = $im->colorAllocateAlpha(0,0,231,$alpha);
      $color[26] = $im->colorAllocateAlpha(0,0,235,$alpha);
      $color[27] = $im->colorAllocateAlpha(0,0,239,$alpha);
      $color[28] = $im->colorAllocateAlpha(0,0,243,$alpha);
      $color[29] = $im->colorAllocateAlpha(0,0,247,$alpha);
      $color[30] = $im->colorAllocateAlpha(0,0,251,$alpha);
      $color[31] = $im->colorAllocateAlpha(0,0,255,$alpha);
      $color[32] = $im->colorAllocateAlpha(0,4,255,$alpha);
      $color[33] = $im->colorAllocateAlpha(0,8,255,$alpha);
      $color[34] = $im->colorAllocateAlpha(0,12,255,$alpha);
      $color[35] = $im->colorAllocateAlpha(0,16,255,$alpha);
      $color[36] = $im->colorAllocateAlpha(0,20,255,$alpha);
      $color[37] = $im->colorAllocateAlpha(0,24,255,$alpha);
      $color[38] = $im->colorAllocateAlpha(0,28,255,$alpha);
      $color[39] = $im->colorAllocateAlpha(0,32,255,$alpha);
      $color[40] = $im->colorAllocateAlpha(0,36,255,$alpha);
      $color[41] = $im->colorAllocateAlpha(0,40,255,$alpha);
      $color[42] = $im->colorAllocateAlpha(0,44,255,$alpha);
      $color[43] = $im->colorAllocateAlpha(0,48,255,$alpha);
      $color[44] = $im->colorAllocateAlpha(0,52,255,$alpha);
      $color[45] = $im->colorAllocateAlpha(0,56,255,$alpha);
      $color[46] = $im->colorAllocateAlpha(0,60,255,$alpha);
      $color[47] = $im->colorAllocateAlpha(0,64,255,$alpha);
      $color[48] = $im->colorAllocateAlpha(0,68,255,$alpha);
      $color[49] = $im->colorAllocateAlpha(0,72,255,$alpha);
      $color[50] = $im->colorAllocateAlpha(0,76,255,$alpha);
      $color[51] = $im->colorAllocateAlpha(0,80,255,$alpha);
      $color[52] = $im->colorAllocateAlpha(0,84,255,$alpha);
      $color[53] = $im->colorAllocateAlpha(0,88,255,$alpha);
      $color[54] = $im->colorAllocateAlpha(0,92,255,$alpha);
      $color[55] = $im->colorAllocateAlpha(0,96,255,$alpha);
      $color[56] = $im->colorAllocateAlpha(0,100,255,$alpha);
      $color[57] = $im->colorAllocateAlpha(0,104,255,$alpha);
      $color[58] = $im->colorAllocateAlpha(0,108,255,$alpha);
      $color[59] = $im->colorAllocateAlpha(0,112,255,$alpha);
      $color[60] = $im->colorAllocateAlpha(0,116,255,$alpha);
      $color[61] = $im->colorAllocateAlpha(0,120,255,$alpha);
      $color[62] = $im->colorAllocateAlpha(0,124,255,$alpha);
      $color[63] = $im->colorAllocateAlpha(0,128,255,$alpha);
      $color[64] = $im->colorAllocateAlpha(0,131,255,$alpha);
      $color[65] = $im->colorAllocateAlpha(0,135,255,$alpha);
      $color[66] = $im->colorAllocateAlpha(0,139,255,$alpha);
      $color[67] = $im->colorAllocateAlpha(0,143,255,$alpha);
      $color[68] = $im->colorAllocateAlpha(0,147,255,$alpha);
      $color[69] = $im->colorAllocateAlpha(0,151,255,$alpha);
      $color[70] = $im->colorAllocateAlpha(0,155,255,$alpha);
      $color[71] = $im->colorAllocateAlpha(0,159,255,$alpha);
      $color[72] = $im->colorAllocateAlpha(0,163,255,$alpha);
      $color[73] = $im->colorAllocateAlpha(0,167,255,$alpha);
      $color[74] = $im->colorAllocateAlpha(0,171,255,$alpha);
      $color[75] = $im->colorAllocateAlpha(0,175,255,$alpha);
      $color[76] = $im->colorAllocateAlpha(0,179,255,$alpha);
      $color[77] = $im->colorAllocateAlpha(0,183,255,$alpha);
      $color[78] = $im->colorAllocateAlpha(0,187,255,$alpha);
      $color[79] = $im->colorAllocateAlpha(0,191,255,$alpha);
      $color[80] = $im->colorAllocateAlpha(0,195,255,$alpha);
      $color[81] = $im->colorAllocateAlpha(0,199,255,$alpha);
      $color[82] = $im->colorAllocateAlpha(0,203,255,$alpha);
      $color[83] = $im->colorAllocateAlpha(0,207,255,$alpha);
      $color[84] = $im->colorAllocateAlpha(0,211,255,$alpha);
      $color[85] = $im->colorAllocateAlpha(0,215,255,$alpha);
      $color[86] = $im->colorAllocateAlpha(0,219,255,$alpha);
      $color[87] = $im->colorAllocateAlpha(0,223,255,$alpha);
      $color[88] = $im->colorAllocateAlpha(0,227,255,$alpha);
      $color[89] = $im->colorAllocateAlpha(0,231,255,$alpha);
      $color[90] = $im->colorAllocateAlpha(0,235,255,$alpha);
      $color[91] = $im->colorAllocateAlpha(0,239,255,$alpha);
      $color[92] = $im->colorAllocateAlpha(0,243,255,$alpha);
      $color[93] = $im->colorAllocateAlpha(0,247,255,$alpha);
      $color[94] = $im->colorAllocateAlpha(0,251,255,$alpha);
      $color[95] = $im->colorAllocateAlpha(0,255,255,$alpha);
      $color[96] = $im->colorAllocateAlpha(4,255,251,$alpha);
      $color[97] = $im->colorAllocateAlpha(8,255,247,$alpha);
      $color[98] = $im->colorAllocateAlpha(12,255,243,$alpha);
      $color[99] = $im->colorAllocateAlpha(16,255,239,$alpha);
      $color[100] = $im->colorAllocateAlpha(20,255,235,$alpha);
      $color[101] = $im->colorAllocateAlpha(24,255,231,$alpha);
      $color[102] = $im->colorAllocateAlpha(28,255,227,$alpha);
      $color[103] = $im->colorAllocateAlpha(32,255,223,$alpha);
      $color[104] = $im->colorAllocateAlpha(36,255,219,$alpha);
      $color[105] = $im->colorAllocateAlpha(40,255,215,$alpha);
      $color[106] = $im->colorAllocateAlpha(44,255,211,$alpha);
      $color[107] = $im->colorAllocateAlpha(48,255,207,$alpha);
      $color[108] = $im->colorAllocateAlpha(52,255,203,$alpha);
      $color[109] = $im->colorAllocateAlpha(56,255,199,$alpha);
      $color[110] = $im->colorAllocateAlpha(60,255,195,$alpha);
      $color[111] = $im->colorAllocateAlpha(64,255,191,$alpha);
      $color[112] = $im->colorAllocateAlpha(68,255,187,$alpha);
      $color[113] = $im->colorAllocateAlpha(72,255,183,$alpha);
      $color[114] = $im->colorAllocateAlpha(76,255,179,$alpha);
      $color[115] = $im->colorAllocateAlpha(80,255,175,$alpha);
      $color[116] = $im->colorAllocateAlpha(84,255,171,$alpha);
      $color[117] = $im->colorAllocateAlpha(88,255,167,$alpha);
      $color[118] = $im->colorAllocateAlpha(92,255,163,$alpha);
      $color[119] = $im->colorAllocateAlpha(96,255,159,$alpha);
      $color[120] = $im->colorAllocateAlpha(100,255,155,$alpha);
      $color[121] = $im->colorAllocateAlpha(104,255,151,$alpha);
      $color[122] = $im->colorAllocateAlpha(108,255,147,$alpha);
      $color[123] = $im->colorAllocateAlpha(112,255,143,$alpha);
      $color[124] = $im->colorAllocateAlpha(116,255,139,$alpha);
      $color[125] = $im->colorAllocateAlpha(120,255,135,$alpha);
      $color[126] = $im->colorAllocateAlpha(124,255,131,$alpha);
      $color[127] = $im->colorAllocateAlpha(128,255,128,$alpha);
      $color[128] = $im->colorAllocateAlpha(131,255,124,$alpha);
      $color[129] = $im->colorAllocateAlpha(135,255,120,$alpha);
      $color[130] = $im->colorAllocateAlpha(139,255,116,$alpha);
      $color[131] = $im->colorAllocateAlpha(143,255,112,$alpha);
      $color[132] = $im->colorAllocateAlpha(147,255,108,$alpha);
      $color[133] = $im->colorAllocateAlpha(151,255,104,$alpha);
      $color[134] = $im->colorAllocateAlpha(155,255,100,$alpha);
      $color[135] = $im->colorAllocateAlpha(159,255,96,$alpha);
      $color[136] = $im->colorAllocateAlpha(163,255,92,$alpha);
      $color[137] = $im->colorAllocateAlpha(167,255,88,$alpha);
      $color[138] = $im->colorAllocateAlpha(171,255,84,$alpha);
      $color[139] = $im->colorAllocateAlpha(175,255,80,$alpha);
      $color[140] = $im->colorAllocateAlpha(179,255,76,$alpha);
      $color[141] = $im->colorAllocateAlpha(183,255,72,$alpha);
      $color[142] = $im->colorAllocateAlpha(187,255,68,$alpha);
      $color[143] = $im->colorAllocateAlpha(191,255,64,$alpha);
      $color[144] = $im->colorAllocateAlpha(195,255,60,$alpha);
      $color[145] = $im->colorAllocateAlpha(199,255,56,$alpha);
      $color[146] = $im->colorAllocateAlpha(203,255,52,$alpha);
      $color[147] = $im->colorAllocateAlpha(207,255,48,$alpha);
      $color[148] = $im->colorAllocateAlpha(211,255,44,$alpha);
      $color[149] = $im->colorAllocateAlpha(215,255,40,$alpha);
      $color[150] = $im->colorAllocateAlpha(219,255,36,$alpha);
      $color[151] = $im->colorAllocateAlpha(223,255,32,$alpha);
      $color[152] = $im->colorAllocateAlpha(227,255,28,$alpha);
      $color[153] = $im->colorAllocateAlpha(231,255,24,$alpha);
      $color[154] = $im->colorAllocateAlpha(235,255,20,$alpha);
      $color[155] = $im->colorAllocateAlpha(239,255,16,$alpha);
      $color[156] = $im->colorAllocateAlpha(243,255,12,$alpha);
      $color[157] = $im->colorAllocateAlpha(247,255,8,$alpha);
      $color[158] = $im->colorAllocateAlpha(251,255,4,$alpha);
      $color[159] = $im->colorAllocateAlpha(255,255,0,$alpha);
      $color[160] = $im->colorAllocateAlpha(255,251,0,$alpha);
      $color[161] = $im->colorAllocateAlpha(255,247,0,$alpha);
      $color[162] = $im->colorAllocateAlpha(255,243,0,$alpha);
      $color[163] = $im->colorAllocateAlpha(255,239,0,$alpha);
      $color[164] = $im->colorAllocateAlpha(255,235,0,$alpha);
      $color[165] = $im->colorAllocateAlpha(255,231,0,$alpha);
      $color[166] = $im->colorAllocateAlpha(255,227,0,$alpha);
      $color[167] = $im->colorAllocateAlpha(255,223,0,$alpha);
      $color[168] = $im->colorAllocateAlpha(255,219,0,$alpha);
      $color[169] = $im->colorAllocateAlpha(255,215,0,$alpha);
      $color[170] = $im->colorAllocateAlpha(255,211,0,$alpha);
      $color[171] = $im->colorAllocateAlpha(255,207,0,$alpha);
      $color[172] = $im->colorAllocateAlpha(255,203,0,$alpha);
      $color[173] = $im->colorAllocateAlpha(255,199,0,$alpha);
      $color[174] = $im->colorAllocateAlpha(255,195,0,$alpha);
      $color[175] = $im->colorAllocateAlpha(255,191,0,$alpha);
      $color[176] = $im->colorAllocateAlpha(255,187,0,$alpha);
      $color[177] = $im->colorAllocateAlpha(255,183,0,$alpha);
      $color[178] = $im->colorAllocateAlpha(255,179,0,$alpha);
      $color[179] = $im->colorAllocateAlpha(255,175,0,$alpha);
      $color[180] = $im->colorAllocateAlpha(255,171,0,$alpha);
      $color[181] = $im->colorAllocateAlpha(255,167,0,$alpha);
      $color[182] = $im->colorAllocateAlpha(255,163,0,$alpha);
      $color[183] = $im->colorAllocateAlpha(255,159,0,$alpha);
      $color[184] = $im->colorAllocateAlpha(255,155,0,$alpha);
      $color[185] = $im->colorAllocateAlpha(255,151,0,$alpha);
      $color[186] = $im->colorAllocateAlpha(255,147,0,$alpha);
      $color[187] = $im->colorAllocateAlpha(255,143,0,$alpha);
      $color[188] = $im->colorAllocateAlpha(255,139,0,$alpha);
      $color[189] = $im->colorAllocateAlpha(255,135,0,$alpha);
      $color[190] = $im->colorAllocateAlpha(255,131,0,$alpha);
      $color[191] = $im->colorAllocateAlpha(255,128,0,$alpha);
      $color[192] = $im->colorAllocateAlpha(255,124,0,$alpha);
      $color[193] = $im->colorAllocateAlpha(255,120,0,$alpha);
      $color[194] = $im->colorAllocateAlpha(255,116,0,$alpha);
      $color[195] = $im->colorAllocateAlpha(255,112,0,$alpha);
      $color[196] = $im->colorAllocateAlpha(255,108,0,$alpha);
      $color[197] = $im->colorAllocateAlpha(255,104,0,$alpha);
      $color[198] = $im->colorAllocateAlpha(255,100,0,$alpha);
      $color[199] = $im->colorAllocateAlpha(255,96,0,$alpha);
      $color[200] = $im->colorAllocateAlpha(255,92,0,$alpha);
      $color[201] = $im->colorAllocateAlpha(255,88,0,$alpha);
      $color[202] = $im->colorAllocateAlpha(255,84,0,$alpha);
      $color[203] = $im->colorAllocateAlpha(255,80,0,$alpha);
      $color[204] = $im->colorAllocateAlpha(255,76,0,$alpha);
      $color[205] = $im->colorAllocateAlpha(255,72,0,$alpha);
      $color[206] = $im->colorAllocateAlpha(255,68,0,$alpha);
      $color[207] = $im->colorAllocateAlpha(255,64,0,$alpha);
      $color[208] = $im->colorAllocateAlpha(255,60,0,$alpha);
      $color[209] = $im->colorAllocateAlpha(255,56,0,$alpha);
      $color[210] = $im->colorAllocateAlpha(255,52,0,$alpha);
      $color[211] = $im->colorAllocateAlpha(255,48,0,$alpha);
      $color[212] = $im->colorAllocateAlpha(255,44,0,$alpha);
      $color[213] = $im->colorAllocateAlpha(255,40,0,$alpha);
      $color[214] = $im->colorAllocateAlpha(255,36,0,$alpha);
      $color[215] = $im->colorAllocateAlpha(255,32,0,$alpha);
      $color[216] = $im->colorAllocateAlpha(255,28,0,$alpha);
      $color[217] = $im->colorAllocateAlpha(255,24,0,$alpha);
      $color[218] = $im->colorAllocateAlpha(255,20,0,$alpha);
      $color[219] = $im->colorAllocateAlpha(255,16,0,$alpha);
      $color[220] = $im->colorAllocateAlpha(255,12,0,$alpha);
      $color[221] = $im->colorAllocateAlpha(255,8,0,$alpha);
      $color[222] = $im->colorAllocateAlpha(255,4,0,$alpha);
      $color[223] = $im->colorAllocateAlpha(255,0,0,$alpha);
      $color[224] = $im->colorAllocateAlpha(251,0,0,$alpha);
      $color[225] = $im->colorAllocateAlpha(247,0,0,$alpha);
      $color[226] = $im->colorAllocateAlpha(243,0,0,$alpha);
      $color[227] = $im->colorAllocateAlpha(239,0,0,$alpha);
      $color[228] = $im->colorAllocateAlpha(235,0,0,$alpha);
      $color[229] = $im->colorAllocateAlpha(231,0,0,$alpha);
      $color[230] = $im->colorAllocateAlpha(227,0,0,$alpha);
      $color[231] = $im->colorAllocateAlpha(223,0,0,$alpha);
      $color[232] = $im->colorAllocateAlpha(219,0,0,$alpha);
      $color[233] = $im->colorAllocateAlpha(215,0,0,$alpha);
      $color[234] = $im->colorAllocateAlpha(211,0,0,$alpha);
      $color[235] = $im->colorAllocateAlpha(207,0,0,$alpha);
      $color[236] = $im->colorAllocateAlpha(203,0,0,$alpha);
      $color[237] = $im->colorAllocateAlpha(199,0,0,$alpha);
      $color[238] = $im->colorAllocateAlpha(195,0,0,$alpha);
      $color[239] = $im->colorAllocateAlpha(191,0,0,$alpha);
      $color[240] = $im->colorAllocateAlpha(187,0,0,$alpha);
      $color[241] = $im->colorAllocateAlpha(183,0,0,$alpha);
      $color[242] = $im->colorAllocateAlpha(179,0,0,$alpha);
      $color[243] = $im->colorAllocateAlpha(175,0,0,$alpha);
      $color[244] = $im->colorAllocateAlpha(171,0,0,$alpha);
      $color[245] = $im->colorAllocateAlpha(167,0,0,$alpha);
      $color[246] = $im->colorAllocateAlpha(163,0,0,$alpha);
      $color[247] = $im->colorAllocateAlpha(159,0,0,$alpha);
      $color[248] = $im->colorAllocateAlpha(155,0,0,$alpha);
      $color[249] = $im->colorAllocateAlpha(151,0,0,$alpha);
      $color[250] = $im->colorAllocateAlpha(147,0,0,$alpha);
      $color[251] = $im->colorAllocateAlpha(143,0,0,$alpha);
      $color[252] = $im->colorAllocateAlpha(139,0,0,$alpha);
      $color[253] = $im->colorAllocateAlpha(135,0,0,$alpha);
      $color[254] = $im->colorAllocateAlpha(131,0,0,$alpha);
      $color[255] = $im->colorAllocateAlpha(128,0,0,$alpha);
      $color[256] = $im->colorAllocateAlpha(0,0,0,$alpha);
      $color[256] = $im->colorAllocateAlpha(0,0,0,$alpha);
     
     
     
      $im->transparent($color[0]);  
      return (@color);
}


