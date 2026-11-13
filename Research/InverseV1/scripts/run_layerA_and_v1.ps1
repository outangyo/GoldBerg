$scratch = "C:\Users\ACER\.gemini\antigravity\brain\58ab35aa-a701-45db-a18f-d8f6f11fcccc\scratch"
$testerLogDir = "C:\Users\ACER\AppData\Roaming\MetaQuotes\Tester\BB16F565FAAA6B23A20C26C49416FF05\Agent-127.0.0.1-3000\logs"
$mt5 = "C:\Program Files\XM Global MT5\terminal64.exe"

# 1. V1 Layer B (Baseline Portfolio, MaxOpenTrades=1, Deposit=10000, Risk=1.0%)
@"
[Tester]
Expert=GoldBerg_0.01.ex5
Symbol=GOLD
Period=D1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2023.12.01
ToDate=2026.10.08
ForwardMode=0
Deposit=10000
Currency=USD
ProfitInPips=1
Leverage=500
Visual=0
ShutdownTerminal=1
Report=V1_LayerB_Report
ReplaceReport=1
[TesterInputs]
InpMagicNumber=100888
InpRiskPercent=1.0
InpMaxOpenTrades=1
InpMaxDailyLossPct=3.0
InpMaxLosses=3
InpMaxSpreadPoints=500.0
InpUseSessionFilter=false
InpStartHour=8
InpStartMin=0
InpEndHour=22
InpEndMin=0
"@ | Set-Content "$scratch\tester_v1_layerB.ini" -Encoding ASCII

Start-Process -FilePath $mt5 -ArgumentList "/config:`"$scratch\tester_v1_layerB.ini`"" -Wait
Copy-Item "$testerLogDir\20261113.log" "$scratch\v1_layerB_portfolio.log" -Force
Write-Host "Completed V1 Layer B"

# 2. V1 Layer A (Unsuppressed Matched-Signal Diagnostic, MaxOpenTrades=10000)
@"
[Tester]
Expert=GoldBerg_0.01.ex5
Symbol=GOLD
Period=D1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2023.12.01
ToDate=2026.10.08
ForwardMode=0
Deposit=100000
Currency=USD
ProfitInPips=1
Leverage=500
Visual=0
ShutdownTerminal=1
Report=V1_LayerA_Report
ReplaceReport=1
[TesterInputs]
InpMagicNumber=100888
InpRiskPercent=0.25
InpMaxOpenTrades=10000
InpMaxDailyLossPct=3.0
InpMaxLosses=3
InpMaxSpreadPoints=500.0
InpUseSessionFilter=false
InpStartHour=8
InpStartMin=0
InpEndHour=22
InpEndMin=0
"@ | Set-Content "$scratch\tester_v1_layerA.ini" -Encoding ASCII

Start-Process -FilePath $mt5 -ArgumentList "/config:`"$scratch\tester_v1_layerA.ini`"" -Wait
Copy-Item "$testerLogDir\20261113.log" "$scratch\v1_layerA_matched.log" -Force
Write-Host "Completed V1 Layer A"

# 3. Inverse V2 Layer A (Unsuppressed Matched-Signal Diagnostic, MaxOpenTrades=10000)
@"
[Tester]
Expert=GoldBerg_InverseV2.ex5
Symbol=GOLD
Period=D1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2023.12.01
ToDate=2026.10.08
ForwardMode=0
Deposit=100000
Currency=USD
ProfitInPips=1
Leverage=500
Visual=0
ShutdownTerminal=1
Report=InverseV2_LayerA_Report
ReplaceReport=1
[TesterInputs]
InpMagicNumber=100889
InpRiskPercent=0.25
InpMaxOpenTrades=10000
InpMaxDailyLossPct=3.0
InpMaxLosses=3
InpMaxSpreadPoints=500.0
InpUseSessionFilter=false
InpStartHour=8
InpStartMin=0
InpEndHour=22
InpEndMin=0
"@ | Set-Content "$scratch\tester_v2_layerA.ini" -Encoding ASCII

Start-Process -FilePath $mt5 -ArgumentList "/config:`"$scratch\tester_v2_layerA.ini`"" -Wait
Copy-Item "$testerLogDir\20261113.log" "$scratch\inverse_v2_layerA_matched.log" -Force
Write-Host "Completed Inverse V2 Layer A"
