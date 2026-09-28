#!/usr/bin/env tclsh
# file github/github.tcl
#https://wiki.tcl-lang.org/page/github%3A%3Agithub
#
#Version 1.1 - added a timer in seconds between files & folders
#Version 1.2 - branch/ref support, no insecure default TLS registration,
#              HTTP status checks (BlackTools fork)

# chicken and egg problem we need non-standard packages tls and json ...
package require tls
package require http
#Safe default; BlackTools re-registers with full options (SNI, cert
#verification) via blacktools:update_tls_register before downloading.
::http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 0 -tls1.1 0 -tls1.2 1]

namespace eval ::github {
    variable libdir [file normalize [file join [file dirname [info script]] ..]]
    if {[lsearch $::auto_path $libdir] == -1} {
        lappend auto_path $libdir
    }
} 

# I already placed the json folder below of the github folder
package require json
package provide github::github 0.2
package provide github 0.2

# Tcl package download
proc ::github::github {cmd owner repo folder {ref ""}} {
    variable libdir
    variable ref_query ""
if {$ref ne ""} {
if {![regexp {^[A-Za-z0-9._/-]+$} $ref]} {
    return -code error "github: invalid branch/ref name \"$ref\""
    }
    set ref_query "?ref=$ref"
}
    set url https://api.github.com/repos/$owner/$repo/contents/
    download $url $folder
}

# Folder download
proc ::github::download {url folder {debug true}} {
    if {![file exists $folder]} {
        file mkdir $folder
    }
    set sfiles ""
    set dfiles ""
    variable ref_query
    set tok [http::geturl "$url$ref_query" -timeout 30000]
if {[http::status $tok] ne "ok" || [http::ncode $tok] != 200} {
    set err "[http::status $tok] [http::code $tok]"
    http::cleanup $tok
    return -code error "github: failed to list $url ($err)"
}
    set data [http::data $tok]
    http::cleanup $tok
    set d [json::json2dict $data]
    set l [llength $d]
    set files [list]
for {set i 0} {$i < $l} {incr i 1} {
    set dic [dict create {*}[lindex $d $i]]
    set file [dict get $dic download_url]
    set type [dict get $dic type]
if {$file eq "null" &&  $type eq "dir"} {
    set file [dict get $dic url]
    set file [regsub {\?ref=.*$} $file ""]
}
if {$type eq "file"} {
    lappend sfiles $file
} else {
    lappend dfiles $file
    }
}
if {$sfiles != ""} {
    files $sfiles $folder 0 $dfiles
    return
    }
if {$dfiles != ""} {
    dirs $dfiles $folder 0
    }
}

# Folders make
proc ::github::dirs {dirs dir num} {
    set file [lindex $dirs $num]
    set nfolder [file join $dir [file tail $file]]
     download $file $nfolder
    set counter [expr $num + 1]
if {[lindex $dirs $counter] != ""} {
    utimer 2 [list ::github::dirs $dirs $dir $counter]
    }
}

# Files make
proc ::github::files {files dir num dirs} {
    set item [lindex $files $num]
    set file [lindex $item 0]
    set fname [file tail $file]
    set fname [file join $dir $fname]
    set f [open $fname w]
    fconfigure $f -translation binary
    set tok [http::geturl $file -channel $f]
    set Stat [::http::status $tok]
    flush $f
    close $f
    http::cleanup $tok
    set counter [expr $num + 1]
if {[lindex $files $counter] != ""} {
    utimer 2 [list ::github::files $files $dir $counter $dirs]
    } else {
if {$dirs != ""} {
    dirs $dirs $dir 0
        }
    }
}

