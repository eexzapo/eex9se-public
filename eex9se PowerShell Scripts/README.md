# eex9se FPS Registry Monitor (PowerShell)

Kevyt PowerShell-työkalu, joka tarkastelee Windowsin peli- ja suorituskykyyn liittyviä
rekisteriasetuksia (Game Mode, GPU, hiiri, MMCSS, power throttling, jne.)
ja esittää ne WPF-käyttöliittymässä.

Työkalu on **vain tarkasteluun** – se ei muuta järjestelmän asetuksia.

---

##  Käynnistys suoraan PowerShellistä (ei asennusta)

Avaa PowerShell (Windows PowerShell 5.1 tai uudempi) ja suorita:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/eexzapo/eex9se-public/main/eex9se%20PowerShell%20Scripts/eex9se-fps-register-monitor.ps1")))