@0xd7de9e0850af18b2; 
# A unique identification string

struct Config {
  id @0 : Text = "default_id"; # field with default value
  workers @1 : Int8;
  port @2 : Int16; #max 65535 ports
}