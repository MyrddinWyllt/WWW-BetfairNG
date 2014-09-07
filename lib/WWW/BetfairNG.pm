package WWW::BetfairNG;
use strict;
use warnings;
use JSON;
use REST::Client;
use Carp qw /croak/;

# Define Betfair Endpoints
use constant BF_BETTING_ENDPOINT => 'https://api.betfair.com/exchange/betting/rest/v1';
use constant BF_C_LOGIN_ENDPOINT => 'https://identitysso.betfair.com/api/certlogin';
use constant BF_LOGIN_ENDPOINT   => 'https://identitysso.betfair.com/api/login';
use constant BF_LOGOUT_ENDPOINT  => 'https://identitysso.betfair.com/api/logout';
use constant BF_KPALIVE_ENDPOINT => 'https://identitysso.betfair.com/api/keepAlive';
use constant BF_ACCOUNT_ENDPOINT => 'https://api.betfair.com/exchange/account/rest/v1.0';

=head1 NAME

WWW::BetfairNG - Object-oriented Perl interface to the Betfair JSON API

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

  use WWW::BetfairNG;

  my $bf = WWW::BetfairNG->new();
  $bf->ssl_cert(<path to ssl cert file>);
  $bf->ssl_key(<path to ssl key file>);
  $bf->app_key(<application key>);

  $bf->login({username => <username>, password => <password>});
  ...
  $bf->keepAlive();
  ...
  $bf->logout();

=head1 DESCRIPTION

Betfair is an online betting exchange which allows registered users to interact with it
using a JSON-based API. This module provides an interface to that service which handles
the JSON exchange, taking and returning perl data structures (usually hashrefs). Although
some checking of the existence of required parameter fields is done, and a listing of the
BETFAIR DATA TYPES is provided below, it requires a level of understanding of the Betfair
API which is best gained from their own documentation, available from
L<https://developer.betfair.com/>

To use this library, you will need a funded Betfair account and an application key. To use
the non-interactive log in, you will also need an SSL certificate and key (in seperate
files, rather than a single .pem file). Details of how to create or obtain these, and how
to register your certificate with Betfair are also available on the above website. The
interactive login does not require an SSL certificate or key and is therefore easier to
set up, but Betfair strongly recommend that unattended bots use the non-interactive
version.

=head1 METHODS

=head2 Construction and Setup

=head3 new([$parameters])

  my $bf = new WWW::BetfairNG;          OR
  my $bf = WWW::BetfairNG->new();       OR
  my $bf = WWW::BetfairNG->new({
                                ssl_cert => '<path to ssl certificate file>',
                                ssl_key  => '<path to ssl key file>',
                                app_key  => '<application key value>',
                               });

Creates a new instance of the WWW::BetfairNG class. Takes an optional hash or hash
reference of configurable attributes to set the application key and/or paths to ssl cert
and key files. (These may also be set after instantiation via the accessors described
below, but in any case the ssl cert and key need to be present for a successful
non-interactive login). The application key is required for most of the API calls, but not
for login/logout or 'getDeveloperAppKeys', so if necessary the key can be retrieved from
Betfair and then passed to the object using $bf->app_key. You can also 
possible for some reason, but an active session token can be obtained by other means, this
may also be passed to the new object using {session => <session token value>}.

=cut

sub new {
    my $class = shift;
    # set attributes configurable at instantiation
    my $self = {
        ssl_cert  => '',
        ssl_key   => '',
        app_key   => '',
        session   => '',
    };
    # check if we were passed any configurable parameters and load them
    if (@_) {
      my $params = shift;
      unless(ref($params) eq 'HASH') {
	croak 'Parameters must be a hash ref or anonymous hash';
      }
      for my $key (keys %$params) {
	unless (exists $self->{$key}) {
	  croak "Unknown key value $key in parameter hash";
	}
	$self->{$key} = $params->{$key};
      }
    }
    # set non-configurable attributes
    $self->{error}    = 'OK',
    $self->{response} = {};
    my $obj = bless $self, $class;
    # Create a REST::Client object to do all the heavy lifting
    my $client = REST::Client->new;
    # Set defaults for betting API requests - overridden by login, logout etc.
    $client->setHost(BF_BETTING_ENDPOINT);
    $client->setTimeout(5);
    $client->addHeader('Content-Type',    'application/json');
    $client->addHeader('Accept',          'application/json');
    $client->addHeader('Connection',      'Keep-Alive');
    $client->addHeader('Accept-Encoding', 'gzip');
    $client->addHeader('User-Agent',      "WWW::BetfairNG/$VERSION");
    $obj->{client} = $client;
    return $obj;
}

=head2 Accessors

=head3 ssl_cert([<path to ssl cert file>])

  my $cert_file = $bf->ssl_cert();
  $bf->ssl_cert('<path to ssl certificate file>');

Gets or sets the path to the file containing the client certificate required for
non-interactive login. Default is '', so this needs to be set for a sucessful login. See
Betfair documentation for details on how to create and register client SSL certificates
and keys.

=cut

sub ssl_cert {
  my $self = shift;
  if (@_){$self->{ssl_cert} = shift};
  return $self->{ssl_cert};
}

=head3 ssl_key([<path to ssl key file>])

  my $key_file = $bf->ssl_key();
  $bf->ssl_key('<path to ssl key file>');

Gets or sets the path to the file containing the client key required for
non-interactive login. Default is '', so this needs to be set for a sucessful
login. See Betfair documentation for details on how to create and register client SSL
certificates and keys.

=cut

sub ssl_key {
  my $self = shift;
  if (@_){$self->{ssl_key} = shift};
  return $self->{ssl_key};
}

=head3 app_key([<key value>])

  my $app_key = $bf->app_key();
  $bf->app_key('<application key value>');

Gets or sets the application key required for most communications with the API. This key
is not required to log in or to use 'getDeveloperAppKeys', so it may be retrieved from
Betfair and then passed to the object using this accessor. It may also be possible to
create the app keys using 'createDeveloperAppKeys', but as this call fails if keys already
exist, it was not possible to test this. See Betfair documentation for how to obtain
Application Keys using their API-NG Visualiser.

=cut

sub app_key {
  my $self = shift;
  if (@_) {
    $self->{app_key} = shift;
    $self->{client}->addHeader('X-Application', $self->{app_key});
  }
  return $self->{app_key};
}

=head3 session()

  my $session_token = $bf->session();
  $bf->session('<session token value>');

Gets or sets the current Session Token. Contains '' if logged out. Normally this is set
automatically at login and after keepAlive, and unset at logout, but it can be set by hand
if necessary.

=cut

sub session {
  my $self = shift;
  if (@_){
    $self->{session} = shift;
    $self->{client}->addHeader('X-Authentication', $self->{session});
  }
  return $self->{session};
}

=head3 error()

  my $err_str = $bf->error();

Read-only string containing the last error encountered. This is not reset by sucessful
calls, so the return value of the method needs to be checked to determine success or
failure (all methods return '0' if any error is encountered):

  unless ($ret_value = $bf->someCall($parameters) {
    $err_str = $bf->error();
    print "someCall FAILED : $err_str\n";
    <error handling code>
  }

Errors at any stage will populate this string, including connection timeouts and HTTP
errors. If the call makes it as far as the Betfair API before failing (for instance, a
lack of available funds), the decoded JSON response will be available in $bf->response and
may well contain more detailed and descriptive error messages, so this is probably the
best place to look if the high level Betfair error string returned in $bf->error() is
vague or ambiguous. (This is especially useful in cases where a number of bets are
submitted for processing, and one of them fails - this usually makes the whole call fail,
and the only way to find the culprit is to dig through the response and find the bet which
caused the problem).

=cut

sub error {
  my $self = shift;
  return $self->{error};
}

=head3 response()

  my $resp = $bf->response();

Read-only hash ref containing the last successful response from the API (for certain
values of 'successful'). If an API call succeeds completely, it will return a hash
reference containing the decoded JSON response (which will be identical to $bf->response),
so in this case, $bf->response() is pretty much redundant. If ANY error is encountered,
the return value from the API call will be '0', and in this case more details on the
specific error can often be found by examining $bf->response(). (Obviously this only works
for calls which fail after reaching the API; an HTTP 404 error, for example, will leave
the response from the previous successful API call in $bf->response).

=cut

sub response {
  my $self = shift;
  return $self->{response};
}


=head1 API CALLS

These are generally of the form '$return_value = $bf->someCall($parameters)', where
'$parameters' is a hash reference (or anonymous hash) containing one or more BETFAIR DATA
TYPES (described below), and $return_value is a hash or array reference, again containing
one or more BETFAIR DATA TYPES. Many of these data types are straightforward lists or
hashes of scalars, but some are quite complex structures. Depending on the call, some
parameters may be required (RQD) and others may be optional (OPT). A check for the
existence of required parameters is made before a call is despatched, but no detailed
checking is made of the data structures to make sure they conform to what Betfair expects
- the call is just sent 'as is' to the API, and any errors in the construction of the hash
will result in an error being returned by Betfair. Any error in a call, for whatever
reason, will result in a $return_value of '0'. In this case, $bf->error() will contain a
string describing the error and further details of the error may be found by examining
$bf->response().


=head2 Session Methods

=head3 login({username => 'username', password => 'password'})

  my $return_value = $bf->login({username => 'username', password => 'password'});

Logs in to the application using the supplied username and password. For a successful
login, 'ssl_cert' and 'ssl_key' must already be set. Returns '1' if the login succeeded,
'0' if any errors were encountered.

=cut

sub login {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Username and Password Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{username} and $params->{password}) {
    $self->{error} = 'Username and Password Required';
    return 0;
  }
  my $cert_file = $self->ssl_cert();
  unless ($cert_file) {
    $self->{error} = 'SSL Client Certificate Required';
    return 0;
  }
  my $key_file = $self->ssl_key();
  unless ($key_file) {
    $self->{error} = 'SSL Client Key Required';
    return 0;
  }
  # Stash the standard client and swap it for a login version
  my $saved_client  = $self->{client};
  my $client  = REST::Client->new;
  # Set login-specific headers
  $client->setHost(BF_C_LOGIN_ENDPOINT);
  $client->setTimeout(5);
  $client->addHeader('Content-Type',    'application/x-www-form-urlencoded');
  $client->addHeader('X-Application',    $self->app_key);
  $client->addHeader('Connection',      'Keep-Alive');
  $client->addHeader('Accept-Encoding', 'gzip');
  $client->addHeader('User-Agent',      "WWW::BetfairNG/$VERSION");
  $client->setCert($self->ssl_cert);
  $client->setKey($self->ssl_key);
  $self->{client} = $client;
  # Make and check the request
  my $content = 'username='.$params->{username}.'&password='.$params->{password};
  $self->{client}->POST('/', $content);
  unless ($self->{client}->responseCode == 200) {
    $self->{error}  = $self->{client}->{_res}->status_line;
    $self->{client} = $saved_client;
    return 0;
  }
  $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
  unless ($self->{response}->{loginStatus} eq 'SUCCESS') {
    $self->{error}  = $self->{response}->{loginStatus};
    $self->{client} = $saved_client;
    return 0;
  }
  # Swap the standard client back in
  $self->{client} = $saved_client;
  $self->session($self->{response}->{sessionToken});
  return 1;
}

=head3 interactiveLogin({{username => 'username', password => 'password'}})

  my $return_value = $bf->interactiveLogin({username => 'username',
                                            password => 'password'});

Logs in to the application using the supplied username and password. This method doesn't
use SSL certificates, so it will work without setting those up. However, Betfair STRONGLY
RECOMMEND that unattended bots use the non-interactive login ($bf->login()). Returns '1'
if the login succeeded, '0' if any errors were encountered.

=cut

sub interactiveLogin {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Username and Password Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{username} and $params->{password}) {
    $self->{error} = 'Username and Password Required';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  my $got_app_key = $self->app_key;
  $self->app_key('login') unless $got_app_key;
  $self->{client}->setHost(BF_LOGIN_ENDPOINT);
  $self->{client}->addHeader('Content-Type', 'application/x-www-form-urlencoded');
  my $content = 'username='.$params->{username}.'&password='.$params->{password};
  $self->{client}->POST('/', $content);
  $self->app_key(undef) unless $got_app_key;
  unless ($self->{client}->responseCode == 200) {
    $self->{error}  = $self->{client}->{_res}->status_line;
    $self->{client}->setHost($saved_host);
    $self->{client}->addHeader('Content-Type', 'application/json');
    return 0;
  }
  $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
  unless ($self->{response}->{status} eq 'SUCCESS') {
    $self->{error}  = $self->{response}->{error};
    $self->{client}->setHost($saved_host);
    $self->{client}->addHeader('Content-Type', 'application/json');
    return 0;
  }
  # Swap the standard host back in
  $self->{client}->setHost($saved_host);
  $self->{client}->addHeader('Content-Type', 'application/json');
  $self->session($self->{response}->{token});
  return 1;
}

=head3 logout()

  my $return_value = $bf->logout();

Logs out of the application. Returns '1' if the logout succeeded,'0' if any errors were
encountered.

=cut

sub logout {
  my $self = shift;
  unless ($self->session){
    $self->{error} = 'Not logged in';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_LOGOUT_ENDPOINT);
  $self->{client}->addHeader('Connection', 'Close');
  $self->{client}->GET('/');
  $self->{client}->addHeader('Connection', 'Keep-Alive');
  unless ($self->{client}->responseCode == 200) {
    $self->{error}  = $self->{client}->{_res}->status_line;
    $self->{client}->setHost($saved_host);
    return 0;
  }
  $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
  unless ($self->{response}->{status} eq 'SUCCESS') {
    $self->{error}  = $self->{response}->{error};
    $self->{client}->setHost($saved_host);
    return 0;
  }
  # Swap the standard host back in
  $self->{client}->setHost($saved_host);
  $self->session('');
  return 1;
}

=head3 keepAlive()

  my $return_value = $bf->keepAlive();

Sends a 'Keep Alive' message to the host. Without this, the session will time out after
about twelve hours. Unlike the SOAP interface, other API calls do NOT reset the timeout;
it has to be done explicitly with a 'keepAlive'. Returns '1' if the keepAlive succeeded,
'0' if any errors were encountered.

=cut

sub keepAlive {
  my $self = shift;
  unless ($self->session){
    $self->{error} = 'Not logged in';
    return 0;
  }
  unless ($self->app_key){
    $self->{error} = 'No application key set';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_KPALIVE_ENDPOINT);
  $self->{client}->GET('/');
  unless ($self->{client}->responseCode == 200) {
    $self->{error}  = $self->{client}->{_res}->status_line;
    $self->{client}->setHost($saved_host);
    return 0;
  }
  $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
  unless ($self->{response}->{status} eq 'SUCCESS') {
    $self->{error}  = $self->{response}->{error};
    $self->{client}->setHost($saved_host);
    return 0;
  }
  # Swap the standard host back in
  $self->{client}->setHost($saved_host);
  $self->session($self->{response}->{token});
  return 1;
}

=head2 Betting Operations

The descriptions of these methods are taken directly from the Betfair documentation.  A
listing is given of parameters which can be passed to each method together with their data
type (BETFAIR DATA TYPES are described below). Required parameters are marked as RQD and
optional ones as OPT. If a parameter is marked as RQD, you need to pass it even if it
contains no data, so a MarketFilter which selects all markets would be passed as:

  filter => {}

=head3 listCompetitions($parameters)

  my $return_value = $bf->listCompetitions({filter => {}});

Returns a list of Competitions (i.e., World Cup 2013) associated with the markets selected
by the MarketFilter. Currently only Football markets have an associated competition.

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         CompetitionResult

=cut

sub listCompetitions {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listCompetitions/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listCountries($parameters)

  my $return_value = $bf->listCountries({filter => {}});

Returns a list of Countries associated with the markets selected by the MarketFilter.

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         CountryCodeResult

=cut

sub listCountries {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listCountries/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listCurrentOrders([$parameters])

  my $return_value = $bf->listCurrentOrders();

Returns a list of your current orders. Optionally you can filter and sort your current
orders using the various parameters, setting none of the parameters will return all of
your current orders, up to a maximum of 1000 bets, ordered BY_BET and sorted
EARLIEST_TO_LATEST. To retrieve more than 1000 orders, you need to make use of the
fromRecord and recordCount parameters.

Parameters

  betIds            Array of Strings    OPT
  MarketIds         Array of Strings    OPT
  orderProjection   OrderProjection     OPT
  dateRange         TimeRange           OPT
  orderBy           OrderBy             OPT
  sortDir           SortDir             OPT
  fromRecord        Integer             OPT
  recordCount       Integer             OPT

Return Value

  currentOrders     Array of CurrentOrderSummary
  moreAvailable     Boolean

=cut

sub listCurrentOrders {
  my $self = shift;
  my $params = shift || {};
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  my $url = '/listCurrentOrders/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listClearedOrders([$parameters])

  my $return_value = $bf->listClearedOrders({betStatus => 'SETTLED'});

Returns a list of settled bets based on the bet status, ordered by settled date.  To
retrieve more than 1000 records, you need to make use of the fromRecord and recordCount
parameters. (NOTE The default ordering is DESCENDING settled date, so most recently
settled is listed first).

Parameters

  betStatus         BetStatus           RQD
  eventTypeIds      Array of Strings    OPT
  eventIds          Array of Strings    OPT
  marketIds         Array of Strings    OPT
  runnerIds         Array of Strings    OPT
  betIds            Array of Strings    OPT
  side              Side                OPT
  settledDateRange  TimeRange           OPT
  groupBy           GroupBy             OPT
  includeItemDescription     Boolean    OPT
  locale            String              OPT
  fromRecord        Integer             OPT
  recordCount       Integer             OPT

Return Value

  clearedOrders     Array of ClearedOrderSummary
  moreAvailable     Boolean

=cut

sub listClearedOrders {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Bet Status is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{betStatus}) {
    $self->{error} = 'Bet Status is Required';
    return 0;
  }
  my $url = '/listClearedOrders/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listEvents($parameters)

  my $return_value = $bf->listEvents({filter => {}});

Returns a list of Events associated with the markets selected by the MarketFilter.

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         EventResult

=cut

sub listEvents {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listEvents/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listEventTypes($parameters)

  my $return_value = $bf->listEventTypes({filter => {}});

Returns a list of Event Types (i.e. Sports) associated with the markets selected
by the MarketFilter.

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         EventTypeResult

=cut

sub listEventTypes {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listEventTypes/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listMarketBook($parameters)

  my $return_value = $bf->listMarketBook({marketIds => [<market id>]});

Returns a list of dynamic data about markets. Dynamic data includes prices, the status of
the market, the status of selections, the traded volume, and the status of any orders you
have placed in the market. Calls to listMarketBook should be made up to a maximum of 5
times per second to a single marketId.

Parameters

  marketIds         Array of Strings    RQD
  priceProjection   PriceProjection     OPT
  orderProjection   OrderProjection     OPT
  matchProjection   MatchProjection     OPT
  currencyCode      String              OPT
  locale            String              OPT

Return Value

  Array Ref         MarketBook

=cut

sub listMarketBook {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Ids are Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{marketIds}) {
    $self->{error} = 'Market Ids are Required';
    return 0;
  }
  my $url = '/listMarketBook/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listMarketCatalogue($parameters)

  my $return_value = $bf->listMarketCatalogue({filter => {}, maxResults => 1});

Returns a list of information about markets that does not change (or changes very rarely).
You use listMarketCatalogue to retrieve the name of the market, the names of selections
and other information about markets.  Market Data Request Limits apply to requests made
to listMarketCatalogue.

Parameters

  filter            MarketFilter                 RQD
  marketProjection  Array of MarketProjection    OPT
  sort              MarketSort                   OPT
  maxResults        Integer                      RQD
  locale            String                       OPT

Return Value

  Array Ref         MarketCatalogue

=cut

sub listMarketCatalogue {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  unless ($params->{maxResults}) {
    $self->{error} = 'maxResults is Required';
    return 0;
  }
  my $url = '/listMarketCatalogue/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listMarketProfitAndLoss($parameters)

  my $return_value = $bf->listMarketProfitAndLoss({marketIds => [<market id>]});

Retrieve profit and loss for a given list of markets. The values are calculated using
matched bets and optionally settled bets. Only odds (MarketBettingType = ODDS) markets
are implemented, markets of other types are silently ignored.

Parameters

  marketIds         Array of Strings    RQD
  includeSettledBets         Boolean    OPT
  includeBspBets             Boolean    OPT
  netOfCommission            Boolean    OPT

Return Value

  Array Ref         MarketProfitAndLoss

=cut

sub listMarketProfitAndLoss {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Ids are Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{marketIds}) {
    $self->{error} = 'Market Ids are Required';
    return 0;
  }
  my $url = '/listMarketProfitAndLoss/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listMarketTypes($parameters)

  my $return_value = $bf->listMarketTypes({filter => {}});

Returns a list of market types (i.e. MATCH_ODDS, NEXT_GOAL) associated with the markets
selected by the MarketFilter. The market types are always the same, regardless of locale

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         MarketTypeResult

=cut

sub listMarketTypes {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listMarketTypes/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listTimeRanges($parameters)

  my $return_value = $bf->listMarketTypes({filter => {}, granularity => 'DAYS'});

Returns a list of time ranges in the granularity specified in the request (i.e. 3PM
to 4PM, Aug 14th to Aug 15th) associated with the markets selected by the MarketFilter.

Parameters

  filter            MarketFilter        RQD
  granularity       TimeGranularity     RQD

Return Value

  Array Ref         TimeRangeResult

=cut

sub listTimeRanges {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  unless ($params->{granularity}) {
    $self->{error} = 'Time Granularity is Required';
    return 0;
  }
  my $url = '/listTimeRanges/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 listVenues($parameters)

  my $return_value = $bf->listVenues({filter => {}});

Returns a list of Venues (i.e. Cheltenham, Ascot) associated with the markets
selected by the MarketFilter. Currently, only Horse Racing markets are associated
with a Venue.

Parameters

  filter            MarketFilter        RQD
  locale            String (ISO 3166)   OPT

Return Value

  Array Ref         VenueResult

=cut

sub listVenues {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{filter}) {
    $self->{error} = 'Market Filter is Required';
    return 0;
  }
  my $url = '/listVenues/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}

=head3 placeOrders($parameters)

  my $return_value = $bf->placeOrders({marketId    => <market id>,
	                              instructions => [{
				             selectionId => <selection id>,
				                handicap => "0",
				                    side => "BACK",
				               orderType => "LIMIT",
		         	              limitOrder => {
				       	             size  => <bet size>,
					             price => <requested price>,
				           persistenceType => "LAPSE"
                                                            }
                                                      }]
                                     });

Place new orders into market. This operation is atomic in that all orders will
be placed or none will be placed. Please note that additional bet sizing rules
apply to bets placed into the Italian Exchange.

Parameters

  marketId          String                      RQD
  instructions      Array of PlaceInstruction   RQD
  customerRef       String                      OPT

Return Value

  customerRef       String
  status            ExecutionReportStatus
  errorCode         ExecutionReportErrorCode
  marketId          String
  instructionReports  Array of PlaceInstructionReport

=cut

sub placeOrders {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{marketId}) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  unless ($params->{instructions}) {
    $self->{error} = 'Order Instructions are Required';
    return 0;
  }
  my $url = '/placeOrders/';
  my $result = $self->_callAPI($url, $params);
  if ($result) {
    my $status = $result->{status};
    unless ($status eq 'SUCCESS') {
      $self->{error} = $status;
      if ($result->{errorCode}) {
	$self->{error} .= " : ".$result->{errorCode};
      }
      return 0;
    }
  }
  return $result;
}

=head3 cancelOrders([$parameters])

  my $return_value = $bf->cancelOrders();

Cancel all bets OR cancel all bets on a market OR fully or partially cancel
particular orders on a market. Only LIMIT orders can be cancelled or partially
cancelled once placed. Calling this with no parameters will CANCEL ALL BETS.

Parameters

  marketId          String                      OPT
  instructions      Array of CancelInstruction  OPT
  customerRef       String                      OPT

Return Value

  customerRef       String
  status            ExecutionReportStatus
  errorCode         ExecutionReportErrorCode
  marketId          String
  instructionReports  Array of CancelInstructionReport

=cut

sub cancelOrders {
  my $self = shift;
  my $params = shift || {};
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  my $url = '/cancelOrders/';
  my $result = $self->_callAPI($url, $params);
  return $result;
}


=head3 replaceOrders($parameters)

  my $return_value = $bf->replaceOrders({marketId => <market id>,
			             instructions => [{
                                               betId => <bet id>,
                                            newPrice => <new price>
                                                     }]
                                       });

This operation is logically a bulk cancel followed by a bulk place. The
cancel is completed first then the new orders are placed. The new orders
will be placed atomically in that they will all be placed or none will be
placed. In the case where the new orders cannot be placed the cancellations
will not be rolled back.

Parameters

  marketId          String                      RQD
  instructions      Array of ReplaceInstruction RQD
  customerRef       String                      OPT

Return Value

  customerRef       String
  status            ExecutionReportStatus
  errorCode         ExecutionReportErrorCode
  marketId          String
  instructionReports  Array of ReplaceInstructionReport

=cut

sub replaceOrders {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{marketId}) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  unless ($params->{instructions}) {
    $self->{error} = 'Replace Instructions are Required';
    return 0;
  }
  my $url = '/replaceOrders/';
  my $result = $self->_callAPI($url, $params);
  if ($result) {
    my $status = $result->{status};
    unless ($status eq 'SUCCESS') {
      $self->{error} = $status;
      if ($result->{errorCode}) {
	$self->{error} .= " : ".$result->{errorCode};
      }
      return 0;
    }
  }
  return $result;
}

=head3 updateOrders($parameters)

  my $return_value = $bf->updateOrders({marketId => <market id>,
			             instructions => [{
                                               betId => <bet id>,
                                  newPersistenceType => "LAPSE"
                                                     }]
                                       });

Update non-exposure changing fields.

Parameters

  marketId          String                      RQD
  instructions      Array of UpdateInstruction  RQD
  customerRef       String                      OPT

Return Value

  customerRef       String
  status            ExecutionReportStatus
  errorCode         ExecutionReportErrorCode
  marketId          String
  instructionReports  Array of UpdateInstructionReport

=cut

sub updateOrders {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{marketId}) {
    $self->{error} = 'Market Id is Required';
    return 0;
  }
  unless ($params->{instructions}) {
    $self->{error} = 'Update Instructions are Required';
    return 0;
  }
  my $url = '/updateOrders/';
  my $result = $self->_callAPI($url, $params);
  if ($result) {
    my $status = $result->{status};
    unless ($status eq 'SUCCESS') {
      $self->{error} = $status;
      if ($result->{errorCode}) {
	$self->{error} .= " : ".$result->{errorCode};
      }
      return 0;
    }
  }
  return $result;
}

=head2 Accounts Operations

As with the Betting Operations, the descriptions of these methods are taken directly from
the Betfair documentation. Once again, required parameters are denoted by RQD and optional
ones by OPT. Some parameters are described in terms of BETFAIR FATA TYPES, which are
described below.

=head3 createDeveloperAppKeys($parameters)

  my $return_value = createDeveloperAppKeys(<application name>);

Create two application keys for given user; one active and the other delayed. NOTE as this
call fails if the keys have already been created, it has NOT BEEN TESTED.

Parameters

  appName           String              RQD

Return Value

  appName           String
  appId             Long
  appVersions       Array of DeveloperAppVersion

=cut

sub createDeveloperAppKeys {
  my $self = shift;
  unless (@_) {
    $self->{error} = 'App Name is Required';
    return 0;
  }
  my $params = shift;
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  unless ($params->{appName}) {
    $self->{error} = 'App Name is Required';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/createDeveloperAppKeys/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

=head3 getAccountDetails()

  my $return_value = getAccountDetails();

Returns the details relating [to] your account, including your discount rate and Betfair
point balance. Takes no parameters.

Return Value

  currencyCode      String
  firstName         String
  lastName          String
  localeCode        String
  region            String
  timezone          String
  discountRate      Double
  pointsBalance     Integer

=cut

sub getAccountDetails {
  my $self = shift;
  my $params = {};
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/getAccountDetails/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

=head3 getAccountFunds()

  my $return_value = getAccountFunds();

Get available to bet amount. Takes no parameters.

Return Value

  availableToBetBalance  Double
  exposure               Double
  retainedCommission     Double
  exposureLimit          Double
  discountRate           Double
  pointsBalance          Integer

=cut

sub getAccountFunds {
  my $self = shift;
  my $params = {};
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/getAccountFunds/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

=head3 getDeveloperAppKeys()

  my $return_value = getDeveloperAppKeys();

Get all application keys owned by the given developer/vendor. Takes no parameters.

Return Value

  Array Ref         DeveloperApp

=cut

sub getDeveloperAppKeys {
  my $self = shift;
  my $params = {};
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/getDeveloperAppKeys/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

=head3 getAccountStatement([$parameters])

  my $return_value = getAccountStatement();

Get Account Statement.

Parameters

  locale            String              OPT
  fromRecord        Integer             OPT
  recordCount       Integer             OPT
  itemDateRange     TimeRange           OPT
  includeItem       IncludeItem         OPT
  wallet            Wallet              OPT

Return Value

  accountStatement  Array of StatementItem
  moreAvailable     Boolean

=cut

sub getAccountStatement {
  my $self = shift;
  my $params = shift || {};
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/getAccountStatement/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

=head3 listCurrencyRates([$parameters])

  my $return_value = listCurrencyRates();

Returns a list of currency rates based on given currency.

Parameters

  fromCurrency      String              OPT

Return Value

  Array Ref         CurrencyRate

=cut

sub listCurrencyRates {
  my $self = shift;
  my $params = shift || {};
  unless(ref($params) eq 'HASH') {
    $self->{error} = 'Parameters must be a hash ref or anonymous hash';
    return 0;
  }
  my $saved_host = $self->{client}->getHost;
  $self->{client}->setHost(BF_ACCOUNT_ENDPOINT);
  my $url = '/listCurrencyRates/';
  my $result = $self->_callAPI($url, $params);
  $self->{client}->setHost($saved_host);
  return $result;
}

#=================#
# Private Methods #
#=================#

sub _callAPI {
  my ($self, $url, $params) = @_;
  unless ($self->session){
    $self->{error} = 'Not logged in';
    return 0;
  }
  unless ($self->app_key or ($url =~ /DeveloperAppKeys/)){
    $self->{error} = 'No application key set';
    return 0;
  }
  $self->{client}->POST($url, encode_json($params));
  unless ($self->{client}->responseCode == 200) {
    if ($self->{client}->responseCode == 400) {
      $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
      $self->{error}  = $self->{response}->{detail}->{APINGException}->{errorCode} ||
	$self->{client}->{_res}->status_line;
    }
    else {
      $self->{error}  = $self->{client}->{_res}->status_line;
    }
    return 0;
  }
  $self->{response} = decode_json($self->{client}->{_res}->decoded_content);
  return $self->{response};
}

1;

=head1 BETFAIR DATA TYPES

This is an alphabetical list of all the data types defined by Betfair. It includes
enumerations, which are just sets of allowable string values. Higher level types may
contain lower level types, which can be followed down until simple scalars are
reached. Some elements of complex data types are required, while others are optional -
these are denoted by RQD and OPT respectively. Simple scalar type definitions (Long,
Double, Integer, String, Boolean, Date) have been retained for convenience. 'Date' is
a string in ISO 8601 format (e.g. '2007-04-05T14:30Z').

=head3 BetStatus

Enumeration

  SETTLED     A matched bet that was settled normally.
  VOIDED      A matched bet that was subsequently voided by Betfair.
  LAPSED      Unmatched bet that was cancelled by Betfair (for example at turn in play).
  CANCELLED   Unmatched bet that was cancelled by an explicit customer action.

=head3 CancelInstruction

  betId             String              RQD
  sizeReduction     Double              OPT

=head3 CancelInstructionReport

  status            InstructionReportStatus
  errorCode         InstructionReportErrorCode
  instruction       CancelInstruction
  sizeCancelled     Double
  cancelledDate     Date

=head3 ClearedOrderSummary

  eventTypeId       String
  eventId           String
  marketId          String
  selectionId       Long
  handicap          Double
  betId             String
  placedDate        Date
  persistenceType   PersistenceType
  orderType         OrderType
  side              Side
  itemDescription   ItemDescription
  priceRequested    Double
  settledDate       Date
  betCount          Integer
  commission        Double
  priceMatched      Double
  priceReduced      Boolean
  sizeSettled       Double
  profit            Double
  sizeCancelled     Double

=head3 Competition

  id                String
  name              String

=head3 CompetitionResult

  competition       Competition
  marketCount       Integer
  competitionRegion String

=head3 CountryCodeResult

  countryCode       String
  marketCount       Integer

=head3 CurrencyRate

  currencyCode      String (Three letter ISO 4217 code)
  rate              Double

=head3 CurrentOrderSummary

  betId               String
  marketId            String
  selectionId         Long
  handicap            Double
  priceSize           PriceSize
  bspLiability        Double
  side                Side
  status              OrderStatus
  persistenceType     PersistenceType
  orderType           OrderType
  placedDate          Date
  matchedDate         Date
  averagePriceMatched Double
  sizeMatched         Double
  sizeRemaining       Double
  sizeLapsed          Double
  sizeCancelled       Double
  sizeVoided          Double
  regulatorAuthCode   String
  regulatorCode       String

=head3 DeveloperApp

  appName           String
  appId             Long
  appVersions       Array of DeveloperAppVersion

=head3 DeveloperAppVersion

  owner                       String
  versionId                   Long
  version                     String
  applicationKey              String
  delayData                   Boolean
  subscriptionRequired        Boolean
  ownerManaged                Boolean
  active                      Boolean

=head3 Event

  id                String
  name              String
  countryCode       String
  timezone          String
  venue             String
  openDate          Date

=head3 EventResult

  event             Event
  marketCount       Integer

=head3 EventType

  id                String
  name              String

=head3 EventTypeResult

  eventType         EventType
  marketCount       Integer

=head3 ExBestOffersOverrides

  bestPricesDepth             Integer       OPT
  rollupModel                 RollupModel   OPT
  rollupLimit                 Integer       OPT
  rollupLiabilityThreshold    Double        OPT
  rollupLiabilityFactor       Integer       OPT

=head3 ExchangePrices

  availableToBack             Array of PriceSize
  availableToLay              Array of PriceSize
  tradedVolume                Array of PriceSize

=head3 ExecutionReportErrorCode

Enumeration

  ERROR_IN_MATCHER            The matcher is not healthy.
  PROCESSED_WITH_ERRORS       The order itself has been accepted, but at least one action has generated errors.
  BET_ACTION_ERROR            There is an error with an action that has caused the entire order to be rejected.
  INVALID_ACCOUNT_STATE       Order rejected due to the account's status (suspended, inactive, dup cards).
  INVALID_WALLET_STATUS       Order rejected due to the account's wallet's status.
  INSUFFICIENT_FUNDS          Account has exceeded its exposure limit or available to bet limit.
  LOSS_LIMIT_EXCEEDED         The account has exceed the self imposed loss limit.
  MARKET_SUSPENDED            Market is suspended.
  MARKET_NOT_OPEN_FOR_BETTING Market is not open for betting. It is either not yet active, suspended or closed.
  DUPLICATE_TRANSACTION       duplicate customer reference data submitted.
  INVALID_ORDER               Order cannot be accepted by the matcher due to the combination of actions.
  INVALID_MARKET_ID           Market doesn't exist.
  PERMISSION_DENIED           Business rules do not allow order to be placed.
  DUPLICATE_BETIDS            duplicate bet ids found.
  NO_ACTION_REQUIRED          Order hasn't been passed to matcher as system detected there will be no change.
  SERVICE_UNAVAILABLE         The requested service is unavailable.
  REJECTED_BY_REGULATOR       The regulator rejected the order.

=head3 ExecutionReportStatus

Enumeration

  SUCCESS               Order processed successfully.
  FAILURE               Order failed.
  PROCESSED_WITH_ERRORS The order itself has been accepted, but at least one action has generated errors.
  TIMEOUT               Order timed out.

=head3 GroupBy

Enumeration

  EVENT_TYPE A roll up on a specified event type.
  EVENT      A roll up on a specified event.
  MARKET     A roll up on a specified market.
  SIDE       An averaged roll up on the specified side of a specified selection.
  BET        The P&L, commission paid, side and regulatory information etc, about each individual bet order

=head3 IncludeItem

Enumeration

  ALL                         Include all items.
  DEPOSITS_WITHDRAWALS        Include payments only.
  EXCHANGE                    Include exchange bets only.
  POKER_ROOM                  include poker transactions only.


=head3 InstructionReportErrorCode

Enumeration

  INVALID_BET_SIZE                Bet size is invalid for your currency or your regulator.
  INVALID_RUNNER                  Runner does not exist, includes vacant traps in greyhound racing.
  BET_TAKEN_OR_LAPSED             Bet cannot be cancelled or modified as it has already been taken or has lapsed.
  BET_IN_PROGRESS                 No result was received from the matcher in a timeout configured for the system.
  RUNNER_REMOVED                  Runner has been removed from the event.
  MARKET_NOT_OPEN_FOR_BETTING     Attempt to edit a bet on a market that has closed.
  LOSS_LIMIT_EXCEEDED             The action has caused the account to exceed the self imposed loss limit.
  MARKET_NOT_OPEN_FOR_BSP_BETTING Market now closed to bsp betting. Turned in-play or has been reconciled.
  INVALID_PRICE_EDIT              Attempt to edit down a bsp limit on close lay bet, or edit up a back bet.
  INVALID_ODDS                    Odds not on price ladder - either edit or placement.
  INSUFFICIENT_FUNDS              Insufficient funds available to cover the bet action.
  INVALID_PERSISTENCE_TYPE        Invalid persistence type for this market.
  ERROR_IN_MATCHER                A problem with the matcher prevented this action completing successfully
  INVALID_BACK_LAY_COMBINATION    The order contains a back and a lay for the same runner at overlapping prices.
  ERROR_IN_ORDER                  The action failed because the parent order failed.
  INVALID_BID_TYPE                Bid type is mandatory.
  INVALID_BET_ID                  Bet for id supplied has not been found.
  CANCELLED_NOT_PLACED            Bet cancelled but replacement bet was not placed.
  RELATED_ACTION_FAILED           Action failed due to the failure of a action on which this action is dependent.
  NO_ACTION_REQUIRED              The action does not result in any state change.

=head3 InstructionReportStatus

Enumeration

  SUCCESS     Action succeeded.
  FAILURE     Action failed.
  TIMEOUT     Action Timed out.

=head3 ItemClass

  UNKNOWN     Statement item not mapped to a specific class.

=head3 LimitOnCloseOrder

  liability         Double              REQ
  price             Double              REQ

=head3 LimitOrder

  size              Double              REQ
  price             Double              REQ
  persistenceType   PersistenceType     REQ

=head3 MarketBettingType

Enumeration

  ODDS                        Odds Market.
  LINE                        Line Market.
  RANGE                       Range Market.
  ASIAN_HANDICAP_DOUBLE_LINE  Asian Handicap Market.
  ASIAN_HANDICAP_SINGLE_LINE  Asian Single Line Market.
  FIXED_ODDS                  Sportsbook Odds Market.

=head3 MarketBook

  marketId              String
  isMarketDataDelayed   Boolean
  status                MarketStatus
  betDelay              Integer
  bspReconciled         Boolean
  complete              Boolean
  inplay                Boolean
  numberOfWinners       Integer
  numberOfRunners       Integer
  numberOfActiveRunners Integer
  lastMatchTime         Date
  totalMatched          Double
  totalAvailable        Double
  crossMatching         Boolean
  runnersVoidable       Boolean
  version               Long
  runners               Array of Runner

=head3 MarketCatalogue

  marketId          String
  marketName        String
  marketStartTime   Date
  description       MarketDescription
  totalMatched      Double
  runners           Array of RunnerCatalog
  eventType         EventType
  competition       Competition
  event             Event

=head3 MarketDescription

  persistenceEnabled Boolean
  bspMarket          Boolean
  marketTime         Date
  suspendTime        Date
  settleTime         Date
  bettingType        MarketBettingType
  turnInPlayEnabled  Boolean
  marketType         String
  regulator          String
  marketBaseRate     Double
  discountAllowed    Boolean
  wallet             String
  rules              String
  rulesHasDate       Boolean
  clarifications     String

=head3 MarketFilter

  textQuery          String                       OPT
  exchangeIds        Array of String              OPT
  eventTypeIds       Array of String              OPT
  eventIds           Array of String              OPT
  competitionIds     Array of String              OPT
  marketIds          Array of String              OPT
  venues             Array of String              OPT
  bspOnly            Boolean                      OPT
  turnInPlayEnabled  Boolean                      OPT
  inPlayOnly         Boolean                      OPT
  marketBettingTypes Array of MarketBettingType   OPT
  marketCountries    Array of String              OPT
  marketTypeCodes    Array of String              OPT
  marketStartTime    TimeRange                    OPT
  withOrders         Array of OrderStatus         OPT

=head3 MarketOnCloseOrder

  liability          Double              REQ

=head3 MarketProfitAndLoss

  marketId           String
  commissionApplied  Double
  profitAndLosses    Array of RunnerProfitAndLoss

=head3 MarketProjection

Enumeration

  COMPETITION        If not selected then the competition will not be returned with marketCatalogue.
  EVENT              If not selected then the event will not be returned with marketCatalogue.
  EVENT_TYPE         If not selected then the eventType will not be returned with marketCatalogue.
  MARKET_START_TIME  If not selected then the start time will not be returned with marketCatalogue.
  MARKET_DESCRIPTION If not selected then the description will not be returned with marketCatalogue.
  RUNNER_DESCRIPTION If not selected then the runners will not be returned with marketCatalogue.
  RUNNER_METADATA    If not selected then the runner metadata will not be returned with marketCatalogue.

=head3 MarketSort

Enumeration

  MINIMUM_TRADED     Minimum traded volume
  MAXIMUM_TRADED     Maximum traded volume
  MINIMUM_AVAILABLE  Minimum available to match
  MAXIMUM_AVAILABLE  Maximum available to match
  FIRST_TO_START     The closest markets based on their expected start time
  LAST_TO_START      The most distant markets based on their expected start time

=head3 MarketStatus

Enumeration

  INACTIVE           Inactive Market
  OPEN               Open Market
  SUSPENDED          Suspended Market
  CLOSED             Closed Market

=head3 MarketTypeResult

  marketType        String
  marketCount       Integer

=head3 Match

  betId             String
  matchId           String
  side              Side
  price             Double
  size              Double
  matchDate         Date

=head3 MatchProjection

Enumeration

  NO_ROLLUP              No rollup, return raw fragments.
  ROLLED_UP_BY_PRICE     Rollup matched amounts by distinct matched prices per side.
  ROLLED_UP_BY_AVG_PRICE Rollup matched amounts by average matched price per side.

=head3 Order

  betId             String
  orderType         OrderType
  status            OrderStatus
  persistenceType   PersistenceType
  side              Side
  price             Double
  size              Double
  bspLiability      Double
  placedDate        Date
  avgPriceMatched   Double
  sizeMatched       Double
  sizeRemaining     Double
  sizeLapsed        Double
  sizeCancelled     Double
  sizeVoided        Double

=head3 OrderBy

Enumeration

  BY_BET          Deprecated Use BY_PLACE_TIME instead. Order by placed time, then bet id.
  BY_MARKET       Order by market id, then placed time, then bet id.
  BY_MATCH_TIME   Order by time of last matched fragment (if any), then placed time, then bet id.
  BY_PLACE_TIME   Order by placed time, then bet id. This is an alias of to be deprecated BY_BET.
  BY_SETTLED_TIME Order by time of last settled fragment, last match time, placed time, bet id.
  BY_VOID_TIME    Order by time of last voided fragment, last match time, placed time, bet id.

=head3 OrderProjection

Enumeration

  ALL                EXECUTABLE and EXECUTION_COMPLETE orders.
  EXECUTABLE         An order that has a remaining unmatched portion.
  EXECUTION_COMPLETE An order that does not have any remaining unmatched portion.

=head3 OrderStatus

Enumeration

  EXECUTION_COMPLETE An order that does not have any remaining unmatched portion.
  EXECUTABLE         An order that has a remaining unmatched portion.

=head3 OrderType

Enumeration

  LIMIT             A normal exchange limit order for immediate execution.
  LIMIT_ON_CLOSE    Limit order for the auction (SP).
  MARKET_ON_CLOSE   Market order for the auction (SP).

=head3 PersistenceType

Enumeration

  LAPSE           Lapse the order when the market is turned in-play.
  PERSIST         Persist the order to in-play.
  MARKET_ON_CLOSE Put the order into the auction (SP) at turn-in-play.

=head3 PlaceInstruction

  orderType          OrderType            RQD
  selectionId        Long                 RQD
  handicap           Double               OPT
  side               Side                 RQD
  limitOrder         LimitOrder           OPT/RQD \
  limitOnCloseOrder  LimitOnCloseOrder    OPT/RQD  > Depending on OrderType
  marketOnCloseOrder MarketOnCloseOrder   OPT/RQD /

=head3 PlaceInstructionReport

  status              InstructionReportStatus
  errorCode           InstructionReportErrorCode
  instruction         PlaceInstruction
  betId               String
  placedDate          Date
  averagePriceMatched Double
  sizeMatched         Double

=head3 PriceData

Enumeration

  SP_AVAILABLE      Amount available for the BSP auction.
  SP_TRADED         Amount traded in the BSP auction.
  EX_BEST_OFFERS    Only the best prices available for each runner, to requested price depth.
  EX_ALL_OFFERS     EX_ALL_OFFERS trumps EX_BEST_OFFERS if both settings are present.
  EX_TRADED         Amount traded on the exchange.

=head3 PriceProjection

  priceData             Array of PriceData        OPT
  exBestOffersOverrides ExBestOffersOverrides     OPT
  virtualise            Boolean                   OPT
  rolloverStakes        Boolean                   OPT

=head3 PriceSize

  price             Double
  size              Double

=head3 ReplaceInstruction

  betId             String              RQD
  newPrice          Double              RQD

=head3 ReplaceInstructionReport

  status                  InstructionReportStatus
  errorCode               InstructionReportErrorCode
  cancelInstructionReport CancelInstructionReport
  placeInstructionReport  PlaceInstructionReport

=head3 RollupModel

Enumeration

  STAKE             The volumes will be rolled up to the minimum value which is >= rollupLimit.
  PAYOUT            The volumes will be rolled up to the minimum value where the payout( price * volume ) is >= rollupLimit.
  MANAGED_LIABILITY The volumes will be rolled up to the minimum value which is >= rollupLimit, until a lay price threshold.
  NONE              No rollup will be applied.

=head3 Runner

  selectionId       Long
  handicap          Double
  status            RunnerStatus
  adjustmentFactor  Double
  lastPriceTraded   Double
  totalMatched      Double
  removalDate       Date
  sp                StartingPrices
  ex                ExchangePrices
  orders            Array of Order
  matches           Array of Match

=head3 RunnerCatalog

  selectionId       Long
  runnerName        String
  handicap          Double
  sortPriority      Integer
  metadata          Hash of Metadata


=head3 RunnerProfitAndLoss

  selectionId       String
  ifWin             Double
  ifLose            Double

=head3 RunnerStatus

Enumeration

  ACTIVE            Active in a live market.
  WINNER            Winner in a settled market.
  LOSER             Loser in a settled market.
  REMOVED_VACANT    Vacant (e.g. Trap in a dog race)
  REMOVED           Removed from the market.
  HIDDEN            Hidden from the market

=head3 Side

Enumeration

  BACK  To bet on the selection to win.
  LAY   To bet on the selection to lose.

=head3 SortDir

Enumeration

  EARLIEST_TO_LATEST          Order from earliest value to latest.
  LATEST_TO_EARLIEST          Order from latest value to earliest.

=head3 StartingPrices

  nearPrice                   Double
  farPrice                    Double
  backStakeTaken              Array of PriceSize
  layLiabilityTaken           Array of PriceSize
  actualSP                    Double

=head3 StatementItem

  refId             String
  itemDate          Date
  amount            Double
  balance           Double
  itemClass         ItemClass
  itemClassData     Hash of ItemClassData
  legacyData        StatementLegacyData

=head3 StatementLegacyData

  avgPrice                    Double
  betSize                     Double
  betType                     String
  betCategoryType             String
  commissionRate              String
  eventId                     Long
  eventTypeId                 Long
  fullMarketName              String
  grossBetAmount              Double
  marketName                  String
  marketType                  String
  placedDate                  Date
  selectionId                 Long
  selectionName               String
  startDate                   Date
  transactionType             String
  transactionId               Long
  winLose                     String

=head3 TimeGranularity

Enumeration

  DAYS              Days.
  HOURS             Hours.
  MINUTES           Minutes.

=head3 TimeRange

  from              Date
  to                Date

=head3 TimeRangeResult

  timeRange         TimeRange
  marketCount       Integer

=head3 UpdateInstruction

  betId              String             RQD
  newPersistenceType PersistenceType    RQD

=head3 UpdateInstructionReport

  status            InstructionReportStatus
  errorCode         InstructionReportErrorCode
  instruction       UpdateInstruction

=head3 Wallet

Enumeration

  UK                UK Exchange wallet.
  AUSTRALIAN        Australian Exchange wallet.

=head1 SEE ALSO

The Betfair Developer's Website L<https://developer.betfair.com/>
In particular, the Sports API Documentation and the Forum.

=head1 AUTHOR

Myrddin Wyllt, E<lt>myrddinwyllt@tiscali.co.ukE<gt>

=head1 ACKNOWLEDGEMENTS

Main inspiration for this was David Farrell's WWW::betfair module, which was written for the v6 SOAP interface.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Myrddin Wyllt

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
