#
#
#  some functions for writing pieces of kml
#

package kmlTools;

use strict;
use warnings;

###################################################
#  sub KmlPolygon
#
#  write a string for a simple polygon with one 
#  outerBoundaryIs
# 
#  input is a ref to a hash including:
#
#  coordinates => ($pxref, $pyref, $pzref),
#  description => $description_string,
#  name        => $name_string,
#  styleUrl    => $styleUrl_name
#
# e.g.
#
#  %args=( 'coordinates' => [\@px,\@py,\@pz],   # use a reference to a list of lists
#          'description' => "text will be put in description",
#          'name' => "nameForPlacemark",
#          'styleUrl' => 'nameOfStyleURL' );
#
#      my $pmark=kmlTools::kmlPolygon( \%args );
#
#  
#  output is a string containing the placemark
#  which can then be written to file
###################################################
sub kmlPolygon { #polyHashref


   my $hashref=shift;
   my %args=%$hashref;

   my @coords=@{$args{coordinates}};
   my @px=@{$coords[0]};
   my @py=@{$coords[1]};
   my @pz=@{$coords[2]};

   # close polygon if not closed
   if ($px[0] != $px[$#px] or $py[0] != $py[$#py]){
      push (@px, $px[0]);
      push (@py, $py[0]);
      push (@pz, $pz[0]);
   }

   my $coordstr='';
   foreach my $i (0..$#px){
      my  $point=sprintf("%0.14f,%0.14f,%0.5f",$px[$i],$py[$i],$pz[$i]);
      $coordstr="$coordstr $point";
   }

   my $kmlStr='<Placemark>';
   $kmlStr="$kmlStr\n"."   <name>$args{name}</name>";
   $kmlStr="$kmlStr\n"."   <description>$args{description}</description>";
   $kmlStr="$kmlStr\n"."   <styleUrl>$args{styleUrl}</styleUrl>";
   $kmlStr="$kmlStr\n".'   <Polygon>';
   $kmlStr="$kmlStr\n".'      <tessellate>1</tessellate>';
   $kmlStr="$kmlStr\n".'       <outerBoundaryIs>';
   $kmlStr="$kmlStr\n".'          <LinearRing>';
   $kmlStr="$kmlStr\n".'             <coordinates>';
   $kmlStr="$kmlStr\n"."                $coordstr";
   $kmlStr="$kmlStr\n".'             </coordinates>';
   $kmlStr="$kmlStr\n".'          </LinearRing>';
   $kmlStr="$kmlStr\n".'       </outerBoundaryIs>';
   $kmlStr="$kmlStr\n".'   </Polygon>';
   $kmlStr="$kmlStr\n".'</Placemark>';
   
   return $kmlStr;
   
}






sub kmlPath { #polyHashref


   my $hashref=shift;
   my %args=%$hashref;

   my @coords=@{$args{coordinates}};
   my @px=@{$coords[0]};
   my @py=@{$coords[1]};
   my @pz=@{$coords[2]};

   
   my $coordstr='';
   foreach my $i (0..$#px){
      my  $point=sprintf("%0.14f,%0.14f,%0.5f",$px[$i],$py[$i],$pz[$i]);
      $coordstr="$coordstr $point";
   }

   my $kmlStr='<Placemark>';

   $kmlStr="$kmlStr\n"."$args{TIMESPAN}" if defined $args{TIMESPAN};  
   $kmlStr="$kmlStr\n"."   <name>$args{name}</name>";
   $kmlStr="$kmlStr\n"."   <description>$args{description}</description>";
   $kmlStr="$kmlStr\n"."   <styleUrl>$args{styleUrl}</styleUrl>";
   $kmlStr="$kmlStr\n".'   <LineString>';
   $kmlStr="$kmlStr\n".'      <tessellate>1</tessellate>';
   $kmlStr="$kmlStr\n".'             <coordinates>';
   $kmlStr="$kmlStr\n"."                $coordstr";
   $kmlStr="$kmlStr\n".'             </coordinates>';
   $kmlStr="$kmlStr\n".'   </LineString>';
   $kmlStr="$kmlStr\n".'</Placemark>';
   
   return $kmlStr;
   
}










################################################################
# return style name and a string for a green outlined polygon
#################################################################
# aabbggrr

sub blueStyle {

 my $str='<Style id="blueOutline">
	  <IconStyle>
		<scale>1.3</scale>
		<Icon>
			<href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href>
		</Icon>
		<hotSpot x="20" y="2" xunits="pixels" yunits="pixels"/>
	</IconStyle>
	<LineStyle>
		<color>ffff0000</color>
		<width>3</width>
	</LineStyle>
	<PolyStyle>
		<fill>0</fill>
	</PolyStyle>
</Style>';

    return ('#blueOutline',$str);
}

sub greenStyle {

 my $str='<Style id="greenOutline">
	  <IconStyle>
		<scale>1.3</scale>
		<Icon>
			<href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href>
		</Icon>
		<hotSpot x="20" y="2" xunits="pixels" yunits="pixels"/>
	</IconStyle>
	<LineStyle>
		<color>ff00ff00</color>
		<width>3</width>
	</LineStyle>
	<PolyStyle>
		<fill>0</fill>
	</PolyStyle>
</Style>';

    return ('#greenOutline',$str);
}

sub redStyle {

 my $str='<Style id="redOutline">
	  <IconStyle>
		<scale>1.3</scale>
		<Icon>
			<href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href>
		</Icon>
		<hotSpot x="20" y="2" xunits="pixels" yunits="pixels"/>
	</IconStyle>
	<LineStyle>
		<color>ff0000ff</color>
		<width>3</width>
	</LineStyle>
	<PolyStyle>
		<fill>0</fill>
	</PolyStyle>
</Style>';

    return ('#redOutline',$str);
}



###############################################################
# sub createStyle
#
#
# returns the id with the '#' in front of it, and a string
# with the kml
#
###############################################################
sub createStyle {

   my $hashref=shift;
   my %args=%$hashref;
   
   # default icon href
   my $icon='http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png';
   $icon=$args{icon} if (defined $args{icon});

   my $lineColor='ffffffff';
   $lineColor=$args{lineColor} if (defined $args{lineColor});
   
   my $fillColor='ffffffff';
   $fillColor=$args{fillColor} if (defined $args{fillColor});

   my $fill=1;
   $fill = 0 if ($args{fill}==0);

   my $outline=1;
   $outline=0 if ($args{outline}==0);

   my $id='defaultStyle';
   $id=$args{id} if (defined $args{id});

   my $width=2;
   $width=$args{width} if (defined $args{width});

   my $scale=1.3;
   $scale = $args{scale} if (defined $args{scale});

   my $kmlStr='<Style id="'."$id".'">';
   $kmlStr="$kmlStr\n".'   <IconStyle>';
   $kmlStr="$kmlStr\n"."      <scale>$scale</scale>"; 
   $kmlStr="$kmlStr\n".'      <Icon>';     
   $kmlStr="$kmlStr\n"."         <href>$icon</href>";   
   $kmlStr="$kmlStr\n".'      </Icon>';
   $kmlStr="$kmlStr\n".'   </IconStyle>';
   $kmlStr="$kmlStr\n".'   <LineStyle>';
   $kmlStr="$kmlStr\n"."      <color>$lineColor</color>";
   $kmlStr="$kmlStr\n"."      <width>$width</width>"; 
   $kmlStr="$kmlStr\n".'   </LineStyle>';
   $kmlStr="$kmlStr\n".'   <PolyStyle>';
   $kmlStr="$kmlStr\n"."      <color>$fillColor</color>";
   $kmlStr="$kmlStr\n".'      <fill>0</fill>'             if ($fill==0);
   $kmlStr="$kmlStr\n".'      <outline>0</outline>'       if ($outline==0);
   $kmlStr="$kmlStr\n".'   </PolyStyle>';
   $kmlStr="$kmlStr\n".'</Style>';

   my $poundId='#'."$id";   

   return   ($poundId,$kmlStr);


}

###############################################################
#  sub openDoc('name of kml document);
#
#  return a string to write at the beginning of the kml document 
# (taken from a file saved by Google Earth)
#
#  input is a scalar that will be used for the name of the document
#
################################################################
sub openDoc{

my $name=shift;

my $str='<?xml version="1.0" encoding="UTF-8"?>';
$str="$str\n".'<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">';
$str="$str\n".'<Document>';
$str="$str\n<name>$name</name>";

return ($str);

}


######################################################
# return a string of the tags for closing the document
sub closeDoc{
   my $str='</Document>'."\n".'</kml>';
return ($str);

}




# private sub for writing a string of a point placemark
sub writePointPlacemark{
   my $obj=shift;
   my ($x,$y,$z,$desc,$styleID)=@_;

   my $zstr=sprintf('%5.1f',$z);

   my $pmark='';
   $pmark.= "     <Placemark>\n";
   $pmark.= "        <name>$zstr</name>\n";
   $pmark.= "        <styleUrl>$styleID</styleUrl>\n" if (defined $styleID);
   $pmark.= "        <description>$desc</description>\n" if (defined $desc);
   $pmark.= "        <Point>\n ";
   $pmark.= "          <coordinates>$x,$y,$z</coordinates>\n";
   $pmark.= "        </Point>\n";
   $pmark.= "     </Placemark>\n";
   return $pmark;
}




1;






