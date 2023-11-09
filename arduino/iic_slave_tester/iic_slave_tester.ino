#include <Wire.h>

void setup() {
  // clear slaves state if they drive the bus after reset
  digitalWrite(2, LOW); //scl
  for(int n = 0; n < 10; n++) {
    pinMode(2, OUTPUT);
    delay(1);
    pinMode(2, INPUT);
    delay(1);
  }

  Wire.begin();   
  Wire.setClock(1000000);   
  Wire.beginTransmission(0x61);
  Wire.write(0x00);
  Wire.write(0x00);
  Wire.endTransmission();

  Serial.begin(115200);
  pinMode(13, OUTPUT); //led
}

int chk_data(char wanted, char val)
{
  if(val != wanted) {
    Serial.print("Mismatch should=0x");
    Serial.print(wanted, HEX);
    Serial.print(" val=0x");
    Serial.println(val, HEX);
    return 1;
  }
  return 0;
}
int access_test(char val)
{
  int nerr = 0;
  Wire.beginTransmission(0x61);
  Wire.write(0x00);
  Wire.write(val);
  Wire.write(val+1);
  Wire.write(val+2);
  Wire.write(val+3);
  Wire.endTransmission();

  char d;
  Wire.beginTransmission(0x61);
  Wire.write(0x00);
  Wire.endTransmission();
  Wire.requestFrom(0x61, 4);
  d = Wire.read();
  nerr += chk_data(val, d);
  d = Wire.read();
  nerr += chk_data(val+1, d);
  d = Wire.read();
  nerr += chk_data(val+2, d);
  d = Wire.read();
  nerr += chk_data(val+3, d);
  return nerr;
}

int c=0;
int errtot=0;
void loop() {
  Serial.print("Starting round: "); Serial.println(c);

  digitalWrite(13, HIGH); //led

  //Load test writes 256*16*6 bytes on bus and reads it
  for(int n = 0; n < 256*16; n++) {
    errtot += access_test(n);
  }
  Serial.print("errtot: "); Serial.println(errtot);

  digitalWrite(13, LOW); //led

  delay(100);

  c++;
}
