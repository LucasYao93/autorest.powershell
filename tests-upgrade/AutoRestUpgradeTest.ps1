param([switch]$Generate,[string]$TestName,[switch]$M3,[switch]$M4,[switch]$WhiteList,[switch]$BlackList)
#need to use the right version of node.js
#nvs use 10.16.0
# #please use substring to select the compare path
#     $m3Path='.\generate\m3'
#     $m4Path='.\generate\m4'
$scriptPath = Get-Location
if($WhiteList)
{
    $configurationFileName = $scriptPath.path +'\WhiteConfiguration.csv'
    $testList = import-Csv $configurationFileName
}
if($BlackList)
{
    $blackConfigurationFileName = $scriptPath.path +'\BlackConfiguration.csv'
    $blackTestList = import-Csv $blackConfigurationFileName
}
function isCommand([Object]$Object1 , [Object]$Object2)
{
    $isCommandResult = $True
    $difference = Compare-Object $Object1 $Object2
    $difference
    foreach($line in $difference)
    {
        $lineInfo = $line.InputObject.Replace(' ','')
        if(!$lineInfo.Startswith('//'))
        {
            $isCommandResult = $false
            return $isCommandResult
        }
    }
}

function Generate()
{
    ##m3 and m4 all need to be generated
    if((-not $M3) -and (-not $M4))
    {
        ##generate m3 code
        autorest-beta --use:@autorest/powershell@2.1.386 --output-folder:.\generate\m3 --Debug
        ##generate m4 code
        autorest-beta --use:D:\autorest.powershell-m4\autorest.powershell --output-folder:.\generate\m4 --Debug
    }elseif($M3)
    {
        autorest-beta --use:@autorest/powershell@2.1.386 --output-folder:.\generate\m3 --Debug
    }else
    {
        autorest-beta --use:D:\autorest.powershell-m4\autorest.powershell --output-folder:.\generate\m4 --Debug
    }
}

function CompareTest([string]$inputm3Path,[string]$inputm4Path,[string]$testFileName)
{
    #to creare ecah dictionary (the struct is (string,obj))
    #the key is the path of each file,and the obj has two parameters(hashcodevalue,status)
    $initialDict =  @{}
    #in m3Path
    $inputm3Path
    cd $inputm3Path
    $initFileList = Get-ChildItem -Recurse -force
    $initModleFileListName = $inputm3Path + '\generated\modules'
    $targetModleFileListName = $inputm4Path + '\generated\modules'
    # $initFileList
    #foreach initFileList and get the hashcode of them
    foreach( $initFile in $initFileList)
    {
        if(!$initFile.FullName.Startswith($initModleFileListName)){
            $obj = "what" | Select-Object -Property HashCode, Status
            #if the file is not filefolder
            if($initFile.mode -eq '-a---')
            {
                #get the hashcode of the file
                $hashTable = $initFile.PSPath.Replace('Microsoft.PowerShell.Core\FileSystem::','') | get-filehash
                # $initFile.PSPath
                # $hashTable
                $obj.HashCode = $hashTable.Hash
                #get the path of the file
                $detailPath = $hashTable.Path.Replace($inputm3Path,'')
                $initialDict.Add($detailPath,$obj)
            }
        }
    }
    $targetDict =  @{}
    #in m4Path
    cd $inputm4Path
    $targetFileList = Get-ChildItem -Recurse -force
    #foreach initFileList and get the hashcode of them
    foreach( $targetFile in $targetFileList)
    {
        if(!$targetFile.FullName.Startswith($targetModleFileListName)){
            $obj = "waht2" | Select-Object -Property HashCode, Status
            #if the file is not filefolder
            if($targetFile.mode -eq '-a---')
            {
                #get the hashcode of the file
                $hashTable = $targetFile.PSPath.Replace('Microsoft.PowerShell.Core\FileSystem::','') | get-filehash
                $obj.HashCode = $hashTable.Hash
                #get the path of the file
                    # $targetFile
                    # $hashTable
                
                $detailPath = $hashTable.path.Replace($inputm4Path,'')
                $targetDict.Add($detailPath,$obj)
            }
        }
    }
    [object[]] $difArray=@()

    #search each dictDetail in targetDict

    #the status means: 0 this file do not exist in anouther filefolder
    #                   1 the hashcode of the file is the same as that in another filefolder
    #                   2 the hashcode of the file is different from that in another filefolder
    foreach($initDictDetail in $initialDict.Keys)
    {
        $difDetail = "what"| Select-Object -Property fileName,Path,fileFolderName,Status
        #if the file not exists in targetDict
        if($targetDict[$initDictDetail] -eq $null)
        {
            $difDetail.Path = $initDictDetail
            $difDetail.fileFolderName = 'M3'
            $splitStrings = $initDictDetail.Split('\')
            $difDetail.fileName = $splitStrings[$splitStrings.count-1]
            $difDetail.status = 'lack in M4'
            #sign up the status of the file
            $initialDict[$initDictDetail].status = 0
            $difArray+= $difDetail
        }elseif($targetDict[$initDictDetail].HashCode -ne $initialDict[$initDictDetail].HashCode)
        {
            $M3CompareFile = Get-Content ($inputm3Path + $initDictDetail)
            $M4CompareFile = Get-Content ($inputm4Path + $initDictDetail)
            $isCommandResult = isCommand -Object1 $M3CompareFile -Object2 $M4CompareFile
            # $isCommandResult
            if( $isCommandResult -ne $True)
            {
                $detailPath
                $difDetail.Path = $initDictDetail
                $difDetail.fileFolderName = 'M3'
                $splitStrings = $initDictDetail.Split('\')
                $difDetail.fileName = $splitStrings[$splitStrings.count-1]
                $difDetail.status = 'different'
                #sign up the status of the file
                $initialDict[$initDictDetail].status = 2
                $targetDict[$initDictDetail].status = 2
                $difArray+=$difDetail
            }else
            {
                $initialDict[$initDictDetail].status = 1
                $targetDict[$initDictDetail].status = 1
            }
        }else
        {
            $initialDict[$initDictDetail].status = 1
            $targetDict[$initDictDetail].status = 1
        }
    }
    #search those files which status is null 
    foreach($targetDetail in $targetDict.Keys)
    {
        $difDetail = "what"| Select-Object -Property fileName,Path,fileFolderName,Status
        if($targetDict[$targetDetail].Status -eq $null)
        {
            $difDetail.Path = $targetDetail
            $difDetail.fileFolderName = 'M4'
            $splitStrings = $targetDetail.Split('\')
            $difDetail.fileName = $splitStrings[$splitStrings.count-1]
            $difDetail.Status = 'lack in m3'
            $difArray+=$difDetail
        }
    }
    $filename = $scriptPath.Path + '\CompareResult\' + $testFileName + (get-date -format 'yyyyMMddhhmmss')+'.csv'
    # $difArray
    # $inputm3Path
    $filename
    $difArray | Select-Object -Property fileName,Path,fileFolderName,Status | Export-CSV -path $filename
}

$currentPath = Get-Location
$fileList = Get-ChildItem
#if only one case
if($TestName -ne $null -and ($TestName -ne ''))
{
    $currentDetailPath = Get-Location
    # if(($fileDeatil.Mode -eq 'd----') -and ($fileDeatil.Name -eq $TestName))
    # {
        cd ($currentDetailPath.Path+'\'+$TestName)
        $deatilPath = $currentDetailPath.Path + 'generate'
        Generate
    # }
    if(-not $Generate)
    {
        $m3FilePath = $currentDetailPath.Path +'\'+$TestName + '\generate\m3'
        $m4FilePath =$currentDetailPath.Path +'\'+$TestName + '\generate\m4'
        CompareTest -inputm3Path $m3FilePath -inputm4Path $m4FilePath -testFileName $TestName
    }
}elseif($WhiteList)
{
    $currentDetailPath = Get-Location
    #get each testfolder
    foreach($eachTest in $testList)
    {
        # if(($fileDeatil.Mode -eq 'd----') -and ($fileDeatil.Name -eq $TestName))
        # {
            cd ($currentDetailPath.Path+'\'+$eachTest)
            $deatilPath = $currentDetailPath.Path + 'generate'
            Generate
        # }
        if(-not $Generate)
        {
            $m3FilePath = $currentDetailPath.Path +'\'+$TestName + '\generate\m3'
            $m4FilePath =$currentDetailPath.Path +'\'+$TestName + '\generate\m4'
            CompareTest -inputm3Path $m3FilePath -inputm4Path $m4FilePath -testFileName $eachTest
        }
    }
}elseif($BlackList)
{
    $currentDetailPath = Get-Location
    #get each testfolder
    foreach($fileDetail in $fileList)
    {
        foreach($blackTestName in $blackTestList)
        {
            if(($fileDeatil.Mode -eq 'd----') -And (!$eachTest.Name.Startswith($blackTestName)))
            {
                cd ($currentDetailPath.Path+'\'+$fileDetail.Name)
                $deatilPath = $currentDetailPath.Path + 'generate'
                Generate
                if(-not $Generate)
                {
                    $m3FilePath = $currentDetailPath.Path +'\'+$fileDetail.Name + '\generate\m3'
                    $m4FilePath =$currentDetailPath.Path +'\'+$fileDetail.Name + '\generate\m4'
                    CompareTest -inputm3Path $m3FilePath -inputm4Path $m4FilePath -testFileName $fileDeatil.path
                }
            }
        }
            
    }
}
else
{
    foreach($fileDetail in $fileList)
    {
        $currentDetailPath = Get-Location
        if($fileDetail.Mode -eq 'd----' -and (!$fileDetail.Name.Startswith('Compare')))
        {
            $g1 = $currentPath.Path +'\' +$fileDetail.Name
            $g1
            cd ($currentPath.Path +'\' +$fileDetail.Name)
            $deatilPath = $currentDetailPath.Path + 'generate'
            Generate
            if(-not $Generate)
            {
                Compare(($currentDetailPath.Path + '\generate\m3') , ($currentDetailPath.Path + '\generate\m4'))
            }
        }
    }
}
cd $currentPath.Path