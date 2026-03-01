# Name of the new folder
$newFolder = "TxtCopies"

# Create the folder if it doesn't exist
if (!(Test-Path $newFolder)) {
    New-Item -ItemType Directory -Path $newFolder | Out-Null
}

# Copy all files (no folders), appending .txt
Get-ChildItem -File | ForEach-Object {
    $newName = $_.Name + ".txt"
    $destination = Join-Path $newFolder $newName

    Copy-Item $_.FullName $destination
}