# FlashStart Hybrid Firewall 
# Software update post event

package FlashStartHybrid::SoftwareUpdatePost;

use strict;
use warnings;
use JSON;

my $file_TempPostEvent = '/dev/shm/fs_hybrid_update_post.tmp';

sub init_file
{
	write_file($file_TempPostEvent, "");
}

sub add_procedure
{
	# get data
	my ($name, $param) = @_;
	
	if ( length $param ) {
		# replace param separator
		$param =~ s/ /,/g;		
	} else {
		$param = "";
	}
	
	# create line
	my $line = $name.";".$param;
		
	# add to file	
	add_line_file($file_TempPostEvent, $line);
	
}

sub read_procedures
{
	my @return_list;
	
	if ( -e $file_TempPostEvent ) {
		# read file
		open(FH, '<', $file_TempPostEvent) or die $!;	
		while(<FH>){
			my $row = $_;
			chomp $row;
			
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			my ($name, $param) = split(';', $row);
			
			if (length $name && $name ne '') {
				# push
				push(@return_list, { 'name' => $name, 'param' => $param, 'row' => $row } );
			}
		}
		close(FH);
	}
	
	return @return_list;
}

sub check_file
{
	my $exists_proc = 0;
	if ( -e $file_TempPostEvent ) {
		$exists_proc = 1;
	}
	return $exists_proc;
}

sub check_closed
{
	my $is_closed = 0;
	# read file
	my $content = read_file($file_TempPostEvent);
	
	# check 
	if ($content =~ m/#END#/i) {
		$is_closed = 1;
	}
	
	return $is_closed;
}

sub close_file 
{
	
	# check if not is already closed
	if ( check_closed() eq 0 ) {
		# put END
		add_line_file($file_TempPostEvent, "#END#");
	}
}

sub remove_procedures
{
	if ( -e $file_TempPostEvent ) {
		unlink $file_TempPostEvent;
	}
	
	return $file_TempPostEvent;
}

sub set_status_reading
{	
	# put label
	add_line_file($file_TempPostEvent, "#READING#");
}
sub check_status_reading
{	
	my $is_reading = 0;
	# read file
	my $content = read_file($file_TempPostEvent);
	
	# check 
	if ($content =~ m/#READING#/i) {
		$is_reading = 1;
	}
	
	return $is_reading;
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
