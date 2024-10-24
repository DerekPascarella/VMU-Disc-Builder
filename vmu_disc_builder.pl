#!/usr/bin/perl
#
# VMU Disc Builder v1.0
# A utility for compiling a custom CDI containing Dreamcast VMU save files.
#
# Written by Derek Pascarella (ateam)

# Our modules.
use strict;
use GD;
use Encode;
use Archive::Zip;
use File::Copy;
use File::Find;
use File::Path 'rmtree';
use Fcntl ':seek';

# Set version number.
my $version = "1.0";

# Set header used in CLI messages.
my $cli_header = "\nVMU Disc Builder v" . $version . "\nA utility for compiling a custom CDI containing Dreamcast VMU save files.\n\nWritten by Derek Pascarella (ateam)\n\n";

# Store list of required helper utilities and assets.
my @required_files =
(
	"tools/cdi4dc.exe",
	"tools/mkisofs.exe",
	"assets/no_icon.gif",
	"assets/ARIALUNI.TTF",
	"assets/disc_image.zip",
	"assets/html/1.html",
	"assets/html/2.html",
	"assets/html/3.html",
	"assets/html/4.html",
);

# Perform check for reequired helper utilities and assets.
foreach my $file (@required_files)
{
	# Terminate program if missing.
	if(!-e $file)
	{
		print $cli_header;
		print STDERR "One or more helper utilities or assets is missing: " . $file;
		print "\n\nPress Enter to exit.\n";
		<STDIN>;
		
		exit;
	}
}

# Hash to track presence of VMI and VMS files by base name.
my %file_pairs;

# Array to store base file path of VMI/VMS pairs.
my @save_files;

# Recursively find all VMI/VMS pairs in the "save_files" folder.
find({
	wanted => sub
	{
		# Store full path to the file.
		my $file = $File::Find::name;

		# Only process files with VMI or VMS extensions.
		return unless $file =~ /\.(vmi|vms)$/i;

		# Extract the directory path and the filename (without extension).
		my $relative_path = $file;
		$relative_path =~ s/^save_files\///;
		
		# Extract base filename and extension.
		my ($base, $ext) = $relative_path =~ /^(.+)\.(vmi|vms)$/i;

		# Mark the existence of the file for its base name.
		$file_pairs{$base}{lc($ext)} = 1;
	}
}, "save_files");

# Check for matching VMI and VMS pairs
foreach my $base (keys %file_pairs)
{
	# Only store base names if both a VMI and VMS is present.
	if(exists $file_pairs{$base}{vmi} && exists $file_pairs{$base}{vms})
	{
		# Push base name with the relative path to the array.
		push(@save_files, $base);
	}
}

# Throw error if no VMI/VMS pairs found in "save_files" folder.
if(!@save_files)
{
	print $cli_header;
	print STDERR "No VMI/VMS pairs found in \"save_files\" folder.";
	print "\n\nPress Enter to exit.\n";
	<STDIN>;
	
	exit; 
}

# Status message.
print $cli_header;

# Status message.
print scalar(@save_files) . " VMI/VMS pair(s) found in \"save_files\" folder.\n\n";

# Status message.
print "Extracting disc image data...\n\n";

# Extract disc image data.
mkdir("output/data");
my $zip = Archive::Zip->new();
$zip->read("assets/disc_image.zip");
$zip->extractTree("", "output/data");

# Initialize hash used for organizing save files in groups according to first letter of file name.
my %save_file_map = (
	'num' => [],
	'ad'  => [],
	'eh'  => [],
	'il'  => [],
	'mo'  => [],
	'ps'  => [],
	'tv'  => [],
	'wz'  => [],
);

# Status message.
print "Extracting icons and descriptions from VMU save files...\n\n";

# Iterate through and process each identified VMI/VMS pair.
foreach my $base_file_path (@save_files)
{
	# Status message.
	print "-> " . $base_file_path . "\n";

	# Extract base folder from file path.
	my ($directory_name) = $base_file_path =~ m|^([^/]+)/|;

	# Create subfolder in disc image data's "SAVES" folder if it doesn't exist.
	if(!-e "output/data/DPWWW/SAVES/" . $directory_name)
	{
		mkdir("output/data/DPWWW/SAVES/" . $directory_name);
	}

	# Copy VMI/VMS to disc image data's "SAVES" folder.
	copy("save_files/" . $base_file_path . ".VMI", "output/data/DPWWW/SAVES/" . $base_file_path . ".VMI");
	copy("save_files/" . $base_file_path . ".VMS", "output/data/DPWWW/SAVES/" . $base_file_path . ".VMS");

	# Extract save filename from VMI.
	my $save_filename = decode('Shift-JIS', pack('H*', read_bytes_at_offset("save_files/" . $base_file_path . ".VMI", 12, 88)));

	# Determine if VMS represents a VMU icon.
	my $save_is_icondata = 0;

	if($save_filename eq "ICONDATA_VMS")
	{
		$save_is_icondata = 1;
	}
	
	# Extract save description from VMS.
	my $save_description = read_bytes_at_offset("save_files/" . $base_file_path . ".VMS", 32, 16);
	
	# Determine if VMS represents a minigame, where description data starts at decimal offset 512.
	my $save_is_minigame = 0;
	
	if(!$save_is_icondata)
	{
		for(my $i = 0; $i < length($save_description); $i += 2)
		{
			# Store single byte.
			my $byte = uc(substr($save_description, $i, 2));

			# Check for null bytes (00 or FF) before the first five bytes (rough estimate).
			if(($byte eq "00" || $byte eq "FF") && $i < 10)
			{
				$save_is_minigame = 1;
			}
		}
	}

	# Status message.
	print "   - VMS file identified as ";

	if($save_is_icondata)
	{
		print "icon data.\n";
	}
	elsif($save_is_minigame)
	{
		print "minigame or other VMU software.\n";
	}
	else
	{
		print "save data.\n";
	}

	# Status message.
	print "   - Extracting label and description from VMI/VMS pair...\n";

	# VMS represents icon data.
	if($save_is_icondata)
	{
		$save_description = decode('Shift-JIS', pack('H*', read_bytes_at_offset("save_files/" . $base_file_path . ".VMS", 32, 0)));
	}
	# VMS represents a minigame.
	elsif($save_is_minigame)
	{
		$save_description = decode('Shift-JIS', pack('H*', read_bytes_at_offset("save_files/" . $base_file_path . ".VMS", 32, 528)));
	}
	# VMS represents a standard save file.
	else
	{
		$save_description = decode('Shift-JIS', pack('H*', read_bytes_at_offset("save_files/" . $base_file_path . ".VMS", 32, 16)));
	}

	# Remove leading and trailing whitespace from save description.
	$save_description =~ s/^\s+|\s+$//g;
	
	# Construct complete save text.
	my $save_text = $save_filename . "\n" . $save_description;

	# Generate text GIF.
	generate_text_gif($save_text, "output/data/DPWWW/SAVES/" . $base_file_path . "_DESC.GIF");

	# VMS file contains valid icon data.
	if(has_icon_data("save_files/" . $base_file_path . ".VMS", $save_is_minigame, $save_is_icondata))
	{
		# Status message.
		print "   - Valid icon found, exporting to GIF.\n";

		# Extract icon from VMS and write it to disc image data's "SAVES" folder.
		extract_vms_icon_to_gif("save_files/" . $base_file_path . ".VMS", $save_is_minigame, $save_is_icondata);
	}
	# VMS file does not contain valid icon data.
	else
	{
		# Status message.
		print "   - No valid icon found, using placeholder.\n";

		# Use placeholder icon.
		copy("assets/no_icon.gif", "output/data/DPWWW/SAVES/" . $base_file_path . "_ICON.GIF");
	}

	# Determine the key based on the first character.
	my $first_character;

	if(substr($save_filename, 0, 1) eq "_")
	{
		$first_character = lc(substr($save_filename, 1, 1));
	}
	else
	{
		$first_character = lc(substr($save_filename, 0, 1));
	}

	my $key;

	if($first_character =~ /^[a-d]$/)
	{
		$key = 'ad';
	}
	elsif($first_character =~ /^[e-h]$/)
	{
		$key = 'eh';
	}
	elsif($first_character =~ /^[i-l]$/)
	{
		$key = 'il';
	}
	elsif($first_character =~ /^[m-o]$/)
	{
		$key = 'mo';
	}
	elsif($first_character =~ /^[p-s]$/)
	{
		$key = 'ps';
	}
	elsif($first_character =~ /^[t-v]$/)
	{
		$key = 'tv';
	}
	elsif($first_character =~ /^[w-z]$/)
	{
		$key = 'wz';
	}
	else
	{
		$key = 'num';
	}

	# Append "_X" to duplicate entries, where X starts at one and is iterated.
	my $new_filename = $save_filename;
	my $counter = 1;
	
	while(grep { $_ eq $new_filename } @{$save_file_map{$key}})
	{
		$new_filename = $save_filename . "_" . $counter;
		$counter++;
	}

	# Push a hash reference with both the save and base filenames to the array.
	push(@{$save_file_map{$key}}, {save_filename => $new_filename, base_file_path => $base_file_path});
}

# Status message.
print "\nGenerating HTML...\n\n";

# Construct HTML files for each letter group.
foreach my $key (keys %save_file_map)
{
	# Begin constructing HTML.
	my $html = read_file("assets/html/1.html");

	# Store default menu HTML.
	my $menu_html = "<a href=\"NUM.HTM\"><b>#</b></a>&nbsp;&nbsp;<a href=\"AD.HTM\"><b>A-D</b></a>&nbsp;&nbsp;<a href=\"EH.HTM\"><b>E-H</b></a>&nbsp;&nbsp;<a href=\"IL.HTM\"><b>I-L</b></a>&nbsp;&nbsp;<a href=\"MO.HTM\"><b>M-O</b></a>&nbsp;&nbsp;<a href=\"PS.HTM\"><b>P-S</b></a>&nbsp;&nbsp;<a href=\"TV.HTM\"><b>T-V</b></a>&nbsp;&nbsp;<a href=\"WZ.HTM\"><b>W-Z</b></a>";

	# Map the original menu entries to a hash.
	my %default_menu = (
		'num' => '<a href="NUM.HTM"><b>#</b></a>',
		'ad'  => '<a href="AD.HTM"><b>A-D</b></a>',
		'eh'  => '<a href="EH.HTM"><b>E-H</b></a>',
		'il'  => '<a href="IL.HTM"><b>I-L</b></a>',
		'mo'  => '<a href="MO.HTM"><b>M-O</b></a>',
		'ps'  => '<a href="PS.HTM"><b>P-S</b></a>',
		'tv'  => '<a href="TV.HTM"><b>T-V</b></a>',
		'wz'  => '<a href="WZ.HTM"><b>W-Z</b></a>',
	);

	# Map the replacement "active" menu entries to a hash.
	my %active_menu = (
		'num' => '<b>[ # ]</b>',
		'ad'  => '<b>[ A-D ]</b>',
		'eh'  => '<b>[ E-H ]</b>',
		'il'  => '<b>[ I-L ]</b>',
		'mo'  => '<b>[ M-O ]</b>',
		'ps'  => '<b>[ P-S ]</b>',
		'tv'  => '<b>[ T-V ]</b>',
		'wz'  => '<b>[ W-Z ]</b>',
	);

	# Replace menu entry with "active" version for current letter group.
	$menu_html =~ s/\Q$default_menu{$key}\E/$active_menu{$key}/g;

	# Append menu HTML.
	$html .= $menu_html;

	# Continue constructing HTML.
	$html .= read_file("assets/html/2.html");

	# No save files found for current letter group.
	if(@{$save_file_map{$key}} == 0)
	{
		$html .= "\nNo VMU save files are available for this section.\n<br>\n";
	}
	# Save files found for current letter group.
	else
	{
		# Continue constructing HTML.
		$html .= "\n<table width=\"100%\" border=\"1\" cellpadding=\"10\">\n";

		# Iterate through each save file in the current letter group.
		foreach my $entry (sort { $a->{save_filename} cmp $b->{save_filename} } @{$save_file_map{$key}})
		{
			# Continue constructing HTML.
			$html .= "<tr>\n<td align=\"center\" valign=\"middle\">\n";

			# Continue constructing HTML.
			$html .= "<a href=\"SAVES/" . uc($entry->{base_file_path}) . ".VMI\"><img border=\"0\" width=\"32\" height=\"32\" src=\"SAVES/" . uc($entry->{base_file_path}) . "_ICON.GIF\"></a>";

			# Continue constructing HTML.
			$html .= "</td>\n<td align=\"left\" valign=\"middle\">\n";

			# Continue constructing HTML.
			$html .= "<a href=\"SAVES/" . uc($entry->{base_file_path}) . ".VMI\"><img border=\"0\" src=\"SAVES/" . uc($entry->{base_file_path}) . "_DESC.GIF\"></a>";

			# Continue constructing HTML.
			$html .= "</td>\n</tr>\n";
		}

		# Continue constructing HTML.
		$html .= "</table>\n";
	}

	# Continue constructing HTML.
	$html .= read_file("assets/html/3.html");

	# Append menu HTML.
	$html .= $menu_html;

	# Finish constructing HTML.
	$html .= read_file("assets/html/4.html");

	# Write HTML to disc image data's "DPWWW" folder.
	write_file("output/data/DPWWW/" . uc($key) . ".HTM", $html);
}

# Status message.
print "Creating dummy file...\n\n";

# Create dummy file in order to push data to the outside of the disc.
my $total_size = 0;

find(sub {
	return if -d;
	$total_size += -s;
}, "output/data");

my $dummy_file_size = (550 * 1024 * 1024) - $total_size;

open my $fh, '>', "output/data/0.0";
seek($fh, $dummy_file_size - 1, SEEK_SET);
print $fh "\0";
close $fh;

# Status message.
print "Building disc image (this may take a while)...\n\n";

# Build ISO filesystem.
copy("tools/mkisofs.exe", "output/mkisofs.exe");
chdir("output");
system("mkisofs -V VMUDISC -G data/IP.BIN -r -l -duplicates-once -o vmudisc.iso data > NUL 2>&1");
unlink("mkisofs.exe");
chdir("..");

# Built CDI disc image.
copy("tools/cdi4dc.exe", "output/cdi4dc.exe");
chdir("output");
system("cdi4dc vmudisc.iso vmudisc.cdi -d > NUL 2>&1");
unlink("cdi4dc.exe");
unlink("vmudisc.iso");
chdir("..");

# Rename CDI based on current date and time.
my ($sec, $min, $hour, $day, $month, $year) = localtime();
$year += 1900;
$month += 1;
my $current_datetime = sprintf("%04d%02d%02d%02d%02d", $year, $month, $day, $hour, $min);
rename("output/vmudisc.cdi", "output/VMU Disc Builder (" . $current_datetime . ").cdi");

# Clean up disc data folder.
rmtree("output/data");

# Status message.
print "Process complete!\n\n";
print "Disc image saved as \"VMU Disc Builder (" . $current_datetime . ").cdi\" in the \"output\" folder.\n\n";
print "Press Enter to exit.\n";
<STDIN>;

# Subroutine to read a text file and return its contents.
sub read_file
{
	my $input_file = $_[0];
	my $content = '';

	open my $filehandle, "<:encoding(UTF-8)", $input_file or die "Cannot open file '$input_file': $!\n";

	while(my $line = <$filehandle>)
	{
		$content .= $line;
	}

	close $filehandle;

	return $content;
}

# Subroutine to write UTF-8-encoded string data to a file.
sub write_file
{
	my $output_file = $_[0];
	my $content = $_[1];

	open(my $filehandle, '>:encoding(UTF-8)', $output_file) or die "Cannot write to file '$output_file': $!\n";
	print $filehandle $content;
	close $filehandle;
}

# Subroutine to swap between big/little endian by reversing order of bytes from specified hexadecimal
# data.
sub endian_swap
{
	(my $hex_data = $_[0]) =~ s/\s+//g;
	my @hex_data_array = ($hex_data =~ m/../g);

	return join("", reverse(@hex_data_array));
}

# Subroutine to read a specified number of bytes, starting at a specific offset (in decimal format), of
# a specified file, returning hexadecimal representation of data.
sub read_bytes_at_offset
{
	my $input_file = $_[0];
	my $byte_count = $_[1];
	my $read_offset = $_[2];

	if((stat $input_file)[7] < $read_offset + $byte_count)
	{
		die "Offset for read_bytes_at_offset is outside of valid range.\n";
	}

	open my $filehandle, '<:raw', $input_file or die $!;
	seek $filehandle, $read_offset, 0;
	read $filehandle, my $bytes, $byte_count;
	close $filehandle;
	
	return unpack 'H*', $bytes;
}

# Subroutine to determine if a VMS file contains valid icon data.
sub has_icon_data
{
	my $vms_file = $_[0];
	my $save_is_minigame = $_[1];
	my $save_is_icondata = $_[2];

	# Open the file in binary mode.
	open my $fh, '<:raw', $vms_file or die "Cannot open file '$vms_file': $!\n";

	# Seek to offset 0x240 where the icon count is stored.
	if($save_is_minigame)
	{
		seek($fh, 0x240, 0);
	}
	# Seek to custom offset.
	elsif($save_is_icondata)
	{
		my $offset = hex(endian_swap(read_bytes_at_offset($vms_file, 4, 20)));

		# Icon found.
		if($offset != 0)
		{
			seek($fh, $offset, 0);
		}
		# No icon found.
		else
		{
			return 0;
		}
	}
	# Seek to offset 0x40 where the icon count is stored.
	else
	{
		seek($fh, 0x40, 0);
	}

	# Read the 2-byte icon count (little-endian).
	read($fh, my $icon_count_data, 2);
	my $icon_count = unpack('v', $icon_count_data);

	# If the icon count is zero, there is no icon data.
	return 0 if $icon_count == 0;

	# Seek to the start of the icon bitmaps at offset 0x280.
	if($save_is_minigame)
	{
		seek($fh, 0x280, 0);
	}
	# Seek to the start of the icon bitmaps at offset 0x80.
	else
	{
		seek($fh, 0x80, 0);
	}

	# Read the icon bitmaps (512 bytes per icon).
	my $icon_size = 512 * $icon_count;
	read($fh, my $icon_data, $icon_size);

	# Close the file.
	close $fh;

	# Check if the icon data consists entirely of null bytes.
	if($icon_data =~ /^\0+$/)
	{
		# The icon data is all null bytes, so we return false.
		return 0;
	}

	# If the icon data contains non-null bytes, return true.
	return 1;
}


# Subroutine to extract icon data from a VMS file.
sub extract_vms_icon_to_gif
{
	my $filename = $_[0];
	my $save_is_minigame = $_[1];
	my $save_is_icondata = $_[2];

	# Open the VMS file.
	open(my $fh, '<', $filename) or die "Cannot open file '$filename': $!\n";
	binmode($fh);

	# Read the palette.
	if($save_is_minigame)
	{
		seek($fh, 0x260, 0);
	}
	elsif($save_is_icondata)
	{
		seek($fh, 0xA0, 0);
	}
	else
	{
		seek($fh, 0x60, 0);
	}
	
	read($fh, my $palette_data, 32);

	my @palette = ();

	for my $i (0 .. 15)
	{
		my $color_data = substr($palette_data, $i * 2, 2);
		
		# 16-bit little-endian.
		my $color = unpack('v', $color_data);

		# Extract 4-bit fields.
		my $alpha = ($color >> 12) & 0xF;
		my $red   = ($color >> 8)  & 0xF;
		my $green = ($color >> 4)  & 0xF;
		my $blue  = $color		 & 0xF;

		# Normalize to 8-bit values (0-255).
		$alpha = int(($alpha / 15) * 255);
		$red   = int(($red   / 15) * 255);
		$green = int(($green / 15) * 255);
		$blue  = int(($blue  / 15) * 255);

		push @palette, [$red, $green, $blue, $alpha];
	}

	# Read the first icon bitmap (ignore additional icons).
	my $icon_size = 512;
	my $icon_data_offset;

	if($save_is_minigame)
	{
		$icon_data_offset = 0x280;
	}
	elsif($save_is_icondata)
	{
		$icon_data_offset = 0xC0;
	}
	else
	{
		$icon_data_offset = 0x80;
	}

	seek($fh, $icon_data_offset, 0);
	read($fh, my $icon_bitmap_data, $icon_size);

	my @pixels = ();

	for my $byte_index (0 .. $icon_size-1)
	{
		my $byte = ord(substr($icon_bitmap_data, $byte_index, 1));

		# High nybble (left pixel).
		my $left_pixel = ($byte >> 4) & 0xF;

		# Low nybble (right pixel).
		my $right_pixel = $byte & 0xF;

		push @pixels, $left_pixel, $right_pixel;
	}

	# Close the VMS file.
	close($fh);

	# Reshape the pixel data into a 2D array (32x32).
	my @icon_pixels_2d = ();

	while (@pixels)
	{
		push @icon_pixels_2d, [splice(@pixels, 0, 32)];
	}

	# Remove the directory path and extension from the input filename.
	my $base_filename = $filename;
	$base_filename =~ s/^save_files\///;
	$base_filename =~ s{\.[^.]+$}{};

	# Define the GIF filename.
	my $gif_filename = "${base_filename}_ICON.GIF";

	# Write the GIF file.
	write_gif($gif_filename, \@icon_pixels_2d, \@palette);

	return $gif_filename;
}

# Subroutine to write a VMS icon to a GIF.
sub write_gif
{
	my ($filename, $pixels_ref, $palette_ref) = @_;

	my $width = 32;
	my $height = 32;

	# Create a new image.
	my $image = GD::Image->new($width, $height);

	# Allocate colors from the palette.
	my @gd_palette = ();
	my $transparent_index = -1;

	for my $i (0 .. $#{$palette_ref})
	{
		my ($r, $g, $b, $a) = @{$palette_ref->[$i]};

		# Convert alpha value to GD alpha (0-127).
		my $gd_alpha = int((255 - $a) * 127 / 255);

		# Allocate color in GD.
		my $color = $image->colorAllocateAlpha($r, $g, $b, $gd_alpha);

		# If fully transparent, set as transparent index
		if($gd_alpha == 127 && $transparent_index == -1)
		{
			$transparent_index = $color;
		}

		$gd_palette[$i] = $color;
	}

	# Set transparent color, if any.
	if($transparent_index != -1)
	{
		$image->transparent($transparent_index);
	}

	# Set pixels.
	for my $y (0 .. $height - 1)
	{
		for my $x (0 .. $width -1)
		{
			my $pixel_index = $pixels_ref->[$y][$x];
			my $color = $gd_palette[$pixel_index];
			$image->setPixel($x, $y, $color);
		}
	}

	# Save the image as GIF.
	open(my $out_fh, '>', "output/data/DPWWW/SAVES/" . $filename) or die "Cannot open output file '$filename': $!\n";
	binmode $out_fh;
	print $out_fh $image->gif();
	close($out_fh);
}

# Subroutine to generate VMU save file description GIF.
sub generate_text_gif
{
	my ($text, $output_filename) = @_;

	# TTF file.
	my $font_path = "assets/ARIALUNI.TTF";

	# Font size.
	my $font_size = 10;

	# Split text into lines.
	my @lines = split(/\n/, $text);

	# Create a temporary image to calculate text dimensions.
	my $tmp_image = GD::Image->new(1, 1);
	my $black = $tmp_image->colorAllocate(0, 0, 0);

	# Calculate maximum text width and total height.
	my $max_text_width = 0;
	my $total_height = 0;
	
	# To store ascent and descent for each line.
	my @line_metrics = ();

	foreach my $line (@lines)
	{
		# Get bounding box for the line.
		my @bounds = GD::Image->stringFT($black, $font_path, $font_size, 0, 0, 0, $line);

		# Calculate text width and update maximum width.
		my $text_width = $bounds[2] - $bounds[0];
		$max_text_width = $text_width if $text_width > $max_text_width;

		# Calculate ascent and descent.
		my $ascent = -$bounds[7];
		my $descent = $bounds[1];
		my $line_height = $ascent + $descent;

		$total_height += $line_height;

		push @line_metrics, {
			ascent => $ascent,
			descent => $descent,
			height => $line_height,
			bounds => \@bounds,
		};
	}

	# Set image dimensions based on text dimensions without padding.
	my $width = int($max_text_width + 0.5);
	my $height = int($total_height + 0.5);

	# Create the image with calculated dimensions.
	my $image = GD::Image->new($width, $height);

	# Allocate colors.
	my $white = $image->colorAllocate(255, 255, 255);
	$black = $image->colorAllocate(0, 0, 0);

	# Fill background with white.
	$image->filledRectangle(0, 0, $width, $height, $white);

	# Draw each line of text, starting from the top.
	my $y = 0; 

	for(my $i = 0; $i < @lines; $i++)
	{
		my $line = $lines[$i];
		my $metrics = $line_metrics[$i];
		my @bounds = @{$metrics->{bounds}};

		# Calculate x and y positions.
		my $x = -$bounds[0];
		$y += $metrics->{ascent};

		$image->stringFT($black, $font_path, $font_size, 0, $x, $y, $line);

		# Move y position to next line.
		$y += $metrics->{descent};
	}

	# Now, downscale the image if height is greater than 32 pixels.
	my $max_height = 32;

	if($height > $max_height)
	{
		# Calculate scaling factor.
		my $scale = $max_height / $height;
		my $new_width = int($width * $scale + 0.5);
		my $new_height = $max_height;

		# Create a new image with the new dimensions.
		my $scaled_image = GD::Image->new($new_width, $new_height);

		# Copy and resample the original image into the new image.
		$scaled_image->copyResampled($image, 0, 0, 0, 0, $new_width, $new_height, $width, $height);

		# Replace the original image with the scaled image.
		$image = $scaled_image;
		$width = $new_width;
		$height = $new_height;
	}

	# Save the image as GIF.
	open(my $out, '>', $output_filename) or die "Cannot open output file '$output_filename': $!";
	binmode $out;
	print $out $image->gif;
	close($out);

	# Return the output filename.
	return $output_filename;
}