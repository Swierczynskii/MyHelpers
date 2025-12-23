New-NetFirewallRule -DisplayName "<Rulename>" `
  -Direction Inbound -Action Allow -Protocol TCP -RemotePort <port> `
  -RemoteAddress <IP>
