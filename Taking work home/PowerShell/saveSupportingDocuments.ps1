<#
.SYNOPSIS
Downloads one or more supporting documents from a SQL database based on a Request Number.

.DESCRIPTION
The script executes a nested SQL query to first find all supporting documents linked to a 
specific request number. It then filters the list based on optional filenames. 
Finally, it downloads the binary content for the selected file(s) and saves them locally.

.PARAMETER RequestNumber
The primary request number (e.g., a form ID) used to locate the associated supporting documents.

.PARAMETER FileNames
Optional. An array of specific filenames to download. If omitted, ALL supporting documents 
found for the RequestNumber will be downloaded.

.PARAMETER Server
The SQL Server instance name.

.PARAMETER Database
The name of the database containing the file tables.

.PARAMETER DestinationPath
The local directory where files will be saved. Defaults to C:\data.

.EXAMPLE
# Download all files for request 'Project Alpha'
Download-SupportingDocuments -RequestNumber 'Project Alpha'

.EXAMPLE
# Download only 'Invoice.pdf' and 'Contract.docx' for request 'Test'
Download-SupportingDocuments -RequestNumber 'Test' -FileNames 'Invoice.pdf', 'Contract.docx' -DestinationPath 'D:\Downloads\Files'
#>
function Get-FormSupportingDocuments {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$RequestNumber,
        [Parameter(Mandatory=$false)][string[]]$FileNames = $null,
        [Parameter(Mandatory=$false)][string]$Server = "YOUR_SERVER_NAME",
        [Parameter(Mandatory=$false)][string]$Database = "YOUR_DATABASE_NAME",
        [Parameter(Mandatory=$false)][string]$DestinationPath = "C:\data"
    )

    # Helper function for SQL execution (kept local to the main script structure)
    function sqlSelect {
        param (
            [Parameter(Mandatory = $true)][string]$query,
            [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$connection
        )
        # ... [sqlSelect function body remains the same as previous version] ...
        Write-Host "Executing query: $query" -ForegroundColor Yellow
        $cmd = New-Object System.Data.SqlClient.SqlCommand
        $cmd.Connection = $connection
        $cmd.CommandText = $query
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dataTable = New-Object System.Data.DataTable

        try {
            [void]$adapter.Fill($dataTable)
        }
        catch {
            Write-Error "SQL Execution Error: $($_.Exception.Message)"
            return @()
        }

        $results = @()
        foreach ($row in $dataTable.Rows) {
            $object = New-Object PSObject
            foreach ($column in $dataTable.Columns) {
                $object | Add-Member -MemberType NoteProperty -Name $column.ColumnName -Value $row[$column.ColumnName]
            }
            $results += $object
        }
        return $results
    }

    # --- Connection Setup ---
    $connectionString = "Server=$Server;Database=$Database;Integrated Security=True;"
    $sqlConn = New-Object System.Data.SqlClient.SqlConnection
    $sqlConn.ConnectionString = $connectionString

    try {
        # Open SQL Connection
        Write-Host "Connecting to database..."
        $sqlConn.Open()

        # 1. QUERY TO FIND ALL SUPPORTING DOCUMENTS FOR THE REQUEST NUMBER
        $queryFileNames = "SELECT [FileName],[FileId]
        FROM [FR_FileInfo_SupportingDocuments]
        WHERE [SupportingDocumentId] IN (
            SELECT DISTINCT [SupportingDocumentId]
            FROM [FR_FileMap_SupportingDocuments]
            WHERE [DataFileID] = (
                SELECT TOP (1) [DataFileId]
                FROM [FR_FileInfo_DataFiles]
                WHERE [FileName] = '$($RequestNumber.Replace("'", "''"))' 
                AND [IsLatest] = 1
                ORDER BY [CreatedDate] DESC
            )
        )"

        Write-Host "Step 1: Searching for linked documents..."
        $queryResult = sqlSelect -query $queryFileNames -connection $sqlConn

        if (-not $queryResult) {
            Write-Warning "No supporting documents found for Request Number '$RequestNumber'."
            return
        }

        # 2. FILTER RESULTS based on $FileNames parameter
        $targetDocuments = @()

        if (-not $FileNames) {
            # Case 1: Download ALL documents
            Write-Host "No specific filenames provided. Preparing to download ALL $($queryResult.Count) document(s)."
            $targetDocuments = $queryResult
        } else {
            # Case 2: Filter by provided names
            Write-Host "Filtering results to match specific filenames..."
            $targetDocuments = $queryResult | Where-Object { $_.FileName -in $FileNames }

            if (-not $targetDocuments) {
                Write-Error "None of the specified files ($($FileNames -join ', ')) were found linked to Request '$RequestNumber'."
                return
            }
            Write-Host "Found $($targetDocuments.Count) of $($FileNames.Count) requested file(s)." -ForegroundColor Green
        }

        # 3. BATCH RETRIEVAL AND SAVING
        
        # Ensure the destination directory exists
        if (-not (Test-Path $DestinationPath -PathType Container)) {
            Write-Host "Creating output directory: $DestinationPath"
            New-Item -Path $DestinationPath -ItemType Directory | Out-Null
        }

        foreach ($doc in $targetDocuments) {
            $currentFileId = $doc.FileId
            $currentFileName = $doc.FileName
            $currentOutputPath = Join-Path -Path $DestinationPath -ChildPath $currentFileName
            
            Write-Host "Processing file: $currentFileName (ID: $currentFileId)" -ForegroundColor Yellow

            # Define the content query here to use the current $currentFileId
            $queryFileContent = "SELECT [FileContent] FROM [FR_FileBlob_SupportingDocuments] WHERE [FileId] = '$currentFileId'"

            $queryResultContent = sqlSelect -query $queryFileContent -connection $sqlConn

            if ($queryResultContent.Count -gt 0) {
                # Get the byte array from the first (and only) row
                $fileBytes = $queryResultContent[0].FileContent
                
                if ($fileBytes -is [byte[]]) {
                    [IO.File]::WriteAllBytes($currentOutputPath, $fileBytes)
                    Write-Host "   -> Successfully saved to '$currentOutputPath'" -ForegroundColor Green
                }
                else {
                    Write-Error "   -> Failed: Content for FileId '$currentFileId' was not a valid byte array."
                }
            }
            else {
                Write-Error "   -> Failed: No content found in FR_FileBlob_SupportingDocuments for FileId: $currentFileId"
            }
        }

    }
    catch {
        # Catch connection and other terminating exceptions
        Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    }
    finally {
        # Ensure the connection is closed
        if ($null -ne $sqlConn -and $sqlConn.State -eq 'Open') {
            $sqlConn.Close()
            Write-Host "SQL Connection closed." -ForegroundColor Cyan
        }
    }
}

# ----------------------------------------------------
# EXAMPLE USAGE (Uncomment one of the lines below to run)
# ----------------------------------------------------

# Example 1: Download ALL files for a specific request number
# Download-SupportingDocuments -RequestNumber 'Test' 

# Example 2: Download only specific files for a specific request number
# Download-SupportingDocuments -RequestNumber 'Test' -FileNames 'myFile.pdf', 'another_doc.docx' -DestinationPath 'D:\Temp\Docs'