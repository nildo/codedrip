#include "Dissemination.h"

configuration DisseminationAppC {
  
}

implementation {
  components MainC;
  components DisseminationC as App;
  components ActiveMessageC;
  components new AMSenderC(AM_DISSEMINATION_MESSAGE);
  components new AMReceiverC(AM_DISSEMINATION_MESSAGE);
  components new TrickleTimerMilliC(1, 1024, 1, NUM_MSGS) as Timer;
  components RandomC;
  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_SERIAL_MESSAGE);
  components new TimerMilliC();
  
  App.Boot -> MainC;
  App.AMControl -> ActiveMessageC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.TrickleTimer -> Timer;
  App.Random -> RandomC;
  App.SeedInit -> RandomC;
  App.SerialControl -> SerialActiveMessageC;
  App.SerialSend -> SerialAMSenderC;
  App.Timer -> TimerMilliC;
}
