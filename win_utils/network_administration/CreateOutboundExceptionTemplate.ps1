New-NetFirewallRule -DisplayName "<Rulename>" `
  -Direction Outbound -Action Allow -Protocol TCP -RemotePort <port> `
  -RemoteAddress <IP>
