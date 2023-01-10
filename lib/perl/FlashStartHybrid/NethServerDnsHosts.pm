# FlashStart Hybrid Firewall 
# Get NethServer Object [ Host | Group Host | Range IP ]

package FlashStartHybrid::NethServerDnsHosts;

use strict;
use warnings;
use esmith::HostsDB;
use JSON;

my $path_DnsRpzList = '/var/named/data/dns_rpz_list/';

sub return_domain
{
	my @return_list;
	
	my $db = esmith::HostsDB->open_ro();

	foreach ($db->get_all_by_prop('type' => 'remote')) {
		# get data
		my $name = $_->key;
		my $wildcard = $_->prop('WildcardMode');
		my $ip = $_->prop('IpAddress');
		
		if ( $wildcard eq 'disabled' ) {
			# add 
			push(@return_list, {'name' => $name, 'ip' => $ip } );
		
		}
		
	}
	return @return_list;
}

sub create_dns_rpz_file
{	
	my ($domain, $ip) = @_;
	
	my $filename = $path_DnsRpzList.$domain;
	
	# create content
	my $content .= qq(\$TTL 60S
@                       IN  SOA         ns1.$domain. $domain. (
                                      2016041951    ; serial
                                        360             ;refresh: 1 day
                                        720             ;retry: 2 hour
                                        2592000         ;expire: 1 month
                                        86400           ;minimum: 1 day
                                        ) ;
                        IN  NS          ns1.$domain.

);
	$content .= "@   \t IN \t A \t $ip\n";
	$content .= "ns1 \t IN \t A \t $ip\n";
	$content .= "\n";
	$content .= "$domain \t A \t $ip\n";
	$content .= "\n";
	
	# create file
    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";;
    print $out $content;
    close $out;
 
    return $filename;
}
	
1;
