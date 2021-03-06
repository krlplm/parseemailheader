<#
Author : HEM SHANKAR KARLAPALEM
Description : Use this powershell script to analyze the email headers with ease
#>
Begin 
<#The below function is derived with the logic as "All text after by until there is a word called with. This info will be the server who receives the email from the server above." #>
{ 
Function Process-RcvdBy 
{ 
Param($text) 
$regexBy1 = 'Received: by ' 
$regexBy2 = 'Received: by ([\s\S]*?)with([\s\S]*?);([(\s\S)*]{32,36})(?:\s\S*?)' 
$regexBy3 = 'Received: by ([\s\S]*?);([(\s\S)*]{32,36})(?:\s\S*?)' 
$byMatches = $text | Select-String -Pattern $regexBy1 -AllMatches 
 
if ($byMatches) 
{ 
    $byMatches = $text | Select-String -Pattern $regexBy2 -AllMatches 
    if($byMatches) 
    { 
        $rbArray = @() 
        $byMatches.Matches | foreach{ 
        $by = Clean-string $_.groups[1].value 
        $with = Clean-string $_.groups[2].value 
            Switch -wildcard ($with) 
            { 
             "SMTP*" {$with = "SMTP"} 
             "ESMTP*" {$with = "ESMTP"} 
             default{} 
            } 
        $time = Clean-string $_.groups[3].value 
        $byhash = @{ 
            ReceivedByBy = $by 
            ReceivedByWith = $with 
            ReceivedByTime = [Datetime]$time 
        }         
        $byArray = New-Object -TypeName PSObject -Property $byhash         
        $rbArray += $byArray         
        } 
        $rbArray 
    } 
    else 
    { 
        $rbArray = @() 
        $byMatches = $text | Select-String -Pattern $regexBy3 -AllMatches 
        $byMatches.Matches | foreach{ 
        $by = Clean-string $_.groups[1].value 
        $with = "" 
        $time = Clean-string $_.groups[2].value 
        $byhash = @{ 
            ReceivedByBy = $by 
            ReceivedByWith = $with 
            ReceivedByTime = [Datetime]$time 
        } 
        $byArray = New-Object -TypeName PSObject -Property $byhash         
        $rbArray += $byArray         
        } 
        $rbArray 
    } 
} 
else 
{ 
    return $null 
} 
}#end of function Process-RcvdBy 

<#All text after Received: from until there is a word called by. This will be our Received From Server information. #>
Function Process-RcvdFrom 
{ 
Param($text) 
$regexFrom1 = 'Received: from([\s\S]*?)by([\s\S]*?)with([\s\S]*?);([(\s\S)*]{32,36})(?:\s\S*?)' 
$fromMatches = $text | Select-String -Pattern $regexFrom1 -AllMatches 
if ($fromMatches) 
{ 
        $rfArray = @() 
        $fromMatches.Matches | foreach{ 
        $from = Clean-string $_.groups[1].value 
        $by = Clean-string $_.groups[2].value 
        $with = Clean-string $_.groups[3].value 
            Switch -wildcard ($with) 
            { 
             "SMTP*" {$with = "SMTP"} 
             "ESMTP*" {$with = "ESMTP"} 
             default{} 
            } 
        $time = Clean-string $_.groups[4].value 
        $fromhash = @{ 
            ReceivedFromFrom = $from 
            ReceivedFromBy = $by 
            ReceivedFromWith = $with 
            ReceivedFromTime = [Datetime]$time 
        }         
        $fromArray = New-Object -TypeName PSObject -Property $fromhash         
        $rfArray += $fromArray         
        } 
        $rfArray 
} 
else 
{ 
    return $null 
} 
}#end function Process-RcvdFrom 
 
Function Clean-String 
{ 
Param([string]$inputString)   
 $inputString = $inputString.Trim() 
 $inputString = $inputString.Replace("`r`n","")   
 $inputString = $inputString.Replace("`t"," ")  
 $inputString 
}#end function Clean-String 

<#Main Function as below:
** The main function takes both the receivedby and the receivedfrom objects. The function starts with the receivedby object first, because it is the first part that starts. It then takes the server name and the protocol (if available) and continues on to the next object in the array of objects that is passed. 
** The function now starts its calculation, and compares the time of the previous entry with the time of the current entry. The function obtains the difference between the two time stamps and calculates the number of seconds. 
** After it has this information, it is stored in a variable called $delay. This delay value is later added to the final PSObject, which will have all the info gathered from the headers.
** All the times are converted to universal time (UTC), so this way we have one set of times instead of all different time zones such IST, PDT, and EST. 
#> 

Function Process-FromByObject 
{ 
Param([PSObject[]]$fromObjects,[PSObject[]]$byObjects) 
[int]$hop=0 
$delay="" 
$receivedfrom=$receivedby=$receivedtime=$receivedwith=$null 
$prevTime=$null 
$time=$null 
$finalArray = @() 
    if($byObjects) 
    {         
     $byObjects = $byObjects[($byObjects.Length-1)..0] # Reversing the Array 
     for($index = 0;$index -lt $byobjects.Count;$index++) 
        { 
            if($index -eq 0) 
            { 
                $hop=1 
                $delay="*" 
                $receivedfrom = "" 
                $receivedby = $byobjects[$index].ReceivedByBy 
                $with = $byobjects[$index].ReceivedByWith 
                $time = $byobjects[$index].ReceivedBytime 
                $time = $time.touniversaltime() 
                $prevTime = $time 
                $finalHash = @{ 
                    Hop   = $hop 
                    Delay = $delay 
                    From  = $receivedfrom 
                    By       = $receivedby 
                    With  = $with 
                    Time  = $time 
                    }                 
                $obj = New-Object -TypeName PSObject -Property $finalHash 
                $finalArray += $obj                 
            } 
            else 
            { 
                $hop = $index+1                 
                $receivedfrom = "" 
                $receivedby = $byobjects[$index].ReceivedByBy 
                $with = $byobjects[$index].ReceivedByWith 
                $time = $byobjects[$index].ReceivedBytime 
                $time = $time.touniversaltime()                 
                $delay = $time - $prevTime 
                $delay = $delay.totalseconds 
                if ($delay -le -1) {$delay = 0}                 
                $prevTime = $time 
                                $finalHash = @{ 
                    Hop   = $hop 
                    Delay = $delay 
                    From  = $receivedfrom 
                    By       = $receivedby 
                    With  = $with 
                    Time  = $time 
                    }                 
                $obj = New-Object -TypeName PSObject -Property $finalHash 
                $finalArray += $obj 
            } 
        } 
     $lastHop = $hop 
      
    } 
    $hop = $lastHop 
    if($fromObjects) 
    {         
     $fromObjects = $fromObjects[($fromObjects.Length-1)..0] #Reversing the Array 
     for($index = 0;$index -lt $fromobjects.Count;$index++) 
        {             
         
                $hop = $hop + 1 
                $receivedfrom = $fromobjects[$index].ReceivedFromFrom 
                $receivedby = $fromobjects[$index].ReceivedFromBy 
                $with = $fromobjects[$index].ReceivedFromWith 
                $time = $fromobjects[$index].ReceivedFromTime 
                $time = $time.touniversaltime()                 
                if($prevTime) 
                { 
                    $delay = $time - $prevTime 
                    $delay = $delay.totalseconds 
                } 
                else 
                { 
                    $delay = "*" 
                }                 
                $prevTime = $time 
                $finalHash = @{ 
                    Hop   = $hop 
                    Delay = $delay 
                    From  = $receivedfrom 
                    By       = $receivedby 
                    With  = $with 
                    Time  = $time 
                    }                 
                $obj = New-Object -TypeName PSObject -Property $finalHash 
                $finalArray += $obj 
             
        } 
      
    } 
$finalArray 
}#end function Process-FromByObject 

Function Get-FileName($initialDirectory)
{   
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
 Out-Null

$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.initialDirectory = $initialDirectory
$OpenFileDialog.filter = "All files (*.*)| *.*"
$OpenFileDialog.ShowDialog() | Out-Null
$OpenFileDialog.filename
}#end function Get-FileName. This function will throw a file open dialog.
 
} 
<# Because we do not know how the text is going to be in the message header, it is good to read the whole data as one long string and work with it. 
Here is the technique to do read a file into one big string. 
$text = [System.IO.File]::OpenText("C:\...\msg.txt").ReadToEnd()
#>


<#Script works here using the above functions#>
Process 
{ 
#$text = [System.IO.File]::OpenText($InputFileName).ReadToEnd() 
$filename = Get-FileName -initialDirectory "C:\Users\"
$text = [System.IO.File]::OpenText($filename).ReadToEnd()
$fromObject = Process-RcvdFrom -text $text 
$byObject = Process-RcvdBy -text $text 
 
$finalArray = Process-FromByObject $fromObject $byObject 
#Write-Output $finalArray | select hop,@{n='Delay(Seconds)';e={$_.delay}},from,by,with,@{n='Time(UTC)';e={$_.time}} | Out-GridView #this will format the output
#Write-Output $finalArray | select hop,@{n='Delay(Seconds)';e={$_.delay}},from,by,with,@{n='Time(UTC)';e={$_.time}}| ConvertTo-HTML -Title "Email Header Analysis" -body "Email Header Analysis as below."| Out-File -Width 10 "C:\Users\$env:username\emailHeaders.html"
#Write-Output $finalArray | select hop, @{n='Delay(Seconds)';e={$_.delay}}, from, by, with, @{n='Time(UTC)';e={$_.time}} | ConvertTo-HTML -Title "Email Header Analysis" -body "<H2>Email Header Analysis as below.</H2>"| Out-File -Width 10 "C:\Users\$env:username\emailHeaders.html"
Write-Output $finalArray | Format-Table -wrap hop,@{n='Time(UTC)';e={$_.time}},@{n='Delay(Seconds)';e={$_.delay}},from,by,with
Write-Output $finalArray | select hop, @{n='Time(UTC)';e={$_.time}}, @{n='Delay(Seconds)';e={$_.delay}}, from, by, with  | Export-Csv -Path C:\Users\$env:username\emailHeaders.csv -Encoding ascii -NoTypeInformation
}