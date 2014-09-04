#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;

# Tests of accounts methods NOT requiring internet connection
# ===========================================================

# Load Module
BEGIN { use_ok('WWW::BetfairNG') };
# Create Object w/o attributes
my $bf = new_ok('WWW::BetfairNG');
# Check all accounts methods exist
my @methods = qw/
		  createDeveloperAppKeys
		  getAccountDetails
		  getAccountFunds
		  getDeveloperAppKeys
		  getAccountStatement
		  listCurrencyRates/;
can_ok('WWW::BetfairNG', @methods);
