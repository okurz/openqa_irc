use Test::More;
use Mojo::Base -strict;
use Mojo::UserAgent;
use Mojo::Transaction;

sub mock_web_body {
    my ($url) = @_;
    if ($url =~ /mock_staging/) {
        return '<a class="openqa-failed" href="http://openqa/tests/1234">failing_module</a>
            <a class="openqa-failed" href="http://openqa/tests/1235">failing_module</a>
            <div id="other">some other stuff</div>
            <a class="openqa-failed" href="http://openqa/tests/1236">another_failing_module</a>';
    }
    elsif ($url =~ /v\.gd\/create.*shorturl=(.*)/) {
        return "http://v.gd/$1";
    }
    elsif ($url =~ /v\.gd\/t(\d+)/) {
        return "<a class=\"biglink\" href=\"http://openqa/tests/$1\"></a>";
    }
    else {
        return 'Hello';
    }
};

# monkey patching the user agent with our mock implementation
no warnings 'redefine';
local *Mojo::UserAgent::get = sub {
    my ($self, $url) = @_; # we should not need to look at the other attributes
    my $tx = Mojo::Transaction->new;
    $tx->res->body('<html><body>' . mock_web_body($url) . '</body></html>');
    return $tx;
};

use Test::Bot::BasicBot::Pluggable; # SUT

my $bot = Test::Bot::BasicBot::Pluggable->new();

ok(my $ob = $bot->load('OpenQA'), 'load openqa module');
is($bot->tell_direct('perl'), 'I hear Ruby is better than perl..', 'simple messages work');
is($bot->tell_indirect('!perl'), 'I hear Ruby is better than perl..', 'exclamation mark tags are accepted');
isnt($bot->tell_indirect('perl'), 'I hear Ruby is better than perl..', 'only responds if addressed');
like($bot->tell_direct('help'), qr/Ask me for help about: openqa/);
like($bot->tell_direct('help openqa'), qr/Try the following commands.*status staging/);
$bot->{handlers}->{openqa}->set(staging_dashboard => 'mock_staging');
$bot->{handlers}->{openqa}->set(url_shortener => 'v.gd');
is($bot->tell_direct('status staging'), 'The following staging tests are failing: another_failing_module (http://v.gd/t1236), failing_module (http://v.gd/t1234, http://v.gd/t1235)');

done_testing();
