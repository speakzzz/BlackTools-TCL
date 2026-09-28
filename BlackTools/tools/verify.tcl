# Reads checks (one per line: id TAB kind TAB var TAB expr TAB new) and prints
# "id TAB ok" or "id TAB reason". A conversion is ok only if:
#  1. the braced expression is valid syntax with every $var and [cmd]
#     replaced by a number (catches deliberately dynamic exprs like $a $op $b)
#  2. old and new give identical results (or identical errors) for several
#     sets of sample values, run in a fresh interpreter with stubbed commands

proc placeholder_ok {e} {
    while {[regsub -all {\[[^\[\]]*\]} $e 1 e]} {}
    regsub -all {\$\{[A-Za-z0-9_:-]+\}} $e 1 e
    regsub -all {\$(::)?[A-Za-z0-9_:]+(\([^()]*\))?} $e 1 e
    if {[catch {expr $e} err] && ![string match "*divide by zero*" $err] && ![string match "*domain error*" $err]} {
        return "braced form is not a valid expression ($err)"
    }
    return ok
}

proc varnames {e} {
    set names {}
    foreach {- name idx} [regexp -all -inline {\$((?:::)?[A-Za-z0-9_:]+)(\()?} $e] {
        dict set names $name [expr {$idx ne ""}]
    }
    foreach {- name} [regexp -all -inline {\$\{([A-Za-z0-9_:-]+)\}} $e] {
        dict set names $name 0
    }
    return $names
}

proc sandbox {names round} {
    set i [interp create]
    $i eval {
        proc unknown args { return 3 }
        rename clock _clock
        proc clock args {
            if {[lindex $args 0] eq "seconds"} { return 1700000000 }
            _clock {*}$args
        }
    }
    set k 0
    dict for {name isarr} $names {
        set val [lindex [list [expr {7 + 4*$k}] [expr {20 - 3*$k}] [expr {-5 - 2*$k}] [expr {2.5 + $k}]] $round]
        if {$isarr} {
            $i eval [list array set $name {}]
            $i eval [list trace add variable $name read [list apply {{val n1 n2 op} {
                upvar #0 $n1 a
                if {$n2 ne "" && ![info exists a($n2)]} { set a($n2) $val }
            }} $val]]
        } else {
            $i eval [list set $name $val]
        }
        incr k
    }
    return $i
}

proc run {i script} {
    $i eval {expr {srand(42)}}
    set code [catch {$i eval $script} res]
    return [list $code $res]
}

proc check {kind var e new} {
    if {$kind eq "brace"} {
        set p [placeholder_ok $e]
        if {$p ne "ok"} { return $p }
    }
    set names [varnames $e]
    set rounds [expr {$kind eq "incr" ? {0 1 2} : {0 1 2 3}}]
    foreach round $rounds {
        set a [sandbox $names $round]
        set b [sandbox $names $round]
        if {$kind eq "brace"} {
            set r1 [run $a "expr $e"]
            set r2 [run $b "expr {$e}"]
        } else {
            set r1 [run $a "set $var \[expr $e\]"]
            set r2 [run $b $new]
            lappend r1 [$a eval [list set $var]]
            lappend r2 [$b eval [list set $var]]
        }
        interp delete $a
        interp delete $b
        if {$r1 ne $r2} {
            return "results differ in test round $round: old={$r1} new={$r2}"
        }
    }
    return ok
}

set f [open [lindex $argv 0]]
while {[gets $f line] >= 0} {
    lassign [split $line \t] id kind var e new
    if {[catch {check $kind $var $e $new} v]} { set v "verifier error: $v" }
    puts "$id\t[string map {\t " " \n " "} $v]"
}
close $f
