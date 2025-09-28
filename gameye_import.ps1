param(
    [Parameter(Mandatory=$true)]
    [string]$inputCsv,
    [Parameter(Mandatory=$true)]
    [string]$outputCsv
)

# Import the input CSV
# CLZ export delimiter is , but if processed thru Excel you'll want ;
$data = Import-Csv -Path $inputCsv -Delimiter ';'

# Initialize an array to store the results
$results = @()
$notfound = @()
$id = 1


# Loop through each row in the CSV
foreach ($row in $data) {

    # Assume CLZ CSV has the following headers: Title,Platform,Region,Box,Manual
    $title = $row.Title
    $platform = $row.Platform
    $region = $row.Region
    $box = $row.Box
    $manual = $row.Manual

    # Calculate gameeye ownership mask
    $ownershipMask = 1 # loose
    if ($box -eq "Yes" -And $manual -eq "Yes") {
        $ownershipMask = 7 # complete
    } elseif ($box -eq "Yes" -And $manual -eq "No") {
        $ownershipMask = 5 # box no manual
    } elseif ($box -eq "No" -And $manual -eq "Yes") {
        $ownershipMask = 3 # manual no box
    }

    # Convert region/platform to gameeye IDs
    switch ($region) {
        "USA" { $regionId = 1 }
        "Europe" { $regionId = 15 } # UK
        "Japan" { $regionId = 3 }
        default { $regionId = 34 } # World
    }

    switch ($platform) {
        "Dreamcast" { $platformId = 16 }
        "Family Computer / Famicom" { $platformId = 7 } # Same as NES
        "Game & Watch" { $platformId = 76 }
        "Game Boy Advance" { $platformId = 5 }
        "GameCube" { $platformId = 2 }
        "Genesis / Mega Drive" { $platformId = 18 }
        "NES" { $platformId = 7 }
        "Nintendo 64" { $platformId = 3 }
        "Nintendo 3DS" { $platformId = 41 }
        "Nintendo DS" { $platformId = 8 }
        "Nintendo Switch" { $platformId = 97 }
        "PC" { $platformId = 1 }
        "PlayStation" { $platformId = 10 }
        "PlayStation 2" { $platformId = 11 }
        "PlayStation 3" { $platformId = 12 }
        "PlayStation 4" { $platformId = 46 }
        "PlayStation 5" { $platformId = 105 }
        "PSP" { $platformId = 13 }
        "PlayStation Vita" { $platformId = 37 }
        "Saturn" { $platformId = 17 }
        "Sega 32X" { $platformId = 32 }
        "Sega CD" { $platformId = 20 }
        "Sega Master System" { $platformId = 34 }
        "SNES" { $platformId = 6 }
        "Super Famicom" { $platformId = 6 } # Same as SNES
        "Wii" { $platformId = 9 }
        "Wii U" { $platformId = 36 }
        "Xbox" { $platformId = 14 }
        "Xbox 360" { $platformId = 15 }
        "Xbox One" { $platformId = 47 }
        "Xbox Series X" { $platformId = 106 }
        default { $platformId = 0 } # Unknown
    }

    Write-Output "Processing: $title on $platform for $region (Platform ID: $platformId, Region ID: $regionId)"

    # Perform the API request to find the gameye ID for the title
    try {
        $apiUrl = "https://www.gameye.app/api/deep_search?offset=0&limit=25&title=$title&platforms=$platformId&country=$regionId&order=0&asc=1&cat=0"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Body $body -ContentType "application/json"
        
        if ($response -and $response.records.Count -gt 0) {
            # If there are any results, take the first one
            $gameID = $response.records[0].id
            $gametitle = $response.records[0].title
            Write-Output "   Found Gameye equivalent: $gameID - $gametitle"
        } else {
            Write-Output "   Nope!"
            $notfound += "$title ($platform)" 
            continue
        }

        # Craft gameye DB entry
        # id,item_id,platform_id,country_id,ownership_mask,item_quality,manual_quality,box_quality,paid,sold,note,created_at,updated_at,category_id,user_record_type,title,uuid,generation_id,collection_id
        $results += [PSCustomObject]@{
            id = $id
            item_id = $gameID
            platform_id = $platformId
            country_id = $regionId
            ownership_mask = $ownershipMask
            item_quality = ""
            manual_quality = ""
            box_quality = ""
            paid = ""
            sold = ""
            note = ""
            # unix timestamp
            created_at = [int][double]::Parse((Get-Date -UFormat %s))
            updated_at = [int][double]::Parse((Get-Date -UFormat %s))
            category_id = 0
            user_record_type = 0
            title = $title
            uuid = [guid]::NewGuid().ToString()
            generation_id = 0
            collection_id = 1
        }
        $id++
    } catch {
        Write-Output "Error processing row: $($_.Exception.Message)"
    }
}

# Export the results to the output CSV
$results | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Output "Processing complete. Results saved to $outputCsv"
if ($notfound.Count -gt 0) {
    Write-Output "The following titles were not found in Gameye:"
    $notfound | Sort-Object | Get-Unique | ForEach-Object { Write-Output " - $_" }
}