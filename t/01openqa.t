use Test::More;
use Mojo::Base -strict;
use Mojo::UserAgent;
use Mojo::Transaction;

sub mock_web_body {
    my ($url) = @_;
    if ($url =~ /mock_staging_new_design/) {
        return '<a class="check-failure" href="http://openqa/tests/1234">openqa:foo</a>
            <a class="check-failure" href="http://openqa/tests/1235">openqa:bar</a>
            <div id="other">some other stuff</div>
            <a class="check-failure" href="http://openqa/tests/1236">openqa:bar</a>';
    }
    elsif ($url =~ /mock_staging/) {
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

# basic tests
ok(my $ob = $bot->load('OpenQA'), 'load openqa module');
is($bot->tell_direct('perl'), 'I hear Ruby is better than perl..', 'simple messages work');
is($bot->tell_indirect('!perl'), 'I hear Ruby is better than perl..', 'exclamation mark tags are accepted');
isnt($bot->tell_indirect('perl'), 'I hear Ruby is better than perl..', 'only responds if addressed');
like($bot->tell_direct('help'), qr/Ask me for help about: openqa/);
like($bot->tell_direct('help openqa'), qr/Try the following commands.*status staging/);
$bot->{handlers}->{openqa}->set(staging_dashboard => 'mock_staging');
is($bot->tell_direct('status staging'), 'The following staging tests are failing: another_failing_module (http://v.gd/t1236), failing_module (http://v.gd/t1234, http://v.gd/t1235)');
$bot->{handlers}->{openqa}->set(staging_dashboard => 'mock_staging_new_design');
is($bot->tell_direct('status staging'), 'The following staging tests are failing: bar (http://v.gd/t1235, http://v.gd/t1236), foo (http://v.gd/t1234)');

# defcon tests
$bot->{handlers}->{openqa}->set(defcon1_allowed => 'foo|bar');
like($bot->tell_direct('defcon 1'), qr/What did I tell you.*/, 'do not allow setting DEFCON works');
$bot->{handlers}->{openqa}->set(defcon1_allowed => 'test_user|foo|bar');
like($bot->tell_direct('defcon 1'), qr/Heads up.*DEFCON increase/, 'set DEFCON works!');
like($bot->tell_direct('defcon 5'), qr/We are down to/);
like($bot->tell_direct('defcon 42'), qr/Err, I won't accept that/, 'do not allow setting invalid DEFCON works');

done_testing();
