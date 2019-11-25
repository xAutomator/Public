function invoke-QRadarAPICall {
    param (
        $filter,
        $uri = "https://qradar.mydomain.com/api/config/event_sources/log_source_management/log_sources",
        $apikey = ""
    )
    

    ########## Below is required Cert code ############
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [Net.ServicePointManager]::SecurityProtocol ="tls12"
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    ########## Above is required Cert code ############


   $log_source_array =@()
   $wincollect_array = @()
   $response= Invoke-WebRequest -method get -Uri $uri -Headers @{"SEC"=$apikey;"Version" = "9.0"; "Content-Type"  = "application/json"; "accept"="application/json"   } -UseBasicParsing 
   $log_source_array = $response.content | Convertfrom-json # This list is the master list and should not be altered
   foreach ($log_source in $log_source_array){

        if ($log_source.wincollect_internal_destination_id -ne $null ){
            $wincollect_array += $log_source
        }
   }
   $udp_collector = @()
   $tcp_collector = @()
   foreach ($log_source in $wincollect_array){
       if ($log_source.wincollect_internal_destination_id -eq 1){
           $udp_collector += $log_source
       }elseif ($log_source.wincollect_internal_destination_id -eq 2) {
           $tcp_collector += $log_source
       }

   }
   write-host "TCP Collectors found - $($tcp_collector.count)"
   write-host "UDP Collectors found - $($UDP_collector.count)"
   [int]$answer = Read-Host("Would like to see a list of any of these servers?`n1 - UDP`n2- TCP`n3 - Both`nAny other value will continue")
   if ($answer -eq 1){
       $grid_view_print = $udp_collector | select name
       $grid_view_print | Out-GridView
   } elseif ($answer -eq 2) {
        $grid_view_print = $TCP_collector | select name
        $grid_view_print | Out-GridView
   } elseif ($answer -eq 3) {
        $grid_view_print = $TCP_collector | select name
        $grid_view_print | Out-GridView -Title "Current TCP Collectors"
        $grid_view_print = $udp_collector | select name
        $grid_view_print | Out-GridView -Title "Current UDP Collectors"

   } else {
       write-host "Invalid Input, contining."
   }
   $success = @()
   $fail = @()
   foreach ($log_source in $udp_collector){
       $post_uri = $uri + "/$($log_source.id)"
       $log_source.wincollect_internal_destination_id = 2
       $body = $log_source |ConvertTo-Json
       write-host "Sending Post to $post_uri" -ForegroundColor DarkYellow
       $raw = Invoke-WebRequest -method post -Uri $post_uri -Headers @{"SEC"=$apikey;"Version" = "9.0"; "Content-Type"  = "application/json"; "accept"="application/json"   } -Body $body -UseBasicParsing 
       if ($raw.StatusCode -eq 200){
           write-host "Post Request was sucessful" -ForegroundColor Green
           $log_source_response = $raw.content | ConvertFrom-Json
           if ($($log_source_response.wincollect_internal_destination_id) -eq 2){
            write-host "$($log_source_response.name) was sucesfully switch to TCP collector" -ForegroundColor Green
            $success += $log_source.name
           } else {
               write-host "$($log_source_response.name) failed to switch to TCP collector" -ForegroundColor red
               $fail += $log_source.name
           }
       } else {
        write-host "Post Request failed to update" -ForegroundColor red
       }
    }

    write-host "Secessfully changed $($success.count) log sources" -ForegroundColor Green
    write-host "Failed to change $($fail.count) log sources" -ForegroundColor Red
}


invoke-QRadarAPICall
