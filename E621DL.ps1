[string]$logodata = "
███████╗ ██████╗ ██████╗  ██╗                                                         
██╔════╝██╔════╝ ╚════██╗███║                                                         
█████╗  ███████╗  █████╔╝╚██║                                                         
██╔══╝  ██╔═══██╗██╔═══╝  ██║                                                         
███████╗╚██████╔╝███████╗ ██║                                                         
╚══════╝ ╚═════╝ ╚══════╝ ╚═╝                                                         
                                                                                      
██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗ 
██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝                                            
"


## Making the Class and setting default attributes
class e621Attributes {
[string]$КорневойURI = "https://e621.net/post"
#Базовый URL-адрес API-интерфейс 
[boolean]$VerbosePreference
#Корень E621
hidden[array]$IndexURI
#Отправлено Пользователем Фильтры
[array]$Фильтры
#папка для загрузки, должна быть относительным путем
[string]$ЗагрузитьПапку = ".\загруженный"
#сколько страниц, чтобы вытащить сообщения из
[int]$PageLimit
#максимальное количество сообщений для загрузки, независимо от выбранных страниц
[int]$PostLimit = 75
#Сгенерированный список всех сообщений в очереди для загрузки из e621.net
hidden[array]$PostsQueued
hidden[array]$PostsPreviouslyDownloaded
#The rating to filter by
[array]$Rating
#score threshold for a post, filter any content below the score value
[int]$Score
#дополнительный черный список, это не считается с ограничением тегов поиска E621, это будет фильтровать любые нефильтрованные сообщения, которые могут иметь метки, содержащиеся в черном списке
[Array]$Blacklist
}
$e621Attributes = New-Object -TypeName e621Attributes

#$logodata
$logodata
Write-Host "Версия 6.21" -ForegroundColor Yellow
Write-Host "Евровидение - это гей" -ForegroundColor Green
if (!(test-path ".\Умолчанию.config.txt"))
{
"
Фильтры=
VerbosePreference=false
Blacklist=
Score=0
Rating=safe,questionable,explicit
PageLimit=1
PostLimit=15
" | Out-File -FilePath .\Умолчанию.config.txt -Encoding utf8
Write-Host "измените значение по умолчанию.конфиг.txt-файл или создайте свой собственный файл конфигурации, а затем снова запустите сценарий" -ForegroundColor Yellow
pause 
Break
}






#Set the user's config file, logfile, and загруженный folder
$UserConfig = Get-ChildItem .\ |Where-Object {$_.name -like "*config*"} |Out-GridView -Title "select a config file" -OutputMode Multiple


if ([string]::IsNullOrWhiteSpace($UserConfig))
{
    break
}

function Downloadfromconfig
{
    
$config = $config.FullName
$tempfilepath = (split-path $config) + "\загруженный\" + (Split-Path $config -Leaf).Replace(".config.txt","") + "\"

if (!(Test-Path $tempfilepath.Trim("\")))
{
    $temp = New-Item -Path $tempfilepath.Trim("\") -ItemType directory    
}
$ЖурналПользователя = $tempfilepath + ($config.Split("\")[-1]) -replace ("config","log")
if (!(Test-Path -Path $ЖурналПользователя))
{
    $temp = New-Item -ItemType file -Path $ЖурналПользователя
}
$ЗагрузкиПользователя = $tempfilepath.Trim("\")
if (!(Test-Path -Path $ЗагрузкиПользователя))
{
    $temp = New-Item -ItemType directory -Path $ЗагрузкиПользователя
}


#Update all needed attributes


$ConfigSettings = Get-Content $config | ConvertFrom-StringData
$e621Attributes.VerbosePreference = $ConfigSettings.verbosePreference

if ($ConfigSettings.verbosePreference -like "false")
{
    $e621Attributes.VerbosePreference = $false
}
else
{
    $e621Attributes.VerbosePreference = $true
}








$e621Attributes.Фильтры = $ConfigSettings.Фильтры.Split(",").replace(" ","_")|ForEach-Object {($_).trim("_")}
$e621Attributes.Blacklist =$ConfigSettings.blacklist.Split(",").replace(" ","_")|ForEach-Object {($_).trim("_")}|Where-Object {$_}
$e621Attributes.Score = $ConfigSettings.score
$e621Attributes.Rating = $ConfigSettings.rating.Split(",").replace(" ","_")|ForEach-Object {($_).trim("_")}
$e621Attributes.PageLimit = $ConfigSettings.pagelimit
$e621Attributes.PostLimit = $ConfigSettings.postlimit
$e621Attributes.ЗагрузитьПапку = $ЗагрузкиПользователя
$e621Attributes.PostsPreviouslyDownloaded = get-content $ЖурналПользователя

$e621Attributes


##setting powershell to verbose mode if marked true in the config




if ($e621Attributes.VerbosePreference -eq $true){
    $VerbosePreference = "Continue"
}
else 
{
    $VerbosePreference="SilentlyContinue"
}




##display logo, creation date, EULA


#Test E621
if (!(Invoke-WebRequest -Uri $e621Attributes.КорневойURI).statuscode -like "200"){
    Write-Warning -Message "E621.net is not accessible!"
    pause
    Break
}



#generate the index pages that will be used to download content
function GENERATEPAGES {
    #setting the temporary Фильтры to generate the URLs
$tempФильтры = $e621Attributes.Фильтры |ForEach-Object {$_ + ","}
$tempФильтры = (-join $tempФильтры).Trim(",")
#setting the page counter to 1 (e621's pages effectivly start at one as page 0 and page one are equivilant)
[int]$pagecounter = 1
$tempoutput = @()
do
{
    #generating the pages that need to be searched
    $tempoutput += ($e621Attributes.КорневойURI + "/index/"+  $pagecounter  +"/" + $tempФильтры)

    #incrementing the page counter one step
    $pagecounter = $pagecounter + 1
}
until ($pagecounter -gt $e621Attributes.PageLimit)

$tempoutput
}; $e621Attributes.IndexURI = GENERATEPAGES 

#get all the posts!
$weblinks = foreach ($item in $e621Attributes.IndexURI){(Invoke-WebRequest -Uri $item).links | Where-Object {$_.href -like "/post/show/*"}}

#get the previously downloaded posts (to filter out...)
$DLLog = Get-Content -path $ЖурналПользователя

#Starting filtering for previous posts blacklist filtering

$Global:WeblinksOmitted = @()
$Global:WeblinksFiltered = @()

function POSTQUALITYTEST ($PostsToParse){

##FUNCTIONS

        function BLACKLIST_TEST ($Post, $BlacklistedTags){
  
            $TempPostTags = (((($post.outerHTML) -split 'alt="')[1]-split '&#13')[0]).Split(" ")
           $BlacklistTestResults = foreach ($BlacklistedTag in $BlacklistedTags){$TempPostTags -contains $BlacklistedTag}
            if ($BlacklistTestResults -contains $true)
            {
                "FAIL"  
            }
            else
            {
                "PASS"
            }
  
    
}
        function PREVIOUSLYDOWNLOADEDPOST_TEST ($Post, $PreviouslyDownloadedPosts){
        $TestingPostNumber = ((($Post.outerHTML)-split "&#13").trim(";") -split "`n")[0].split("/")[3]   
        #$ItemResults += [string]::IsNullOrWhiteSpace(($PreviouslyDownloadedPosts -like $TestingPostNumber))
    
        if ($PreviouslyDownloadedPosts -contains $TestingPostNumber)
                {
        "FAIL"
    }
        else
                {
        "PASS"
    }


        }
        function RATING_TEST ($Post, $Rating){
                $PostRating = ((($Post.outerHTML)-split "&#13").trim(";") -split "`n")[2] -replace "Rating: "  #rating
                $results = foreach ($RatingTag in $Rating) {$PostRating -contains $RatingTag}
           
                if ($results -contains $true)
                        {
                "PASS"
            }
                else
                        {
                "FAIL"
            }

        }
        function SCORE_TEST ($Post, $Score){
            [int]$TestingScore = ((($Post.outerHTML)-split "&#13").trim(";") -split "`n")[3]-replace "Score: ",""
            if ($TestingScore -ge $Score)
                    {
            "PASS"
        }
            else
                    {
            "FAIL"
        }
        }
        function POSTQUALITY_TEST
        {
            SCORE_TEST -Post $Post -Score $e621Attributes.Score
            RATING_TEST -Post $Post -Rating $e621Attributes.Rating
            PREVIOUSLYDOWNLOADEDPOST_TEST -Post $Post -PreviouslyDownloadedPosts (Get-Content -path $ЖурналПользователя)
            BLACKLIST_TEST -Post $Post -BlacklistedTags $e621Attributes.Blacklist            
        }
##ENDOFFUNCTIONS
##START PROCESS

    foreach ($Post in $PostsToParse){
    
    
    if ((POSTQUALITY_TEST)-contains "FAIL")
    {
        $Global:WeblinksOmitted += $Post.href
        Write-Verbose -Message ($Post.href + " failed user selected criteria")
    }
    else
    {
        $Global:WeblinksFiltered += $Post.href
        Write-Verbose -Message ($Post.href + " passed user selected criteria")
    }
    
    
    }

##END PROCESS
};
POSTQUALITYTEST -PostsToParse $weblinks -BlacklistTags $e621Attributes.Blacklist







Write-Verbose -Message ($WeblinksOmitted.count.ToString() + " posts have been omitted due to your Фильтры!") 
$e621Attributes.PostsQueued =  foreach ($item in $WeblinksFiltered){$item.Split("/")[3]}



if ($e621Attributes.PostsQueued.count -gt $e621Attributes.PostLimit)
{
    Write-Verbose -Message (($e621Attributes.PostsQueued.count).ToString() + " posts had been found, due to your post download limit only " + ($e621Attributes.PostLimit).ToString() + " will be downloaded.")
}

if ($e621Attributes.PostsQueued.count -lt $e621Attributes.PostLimit)
{
    Write-Host (($e621Attributes.PostsQueued.count).ToString() + " posts had been found based on your search criteria, because of this only " + ($e621Attributes.PostsQueued.count).ToString() + " posts will be downloaded.") -ForegroundColor Yellow
}


$e621Attributes.PostsQueued = $e621Attributes.PostsQueued | Select-Object -First ($e621Attributes.PostLimit)

Write-Verbose -Message ("Planning to download the following posts:"+"`n"+$WeblinksFiltered)


Write-Verbose -Message ("starting download of " + $e621Attributes.PostsQueued.Count + " posts!") 
[int]$ProgressCounter = 0
foreach ($item in $e621Attributes.PostsQueued){
    
    $ProgressCounter += 1
    Write-Progress -Activity "e621 Загрузчик" -Status ("Загрузка файла число "+ $ProgressCounter)  -PercentComplete ($ProgressCounter/$e621Attributes.PostsQueued.count*100)






    $imagepost = Invoke-WebRequest -Uri ("https://e621.net/post" +"/show/"+ ($item))
    $image = ($imagepost.Links|Where-Object {$_.outertext -like "download"}).href

    if ([string]::IsNullOrWhiteSpace($image))
    {
        Write-Warning -Message ("Something has failed with item " + (($imagepost.Links|Where-Object {$_.outertext -like "Download"}).href).tostring())
        
        

    }


    if (Test-Path ($e621Attributes.ЗагрузитьПапку + $image.Split("/")[-1]))
    {
        Write-verbose -Message ($image.Split("/")[-1] + " already exists!") 
    }
    else
    {

            Start-BitsTransfer -Source $Image -Destination $e621Attributes.ЗагрузитьПапку -Description ("https://e621.net/post" +"/show/"+ ($item)) -DisplayName "Загрузка изображения."
            

        
        
    }



}

#log the downloaded posts
function LOGDOWNLOADEDPOSTS ($Posts){
    
    #load up the log of already downloaded posts
     $DLLog = Get-Content -path $ЖурналПользователя
    #add the just downloaded posts
     $Output = $Posts + $DLLog
    #Update the downloaded posts logfile, (filtering dulicates too)
     $Output|Sort-Object -Unique| Out-File -FilePath $ЖурналПользователя -Force -Encoding utf8

} ; LOGDOWNLOADEDPOSTS -Posts $e621Attributes.PostsQueued



Write-Host ("Загрузка завершена, " + $e621Attributes.PostsQueued.count + " были загружены")
}


foreach ($Config in $UserConfig)
{
    Downloadfromconfig $Config
    "-"*50
    "`n"
}




pause