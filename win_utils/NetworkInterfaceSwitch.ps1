#  Network Interface Switcher
if ($args.Count -ne 2){
    throw "Error: Wrong number of parameters provided, script needs two..."
}

function Get-NetworkInterface($name){
    Get-NetAdapter -IncludeHidden | Where-Object {$_.Name -eq $name}
}

$firstInterface = $args[0]
$secondInterface = $args[1]

Write-Output "Disabling $firstInterface..."

$firstAdapter = Get-NetworkInterface -name $firstInterface
if ($firstAdapter -and $firstAdapter.Status -eq "Up"){
    Disable-NetAdapter -Name $firstInterface -Confirm:$false
    Write-Output "$firstInterface has been disabled."
}else{
    Write-Output "$secondAdapter"
    Write-Output "$firstInterface is already disabled or not found."
}

Write-Output "Enabling $secondInterface..."

$secondAdapter = Get-NetworkInterface -name $secondInterface
if ($secondAdapter -and $secondAdapter.Status -ne "Up"){
    Enable-NetAdapter -Name $secondInterface -Confirm:$false
    Write-Output "$secondInterface has been enabled."
}else{
    Write-Output "$secondAdapter"
    Write-Output "$secondInterface is already enabled or not found."
}
