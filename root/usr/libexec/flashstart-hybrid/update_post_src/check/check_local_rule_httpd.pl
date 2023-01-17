#!/bin/perl

# ----------------------------------------------------------------
# Check if exits block on 80 and 443 port to Firewall from Red
# ----------------------------------------------------------------

use strict;
use warnings;
use JSON;

# convert to json
my $json_data = JSON->new->decode( $ARGV[0] );

# init
my $add_rule = 1;

# get rules
for my $key (sort keys $json_data->{rules}) {
	# get rule
	my $rule = $json_data->{rules}[$key];
	my $Service = $rule->{Service};	
	
	# init 
	my $check_rule = 0;
	
	# check
	if ( length $Service->{Ports} ) {
		# check ports
		my $Ports = $Service->{Ports};		
		foreach my $port ( @$Ports ) {
			if ( $port eq 80 || $port eq 443 ) {
				# set var
				$check_rule = 1;
			}
		}
	} elsif ( $Service->{name} eq 'any' ) {
		# set var
		$check_rule = 1;
	}
	
	# if find rule and reject
	if ( $check_rule eq 1 && $rule->{Action} eq 'reject' && $rule->{Dst}->{name} eq 'fw' && $rule->{Src}->{zone} eq 'red' ) {	
		$add_rule = 0;
	}
}

# return value
print "$add_rule";
