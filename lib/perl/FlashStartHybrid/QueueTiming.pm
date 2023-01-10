# FlashStart Hybrid Firewall 
# QueueTiming file management

package FlashStartHybrid::QueueTiming;

use strict;
use warnings;
use JSON;

my $file_QueueTiming = '/etc/flashstart-hybrid/queue.conf';
my $file_DefaultQueueTiming = '/usr/libexec/flashstart-hybrid/confs/queue_timing.conf';
my $default_label = 'DEFAULT_QTIME_';

# Crontab file
my $file_DefaultCrontab = '/usr/libexec/flashstart-hybrid/confs/crontab.json';
my $file_CustomCrontab = '/etc/flashstart-hybrid/crontab.json';

sub get_config
{
		
	my @return_config;
	
	if (-e $file_QueueTiming) {
		
		open(FH, '<', $file_QueueTiming) or die $!;
		
		while(<FH>){
			my $row = $_;
			chomp $row;
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			my ($key, $value) = split("=", $row);
			
			if (length $key && $key ne '' && length $value && $value ne '') {
				# add
				push(@return_config, {'key' => $key, 'value' => $value, 'shell_eval' => "let $default_label$key=$value"} );
				
			}
			
		}

		close(FH);
	}
	
	return @return_config;
}

sub set_config
{
	my ($data) = @_;
	
	my @new_line;
	my $new_text;
	my @return_line;
	my $return_string;
	
	# decode string	
	my $json_data;
	my $empty_data = 0;
	
	# decode string
	if ( $data ne '' && $data ne '[]' ) {
		$json_data = JSON->new->decode( $data );
		# check option
		if ( not exists $json_data->{queue_timing} ) { $empty_data = 1; }
	} else {
		$empty_data = 1;
	}
	
	# init file
	push(@new_line, "# Queue Timing configuration - second (multiple 10 second)");
	push(@new_line, " ");
	
	if ( $empty_data eq 0 ) {
		# create list
		for my $key (sort keys $json_data->{queue_timing}) {	
			# set string
			my $line = "$key=$json_data->{queue_timing}{$key}";
			# add to lines list
			push(@new_line, $line);
			push(@return_line, $line);
		}
	}
	
	# create file 
	$new_text =  join("\n", @new_line);	
	write_file($file_QueueTiming, $new_text);
	
	# set return
	$return_string =  join(" | ", @return_line);	
	
	return $return_string
}


sub search_default_config
{
	my ($sendCode) = @_;
	
	my $result_value = '';	
	
	if (-e $file_DefaultQueueTiming) {
		
		open(FH, '<', $file_DefaultQueueTiming) or die $!;
		
		while(<FH>){
			my $row = $_;
			chomp $row;
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			my ($key, $value) = split("=", $row);
			
			if (length $key && $key ne '' && length $value && $value ne '') {
				# set string
				my $search_string = "$default_label$sendCode";
				
				# check
				if ($search_string eq $key) {
					# set
					$result_value = $value;
				
					# exit
					last;
				}
			}
			
		}

		close(FH);
	}
	
	# set result 
	return $result_value;
}

sub search_timing
{
	my ($sendCode) = @_;
	
	# check default timing
	my $result_value = FlashStartHybrid::QueueTiming::search_default_config($sendCode);
	
	# check custom timing
	my @list = FlashStartHybrid::QueueTiming::get_config();
	foreach my $elem (@list) { 
		# check exist code
		if ( $elem->{key} eq $sendCode ) {
			# set
			$result_value = $elem->{value};
			# exit
			last;
		}		
	}
	
	return $result_value;
}

sub crontab_get_config
{
	# init
	my $return_config;
	
	# get default file
	my $json_data = JSON->new->decode( read_file($file_DefaultCrontab) );
	
	# check and get custom file
	my $json_custom;
	if (-e $file_CustomCrontab) {
		$json_custom = JSON->new->decode( read_file($file_CustomCrontab) );
	}
	
	# create template
	for my $key (sort keys $json_data) {
		# remove comment line
		if ( $key ne "___comment___" ) {
			# init timing
			my $minute = ( length $json_data->{$key}{minute} ) ? $json_data->{$key}{minute} : "*";
			my $hour = ( length $json_data->{$key}{hour} ) ? $json_data->{$key}{hour} : "*";
			my $month_day = ( length $json_data->{$key}{month_day} ) ? $json_data->{$key}{month_day} : "*";
			my $month = ( length $json_data->{$key}{month} ) ? $json_data->{$key}{month} : "*";
			my $week_day = ( length $json_data->{$key}{week_day} ) ? $json_data->{$key}{week_day} : "*";
			
			# check custom
			if ( length $json_custom->{$key} ) {
				# get custom data
				my $custom_data = $json_custom->{$key};
				# set
				$minute = ( length $custom_data->{minute} ) ? $custom_data->{minute} : $minute;
				$hour = ( length $custom_data->{hour} ) ? $custom_data->{hour} : "*";
				$month_day = ( length $custom_data->{month_day} ) ? $custom_data->{month_day} : "*";
				$month = ( length $custom_data->{month} ) ? $custom_data->{month} : "*";
				$week_day = ( length $custom_data->{week_day} ) ? $custom_data->{week_day} : "*";
			}			
			# set config
			$return_config->{$key} = {"minute" => $minute, "hour" => $hour, "month_day" => $month_day, "month" => $month, "week_day" =>$week_day };
		}
	}
	
	return $return_config;
}

sub crontab_search_timing
{
	my ($sendProc) = @_;
	
	# get config
	my $config = crontab_get_config();
	
	# get key
	my $return = $config->{$sendProc};
	
	return $return;	
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
