package Spellbook::Core::Orchestrator {
    use strict;
    use threads;
    use warnings;
    use Getopt::Long;
    use Thread::Queue;
    use threads::shared;
    use Spellbook::Helper::Read_File;
    
    sub new {
        my ($self, $parameters) = @_;
        my ($help, $wordlist, $module);

        my $threads = 10;
        my $resources = Spellbook::Core::Resources -> new();
        
        Getopt::Long::GetOptionsFromArray (
            $parameters,
            "h|help"         => \$help,
            "t|threads=i"    => \$threads,
            "w|wordlist=s"   => \$wordlist,
            "e|entrypoint=s" => \$module
        );

        if ($module) {
            my $queue = Thread::Queue -> new(Spellbook::Helper::Read_File -> new([ "-f", $wordlist ]));
            $queue -> end();
            my @results :shared;
            
            async {
                while (defined(my $target = $queue -> dequeue())) {
                    my @res;

                    if (ref $module eq "CODE") {
                        @res = $module -> ($target, $parameters);
                    }
                    
                    else {
                        @res = Spellbook::Core::Module -> new (
                            $resources,
                            $module,
                            [ "-t", $target, @$parameters ]
                        );
                    }
                    
                    lock(@results);
                    
                    if (@res) {
                        push @results, @res;
                    }
                }
            } 
            
            for 1 .. $threads;

            while (threads->list(threads::running) > 0) {  }
            $_->join() for threads->list(threads::all);

            return @results;
        }

        if ($help) {
            return "
                \rCore::Orchestrator
                \r==============
                \r\t-h, --help          See this menu
                \r\t-t, --threads       Number of threads
                \r\t-w, --wordlist      Wordlist file
                \r\t-e, --entrypoint    Module to execute\n\n";
        }

        return 0;
    }
}

1;