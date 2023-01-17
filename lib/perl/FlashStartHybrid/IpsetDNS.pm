# FlashStart Hybrid Firewall 
# View/Rule file management

package FlashStartHybrid::IpsetDNS;

use strict;
use warnings;

my $file_IpsetDNS = '/etc/flashstart-hybrid/ipset_dns.conf';
my $fileInit_IpsetDNS = '/usr/libexec/flashstart-hybrid/template/ipset_dns.conf.init';
my $setnameSuffix = "PROFILE";
my $setnameSeparator = "-";
my $fieldSeparator = ";";
my $dnsSeparator = ",";
my $minServicePort = 10000;

sub return_row
{
	my @return_row_list;

	if (-e $file_IpsetDNS) {
		
		open(FH, '<', $file_IpsetDNS) or die $!;
		
		while(<FH>){
			my $row = $_;
			chomp $row;
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			# LINE > PROFILE-53;185.236.104.104,185.236.105.105;0;127.0.0.1;0;
			my ($profileName, $dns, $loID, $loIP, $loCatchAll) = split($fieldSeparator, $row);
			
			if (length $profileName && length $dns && length $loID && length $loIP && $profileName ne '' && $dns ne '' && $loID ne '' && $loIP ne '') {
				
				# extract DNS
				my ($dns1, $dns2) = split($dnsSeparator, $dns);
				# extract port code
				my ($profileLabel, $profileCode) = split($setnameSeparator, $profileName);
				
				my $profilePort = $profileCode;
				if ( $profileCode eq "53" ) {
					$profilePort = "5353";
				}
				# set port over minServicePort
				my $servicePort = $profilePort;
				if ( $profilePort < $minServicePort ) {
					$servicePort = $minServicePort + $profilePort;
				}
				
				push(@return_row_list, {'profile' => $profileName, 'dns1' => $dns1, 'dns2' => $dns2, 'loID' => $loID, 'loIP' => $loIP, 'profile_code' => $profileCode, 'port' => $profilePort, 'service_port' => $servicePort, 'dns_string' => $dns, 'catch_all' => $loCatchAll} );
				
			}
		
		}

		close(FH);
	}
	
	return @return_row_list;
}

sub return_search_profile
{
	my ($sendDns) = @_;
	
	my @list = return_row();
	
	my $profile = "";
	
	foreach my $elem (@list) { 
		
		if ( $sendDns eq "$elem->{dns_string}" ) {
			
			$profile = "$elem->{profile}";
			
			# exit
			last;
			
		}
	}
	
	return $profile;
}

sub return_search_dns
{
	my ($sendProfile) = @_;
	
	my @list = return_row();
	
	my $dns = "";
	
	foreach my $elem (@list) { 
		
		if ( $sendProfile eq "$elem->{profile}" ) {
			
			$dns = "$elem->{dns_string}";
			
			# exit
			last;
			
		}
	}
	
	return $dns;
}

sub return_profile_port
{
	my ($sendProfile) = @_;
	
	my ($profileSuffix, $profilePort) = split($setnameSeparator, $sendProfile);
						 
	
	return $profilePort;
}

sub return_search_by_id
{
	my ($whoID) = @_;
	
	my @list = return_row();
	
	my $return_elem = $list[0];
		
	foreach my $elem (@list) {
	
		if ( "$elem->{loID}" eq "$whoID" ) {
			$return_elem = $elem;
		}
	}
	
	return $return_elem;
}

sub check_restore_empty_file
{
	my $file = $file_IpsetDNS;	
	my @list = return_row();
	
	my $isEmpty = 0;
	
	if (scalar(@list) == 0) {
		$isEmpty = 1;
		
		# restore by init 
		my $data = read_file($fileInit_IpsetDNS);
		write_file($file_IpsetDNS, $data);
	}
	
	return $isEmpty;
}

sub new_dns
{
	my ($sendDns1, $sendDns2, $sendProfileCode, $sendCatchAll) = @_;
	
	my $file = $file_IpsetDNS;	
	my @list = return_row();
	
	my $change = 0;
	my $found = 0;
	my $lastLoID = '';
	my $lastLoIP = '';
	
	my $findString = '';
	my $replaceString = '';
	
	# check exists
	foreach my $elem (@list) { 
		
		if ( $sendProfileCode eq "$elem->{profile_code}" || $sendDns1 eq "$elem->{dns1}" || $sendDns2 eq "$elem->{dns2}" ) {
			
			$found = 1;
			
			# check changed catch all
			if ( $sendCatchAll ne "$elem->{catch_all}" ) {
				
				# fix empty catch_all on older string
				my $catch_all = $elem->{catch_all};
				my $string_catch_all = "$catch_all$fieldSeparator";
				if ( $catch_all eq '' ) {
					$string_catch_all = "";
				}
				
				# set search line
				$findString = "$setnameSuffix$setnameSeparator$elem->{profile_code}$fieldSeparator$elem->{dns1}$dnsSeparator$elem->{dns2}$fieldSeparator$elem->{loID}$fieldSeparator$elem->{loIP}$fieldSeparator$string_catch_all";
				
				# set new line 
				$replaceString = "$setnameSuffix$setnameSeparator$sendProfileCode$fieldSeparator$sendDns1$dnsSeparator$sendDns2$fieldSeparator$elem->{loID}$fieldSeparator$elem->{loIP}$fieldSeparator$sendCatchAll$fieldSeparator";
				
			}
			
			# exit
			last;
			
		} else {
			#update last loopback data
			$lastLoID = $elem->{loID};
			$lastLoIP = $elem->{loIP};
		}
	}
	
	if ( $found == 0 && $lastLoID ne '' && $lastLoIP ne '' ) {
		
		# incremend loopback ID and IP
		my $newLoID = $lastLoID + 1;
		my @arrayLoIp = split /\./, $lastLoIP;
		my $newIp3 = int($arrayLoIp[3]) + 1;
		my $newLoIP = "$arrayLoIp[0].$arrayLoIp[1].$arrayLoIp[2].$newIp3";
		
		# LINE > PROFILE-53;185.236.104.104,185.236.105.105;0;127.0.0.1;0;
		# set line 
		my $add = "$setnameSuffix$setnameSeparator$sendProfileCode$fieldSeparator$sendDns1$dnsSeparator$sendDns2$fieldSeparator$newLoID$fieldSeparator$newLoIP$fieldSeparator$sendCatchAll$fieldSeparator";
		
		# add string
		my $data = read_file($file);
		$data .= "$add\n";
		write_file($file, $data);
		
		# set changed
		$change = 1;
		
	} elsif ( $found == 1 && $findString ne '' && $replaceString ne '' ) {
		
		# replace line
		my $data = read_file($file);
		$data =~ s/$findString/$replaceString/g;
		write_file($file, $data);
		
		# set changed
		$change = 1;
	}
	
	return $change;
}

sub get_catch_all
{
	my $file = $file_IpsetDNS;	
	my @list = return_row();
	
	my $catch_all_loip = "";
		
	foreach my $elem (@list) {
	
		if ( "$elem->{catch_all}" eq '1' ) {
			$catch_all_loip = "$elem->{loIP}";			
		}
	}
	
	# check empty
	if ( $catch_all_loip eq '' ) {
		$catch_all_loip = "$list[0]->{loIP}";			
	}
	
	return $catch_all_loip;
}

sub get_catch_all_data
{
	my ($who) = @_;
	
	my $file = $file_IpsetDNS;	
	my @list = return_row();
	
	my $return_elem = $list[0];
		
	foreach my $elem (@list) {
	
		if ( "$elem->{catch_all}" eq '1' ) {
			$return_elem = $elem;
		}
	}
	
	return $return_elem;
}

sub get_config
{
	my ($who) = @_;
	
	my $result = '';
	
	if ( $who eq 'setname_label' ) {
		$result = $setnameSuffix.$setnameSeparator;
	} elsif ( $who eq 'default_setname' ) {
		$result = $setnameSuffix.$setnameSeparator.'53';
	}
	
	return $result;
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

1;
