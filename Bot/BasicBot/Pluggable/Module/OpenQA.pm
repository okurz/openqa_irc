package Bot::BasicBot::Pluggable::Module::OpenQA;

use base 'Bot::BasicBot::Pluggable::Module';

use strict;
use warnings;

use Mojo::UserAgent;
use Carp qw(confess carp croak);
use Log::Log4perl;


=pod
Ideas and TODOS what to implement and where to look for cool stuff:
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::WWWShorten
https://github.com/CloudBotIRC/CloudBot
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Crontab
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::GitHub
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Notes
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Shutdown
https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module::Log
=cut

my $ua = Mojo::UserAgent->new;
my $log;

sub init {
    my ($self) = @_;
    $log = Log::Log4perl->get_logger(ref $self);
    $self->config({
            notice_period_ready  => 600,
            host => 'openqa.opensuse.org',
        });

    $self->{tick_count} = 0;
}

my $last_staging_failing_modules = "";
my $last_staging_modules = "";
my $do_not_inform_count = 0;
my $defcon_level = 5;  # chattiness, 5 is lowest level, 1 is really annoying

my %short_links;

sub _gather_error_details {
    my ($self, $ua, $openqa_failed) = @_;
    my $host = $self->get('host');

    # try to find out test details if we can
    # TODO for now we just search for the first error, maybe they are all the
    # same anyway
    my $failed_detail = $ua->get($openqa_failed->first->{href})->res->dom->find('span.resborder_fail');
    return unless $failed_detail;
    unless ($failed_detail->first) {
        carp "No content received for $failed_detail";
        return;
    }
    my $failed_detail_url = $failed_detail->first->parent->{href};
    chomp(my $error_details = $ua->get("$host/$failed_detail_url")->res->dom->find('#content .box pre')->map('text')->join(', '));
    return $error_details ? ". Details of first error: $error_details" : '';
}

sub _shorten_url {
    my ($url) = @_;
    confess "TODO implement: Only test paths supported right now" unless $url =~ m@tests@;
    my $short_name = $url =~ s@^.*tests/@t@r;
    unless ($short_links{$url}) {
        my $new_tgt = "http://v.gd/$short_name";
        my $new_tgt_link = $ua->get($new_tgt)->res->dom->at('.biglink');
        if ($new_tgt_link and $new_tgt_link->{href} eq $url) {
            # found already existing link not in our in-memory cache
            $short_links{$url} = $new_tgt;
        }
        else {
            my $my_url = $ua->get("https://v.gd/create.php?format=simple&url=$url&shorturl=$short_name");
            if ($my_url->res->code != 200) {
                carp "url shorten failed with code " . $my_url->res->code . ", returning input link instead";
                return $url;
            }
            $short_links{$url} = $my_url->res->text;
        }
    }
    return $short_links{$url};
}

sub _poll_staging {
    my ($self) = @_;
    my $url = $self->get('staging_dashboard');
    confess "missing staging URL" unless $url;
    $log->debug("polling staging on $url");
    my $openqa_failed = $ua->get($url  => {Accept => '*/*'})->res->dom->find('.openqa-failed');
    $log->debug('Found ' . scalar @$openqa_failed . ' failed jobs');
    my %openqa_failed_map = ();
    # group tests by module name to save some space
    foreach (@$openqa_failed) {
        push(@{$openqa_failed_map{$_->text}}, _shorten_url($_->{href}));
        # TODO the test heading could be used to extract the scenario for each
        # failing test
        #my $test_heading = $ua->get($_->{href})->res->dom->at('#info_box .panel-heading')->text;
        #$test_heading =~ s/^.*Build[^-]*-//;
    };
    # sorting on keys to make comparison of runs possible but still not
    # optimal as we loose which module failed first
    my $failed_str = join ', ', map { $_ . ' (' . join(', ', @{$openqa_failed_map{$_}}) . ')' } sort keys %openqa_failed_map;
    $log->trace($failed_str);

    if ($defcon_level < 5 and !($failed_str eq '')) {
        $failed_str .= _gather_error_details($self, $ua, $openqa_failed) // '';
    }

    return $failed_str;
}


sub told {
    my ($self, $mess) = @_;
    return unless ($mess->{body} =~ /^!/) or $mess->{address};
    if ($mess->{body} =~ /\bperl\b/) {
        return "I hear Ruby is better than perl..";
    }
    elsif ($mess->{body} =~ /help/) {
        return help();
    }
    elsif ($mess->{body} =~ /defcon/) {
        my $new_defcon = $mess->{body};
        $new_defcon =~ s/^.*defcon.*([1-5])/$1/g;
        unless (1 <= $new_defcon && $new_defcon <= 5) {
            return "Err, I won't accept that. Try a number between 1 and 5, maybe? If you need to ask you are probably NOT ALLOWED to request DEFCON 1";
        }
        if ($new_defcon == 1 and not $mess->{who} =~ /$self->get('defcon1_allowed')/) {
            return "What did I tell you? You are NOT ALLOWED to request DEFCON 1";
        }
        my $old_defcon = $defcon_level;
        $defcon_level = $new_defcon;
        if ($defcon_level < $old_defcon) {
            # everytime increase of defcon means probably we are interested in
            # the status more often so it makes sense to also send out the
            # next notice in the next tick
            $do_not_inform_count = 0;
            return "Heads up everyone, " . $mess->{who} . " requested DEFCON increase from $old_defcon to $defcon_level";
        }
        elsif ($defcon_level == $old_defcon) {
            return $mess->{who} . " <--- stupid, we are already on $old_defcon";
        }
        else {
            return "We are down to $defcon_level, thanks " . $mess->{who};
        }
    }
    elsif ($mess->{body} =~ /status staging/) {
        my $failed_staging_str = _poll_staging($self);
        if (length $failed_staging_str > 0) {
            return "The following staging tests are failing: " . $failed_staging_str;
        }
        else {
            return "Currently there are no failing staging tests, stay sharp!";
        }
    }
    elsif ($mess->{body} =~ /\blast builds\b/) {
        my $host = $self->get('host');
        my $products = $ua->get($host)->res->dom->find('h2 > a');
        my $products_text = $products->map('text')->join("\n");
        # TODO replace hardcoded by search
        my $product = qr/Server/;
        return "Give me a product to search for. The following products are available: $products_text\n" unless $product;
        # TODO assuming there is only one (discarding all others)
        my $build = $products->first($product);
        return "Could not find $product. The following products are available: $products_text\n" unless $build;
        my $last_builds = $ua->get($host.$build->{href})->res->dom->find('.col-md-4 > h4 a');
        return "Last builds for $product: ".$last_builds->map('text')->join(", ");
    }
    #elsif ($mess->{body} =~ /\blast review\b/) {
    #    my $products = $ua->get($host)->res->dom->find('h2 > a');
    #}
}

sub chanjoin {
    my ($self, $mess) = @_;
    return if ($mess->{who} eq $self->bot->{nick});  # TODO check if "nick" is the right attribute of bot
    if (($defcon_level < 5 and length $last_staging_modules > 0) or ($defcon_level < 3)) {
        if (length $last_staging_modules > 0) {
            return "Let me inform you about the current status of staging. The following modules failed: " . _poll_staging($self);
        }
        else {
            return "Hi. There are no failing openQA staging modules right now";
        }
    }
    else {
        # Don't do anything by default on defcon 5 not to annoy people with
        # flaky connections
    }
}

# how often to inform about current situation in minutes  based on defcon
my %inform_period_m = (
     1 => 1,
     2 => 4,
     3 => 20,
     4 => 120,
     5 => 1440
 );

sub tick {
    my ($self) = @_;
    croak if scalar @{$self->bot->{channels}} > 1;
    my $channel = $self->bot->{channels}->[0];  # we just select the first if multiple
    # tick is called in 5 second interval
    # ensuring we always have multiple of the tick period in seconds to make
    # checks for "... % x == 0" work
    $self->{tick_count} = ($self->{tick_count} % ~0) + 5;

    return unless ($self->{tick_count} % 60) == 0;  # so far not looking more often than each minute
    my $failed_staging_str = _poll_staging($self);
    if ($failed_staging_str eq $last_staging_modules) {
        $do_not_inform_count++;
        if ($do_not_inform_count % $inform_period_m{$defcon_level} == 0) {
            if (length $failed_staging_str > 0) {
                $self->bot->notice(
                    channel => $channel,
                    body => "I just want to remind that the following staging tests are still failing: " . $failed_staging_str,
                );
            }
            else {
                $self->bot->notice(
                    channel => $channel,
                    body => "Everything is still awesome, nothing broken",  # TODO since … last time it broke
                );
            }
        }
    }
    else {
        # no failing tests
        if ($failed_staging_str eq "") {
            return unless ($defcon_level < 5);  # no report in dc5 necessary, stay quiet
            $self->bot->notice(
                channel => $channel,
                body => "Good news everyone! All staging tests got fixed (or maybe just none completed ...)",
            );
        }
        # state change: no_fail->fail
        elsif (length $failed_staging_str > length $last_staging_modules and $last_staging_modules eq "") {
            # same as previously failing
            # there was no fail in before but now just the same as in before
            # show up again, see
            # https://github.com/openSUSE-Team/obs_factory/issues/49
            if ($failed_staging_str eq $last_staging_failing_modules) {
                return unless ($defcon_level < 5);
                $self->bot->notice(
                    channel => $channel,
                    body => "Same failing tests as in before: " . $failed_staging_str,
                );
            }
            # different
            else {
                $self->bot->notice(
                    channel => $channel,
                    body => "There are new failing tests, get to work!: " . $failed_staging_str,
                );
            }
        }
        # state change: fail->fail_more
        elsif (length $failed_staging_str > length $last_staging_modules) {
            $self->bot->notice(
                channel => $channel,
                body => "OMG! Even more tests are failing now: " . $failed_staging_str,
            );
        }
        # state change: fail->fail_less
        else {
            $self->bot->notice(
                channel => $channel,
                body => "Some fixed, but staging tests failed are: " . $failed_staging_str,
            );
        }
        $last_staging_failing_modules = $failed_staging_str;
    }
    $last_staging_modules = $failed_staging_str;
}

# help text for the bot
sub help { "Help for 'openQA-bot'
    Write a message in a room I am in starting with '!' as a prefix.
    Try the following commands: perl, last builds, status staging, defcon"
}

1;
