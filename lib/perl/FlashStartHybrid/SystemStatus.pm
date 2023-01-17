# FlashStart Hybrid Firewall 
# Get System status data

package FlashStartHybrid::SystemStatus;

use strict;
use warnings;
use JSON;


sub get_status
{
	# get status
	my $data = `/usr/bin/sudo /usr/libexec/nethserver/api/system-status/read`;
	
	# convert
	my $json_data = JSON->new->decode( $data );
	
	# calc mem
	my $MemTotal = $json_data->{status}{memory}{MemTotal};
	my $MemFree = $json_data->{status}{memory}{MemFree};
	my $MemAvailable = $json_data->{status}{memory}{MemAvailable};

	my $MemUsed = ($MemTotal - $MemAvailable);
	my $PercMemUsed = ($MemUsed * 100) / $MemTotal;
	$PercMemUsed = sprintf("%.2f", $PercMemUsed);
	
	# get cpu
	my $PercCpuUsed = calc_cpu();
	
	# calc disk
	my $DiskTotal = $json_data->{status}{disk}{root}{total};
	my $DiskUsed = $json_data->{status}{disk}{root}{used};
	my $PercDiskUsed = ($DiskUsed * 100) / $DiskTotal;
	$PercDiskUsed = sprintf("%.2f", $PercDiskUsed);
	
	# return
	my %return_status;
	$return_status{perc_mem_used} = $PercMemUsed;
	$return_status{perc_cpu_used} = $PercCpuUsed;
	$return_status{perc_disk_used} = $PercDiskUsed;
	
	return %return_status;
}

sub calc_cpu 
{	
	# gets cpu seperated by 2 seconds
	open(STAT, "</proc/stat");
	my ($junk, $cpu_user, $cpu_nice, $cpu_sys, $cpu_idle) = split(/\s+/,<STAT>);
	close(STAT);
	my $cpu_total1 = $cpu_user + $cpu_nice + $cpu_sys + $cpu_idle;
	my $cpu_load1 = $cpu_user + $cpu_nice + $cpu_sys;
	sleep 2;
	open(STAT,"</proc/stat");
	($junk, $cpu_user, $cpu_nice, $cpu_sys, $cpu_idle) = split(/\s+/,<STAT>);
	close(STAT);
	my $cpu_total2 = $cpu_user + $cpu_nice + $cpu_sys + $cpu_idle;
	my $cpu_load2 = $cpu_user + $cpu_nice + $cpu_sys;
	my $a = $cpu_load2 - $cpu_load1;
	my $b = $cpu_total2 - $cpu_total1;
	##printf("CPU Usage: %4.1f\n", 100.0*$a/$b);
	my $result = sprintf("%.2f", 100.0*$a/$b);
	
	return $result;
}

sub return_network_ip
{
	use esmith::NetworksDB;
	use esmith::ConfigDB;
	
	my $cdb = esmith::ConfigDB->open_ro();
	my $ndb = esmith::NetworksDB->open_ro or warn("Could not open NetworksDB");
		
	my $obj_net;
	my $LocalIP = '';

	# Get FlashStart zone
	my $zones = $cdb->get_prop('flashstart', 'Roles') || 'green';
	foreach my $zone (split(",",$zones)) {
		my $zone = substr($zone, 0, 5); #truncate zone name to 5 chars
				
		# only first element
		if ($LocalIP eq '') {
			# get object
			if ($zone eq 'green') {
				$obj_net = ($ndb->green())[0];
				$LocalIP = $obj_net->prop('ipaddr') || '';
				
			} elsif ($zone eq 'blue') {
				$obj_net = ($ndb->blue())[0];
				$LocalIP = $obj_net->prop('ipaddr') || '';
			}
		}
	}
	
	return $LocalIP;
}
	
sub nethserver_packages_to_update
{	
	# read list
	my $data =  `/usr/bin/sudo /usr/libexec/nethserver/api/system-packages/list-updates`;

	my $json_data = JSON->new->decode( $data );
	
	# init data
	my $count = 0;
	my @package_list;
	
	if ( length $json_data->{updates} ) {
		# get update lists
		my $updates = $json_data->{updates};
		# get updates in package
		foreach my $package (@$updates) {
			# get list
			my $package_updates = $package->{updates};
			my $count_updates = scalar @$package_updates;
			# add to counter
			$count = $count + $count_updates;		
			# add to package name
			push(@package_list, {'name' => $package->{name}, 'updates' => $count_updates} );
		}
		
		# return data
		return {'count' => $count, 'list' => @package_list };
		
	} else {
		# return empty
		return {'count' => $count, 'list' => {} };
	}
}

sub phpfpm_version
{
	my ($who_package) = @_;
	
	my $data =  `echo '{"action":"live"}' | /usr/bin/sudo /usr/libexec/nethserver/api/nethserver-httpd/dashboard/read | jq`;

	my $json_data = JSON->new->decode( $data );
	
	# init
	my $return_version="";
	my $return_package="";
	my $return_directory="";
	my $return_code="";
	
	if ( length $json_data->{versions}->{"php_SCL"} ) {
		# get lists
		my $phplist = $json_data->{versions}->{"php_SCL"};
		
		my @keys = keys $phplist;
		
		# init array
		my @version_list;
		my $version_info;
		my $version_directory;
		my $version_code;
		
		foreach my $package (@keys) {
			# get info
			my $this_version = $phplist->{"$package"};
			my ($v1, $v2, $v3) = split('\.', $this_version);
			
			if ( $who_package eq "last" ) {
				# add to list
				push(@version_list, $this_version);
			} elsif ( $who_package eq $package ) {
				# add to list
				push(@version_list, $this_version);
			}
			
			# set info
			$version_info->{"$this_version"} = $package;
			
			# set directory			
			$version_directory->{"$this_version"} = "/var/run/rh-php$v1$v2-php-fpm";
			
			# set code			
			$version_code->{"$this_version"} = "php$v1$v2";
		}
		
		# order
		my @l = sort @version_list;
		# get last
		$return_version = $l[-1];
		
		# get data
		$return_package = $version_info->{"$return_version"};
		$return_directory = $version_directory->{"$return_version"};
		$return_code = $version_code->{"$return_version"};
	}
	
	return {'version' => $return_version, 'package' => $return_package, 'directory' => $return_directory, 'code' => $return_code};
}

1;
