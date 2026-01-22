[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Tarkistetaan järjestelmä
$IsWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)

if (-not $IsWindows) {
    Write-Error "Tämä skripti vaatii Windowsin."
    exit
}

# Pakotetaan PowerShell käyttämään STA-tilaa (vaatimus UI-ikkunoille)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
    return
}


# ==========================================================
# REKISTERIDATA
# ==========================================================

function Get-GamingRegistryInfo {
    $results = New-Object System.Collections.Generic.List[pscustomobject]

    function Add-RegRow {
        param(
            [string]$Ominaisuus,
            [string]$Path,
            [string]$Name,
            [string]$Suositus,
            [string]$Selite,
            [scriptblock]$Format = $null
        )

        $value = "Ei loydy"
		try {
			$p = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
			$raw = $p.$Name

			if ($null -eq $raw -or ($raw -is [string] -and [string]::IsNullOrWhiteSpace($raw))) {
				$value = "<empty>"
			}
			elseif ($null -ne $Format) {
				$value = & $Format $raw
			}
			else {
				$value = $raw
			}
		} catch {
			$value = "Ei löydy"
		}

		$results.Add([pscustomobject]@{
			IsHeader  = $false
			Ominaisuus = $Ominaisuus
			Arvo       = $value
			Suositus   = $Suositus
			Selite     = $Selite
			Path       = "$Path\$Name"
		})
    }

    function Add-Row {
        param([string]$Ominaisuus,[object]$Arvo,[string]$Suositus,[string]$Selite)

		$results.Add([pscustomobject]@{
			IsHeader  = $false
			Ominaisuus = $Ominaisuus
			Arvo       = $Arvo
			Suositus   = $Suositus
			Selite     = $Selite
		})
    }

	function Add-Header {
		param([string]$Title)
		$results.Add([pscustomobject]@{
			IsHeader  = $true
			Ominaisuus = $Title
			Arvo       = "----"
			Suositus   = "----"
			Selite     = "----"
		})
	}
    # ==========================================================
    # GAME MODE / GAME BAR / DVR
    # ==========================================================

    # 1) Game Mode
	Add-Header "GAME MODE"
	
    Add-RegRow `
        -Ominaisuus "Windows Game Mode" `
        -Path "HKCU:\Software\Microsoft\GameBar" `
        -Name "AllowAutoGameMode" `
        -Suositus "1" `
        -Selite "Game Mode paalla. Voi vahentaa taustakuormaa pelissa."

    # 2) Xbox Game Bar (overlay)
	Add-Header "XBOX GAME BAR (overlay)"
	
    Add-RegRow `
        -Ominaisuus "Xbox Game Bar (overlay)" `
        -Path "HKCU:\Software\Microsoft\GameBar" `
        -Name "ShowStartupPanel" `
        -Suositus "0" `
        -Selite "Jos et kayta Game Baria, overlay pois voi vahentaa hairioita."
		
	# 2b) Game Bar syvä disablointi / Nexus
	
	Add-RegRow `
		-Ominaisuus "GameBar Nexus (UseNexusForGameBarEnabled)" `
		-Path "HKCU:\Software\Microsoft\GameBar" `
		-Name "UseNexusForGameBarEnabled" `
		-Suositus "0" `
		-Selite "Syvempi Game Bar -kytkin joissain buildeissa. 0 = pois (jos et käytä Game Baria)."

    # 3) Game DVR
	Add-Header "Game DVR"
	
    Add-RegRow `
        -Ominaisuus "Game DVR -Enabled (GameConfigStore)" `
        -Path "HKCU:\System\GameConfigStore" `
        -Name "GameDVR_Enabled" `
        -Suositus "0" `
        -Selite "Taustatallennus voi syoda resursseja. (0 = pois)."

    Add-RegRow `
        -Ominaisuus "AppCaptureEnabled" `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" `
        -Suositus "0" `
        -Selite "Windowsin kaappaus/toistotallennus pois, jos et kayta."

    Add-RegRow `
        -Ominaisuus "FSE Behavior Mode (GameDVR_FSEBehaviorMode)" `
        -Path "HKCU:\System\GameConfigStore" `
        -Name "GameDVR_FSEBehaviorMode" `
        -Suositus "2 (vaihtelee)" `
        -Selite "Fullscreen optimizations -kaytos. Arvot vaihtelee buildien mukaan; tarkoitus on vain tarkastella."
	
	# 3b) Game DVR policy (GPO pakotus)
	Add-RegRow `
		-Ominaisuus "GameDVR Policy (AllowGameDVR)" `
		-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" `
		-Name "AllowGameDVR" `
		-Suositus "0" `
		-Selite "GPO-tason pakotus: 0 = estä GameDVR kokonaan (hyvä jos haluat varmistaa ettei taustakaappaus aktivoidu)."
    # ==========================================================
    # GPU / GRAFIIKKA
    # ==========================================================
    Add-Header "GPU / GRAPHS"
	
    # 4) HAGS
    Add-RegRow `
        -Ominaisuus "GPU Scheduling (HAGS) - HwSchMode" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
        -Name "HwSchMode" `
        -Suositus "2 (paalla) / 1 (pois)" `
        -Selite "HAGS: 2=Enable, 1=Disable joissain ymparistoissa. Tarkista myos Windowsin asetuksista."

    # 5) TDR Delay
    Add-RegRow `
        -Ominaisuus "TDR Delay (TdrDelay)" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
        -Name "TdrDelay" `
        -Suositus "Ei pakko" `
        -Selite "GPU watchdog -aikakatkaisu. Muuttaminen ei ole FPS-tweak, lahinna vakaus/diagnostiikka."

	# 5b) TdrDdiDelay
	Add-RegRow `
		-Ominaisuus "TDR DDI Delay (TdrDdiDelay)" `
		-Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
		-Name "TdrDdiDelay" `
		-Suositus "10" `
		-Selite "Lisäaika TDR-prosessille (stability/diagnostiikka). Ei FPS-tweak, mutta voi vähentää shader-compile resetointeja."

	# 5c) TdrLevel
	Add-RegRow `
		-Ominaisuus "TDR Level (TdrLevel)" `
		-Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
		-Name "TdrLevel" `
		-Suositus "3" `
		-Selite "3 = Recover (oletus/suositus). 0 = TDR pois (en suosittele)."

	# 5d) DirectX Shader Cache (GraphicsDrivers)
	Add-RegRow `
		-Ominaisuus "DirectX Shader Cache (ShaderCache)" `
		-Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
		-Name "ShaderCache" `
		-Suositus "1" `
		-Selite "0=pois, 1=päällä. Yleensä pidä päällä; poisto/tyhjennys auttaa joskus patchin jälkeen stutteriin."
    # ==========================================================
    # HIIRI
    # ==========================================================
	Add-Header "MOUSE"

    # 6) Mouse acceleration
    Add-RegRow `
        -Ominaisuus "Mouse Acceleration (MouseSpeed)" `
        -Path "HKCU:\Control Panel\Mouse" `
        -Name "MouseSpeed" `
        -Suositus "0" `
        -Selite "0 = ei Windows-kiihdytysta (usein hyva FPS-peleissa)."

    # 7) Mouse thresholds
    $mousePath = "HKCU:\Control Panel\Mouse"
    $t1 = (Get-ItemProperty -Path $mousePath -Name "MouseThreshold1" -ErrorAction SilentlyContinue).MouseThreshold1
    $t2 = (Get-ItemProperty -Path $mousePath -Name "MouseThreshold2" -ErrorAction SilentlyContinue).MouseThreshold2
    if ($null -eq $t1) { $t1 = "Ei loydy" }
    if ($null -eq $t2) { $t2 = "Ei loydy" }

    Add-Row `
        -Ominaisuus "Mouse Raw Thresholds (Threshold1/2)" `
        -Arvo "$t1 / $t2" `
        -Suositus "0 / 0" `
        -Selite "Perinteiset kiihdytysrajat. 0/0 yleensa puhtain tuntuma."

    # 8) MouseSensitivity
    Add-RegRow `
        -Ominaisuus "Mouse Sensitivity (MouseSensitivity)" `
        -Path "HKCU:\Control Panel\Mouse" `
        -Name "MouseSensitivity" `
        -Suositus "10 (tyypillinen)" `
        -Selite "Windowsin perusherkkyys. Ei ole DPI, mutta vaikuttaa skaalaan."

    # ==========================================================
    # MULTIMEDIA / PELIAJOITUS (SystemProfile)
    # ==========================================================
	Add-Header "MULTIMEDIA / GAME TIMING (SystemProfile)"

    # 9) SystemResponsiveness
    Add-RegRow `
        -Ominaisuus "SystemResponsiveness" `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
        -Name "SystemResponsiveness" `
        -Suositus "10-20 (tyypillinen)" `
        -Selite "Multimedia scheduler -responsiivisuus. Liian aggressiiviset tweakit voivat pahentaa stutteria."

    # 10) NetworkThrottlingIndex
    Add-RegRow `
        -Ominaisuus "NetworkThrottlingIndex" `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
        -Name "NetworkThrottlingIndex" `
        -Suositus "0xFFFFFFFF (jos kaytossa)" `
        -Selite "Verkkothrottlaus (legacy). Tarkastele - ei ole pakko muuttaa nyky-Windowsissa."

    # 11) MMCSS Games
    $gamesTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"

    Add-RegRow `
        -Ominaisuus "MMCSS Games: GPU Priority" `
        -Path $gamesTask `
        -Name "GPU Priority" `
        -Suositus "8 (tyypillinen)" `
        -Selite "MMCSS Games -tehtavan GPU-prioriteetti."

    Add-RegRow `
        -Ominaisuus "MMCSS Games: Priority" `
        -Path $gamesTask `
        -Name "Priority" `
        -Suositus "2 (tyypillinen)" `
        -Selite "MMCSS Games -prioriteetti."

    Add-RegRow `
        -Ominaisuus "MMCSS Games: Scheduling Category" `
        -Path $gamesTask `
        -Name "Scheduling Category" `
        -Suositus "High (tyypillinen)" `
        -Selite "MMCSS Games -ajoituskategoria."

	# 11b) MMCSS Games: SFIO Priority
	Add-RegRow `
	  -Ominaisuus "MMCSS Games: SFIO Priority" `
	  -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
	  -Name "SFIO Priority" `
	  -Suositus "High" `
	  -Selite "Storage/File I/O prioriteetti MMCSS Games -taskille."

	# 11c) MMCSS Games: Background Only
	Add-RegRow `
	  -Ominaisuus "MMCSS Games: Background Only" `
	  -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
	  -Name "Background Only" `
	  -Suositus "0" `
	  -Selite "0 = vaikuttaa myös foregroundiin (peleille). 1 = vain taustalle."

	# 11d) MMCSS Games: Clock Rate
	Add-RegRow `
	  -Ominaisuus "MMCSS Games: Clock Rate" `
	  -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
	  -Name "Clock Rate" `
	  -Suositus "10000" `
	  -Selite "Ajastus/clock rate -parametri (joissain tweak-profiileissa 10000)."
    # ==========================================================
    # CPU-AJOITUS / PRIORITEETTI
    # ==========================================================
    Add-Header "CPU-TIMING / PRIORITY"
    # 12) Win32PrioritySeparation
    Add-RegRow `
        -Ominaisuus "Win32PrioritySeparation" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
        -Name "Win32PrioritySeparation" `
        -Suositus "Oletus (usein 0x26/0x18)" `
        -Selite "Prosessien aika-viipale / foreground bias. Tweakit voi rikkoa tuntumaa -> tarkastele ensin."

    # ==========================================================
    # POWER / THROTTLING
    # ==========================================================
    Add-Header "POWER / THROTTLING"
    # 13) Power throttling
    Add-RegRow `
        -Ominaisuus "PowerThrottlingOff" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" `
        -Name "PowerThrottlingOff" `
        -Suositus "1 (jos haluat pois)" `
        -Selite "Poistaa Windowsin power throttling -mekanismeja. Hyoty riippuu koneesta."

    # 14) Background apps
    Add-RegRow `
        -Ominaisuus "Background Apps Disabled (GlobalUserDisabled)" `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
        -Name "GlobalUserDisabled" `
        -Suositus "1 (jos haluat pois)" `
        -Selite "Taustasovellukset pois voi vahentaa turhaa kuormaa."

	# 14b) NVMe / DISK power settings (PowerSettings visibility)
	$subDisk = "0012ee47-9041-4b5d-9b77-535fba8b1442"

	Add-RegRow `
	  -Ominaisuus "NVMe: Primary Idle Timeout (Attributes)" `
	  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$subDisk\d639518a-e56d-4345-8af2-b9f32fb26109" `
	  -Name "Attributes" `
	  -Suositus "2 (yleensä = näkyviin)" `
	  -Selite "Power Options -asetuksen näkyvyys. Jos haluat näyttää/piilottaa: powercfg -attributes SUB_DISK <GUID> -ATTRIB_SHOW/-ATTRIB_HIDE."

	Add-RegRow `
	  -Ominaisuus "NVMe: Secondary Idle Timeout (Attributes)" `
	  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$subDisk\d3d55efd-c1ff-424e-9dc3-441be7833010" `
	  -Name "Attributes" `
	  -Suositus "2 (yleensä = näkyviin)" `
	  -Selite "Sama kuin yllä, toinen idle timeout."

	Add-RegRow `
	  -Ominaisuus "NVMe: Primary Latency Tolerance (Attributes)" `
	  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$subDisk\fc95af4d-40e7-4b6d-835a-56d131dbc80e" `
	  -Name "Attributes" `
	  -Suositus "2 (yleensä = näkyviin)" `
	  -Selite "Power state transition latency tolerance (primary)."

	Add-RegRow `
	  -Ominaisuus "NVMe: Secondary Latency Tolerance (Attributes)" `
	  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$subDisk\dbc9e238-6de9-49e3-92cd-8c2b4946b472" `
	  -Name "Attributes" `
	  -Suositus "2 (yleensä = näkyviin)" `
	  -Selite "Power state transition latency tolerance (secondary)."

	Add-RegRow `
	  -Ominaisuus "NVMe: NOPPME (Attributes)" `
	  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$subDisk\fc7372b6-ab2d-43ee-8797-15e9841f2cca" `
	  -Name "Attributes" `
	  -Suositus "2 (yleensä = näkyviin)" `
	  -Selite "NVMe NOPPME -asetuksen näkyvyys (piilotettu/näkyvä)."
    # ==========================================================
    # VERKKO (tarkastelu)
    # ==========================================================
    Add-Header "NETWORK (tarkastelu)"
    # 15) NDU service
    Add-RegRow `
        -Ominaisuus "NDU Service Start" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu" `
        -Name "Start" `
        -Suositus "2 (Auto) / 3 (Manual)" `
        -Selite "Vain tarkasteluun. Disablointi voi sotkea verkkomittauksia/ominaisuuksia."

    # ==========================================================
    # LISAYKSET (pelikoneen checklist)
    # ==========================================================
    Add-Header "Muut pelikone lisäykset)"
    # 16) Sticky / Filter / Toggle keys
    Add-RegRow `
        -Ominaisuus "StickyKeys (Flags)" `
        -Path "HKCU:\Control Panel\Accessibility\StickyKeys" `
        -Name "Flags" `
        -Suositus "Pois kaytosta (jos et kayta)" `
        -Selite "StickyKeys voi aktivoitua Shift-ramputyksesta. Tarkista ettei se hairitse pelaamista."

    Add-RegRow `
        -Ominaisuus "FilterKeys (Flags)" `
        -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" `
        -Name "Flags" `
        -Suositus "Pois kaytosta (jos et kayta)" `
        -Selite "FilterKeys voi muuttaa nappaintoistoa/viiveita."

    Add-RegRow `
        -Ominaisuus "ToggleKeys (Flags)" `
        -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" `
        -Name "Flags" `
        -Suositus "Pois kaytosta (jos et kayta)" `
        -Selite "ToggleKeys piippaa ja voi hairita."

    # 17) Visual effects
    Add-RegRow `
        -Ominaisuus "VisualFXSetting" `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" `
        -Suositus "2 (Best performance) / 0 (Let Windows decide)" `
        -Selite "Vaikuttaa UI-efekteihin. Ei suoraan FPS, mutta voi keventaa kayttoliittymaa."

    # 18) Captures folder (User Shell Folders GUID)
    Add-RegRow `
        -Ominaisuus "Captures Folder" `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" `
        -Name "{EDC0FE71-98D8-4F4A-B920-C8DC133CB165}" `
        -Suositus "Nopea levy (NVMe) jos tallennat" `
        -Selite "Tallennuspolku. Hidas levy voi aiheuttaa piikkeja tallennuksen aikana." `
        -Format { param($v) $v }

    # 19) NVIDIA shader cache path (jos ajuri luo)
    Add-RegRow `
        -Ominaisuus "NVIDIA ShaderCache Path (jos loytyy)" `
        -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\ShaderCache" `
        -Name "Path" `
        -Suositus "Nopea levy" `
        -Selite "Jos ajuri tallentaa shader cachea levylle, NVMe voi vahentaa stutteria (tarkastus)."

    # 20) Audio ducking preference (tarkastelu)
    Add-RegRow `
        -Ominaisuus "Audio Ducking (UserDuckingPreference)" `
        -Path "HKCU:\Software\Microsoft\Multimedia\Audio" `
        -Name "UserDuckingPreference" `
        -Suositus "3 (Do nothing)" `
        -Selite "Ducking/viestien vaimennus. Ei suoraan FPS, mutta voi vaikuttaa pelikokemukseen."

    # 21) Delivery Optimization mode (tarkastelu)
    Add-RegRow `
        -Ominaisuus "Delivery Optimization (DODownloadMode)" `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" `
        -Name "DODownloadMode" `
        -Suositus "0 (P2P pois) / riippuu politiikoista" `
        -Selite "Taustalataus/P2P voi syoda kaistaa. Arvo voi tulla myos GPO:sta."

    # 22) USB selective suspend (jos avain on olemassa)
    Add-RegRow `
        -Ominaisuus "USB Selective Suspend (DisableSelectiveSuspend)" `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" `
        -Name "DisableSelectiveSuspend" `
        -Suositus "0 (oletus) / 1 (pois) - vain jos ongelmia" `
        -Selite "Joskus laite-ongelmissa tarkastellaan tata. Ei yleinen FPS-tweak."

    return $results
}

# ==========================================================
# UI (WPF)
# ==========================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CORE-OS // REGISTRY MONITOR"
        Height="650" Width="1000"
        Background="#05080A" Foreground="#00F2FF"
        WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResizeWithGrip">
   
    <Window.Resources>
        <Style TargetType="{x:Type ScrollBar}">
            <Setter Property="Background" Value="#05080A"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid Background="#05080A">
                            <Track Name="PART_Track" IsDirectionReversed="true">
                                <Track.Thumb>
                                    <Thumb Background="#00F2FF" Opacity="0.3"/>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="10"/>
                    <Setter Property="Width" Value="Auto"/>
                </Trigger>
                <Trigger Property="Orientation" Value="Vertical">
                    <Setter Property="Width" Value="10"/>
                    <Setter Property="Height" Value="Auto"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="RowBackground" Value="#0D1218"/>
            <Setter Property="AlternatingRowBackground" Value="#080C10"/>
        </Style>
    </Window.Resources>

    <Border BorderBrush="#00F2FF" BorderThickness="1" Background="#0A0F14">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="40"/> <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>    
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Rectangle Name="TitleBar" Grid.Row="0" Fill="#101820" Opacity="0.1" Cursor="SizeAll"/>
            <TextBlock Grid.Row="0" Text="::: eex9se SECURE TERMINAL SESSION - DRAG TO MOVE :::"
                       FontSize="9" Foreground="#00F2FF" Opacity="0.4"
                       HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False"/>

            <StackPanel Grid.Row="1" Margin="25,0,25,15">
                <TextBlock Text="SYSTEM DIAGNOSTICS: REGISTRY_FPS_MONITOR"
                           FontSize="24" FontWeight="Bold" Foreground="#00F2FF" FontFamily="Consolas">
                    <TextBlock.Effect>
                        <DropShadowEffect Color="#00F2FF" BlurRadius="12" ShadowDepth="0"/>
                    </TextBlock.Effect>
                </TextBlock>
                <Rectangle Height="1" Fill="#00F2FF" Opacity="0.3" Margin="0,5,0,0"/>
            </StackPanel>

			<Grid Grid.Row="2" Margin="25,0,25,0">
			<Viewbox Stretch="Uniform" Opacity="0.1" IsHitTestVisible="False" Panel.ZIndex="10" Margin="40">
			<TextBlock FontFamily="Consolas" Foreground="#00F2FF" TextAlignment="Center" xml:space="preserve">
			eex9se
			</TextBlock>
			</Viewbox>

			<Border BorderBrush="#00F2FF" BorderThickness="0,1,0,1">
			<DataGrid Name="dgRegistry" AutoGenerateColumns="False"
			 Background="Transparent" Foreground="#00F2FF" IsReadOnly="True"
			 CanUserAddRows="False" GridLinesVisibility="Horizontal"
			 HorizontalGridLinesBrush="#1A00F2FF" FontFamily="Consolas"
			 HeadersVisibility="Column"
			 ScrollViewer.HorizontalScrollBarVisibility="Auto"
			 ScrollViewer.VerticalScrollBarVisibility="Auto">
			<DataGrid.Resources>
			<Style TargetType="DataGridColumnHeader">
			<Setter Property="Background" Value="#101820"/>
			<Setter Property="Foreground" Value="#00F2FF"/>
			<Setter Property="Padding" Value="10"/>
			<Setter Property="BorderThickness" Value="0,0,0,1"/>
			<Setter Property="BorderBrush" Value="#00F2FF"/>
			</Style>
			<Style TargetType="DataGridRow">
			  <Setter Property="Background" Value="#CC0D1218"/>
			  <Style.Triggers>
				<DataTrigger Binding="{Binding IsHeader}" Value="True">
				  <Setter Property="Background" Value="#201A2A33"/>
				  <Setter Property="FontWeight" Value="Bold"/>
				</DataTrigger>
			  </Style.Triggers>
			</Style>
			</DataGrid.Resources>
			<DataGrid.Columns>
				<DataGridTextColumn Header="[ PARAMETER ]" Binding="{Binding Ominaisuus}" Width="250"/>
				<DataGridTextColumn Header="[ CURRENT ]" Binding="{Binding Arvo}" Width="150"/>
				<DataGridTextColumn Header="[ OPTIMAL ]" Binding="{Binding Suositus}" Width="150"/>
				<DataGridTextColumn Header="[ DESCRIPTION ]" Binding="{Binding Selite}" Width="*"/>
				<DataGridTextColumn Header="[ REGISTRY PATH ]" Binding="{Binding Path}" Width="100"/>
			</DataGrid.Columns>
			</DataGrid>
			</Border>
			</Grid>

            <Grid Grid.Row="3" Margin="25,15,25,20">
                <TextBlock Text="eex9se CORE_OS_VER: 1.0.0 - SESSION_ACTIVE | Copyright (c) 2026 eex9se"
                           FontSize="9" Foreground="#00F2FF" Opacity="0.4" VerticalAlignment="Center"/>
               
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button Name="btnRefresh" Content="INITIALIZE SCAN" Width="160" Height="38" Margin="0,0,10,0"
                            Background="#05080A" Foreground="#00F2FF" BorderBrush="#00F2FF"/>
                    <Button Name="btnClose" Content="TERMINATE" Width="130" Height="38"
                            Background="#200505" Foreground="#FF4444" BorderBrush="#FF4444"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

# Ladataan XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Haetaan elementit
$dgRegistry = $window.FindName("dgRegistry")
$btnRefresh = $window.FindName("btnRefresh")
$btnClose   = $window.FindName("btnClose")
$TitleBar   = $window.FindName("TitleBar")

# --- TAPAHTUMAT (Event Handlers) ---

# Ikkunan liikuttaminen yläpalkista
$TitleBar.Add_MouseLeftButtonDown({
    $window.DragMove()
})

# Päivitä-nappi
$btnRefresh.Add_Click({
    $dgRegistry.ItemsSource = Get-GamingRegistryInfo
})

# Sulje-nappi
$btnClose.Add_Click({
    $window.Close()
})

# Alkulataus heti käynnistyksessä
$dgRegistry.ItemsSource = Get-GamingRegistryInfo

# Näytetään ikkuna
$window.ShowDialog() | Out-Null