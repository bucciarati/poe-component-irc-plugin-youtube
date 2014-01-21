package POE::Component::IRC::Plugin::Youtube::Tools;

use strict;
use warnings;

use v5.014;

use Data::Dumper;

use DateTime::Format::Strptime;
use LWP::UserAgent;
use XML::RSS;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

my $rss = XML::RSS->new();

my $dt_parser = DateTime::Format::Strptime->new(
    pattern => '%a, %d %b %Y %T +0000',
    locale => 'C',
    time_zone => 'Europe/Vatican',
);

my $ts_emitter = DateTime::Format::Strptime->new(
    pattern => '%s',
);

my $startup_timestamp = time;

sub periodic_check {
    my ($self, $irc, $usernames) = @_;
    my $status_file = $self->{status_file} // $ENV{HOME} . '/.pocoirc-youtube-status';

    my $last_seen_by_username = ( do $status_file ) // {};

    foreach my $username ( @$usernames ){
        my $url = "https://gdata.youtube.com/feeds/base/users/$username/uploads?alt=rss&v=2&orderby=published";
        my $response = $ua->get( $url );

        unless ( $response->is_success ) {
            warn "Request failed while re-checking youtube feeds [@{[ $response->status_line ]}]\n";
            next;
        }

        my $feed_content = $response->decoded_content;
        $rss->parse( $feed_content );

        # so one doesn't get spammed with lots of entries when the bot starts up
        $last_seen_by_username->{$username} //= $startup_timestamp;

        for my $item ( @{ $rss->{items} } ) {
            $item->{link} =~ s/&feature=youtube_gdata//;
            $item->{timestamp} = $ts_emitter->format_datetime(
                $dt_parser->parse_datetime( $item->{pubDate} )
            );
            warn "timestamp:<$item->{timestamp}> username:<$username> title:<$item->{title}> link:<$item->{link}>\n" if $self->{debug};

            if ( $last_seen_by_username->{$username} < $item->{timestamp} ) {
                warn " ^- $last_seen_by_username->{$username} < $item->{timestamp}\n" if $self->{debug};

                $last_seen_by_username->{$username} = $item->{timestamp};

                for my $chan_name ( keys $irc->{STATE}{Chans} ) {
                    $irc->yield(
                        notice => $chan_name,
                        $item->{link} . ' ' . $item->{title},
                    );
                }
            } else {
                warn " ^- $last_seen_by_username->{$username} >= $item->{timestamp}\n" if $self->{debug};
            }
        }

        # warn Dumper( $rss->{items}[0] ) if $self->{debug};
    }

    open my $fh, '>', $status_file;
    print $fh Dumper( $last_seen_by_username );
    $fh->close;
}

1;

__END__

# vim: tabstop=4 shiftwidth=4 expandtab cindent:
