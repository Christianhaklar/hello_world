<# So, the idea is to have something that can download supporting documents from forms
or at least to get the binary data stored in the DB and do something with it
either save it, or pass it to an external system

Fist, we need the file ID. We can get that using the request number
FR_FileInfo_DataFiles - FileName = RequestNumber -- this gives us the dataFileId
DataFileId can be used in FR_FileMap_Documents (?) to get the supporting document ID -- we only care about distinct
Supporting document Id is then used to get the filename and fileId from FR_FileInfo_SupportingDocuments
and the Id will be used to get the file contents from FR_FileBlob_SupportingDocuments -- name can be used for saving

#>

<#
So first step, we pass a request number and the file name, run the first query, get the file names and IDs
Then we filter the results using the file name - if we didn't pass anything, we can use a loop to get everything
Then we run the second query to get the file contents
Finally we process these contents - either we save it as a file, or pass it along

So I need a query function for the selects - at least i should have one
#>
function sqlSelect {
    param (
        [Parameter(Mandatory = $true)][string]$query,
        [Parameter(Mandatory = $true)][System.Data.SqlClient.SqlConnection]$connection
    )

    Write-Host "Executing query: $query" -ForegroundColor Yellow

    $cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.Connection = $connection
    $cmd.CommandText = $query

    # Use DataAdapter to fill a DataTable
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dataTable = New-Object System.Data.DataTable

    try {
        [void]$adapter.Fill($dataTable)
    }
    catch {
        Write-Error "SQL Execution Error: $($_.Exception.Message)"
        return @() # Return empty array on failure
    }

    # Convert DataTable to an array of custom PowerShell objects
    $results = @()
    foreach ($row in $dataTable.Rows) {
        $object = New-Object PSObject
        foreach ($column in $dataTable.Columns) {
            # Add each column name/value as a property to the object
            $object | Add-Member -MemberType NoteProperty -Name $column.ColumnName -Value $row[$column.ColumnName]
        }
        $results += $object
    }

    return $results
}

# --- Connection Parameters ---
$server = "YOUR_SERVER_NAME" 
$database = "YOUR_DATABASE_NAME" 
$connectionString = "Server=$server;Database=$database;Integrated Security=True;"

# replace these as params
$requestNumber = 'Test';
$fileName = 'myFile.pdf';
$fileId = '';
$outputPath = "C:\data\$fileName"

# queries
$queryFileNames = "SELECT [FileName],[FileId]
FROM [FR_FileInfo_SupportingDocuments]
WHERE [SupportingDocumentId] IN (
SELECT DISTINCT [SupportingDocumentId]
FROM [FR_FileMap_SupportingDocuments]
WHERE [DataFileID] = (
SELECT TOP (1) [DataFileId]
FROM [FR_FileInfo_DataFiles]
WHERE [FileName] = '$requestNumber'
AND [IsLatest] = 1
ORDER BY [CreatedDate] DESC))"

# start doing things
# Open SQL Connection
$sqlConn = New-Object System.Data.SqlClient.SqlConnection
$sqlConn.ConnectionString = $connectionString
$sqlConn.Open()

try {
    # we get the files
    $queryResult = sqlSelect -query $queryFileNames -connection $sqlConn

    # foreach works, but filtering might also be possible
    foreach ($f in $queryResult) {
        <# $currentItemName is the current item #>
        if ($f.FileName -eq $fileName) { 
            $fileId = $f.FileId 
            break
        }
    }

    # Add a check in case the file wasn't found
    if (-not $fileId) {
        Write-Error "File '$fileName' not found in the file list."
        exit
    }

    # 2. RETRIEVE THE BINARY CONTENT
    # Assume $queryFileContent uses $fileId in its WHERE clause to return a single row

    #define the query
    $queryFileContent = "SELECT [FileContent]
    FROM [FR_FileBlob_SupportingDocuments]
    WHERE [FileId] = '$fileId'"

    $queryResultContent = sqlSelect -query $queryFileContent -connection $sqlConn

    # CRITICAL FIX: Access the first row [0] of the result array, 
    # then access the FileContent property to retrieve the byte array ([byte[]]).
    if ($queryResultContent.Count -gt 0) {
        $fileBytes = $queryResultContent[0].FileContent
    }
    else {
        Write-Error "No content found for FileId: $fileId"
        exit
    }

    # 3. WRITE TO LOCAL FILE

    # Check if the content is actually a byte array before writing
    if ($fileBytes -is [byte[]]) {
        [IO.File]::WriteAllBytes($outputPath, $fileBytes)
        Write-Host "Successfully saved '$fileName' to '$outputPath'" -ForegroundColor Green
    }
    else {
        Write-Error "Failed to save file. Content was not a valid byte array."
    }

}
catch {
    <#Do this if a terminating exception happens#>
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
}
finally {
    <#Do this after the try block regardless of whether an exception occurred or not#>
    if ($null -ne $sqlConn -and $sqlConn.State -eq 'Open') {
        $sqlConn.Close()
        Write-Host "SQL Connection closed." -ForegroundColor Cyan
    }
}

