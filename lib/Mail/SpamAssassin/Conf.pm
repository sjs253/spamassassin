#

package Mail::SpamAssassin::Conf;

use Carp;
use strict;

use vars	qw{
  	@ISA $type_body_tests $type_head_tests $type_head_evals
	$type_body_evals $type_full_tests $type_full_evals
};

@ISA = qw();

$type_head_tests = 101;
$type_head_evals = 102;
$type_body_tests = 103;
$type_body_evals = 104;
$type_full_tests = 105;
$type_full_evals = 106;

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
    'main' => shift,
  }; bless ($self, $class);

  $self->{tests} = { };
  $self->{descriptions} = { };
  $self->{test_types} = { };
  $self->{scores} = { };

  # after parsing, tests are refiled into these hashes for each test type.
  # this allows e.g. a full-text test to be rewritten as a body test in
  # the user's ~/.spamassassin.cf file.
  $self->{body_tests} = { };
  $self->{head_tests} = { };
  $self->{head_evals} = { };
  $self->{body_evals} = { };
  $self->{full_tests} = { };
  $self->{full_evals} = { };

  $self->{required_hits} = 5;
  $self->{auto_report_threshold} = 20;
  $self->{report_template} = '';
  $self->{spamtrap_template} = '';
  $self->{razor_config} = $ENV{'HOME'}."/razor.conf";

  $self->{whitelist_from} = [ ];

  $self->{_unnamed_counter} = 'aaaaa';

  $self;
}

###########################################################################

sub parse_scores_only {
  my ($self, $rules) = @_;
  $self->_parse ($rules, 1);
}

sub parse_rules {
  my ($self, $rules) = @_;
  $self->_parse ($rules, 0);
}

sub _parse {
  my ($self, $rules, $scoresonly) = @_;
  local ($_);

  my $report_template = '';
  my $spamtrap_template = '';

  foreach $_ (split (/\n/, $rules)) {
    s/\r//g; s/(^|(?<!\\))\#.*$/$1/;
    s/^\s+//; s/\s+$//; /^$/ and next;

    # note: no eval'd code should be loaded before the SECURITY line below.
    #
    if (/^whitelist_from\s+(\S+)\s*$/) {
      push (@{$self->{whitelist_from}}, $1); next;
    }

    if (/^describe\s+(\S+)\s+(.*)$/) {
      $self->{descriptions}->{$1} = $2; next;
    }

    if (/^required_hits\s+(\d+)$/) {
      $self->{required_hits} = $1+0; next;
    }

    if (/^score\s+(\S+)\s+(\-*[\d\.]+)$/) {
      $self->{scores}->{$1} = $2+0.0; next;
    }

    if (/^report\s*(.*)$/) {
      $report_template .= $1."\n"; next;
    }

    if (/^spamtrap\s*(.*)$/) {
      $spamtrap_template .= $1."\n"; next;
    }

    if (/^auto_report_threshold\s+(\d+)$/) {
      $self->{auto_report_threshold} = $1+0; next;
    }

    # SECURITY: no eval'd code should be loaded before this line.
    #
    if ($scoresonly) { goto failed_line; }

    if (/^header\s+(\S+)\s+eval:(.*)$/) {
      $self->add_test ($1, $2, $type_head_evals); next;
    }
    if (/^header\s+(\S+)\s+(.*)$/) {
      $self->add_test ($1, $2, $type_head_tests); next;
    }
    if (/^body\s+(\S+)\s+eval:(.*)$/) {
      $self->add_test ($1, $2, $type_body_evals); next;
    }
    if (/^body\s+(\S+)\s+(.*)$/) {
      $self->add_test ($1, $2, $type_body_tests); next;
    }
    if (/^full\s+(\S+)\s+eval:(.*)$/) {
      $self->add_test ($1, $2, $type_full_evals); next;
    }
    if (/^full\s+(\S+)\s+(.*)$/) {
      $self->add_test ($1, $2, $type_full_tests); next;
    }

    if (/^razor-config\s*(.*)\s*$/) {
      $self->{razor_config} = $1; next;
    }

failed_line:
    dbg ("Failed to parse line in SpamAssassin configuration, skipping: $_");
  }

  if ($report_template ne '') {
    $self->{report_template} = $report_template;
  }

  if ($spamtrap_template ne '') {
    $self->{spamtrap_template} = $spamtrap_template;
  }
}

sub add_test {
  my ($self, $name, $text, $type) = @_;
  if ($name eq '.') { $name = ($self->{_unnamed_counter}++); }
  $self->{tests}->{$name} = $text;
  $self->{test_types}->{$name} = $type;
  $self->{scores}->{$name} ||= 1.0;
}

sub finish_parsing {
  my ($self) = @_;

  foreach my $name (keys %{$self->{tests}}) {
    my $type = $self->{test_types}->{$name};
    my $text = $self->{tests}->{$name};

    if ($type == $type_body_tests) { $self->{body_tests}->{$name} = $text; }
    elsif ($type == $type_head_tests) { $self->{head_tests}->{$name} = $text; }
    elsif ($type == $type_head_evals) { $self->{head_evals}->{$name} = $text; }
    elsif ($type == $type_body_evals) { $self->{body_evals}->{$name} = $text; }
    elsif ($type == $type_full_tests) { $self->{full_tests}->{$name} = $text; }
    elsif ($type == $type_full_evals) { $self->{full_evals}->{$name} = $text; }
    else {
      # 70 == SA_SOFTWARE
      sa_die (70, "unknown type $type for $name: $text");
    }
  }

  delete $self->{tests};		# free it up
}

sub dbg { Mail::SpamAssassin::dbg (@_); }
sub sa_die { Mail::SpamAssassin::sa_die (@_); }

###########################################################################

1;
