#include "Dissemination.h"

module DisseminationC {
  uses {
    interface Boot;
    interface SplitControl as AMControl;
    interface AMSend;
    interface Receive;
    interface TrickleTimer[uint8_t key];
    interface Random;
    interface ParameterInit<uint16_t> as SeedInit;
    interface SplitControl as SerialControl;
    interface AMSend as SerialSend;
    interface Timer<TMilli>;
  }
}

implementation {
  content_t contents[MAX_STORE];
  uint8_t next_content = 0;
  uint8_t next_send = 0;
  
  content_t combinations[MAX_CSTORE];
  uint8_t next_combination = 0;
  
  message_t m_buf;
  
  message_t s_buf;
  serial_message_t * sMsg;
  
  uint16_t sent = 0;
  uint16_t counter = 0;
  
  /* FUNCTIONS */
  
  void sendSerial() {
    sMsg = (serial_message_t *) call SerialSend.getPayload(&s_buf, sizeof(serial_message_t));
    sMsg->nodeid = TOS_NODE_ID;
    sMsg->sent = sent;
    sMsg->counter = counter;
    call SerialSend.send(AM_BROADCAST_ADDR, &s_buf, sizeof(serial_message_t));
  }
  
  // Verifica se um conteudo é combinação.
  bool isCombination(content_t *content) {
    uint8_t i, count = 0;
    for (i = 0; i < MAX_COMBINATIONS; i++) {
      if (content->ids[i] != 0) {
        count++;
      }
      if (count > 1) {
        return TRUE;
      }
    }
    return FALSE;
  }
  
  // Adiciona um conteudo à lista.
  bool addContent(content_t *content) {
    if (content->ids[0] == 0 || content->ids[0]-1 > MAX_STORE) {
      return FALSE;
    }
    contents[content->ids[0]-1] = *content;
    next_content++;
    return TRUE;
    
    /*if (next_content < MAX_STORE - 1) {
      contents[next_content] = *content;
      next_content++;
      return TRUE;
    }
    return FALSE;*/
  }
  
  // Adiciona combinação à lista.
  bool addCombination(content_t *comb) {
    if (next_combination < MAX_CSTORE - 1) {
      combinations[next_combination] = *comb;
      next_combination++;
      return TRUE;
    }
    return FALSE;
  }
  
  // Remove um conteúdo da lista.
  void removeContent(uint8_t c) {
    uint8_t i;
    for (i = c; i < next_content; i++) {
      contents[i] = contents[i+1];
    }
    next_content--;
  }
  
  // Verifica se um conteúdo é igual ao outro.
  bool isEqual(content_t *c1, content_t *c2) {
    uint8_t i, j;
    bool found;
    if (c1->content != c2->content) {
      return FALSE;
    }
    for (i = 0; i < MAX_COMBINATIONS; i++) {
      if (c1->ids[i] != 0) {
        found = FALSE;
        for (j = 0; j < MAX_COMBINATIONS; j++) {
          if (c1->ids[i] == c2->ids[j]) {
            found = TRUE;
            break;
          }
        }
        if (!found) {
          return FALSE;
        }
      }
    }
    return TRUE;
  }
  
  // Combina dois conteúdos.
  content_t combine(content_t *c1, content_t *c2) {
    content_t result;
    uint8_t i, j, count = 0;
    bool found;
    for (i = 0; i < MAX_COMBINATIONS; i++) {
      if (c1->ids[i] != 0) {
        found = FALSE;
        for (j = 0; j < MAX_COMBINATIONS; j++) {
          if (c1->ids[i] == c2->ids[j]) {
            found = TRUE;
            break;
          }
        }
        if (!found) {
          result.ids[count] = c1->ids[i];
          count++;
        }
      }
    }
    for (i = 0; i < MAX_COMBINATIONS; i++) {
      if (c2->ids[i] != 0) {
        found = FALSE;
        for (j = 0; j < MAX_COMBINATIONS; j++) {
          if (c2->ids[i] == c1->ids[j]) {
            found = TRUE;
            break;
          }
        }
        if (!found) {
          result.ids[count] = c2->ids[i];
          count++;
          if (count > MAX_COMBINATIONS) {
            dbg("All", "%s Error: MAX_COMBINATIONS exceeded.\n", sim_time_string());
            for (j = 0; j < MAX_COMBINATIONS; j++) {
              result.ids[j] = 0;
              //dbg("All", "%s %d\n", sim_time_string(), result.ids[j]);
            }
            //dbg("All", "%s %d\n", sim_time_string(), c2->ids[i]);
            result.content = 0;
            return result;
          }
        }
      }
    }
    while (count < MAX_COMBINATIONS) {
      result.ids[count] = 0;
      count++;
    }
    result.content = c1->content ^ c2->content;
    return result;
  }
  
  // Verifica se o conteúdo já está na lista.
  bool inContents(content_t *content) {
    if (contents[content->ids[0]-1].ids[0] == 0) {
      return FALSE;
    }
    return TRUE;
    /*uint8_t i;
    for (i = 0; i < next_content; i++) {
      if (isEqual(content, &contents[i])) {
        return TRUE;
      }
    }
    return FALSE;*/
  }
  
  // Verifica se o conteúdo com o id passado está na lista.
  bool idInContents(uint8_t id) {
    if (contents[id-1].ids[0] == 0) {
      return FALSE;
    }
    return TRUE;
    
    /*uint8_t i;
    for (i = 0; i < next_content; i++) {
      if (contents[i].ids[0] == id) {
        return TRUE;
      }
    }
    return FALSE;*/
  }
  
  // Verifica se a combinação já está na lista.
  bool inCombinations(content_t *content) {
    uint8_t i;
    for (i = 0; i < next_combination; i++) {
      if (isEqual(content, &combinations[i])) {
        return TRUE;
      }
    }
    return FALSE;
  }
  
  /* EVENTS */
  
  event void Boot.booted() {
    dbg("All", "%s Booted\n", sim_time_string());
    call AMControl.start();
    call SerialControl.start();
  }
  
  event void AMControl.startDone(error_t error) {
    if (error == SUCCESS) {
      dbg("All", "%s Radio Started\n", sim_time_string());
    } else {
      dbg("All", "%s Error Radio Start\n", sim_time_string());
      call AMControl.start();
    }
  }
  
  event void SerialControl.startDone(error_t error) {
    if (error != SUCCESS) {
      call SerialControl.start();
    } else {
      call Timer.startOneShot(80000U);
    }
  }
  
  event void AMControl.stopDone(error_t error) {
    dbg("All", "%s Radio Stop Done\n", sim_time_string());
  }
  
  event void AMSend.sendDone(message_t *msg, error_t error) {
    dbg("All", "%s Send Done\n", sim_time_string());
  }
  
  event void SerialControl.stopDone(error_t error) {
    
  }
  
  event void SerialSend.sendDone(message_t * msg, error_t error) {
    dbg("All", "%s Uart Send Done\n", sim_time_string());
  }
  
  event message_t* Receive.receive(message_t *msg, void *payload, uint8_t len) {
    uint16_t randomNumber = 0;
    dissemination_message_t *dMsg = (dissemination_message_t*) payload;
    content_t content = dMsg->content;
    
    dbg("All", "%s Received %d+%d from %d\n", sim_time_string(), content.ids[0], content.ids[1], dMsg->nodeid);
    if (!isCombination(&content)) {
      
      // É uma mensagem original.
      
      if (!inContents(&content)) {
        
        // Não possui a mensagem recebida.
        
        int i;
        content_t aux;
        
        if (addContent(&content)) {
          dbg("All", "%s Stored %d+%d\n", sim_time_string(), content.ids[0], content.ids[1]);
          counter++;
          call TrickleTimer.start[content.ids[0] - 1]();
          call TrickleTimer.reset[content.ids[0] - 1]();
          //sMsg->key = content.ids[0];
          //sMsg->counter = counter;
          //call SerialSend.send(AM_BROADCAST_ADDR, &s_buf, sizeof(serial_message_t));
        } else {
          dbg("All", "%s Error storing %d+%d\n", sim_time_string(), content.ids[0], content.ids[1]);
        }
        
        // Tentar decodificar as combinações.
        
        for (i = 0; i < next_combination; i++) {
          aux = combine(&content, &combinations[i]);
          if (aux.ids[0] != 0) {
            if (!isCombination(&aux)) {
              if (!inContents(&aux)) {
                if (addContent(&aux)) {
                  dbg("All", "%s Stored %d+%d\n", sim_time_string(), aux.ids[0], aux.ids[1]);
                  counter++;
                  call TrickleTimer.start[aux.ids[0] - 1]();
                  call TrickleTimer.reset[aux.ids[0] - 1]();
                  //sMsg->key = aux.ids[0];
                  //sMsg->counter = counter;
                  //call SerialSend.send(AM_BROADCAST_ADDR, &s_buf, sizeof(serial_message_t));
                } else {
                  dbg("All", "%s Error storing %d+%d\n", sim_time_string(), aux.ids[0], aux.ids[1]);
                }
              }
            }
          }
        }
        
      } else {
        
        // Já possui a mensagem recebida.
        randomNumber = call Random.rand16();
        if (randomNumber % 100 < SUPR)
          call TrickleTimer.incrementCounter[content.ids[0] - 1]();
        
      }
    } else {
      
      // É uma combinação.
      
      if (!inCombinations(&content)) {
        
        // Não possui a combinação.
        
        uint8_t i;
        content_t aux;
        bool ok = TRUE;
        
        for (i = 0; i < MAX_COMBINATIONS; i++) {
          if (!idInContents(content.ids[i])) {
            ok = FALSE;
          }/* else {
            randomNumber = call Random.rand16();
            if (randomNumber % 100 < SUPR)
              call TrickleTimer.incrementCounter[content.ids[i]-1]();
          }*/
        }
        
        // Se já possui todas as mensagens, sai.
        if (ok) {
          //sendSerial();
          return msg;
        }
        
        ok = FALSE;
        
        for (i = 0; i < MAX_STORE; i++) {
          if (contents[i].ids[0] != 0) {
            aux = combine(&content, &contents[i]);
            if (aux.ids[0] != 0) {
              if (!isCombination(&aux)) {
                if (!inContents(&aux)) {
                  if (addContent(&aux)) {
                    dbg("All", "%s Stored %d+%d\n", sim_time_string(), aux.ids[0], aux.ids[1]);
                    counter++;
                    call TrickleTimer.start[aux.ids[0] - 1]();
                    call TrickleTimer.reset[aux.ids[0] - 1]();
                    //sMsg->key = aux.ids[0];
                    //sMsg->counter = counter;
                    //call SerialSend.send(AM_BROADCAST_ADDR, &s_buf, sizeof(serial_message_t));
                    ok = TRUE;
                  } else {
                    dbg("All", "%s Error storing %d+%d\n", sim_time_string(), aux.ids[0], aux.ids[1]);
                  }
                }
              }
            }
          }
        }
        if (!ok) {
          if (addCombination(&content)) {
            dbg("All", "%s Stored %d+%d\n", sim_time_string(), content.ids[0], content.ids[1]);
            //call TrickleTimer.reset[0]();
          } else {
            dbg("All", "%s Error storing %d+%d\n", sim_time_string(), content.ids[0], content.ids[1]);
          }
        }
      }
    }
    //call SerialSend.send(AM_BROADCAST_ADDR, msg, sizeof(dissemination_message_t));
    //sendSerial();
    return msg;
  }
  
  event void TrickleTimer.fired[uint8_t id]() {
    uint8_t rand_num = call Random.rand16();
    dbg("All", "%s TrickleTimer %d fired.\n", sim_time_string(), id);
    if (next_content > 0) {
      dissemination_message_t *msg = call AMSend.getPayload(&m_buf, sizeof(dissemination_message_t));
      msg->nodeid = TOS_NODE_ID;
      if (rand_num % 100 >= COMB || rand_num % MAX_STORE == id || next_content < 2) {
        msg->content = contents[id];
      } else {
        while (contents[rand_num % MAX_STORE].ids[0] == 0 || id == rand_num % MAX_STORE) {
          rand_num++;
        }
        msg->content = combine(&contents[id], &contents[rand_num % MAX_STORE]);
      }
      if (call AMSend.send(AM_BROADCAST_ADDR, &m_buf, sizeof(dissemination_message_t)) == SUCCESS) {
        sent++;
        //sendSerial();
        //call SerialSend.send(AM_BROADCAST_ADDR, &m_buf, sizeof(dissemination_message_t));
        dbg("All", "%s Sent %d+%d\n", sim_time_string(), msg->content.ids[0], msg->content.ids[1]);
      } else {
        dbg("All", "%s Error Sending %d\n", sim_time_string(), msg->content.ids[0]);
      }
    }
  }
  
  event void Timer.fired() {
    if (call Timer.isOneShot()) {
      if (TOS_NODE_ID == ORIGIN_NODE) {
        content_t msgs[NUM_MSGS];
        uint8_t i = 0;
        uint8_t j = 0;
        for (i = 0; i < NUM_MSGS; i++) {
          msgs[i].ids[0] = i+1;
          for (j = 1; j < MAX_COMBINATIONS; j++) {
            msgs[i].ids[j] = 0;
          }
          msgs[i].content = NUM_MSGS + i;
        }
        for (i = 0; i < NUM_MSGS; i++) {
          addContent(&msgs[i]);
          counter++;
          call TrickleTimer.start[msgs[i].ids[0] - 1]();
          call TrickleTimer.reset[msgs[i].ids[0] - 1]();
        }
      }
      call Timer.startPeriodic(1000);
    } else {
      sendSerial();
    }
  }
}
