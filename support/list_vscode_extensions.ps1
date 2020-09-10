param (
    [string]$outfile
)

$extensions = code --list-extensions | sort

if ($outfile) {
    $extensions | out-file $outfile -force -encoding ascii
}
else {
    $extensions
}
