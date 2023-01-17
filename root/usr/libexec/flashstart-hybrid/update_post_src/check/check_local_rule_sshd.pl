#!/bin/perl

# ----------------------------------------------------------------
# Check if exits block on sshd port to Firewall from Red
# ----------------------------------------------------------------

use strict;
use warnings;
use JSON;

# convert to json
my $json_data = JSON->new->decode( $ARGV[0] );
my $json_service = JSON->new->decode( $ARGV[1] );

# init
my $add_rule = 1;


# get port for sshd service
my $sshd_port = 0;
for my $key (sort keys $json_service->{"local-services"}) {
	my $service = $json_service->{"local-services"}[$key];
	my $name = $service->{name};	
	if ( $name eq "sshd" ) {
		# get ports
		$sshd_port = $service->{Ports}[0];
	}
}


# get rules
for my $key (sort keys $json_data->{rules}) {
	# get rule
	my $rule = $json_data->{rules}[$key];
	my $Service = $rule->{Service};	
	
	# init 
	my $check_rule = 0;
	
	# check
	if ( $Service->{name} eq 'sshd' ) {
		# set var
		$check_rule = 1;
	}
	
	# if find rule and reject
	if ( $check_rule eq 1 && $rule->{Action} eq 'reject' && $rule->{Dst}->{name} eq 'fw' && $rule->{Src}->{zone} eq 'red' ) {	
		$add_rule = 0;
	}
}

# return value
print "$add_rule;$sshd_port";
