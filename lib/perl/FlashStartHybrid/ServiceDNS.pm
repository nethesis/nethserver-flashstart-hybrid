# FlashStart Hybrid Firewall 
# ServiceDNS file management

package FlashStartHybrid::ServiceDNS;

use strict;
use warnings;

my $file_Zone = '/etc/flashstart-hybrid/view_zone.list';


sub return_zone_list
{
	my @return_row_list;

	if (-e $file_Zone) {
		
		open(FH, '<', $file_Zone) or die $!;
		
		while(<FH>){
			my $row = $_;
			chomp $row;
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			# LINE > #ZONE_NAME;ZONE_IP;
			my ($zone, $ip) = split(';', $row);
			
			if (length $zone && length $ip && $zone ne '' && $ip ne '') {
				
				# check ip list
				my (@ip_array) = split(",", $ip);
				# create list for zone configuration
				my $ip_list = join("; ", @ip_array); $ip_list .= ";";
				
				push(@return_row_list, {'zone' => $zone, 'ip_string' => $ip, 'ip_list' => $ip_list, 'ip_array' => (\@ip_array) } );
				
			}
			
		}

		close(FH);
	}
	
	return @return_row_list;
}

sub search_zone
{
	my ($sendZone, $sendIp) = @_;
	
	my @zone_list = return_zone_list();
	
	my $result = 0;
	my $zone = "";
	my $ip_string = "";
	my $ip_list = "";
	my $row_string = "";
	my $row_string_to = "";
		
	# get line string
	foreach my $elem (@zone_list) { 
		
		if ( $sendZone eq "$elem->{zone}" ) {
			
			# set data
			$zone = "$elem->{zone}";
			$ip_string = "$elem->{ip_string}";
			$ip_list = "$elem->{ip_list}";
	
			# LINE > #ZONE_NAME;ZONE_IP;
			$row_string = "$elem->{zone};$elem->{ip_string};";
			
			$result = 1;
			
			# exit
			last;
			
		}
	}
	
	# return string to
	if ( length $sendIp ) {
		$row_string_to = "$sendZone;$sendIp;";
	}
	
	# set result 
	my %result_search = ('result' => $result, 'zone' => $zone, 'row_string' => $row_string, 'row_string_to' => $row_string_to );
	return %result_search;	
}

sub write_zone_list
{
	my ($sendAction, $sendZone, $sendIp) = @_;
	
	my $file = $file_Zone;	
	my @zone_list = return_zone_list();
	
	my $change = 0;
	my $string;
	my $string_to;
	
	if ( $sendAction eq 'ADD' ) {
		
		# search zone
		my %search_add = search_zone($sendZone, $sendIp);
		
		# check already present
		if ( $search_add{"result"} == 1 ) {
			
			# set string from
			$string = $search_add{"row_string"};
			
			# set string to 
			$string_to = $search_add{"row_string_to"};
			
			# call replace line
			replace_line_file($file, $string, $string_to);
			
		} else {
			
			# set string			
			$string_to = $search_add{"row_string_to"};
		
			# add string
			add_line_file($file, $string_to);
		
		} 
		
		# set var
		$change = 1;
		
	} elsif ( $sendAction eq 'DEL' ) {

		# search zone
		my %search_del = search_zone($sendZone, $sendIp);
		
		# check found
		if ( $search_del{"result"} == 1 ) {
			
			# set string from
			$string = $search_del{"row_string"};
				
			# remove string
			remove_line_file($file, $string);
			
			# set var
			$change = 1;			
		}
		
	}
	
	return $change;
}

sub clear_zone_list
{
	# set initial text
	my $init_text;
	$init_text .= "# List Zones\n";
	$init_text .= "#ZONE_NAME;ZONE_IP;\n\n";
	# 
	write_file($file_Zone, $init_text);
}


sub read_file {
    my ($filename) = @_;
 
    open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;
 
    return $all;
}
 
sub write_file {
    my ($filename, $content) = @_;
 
    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";;
    print $out $content;
    close $out;
 
    return;
}

sub add_line_file {
    my ($filename, $add) = @_;
	
	# write 
	my $data = read_file($filename);
	$data .= "$add\n";
	write_file($filename, $data);
 
    return;
}

sub replace_line_file {
    my ($filename, $find, $replace) = @_;
	
	my $data = read_file($filename);
	$data =~ s/$find/$replace/g;
	write_file($filename, $data);
 
    return;
}

sub remove_line_file {
    my ($filename, $line_pattern) = @_;
	
	my $new_data = "";
    
	open(FH, '<', $filename) or die $!;		
	while(<FH>){
		my $row = $_;
		chomp $row;
		
		next if ($row =~ m/^$line_pattern/i);
		$new_data .= "$row\n";
	}
	close(FH);
	
	# write 
	write_file($filename, $new_data);
 
    return;
}


1;
