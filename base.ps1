$url = "https://download.mozilla.org/?product=firefox-51.0.1-SSL&os=win64&lang=en-US"
$path = "C:\firefox.exe"
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$webClient = new-object System.Net.WebClient
$webClient.DownloadFile( $url, $path )
