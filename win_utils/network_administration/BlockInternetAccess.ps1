Set-NetFirewallProfile -Profile Domain,Private,Public `
  -DefaultOutboundAction Block -DefaultInboundAction Block
