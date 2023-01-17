# FlashStart Hybrid Firewall 
# Get NethServer Object [ Host | Group Host | Range IP ]

package FlashStartHybrid::NethServerObject;

use strict;
use warnings;
use esmith::HostsDB;
use JSON;
use FlashStartHybrid::IP;
use FlashStartHybrid::IpsetDNS;
use List::MoreUtils qw(uniq);
use XML::Twig;

my $dir_session = '/dev/shm';
my $file_session_host = $dir_session.'/fs_hybrid_host.session';
my $file_session_hostGroup = $dir_session.'/fs_hybrid_hostGroup.session';
my $file_session_ipRange = $dir_session.'/fs_hybrid_ipRange.session';

my $file_info_host = $dir_session.'/fs_hybrid_host.info';
my $file_info_hostGroup = $dir_session.'/fs_hybrid_hostGroup.info';
my $file_info_ipRange = $dir_session.'/fs_hybrid_ipRange.info';

sub return_hosts
{
	my @return_list;
	
	my $host_db = esmith::HostsDB->open_ro();
	
	# get all host type
	foreach ($host_db->get_all_by_prop('type' => 'host')) {
		
		my $name = $_->key;
		my $type = $_->prop('type');		
		my $desc = $_->prop('Description') || '';
		my $ip = $_->prop('IpAddress') || next;
		
		# set
		push(@return_list, {'test' => " $name | $type | $desc || $ip", 'name' => $name, 'type' => $type, 'desc' => $desc, 'ip' => $ip } );
	}
	
	# add local type (ex. dhcp reservation object)	
	foreach ($host_db->get_all_by_prop('type' => 'local')) {
		
		my $name = $_->key;
		my $type = 'host'; # change type 
		my $desc = $_->prop('Description') || '';
		my $ip = $_->prop('IpAddress') || next;
		
		# set
		push(@return_list, {'test' => " $name | $type | $desc || $ip", 'name' => $name, 'type' => $type, 'desc' => $desc, 'ip' => $ip } );
	}
	return @return_list;
}

sub return_host_groups
{
	my @return_list;
	
	my $host_db = esmith::HostsDB->open_ro();
	
	# get all host type
	foreach ($host_db->get_all_by_prop('type' => 'host-group')) {
		
		my $name = $_->key;
		my $type = $_->prop('type');		
		my $desc = $_->prop('Description') || '';
		my $members = $_->prop('Members') || next;
		
		# set
		push(@return_list, {'test' => " $name | $type | $desc || $members", 'name' => $name, 'type' => $type, 'desc' => $desc, 'members' => $members } );
	}
				
	return @return_list;
}

sub return_ipranges
{
	my @return_list;
	
	my $host_db = esmith::HostsDB->open_ro();
	
	# get all host type
	foreach ($host_db->get_all_by_prop('type' => 'iprange')) {
		
		my $name = $_->key;
		my $type = $_->prop('type');		
		my $desc = $_->prop('Description') || '';		
		my $ip_start = $_->prop('Start') || next;
		my $ip_end = $_->prop('End') || next;
		
		# set
		push(@return_list, {'test' => " $name | $type | $desc || $ip_start - $ip_end", 'name' => $name, 'type' => $type, 'desc' => $desc, 'ip_start' => $ip_start, 'ip_end' => $ip_end } );
	}
	
	return @return_list;
}

sub return_obj_list_ip
{
	my ($return_mode, $who, $sendName) = @_;
	
	my @return_iplist;
	my @return_sessionlist;
	
	# get list
	my %obj_list = search($who, $sendName);
	
	if ( $obj_list{"result"} == 1 ) {
		
		# return list by type
		if ( $who eq 'host' ) {				# HOST
			# push ip			
			push(@return_iplist, $obj_list{"data"}->{ip} );
			push(@return_sessionlist, {'name' => $obj_list{"data"}->{name}, 'ip' => $obj_list{"data"}->{ip} } );
		
		} elsif ( $who eq 'host_group' ) {	# HOST GROUP
			# get all host of this group
			my @host_list = split(',', $obj_list{"data"}->{members});
			
			foreach my $elem (@host_list) {
				my %this_host = search('host', $elem);
				
				if ( $this_host{"result"} == 1 && $this_host{"data"}->{ip} ne '' ) {					
					push(@return_iplist, $this_host{"data"}->{ip} );
					push(@return_sessionlist, {'name' => $sendName, 'host' => $this_host{"data"}->{name}, 'ip' => $this_host{"data"}->{ip} } );
				}
			}
		
		} elsif ( $who eq 'iprange' ) {		# IP RANGE
			# get all ip of this range
			
			my $ip_start = $obj_list{"data"}->{ip_start};
			my $ip_end = $obj_list{"data"}->{ip_end};
			 
			my $ip_list = new FlashStartHybrid::IP ("$ip_start - $ip_end") || die;
	
			do {			  
			  push(@return_iplist, $ip_list->ip() );
			  push(@return_sessionlist, {'name' => $sendName, 'ip' => $ip_list->{ip} } );
			} while (++$ip_list);
		}		
		
	}
	
	if ($return_mode eq 'session_list') {
		return @return_sessionlist
	} else {
		return @return_iplist
	}
}

sub search
{
	my ($who, $sendName) = @_;
	
	my @list;
	
	if ( $who eq 'host' ) {
		@list = return_hosts();
		
	} elsif ( $who eq 'host_group' ) {		
		@list = return_host_groups();
		
	} elsif ( $who eq 'iprange' ) {		
		@list = return_ipranges();
		
	}
	
	my %result_search = ('result' => 0);
		
	# get line 
	foreach my $elem (@list) { 
		
		if ( $sendName eq "$elem->{name}" ) {
			
			# set result 
			%result_search = ('result' => 1, 'data' => ($elem) );
			
			# exit
			last;
			
		}
	}
	
	return %result_search;	
}

sub search_by_ip
{
	my ($sendIp) = @_;
	
	my @return_list;
	
	my $host_db = esmith::HostsDB->open_ro();
	
	# get all host type
	foreach ($host_db->get_all_by_prop('IpAddress' => $sendIp)) {
		
		my $name = $_->key;
		my $type = $_->prop('type');		
		my $desc = $_->prop('Description') || '';
		
		# change local type 
		if ( $type eq "local" ) {
			$type = "host";
		}
		
		# set
		push(@return_list, {'test' => " $name | $type | $desc ", 'name' => $name, 'type' => $type, 'desc' => $desc } );
	}
	
	
	# Search in range
	#--------------
	my @list = return_ipranges();
	
	# get line 
	foreach my $elem (@list) { 
		# check
		if ( find_ip_in_range($sendIp, $elem->{ip_start}, $elem->{ip_end}) == 1) {			
			my $name = $elem->{name};
			my $type = $elem->{type};		
			my $desc = $elem->{desc};
			
			push(@return_list, {'test' => " $name | $type | $desc", 'name' => $name, 'type' => $type, 'desc' => $desc } );
		}
		
	}
	#--------------
	
				
	return @return_list;
}

sub find_ip_in_range
{	
	my ($ip_to_check, $start, $finish) = @_;
	
	my $result = 0;
		
	my $dword       = 0;
	for ( split( '\.', $ip_to_check ) ) { $dword *= 256; $dword += $_ }
		
	my $start_dword = 0;
	for ( split '\.', $start ) { $start_dword *= 256; $start_dword += $_ }
	my $end_dword = 0;
	for ( split '\.', $finish ) { $end_dword *= 256; $end_dword += $_ }
	
	if ( $dword >= $start_dword and $dword <= $end_dword ) {
		$result = 1;
	}

	return $result;
}

sub objs_to_api
{
	my ($who) = @_;
	
	my @list;
	
	if ( $who eq 'host' ) {
		@list = return_hosts();
		
	} elsif ( $who eq 'host_group' ) {		
		@list = return_host_groups();
		
	} elsif ( $who eq 'iprange' ) {		
		@list = return_ipranges();
	}
	
	my @return_list;
		
	# get line 
	foreach my $elem (@list) {
		
		# set data
		my $api_username = $elem->{name};
		my $api_name = (substr $elem->{desc}, 0, 255) || '';
		my $api_surname = '';
		# set surname 
		if ( $who eq 'host' ) {
			$api_surname = $elem->{ip};		
		} elsif ( $who eq 'host_group' ) {		
			$api_surname = $elem->{members};			
		} elsif ( $who eq 'iprange' ) {		
			$api_surname = "$elem->{ip_start} - $elem->{ip_end}";
		}
		
		$api_surname = (substr $api_surname, 0, 255) || '';
		
		# add
		push(@return_list, JSON->new->encode( { 'username' => $api_username, "name" => $api_name, "surname" => $api_surname } ) );
	}
	
	# convert
	my $json_data = join(',', @return_list);
	
	#
	return $json_data;
}

sub get_session_file
{
	my ($who) = @_;
	
	# set file
	my $file;
	if ( $who eq 'host' ) {
		$file = $file_session_host;
	} elsif ( $who eq 'host_group' ) {
		$file = $file_session_hostGroup;
	} elsif ( $who eq 'iprange' ) {
		$file = $file_session_ipRange;
	}
	
	return $file;
}

sub get_info_file
{
	my ($who) = @_;
	
	# set file
	my $file;
	if ( $who eq 'host' ) {
		$file = $file_info_host;
	} elsif ( $who eq 'host_group' ) {
		$file = $file_info_hostGroup;
	} elsif ( $who eq 'iprange' ) {
		$file = $file_info_ipRange;
	}
	
	return $file;
}

sub clear_session_file
{
	my @file_list;
	# add file to list
	push(@file_list, $file_session_host);
	push(@file_list, $file_session_hostGroup);
	push(@file_list, $file_session_ipRange);
	
	# clear file
	foreach my $file (@file_list) { 
		# delete file
		if ( -e $file ) { unlink $file; }
		# delete .bak
		if ( -e $file.".bak" ) { unlink $file.".bak"; }
	}	
}

sub create_session_row
{
	my ($source, $who, $obj_row) = @_;
	
	# set string
	my $string_session; 
	my @obj_session;
	if ( $who eq 'host' ) {
		if ($source eq 'obj' || $source eq 'obj_edit_line') {
			$string_session = "$obj_row->{name};$obj_row->{ip};";
		
		} elsif ($source eq 'obj_db_compare') {
			$string_session = "$obj_row->{name};$obj_row->{ip};";
			
		} else {		
			my ($host, $ip) = split(';', $obj_row);
			
			if (length $host && length $ip && $host ne '' && $ip ne '') {
				push(@obj_session, {'name' => $host, 'ip' => $ip } );
			}
		}
		
	} elsif ( $who eq 'host_group' ) {
		if ($source eq 'obj' || $source eq 'obj_edit_line') {
			$string_session = "$obj_row->{name};$obj_row->{ip};$obj_row->{host};";
			
		} elsif ($source eq 'obj_db_compare') {
			$string_session = "$obj_row->{use_db_name};$obj_row->{ip};$obj_row->{name};";
			
		} else {	
			my ($host_group, $ip, $host) = split(';', $obj_row);
			
			if (length $host_group && length $ip && length $host && $host_group ne '' && $ip ne '' && $host ne '') {
				push(@obj_session, { 'name' => $host_group, 'ip' => $ip, 'host' => $host} );
			}
		}
		
	} elsif ( $who eq 'iprange' ) {
		if ($source eq 'obj' || $source eq 'obj_edit_line') {
			$string_session = "$obj_row->{name};$obj_row->{ip};";
		
		} elsif ($source eq 'obj_db_compare') {
			$string_session = "$obj_row->{name};$obj_row->{ip};";
			
		} else {
			my ($iprange, $ip) = split(';', $obj_row);
			
			if (length $iprange && length $ip && $iprange ne '' && $ip ne '') {
				push(@obj_session, {'name' => $iprange, 'ip' => $ip } );
			}
		}
		
	}
	
	if ($source eq 'obj') {
		return ($obj_row->{ip}, $string_session);
		
	} elsif ($source eq 'obj_db_compare' || $source eq 'obj_edit_line') {
		return $string_session;
		
	} else {		
		return @obj_session;	
	}
}

sub session_read
{
	my ($who) = @_;
	
	my @return_sessionlist;
	
	# get file
	my $file_session = get_session_file($who);
	
	if ( -e $file_session && -r $file_session) {
		# read file
		open(FH, '<', $file_session) or die $!;	
		while(<FH>){
			my $row = $_;
			chomp $row;
			
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			# get object row
			my @obj_row = create_session_row('file_row', $who, $row);
			
			# push
			push(@return_sessionlist, @obj_row );
		}
		close(FH);
	}
	
	return @return_sessionlist;
}

sub create_info_row
{
	my ($source, $who, $obj_row) = @_;
	
	# set string
	my $string_info; 
	my @obj_info;
	
	if ($source eq 'string') {
		$string_info = "$obj_row->{name};$obj_row->{setname};";
		return $string_info;
		
	} else {		
		my ($name, $setname) = split(';', $obj_row);
		
		if (length $name && length $setname && $name ne '' && $setname ne '') {
			push(@obj_info, {'name' => $name, 'setname' => $setname } );
		}
		return @obj_info;	
	}	
}

sub info_read
{
	my ($who) = @_;
	
	my @return_infolist;
	
	# get file
	my $file_info = get_info_file($who);
	
	if ( -e $file_info && -r $file_info) {
		# read file
		open(FH, '<', $file_info) or die $!;	
		while(<FH>){
			my $row = $_;
			chomp $row;
			
			# exclude comment
			$row =~ s/\s*#.*$//;
			
			# get object row
			my @obj_row = create_info_row('file_row', $who, $row);
			
			# push
			push(@return_infolist, @obj_row );
		}
		close(FH);
	}
	
	return @return_infolist;
}

sub info_search
{
	my ($who, $sendName) = @_;
	
	my @list = info_read($who);
		
	my %result_search = ('result' => 0);
		
	# get line 
	foreach my $elem (@list) { 
		
		if ( $sendName eq "$elem->{name}" ) {
			
			# set result 
			%result_search = ('result' => 1, 'data' => ($elem) );
			
			# exit
			last;
			
		}
	}
	
	return %result_search;	
}

sub session_search_name
{
	my ($who, $sendName) = @_;
	
	# get session list
	my @list_session = session_read($who);
	
	my @return_list;
	
	foreach my $elem (@list_session) {
		# check
		if ( $elem->{name} eq $sendName ) {
			push(@return_list, ($elem) );
		}
	}
	
	return @return_list;	
}

sub session_host_reset
{
	my ($sendName) = @_;
	
	my @object_list;
	my @return_list;
	my $IpAddress;	
	my $host_db = esmith::HostsDB->open_ro();
		
	# get host ip address
	my $db_obj_host = $host_db->get($sendName);
	if( length $db_obj_host ) { $IpAddress = $db_obj_host->prop('IpAddress'); }	
	
	if ( length $IpAddress && $IpAddress ne "") {
		my @where_list;
		# add file to list
		push(@where_list, 'host' );
		push(@where_list, 'host_group' );
		push(@where_list, 'iprange' );
		
		foreach my $where (@where_list) {
			# get session list
			my @list_session = session_read($where);
			
			foreach my $elem (@list_session) {
				# get data
				my $name = $elem->{name};
				my $ip = $elem->{ip};
				my $host = $elem->{host} || next;
				# check
				if ( $elem->{ip} eq $IpAddress ) {
					push(@object_list, {"where" => $where, "name" => $name, "ip" => $ip, "host" => $host } );
				}
			}
		}
	}
	
	# 
	foreach my $elem (@object_list) {		
		# search into info
		my %info_result = info_search($elem->{where}, $elem->{name});
		# set
		if ( $info_result{"result"} == 1 ) {
			push(@return_list, {"setname" => $info_result{"data"}->{setname}, "where" => $elem->{where}, "name" => $elem->{name}, "ip" => $elem->{ip}} );
			# call edit
			my $edit_file = session_edit_line('obj_edit_line', 'del', $elem->{where}, $elem);
		}		
	}
	
	return @return_list;	
}

sub session_create
{
	my ($who, $sendName, $setname) = @_;
	
	# get file
	my $file_session = get_session_file($who);
	my $file_info = get_info_file($who);
	
	# get list
	my @list_session = return_obj_list_ip("session_list", $who, $sendName);
	my @ip_session;
	
	my $session;
	
	# create string
	foreach my $elem (@list_session) {
		# get data
		my ($ip, $string) = create_session_row('obj', $who, $elem);
		# add
		$session .= $string."\n";
		# return ip for ipset
		push(@ip_session, $ip );
	}
	
	# add list
	add_line_file($file_session, $session);
	
	# add into file info
	if ( $file_info ne '' ) {
		my $info = create_info_row('string', $who, {'name' => $sendName, 'setname' => $setname} );
		add_line_file($file_info, $info);
	}
	
	# return ip list
	return @ip_session;
}

sub session_delete
{
	my ($who, $sendName, $setname) = @_;
	
	# get file
	my $file_session = get_session_file($who);
	my $file_info = get_info_file($who);
	
	# get list
	my @list_session = session_search_name($who, $sendName);
	my @ip_session;
	
	# search 
	foreach my $elem (@list_session) {
		# remove ip from file
		my ($ip, $string) = create_session_row('obj', $who, $elem);
		# remove line
		remove_line_file($file_session, $string);
		# Remove Empty Lines from File
		remove_empty_line_file($file_session);
		# return ip for ipset
		push(@ip_session, $ip );
	}
	
	# remove from file info
	if ( $file_info ne '' ) {
		my $info = create_info_row('string', $who, {'name' => $sendName, 'setname' => $setname} );
		remove_line_file($file_info, $info);
		# Remove Empty Lines from File
		remove_empty_line_file($file_info);
	}
	
	# return ip list
	return @ip_session;
}

sub session_create_event
{
	my ($where, $code, $name, $ip, $use_db_type, $use_db_name, $send_setname) = @_;
	
	# get data from FlashStartHybrid::IpsetDNS package
	my $defaultSetname = FlashStartHybrid::IpsetDNS->get_config("default_setname");

	# check setname sended
	my $use_setname = $defaultSetname;
	if ( length $send_setname && $send_setname ne '') {
		$use_setname = $send_setname;
	} else {
		# get setname
		my %info_result = info_search($use_db_type, $use_db_name);
		
		# set
		if ( $info_result{"result"} == 1 ) {
			$use_setname = $info_result{"data"}->{setname};
		}
	}
	
	# set event data
	my $event_data = '';
	if ( $where eq 'local' ) {
		# for local event	> $code,$use_setname,$ip
		$event_data = "$code,$use_setname,$ip";
	} elsif ( $where eq 'api' ) {
		# for api event		> { 'code' => $code, "name" => $name, "type" => $use_db_type }
		$event_data = JSON->new->encode( { 'code' => $code, "name" => $name, "type" => $use_db_type } );
	}
	
	my @obj_job;
	
	push(@obj_job, {
			'where' => $where, 
			'code' => $code, 'name' => $name, 'ip' => $ip, 
			'use_db_type' => $use_db_type, 'use_db_name' => $use_db_name, 'use_setname' => $use_setname, 
			'event_data' => $event_data
	} );
	
	return @obj_job;
}

sub session_edit_line
{
	my ($source, $mode, $who, $elem) = @_;
	
	# get file
	my $use_file = get_session_file( $who );
		
	# create line
	my $string = create_session_row($source, $who, $elem);		
	
	# execute edit
	if ( $mode eq 'add' ) {	
		# add new line
		$string .= "\n";
		# add list
		add_line_file($use_file, $string);	

	} elsif ( $mode eq 'del' ) {			
		# remove line
		remove_line_file($use_file, $string);
	}
	
	return $use_file;
}

sub session_db_compare
{
	my ($who) = @_;
	
	# read session file
	my @list_session = session_read($who);
	my $host_db = esmith::HostsDB->open_ro();
	
	my @event_list;
	
	if ($who eq 'host') {
		# set check type
		my $check_type = 'host';
		# check session
		foreach my $elem (@list_session) {
			# set data
			my $session_name = $elem->{name};
			my $session_ip = $elem->{ip};
			# search in db
			my $db_obj = $host_db->get($session_name); 
			
			# get type
			my $db_obj_type = '';
			if (length $db_obj->prop('type')) {
				$db_obj_type = $db_obj->prop('type'); 
				# change local type 
				if ( $db_obj_type eq "local" ) {
					$db_obj_type = "host";
				}
			}
			
			# check exists
			if ( length $db_obj && length $db_obj->key && $db_obj_type eq $check_type ) {
				my $IpAddress = $db_obj->prop('IpAddress');
				#check ip
				if ( $IpAddress ne $session_ip ) {
					# add local logout
					push(@event_list, session_create_event('local', 'LOGOUT_OBJ', $session_name, $session_ip, $who, $session_name) );
					# add local login of new ip
					push(@event_list, session_create_event('local', 'LOGIN_OBJ', $session_name, $IpAddress, $who, $session_name) );
				}
				
			} else {	
				# add api logout
				push(@event_list, session_create_event('api', 'LOGOUT_OBJ', $session_name, $session_ip, $who, $session_name) );
			}			
		}
	
	} elsif ($who eq 'host_group') {
		# set check type
		my $check_type = 'host-group';
		my @host_list_checked;
		
		#-----------------
		# check session
		#-----------------
		foreach my $elem (@list_session) {
			# set data
			my $session_name = $elem->{name};			
			my $session_ip = $elem->{ip};
			my $session_host = $elem->{host};
			# search in db
			my $db_obj = $host_db->get($session_name); 
			
			# check exists
			if ( length $db_obj && length $db_obj->key && length $db_obj->prop('type') && $db_obj->prop('type') eq $check_type ) {
				# get member list
				my @host_list = split(',', $db_obj->prop('Members') || next );
				# push to checked
				push(@host_list_checked, $session_host);
				
				#check host exists
				if ( grep $_ eq $session_host, @host_list ) {
					# check host ip
					my $IpAddress = '';
					if( length $host_db->get($session_host) ) { 
						my $db_obj_host = $host_db->get($session_host);
						$IpAddress = $db_obj_host->prop('IpAddress'); 
					}
					#check ip
					if ( $IpAddress eq '' ) {
						#  if host deleted  > add local logout
						push(@event_list, session_create_event('local', 'LOGOUT_OBJ', $session_host, $session_ip, $who, $session_name) );
					} elsif ( $IpAddress ne $session_ip ) {
						# add local logout
						push(@event_list, session_create_event('local', 'LOGOUT_OBJ', $session_host, $session_ip, $who, $session_name) );
						# add local login of new ip
						push(@event_list, session_create_event('local', 'LOGIN_OBJ', $session_host, $IpAddress, $who, $session_name) );
					}
				} else {
					# add local logout
					push(@event_list, session_create_event('local', 'LOGOUT_OBJ', $session_host, $session_ip, $who, $session_name) );
				}
				
			} else {	
				# add api logout
				push(@event_list, session_create_event('api', 'LOGOUT_OBJ', $session_name, $session_ip, $who, $session_name) );
			}
		}
		
		#-----------------
		# check new host
		#-----------------
		my @list_info = info_read($who);
		# check info
		foreach my $elem (@list_info) {
			# get data 
			my $name = $elem->{name};
			my $setname = $elem->{setname};
			# get list
			my %obj_list = search($who, $name);
			
			if ( $obj_list{"result"} == 1 ) {
				# get all host of this group
				my @host_list = split(',', $obj_list{"data"}->{members} || next );				
				foreach my $elem_host (@host_list) {
					#check host also checked
					if ( ! grep $_ eq $elem_host, @host_list_checked ) {
						# check host ip
						my $db_obj_host = $host_db->get($elem_host);
						if( length $db_obj_host && length $db_obj_host->prop('IpAddress') ) { 							
							my $IpAddress = $db_obj_host->prop('IpAddress');
							push(@event_list, session_create_event('local', 'LOGIN_OBJ', $elem_host, $IpAddress, $who, $name, $setname) );						
						}
					}
				}
			}
		}
		
	} elsif ($who eq 'iprange') {
		# set check type
		my $check_type = 'iprange';
		my @ip_list_checked;
				
		#-----------------
		# check session
		#-----------------
		foreach my $elem (@list_session) {
			# set data
			my $session_name = $elem->{name};			
			my $session_ip = $elem->{ip};
			# search in db
			my $db_obj = $host_db->get($session_name); 
			
			# check exists
			if ( length $db_obj && length $db_obj->key && length $db_obj->prop('type') && $db_obj->prop('type') eq $check_type ) {
				# get member list				
				my $ip_start = $db_obj->prop('Start') || next;
				my $ip_end = $db_obj->prop('End') || next;
				
				# push to checked
				push(@ip_list_checked, $session_ip);
								
				#check ip is in range
				my $check_ip = find_ip_in_range($session_ip, $ip_start, $ip_end);
				
				# if not found
				if ( $check_ip == 0 ) {					
					# add local logout
					push(@event_list, session_create_event('local', 'LOGOUT_OBJ', $session_name, $session_ip, $who, $session_name) );
				}
				
			} else {	
				# add api logout
				push(@event_list, session_create_event('api', 'LOGOUT_OBJ', $session_name, $session_ip, $who, $session_name) );
			}
		}
		
		#-----------------
		# check new host
		#-----------------
		my @list_info = info_read($who);
		# check info
		foreach my $elem (@list_info) {
			# get data 
			my $name = $elem->{name};
			my $setname = $elem->{setname};
			# get list
			my %obj_list = search($who, $name);
			
			if ( $obj_list{"result"} == 1 ) {
				# get data
				my $ip_start = $obj_list{"data"}->{ip_start};
				my $ip_end = $obj_list{"data"}->{ip_end};
				# create list
				my $ip_list = new FlashStartHybrid::IP ("$ip_start - $ip_end") || die;
				
				do {
					
					# check host also checked
					if ( ! grep $_ eq $ip_list->ip(), @ip_list_checked ) {
						push(@event_list, session_create_event('local', 'LOGIN_OBJ', $name, $ip_list->ip(), $who, $name, $setname ) );
					} 
				} while (++$ip_list);
			}
		}
		
	}
	
	# clear session and info
	my @file_changed;
	foreach my $elem (@event_list) {
		# check local only
		if ( $elem->{where} eq 'local') {
			# get data
			my $who = $elem->{use_db_type};
			
			# check event code
			if ( $elem->{code} eq 'LOGIN_OBJ') {
				# call edit
				my $edit_file = session_edit_line('obj_db_compare', 'add', $who, $elem);
				# push to file changed list
				push(@file_changed, $edit_file );
				
			} elsif ( $elem->{code} eq 'LOGOUT_OBJ') {
				# call edit
				my $edit_file = session_edit_line('obj_db_compare', 'del', $who, $elem);
				# push to file changed list
				push(@file_changed, $edit_file );
				
			}
		}
	}
	
	# unique array 
	my @unique_file = uniq @file_changed;
	# Remove Empty Lines from File
	foreach my $eFile (@file_changed) { remove_empty_line_file($eFile); }
	
	
	return @event_list;
}

sub return_ipset_sessions_list
{
	my ($ipset_file) = @_;
	
	use FlashStartHybrid::IpsetDNS;
	
	# create session list 
	my %session_list_host;
	my %session_host_group;
	my %session_iprange;
	
	# get host session
	my @list_session_host = session_read('host');	
	foreach my $elem (@list_session_host) {
		# add ip
		$session_list_host{ $elem->{ip} }  = {'type' => 'host', 'ip' => $elem->{ip}, 'name' => $elem->{name} };
	}	
	# get host-group session
	my @list_session_host_group = session_read('host_group');	
	foreach my $elem (@list_session_host_group) {
		# add ip
		$session_host_group{ $elem->{ip} } = {'type' => 'host_group', 'ip' => $elem->{ip}, 'name' => $elem->{name}, 'host' => $elem->{host} };
	}
	# get iprange session
	my @list_session_iprange = session_read('iprange');	
	foreach my $elem (@list_session_iprange) {
		# add ip
		$session_iprange{ $elem->{ip} } = {'type' => 'iprange', 'ip' => $elem->{ip}, 'name' => $elem->{name} };
	}
	
	# create XML
	my $twig=XML::Twig->new();
	$twig->parsefile($ipset_file);
	my $root= $twig->root;
	
	# init list
	my @ipset_list;

	# parse list
	my @list = $root->children('ipset');   # get the para children
	foreach my $elem (@list) { 
		# get name
		my $name = $elem->{'att'}->{'name'};
		
		# if flashstart profile
		if ( $name =~ /^PROFILE-/ ) {
			# get members
			my $members = $elem->first_child('members');			
			my @list_ip = $members->children('member');
			
			# get ip list
			foreach my $elem_ip (@list_ip) {
				# get ip
				my $ip = $elem_ip->first_child_text('elem');
				# get port
				my $profilePort = FlashStartHybrid::IpsetDNS::return_profile_port($name);				

				# check ip in session list
				if ( exists($session_list_host{$ip}) ) {
					# add to list
					push(@ipset_list, {'profile' => $name, 'port' => $profilePort, 'ip' => $ip, 'session' => $session_list_host{$ip} } );
					
				} elsif ( exists($session_host_group{$ip}) ) {
					# add to list
					push(@ipset_list, {'profile' => $name, 'port' => $profilePort, 'ip' => $ip, 'session' => $session_host_group{$ip} } );
					
				} elsif ( exists($session_iprange{$ip}) ) {
					# add to list
					push(@ipset_list, {'profile' => $name, 'port' => $profilePort, 'ip' => $ip, 'session' => $session_iprange{$ip} } );
					
				}
			}
		}
	}
	
	return @ipset_list;
}

sub read_file {
    my ($filename) = @_;
	
	my $all;
	
	if ( -e $filename && -r $filename ) {
		open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
		local $/ = undef;
		$all = <$in>;
		close $in;		
	}
	
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

sub remove_empty_line_file {
	 my ($filename) = @_;
	 
	local @ARGV = $filename;
	local $^I = '.bak';
	while (<>) {
		#tr/ "//d;           # Remove spaces and double quotes
		print if ! /^$/;    # Skip blank lines
	}
	unlink "$filename$^I"; # Optionally delete backup
	
	return;
}

	
1;
