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
  	uint16_t n_originals = 0;
  	uint8_t row = 2*NUM_MSGS;
  	uint8_t columns = NUM_MSGS;

    uint8_t matrix_n[2*NUM_MSGS][NUM_MSGS];
    uint16_t matrix_content[2*NUM_MSGS];
  

    /* FUNCTIONS */

    void sendSerial() {
        sMsg = (serial_message_t *) call SerialSend.getPayload(&s_buf, sizeof(serial_message_t));
	    sMsg->nodeid = TOS_NODE_ID;
	    sMsg->sent = sent;
	    sMsg->counter = n_originals;
	    call SerialSend.send(AM_BROADCAST_ADDR, &s_buf, sizeof(serial_message_t));
    }
  
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
     //Returns the number of messages combined
    uint8_t nCombinations(content_t *content) {
    	uint8_t i, count = 0;
    	for (i = 0; i < MAX_COMBINATIONS; i++) {
      		if (content->ids[i] != 0) {
        		count++;
      		}
    	}
    	return count;
  	}
  
  	// Add original message to buffer of messages original
    bool addContent(content_t *content) {
    	if (content->ids[0] == 0 || content->ids[0]-1 > MAX_STORE) {
      		return FALSE;
    	}
    	contents[content->ids[0]-1] = *content;
    	next_content++;
    	return TRUE;
    }
  
  	// Add combined message to buffer of messages combined.
  	bool addCombination(content_t *comb) {
        if (next_combination < MAX_CSTORE - 1) {
            combinations[next_combination] = *comb;
          	next_combination++;
      	  	return TRUE;
      	}
      	return FALSE;
  	}

    //Check if combined messages are equal
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
		        	if(c2->ids[j] == 0){
		        		break;
		        	}
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
  
    content_t combine(content_t *c1, content_t *c2) {
    	content_t result;
    	uint8_t i, j, count = 0;
    	bool found;
    	dbg("Deep", "%s combine c1->ids[0] %d c1->ids[1] %d c1->ids[2] %d c2->ids[0] %d c2->ids[1] %d c2->ids[2] %d conteudo c1 %d conteudo c2 %d\n", sim_time_string(), c1->ids[0], c1->ids[1], c1->ids[2], c2->ids[0], c2->ids[1], c2->ids[2], c1->content, c2->content);
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
    	dbg("Deep", "%s Result of XOR result.ids[0] %d result.ids[1] %d result.ids[2] %d result.ids->content %d\n", sim_time_string(), result.ids[0], result.ids[1], result.ids[2], result.content);
    	return result;
    }
  
    //Check if already have the message in the buffer
    bool inContents(content_t *content) {
    	if (contents[content->ids[0]-1].ids[0] == 0) {
      		return FALSE;
    	}
    	return TRUE;
  	}
  
    //Check if has the message with the passed id is in the buffer of messages original
    bool idInContents(uint8_t id) {
    	if (contents[id-1].ids[0] == 0) {
      		return FALSE;
    	}
    	return TRUE;
    }
  
    //Check if the combination is already in the list
    bool inCombinations(content_t *content) {
    	uint8_t i, n_comb1, n_comb2;
    	n_comb1 = nCombinations(content); 
	    for (i = 0; i < next_combination; i++) {
	   		n_comb2 = nCombinations(&combinations[i]);
	   		if(n_comb1 == n_comb2){
	      		if (isEqual(content, &combinations[i])) {
	        		return TRUE;
	      		}
	      	}
	    }
    	return FALSE;
  	}

  	uint16_t count_completion(){
    	uint8_t i;
    	uint16_t origs;
    	origs = 0;
        for (i = 0; i < NUM_MSGS; i++) {
        	if(contents[i].ids[0] != 0){
        		origs++;
        	}
        }
        return origs;
  	}

    void clean_buffer_comb(){
    	uint8_t i,j;
        for (i = 0; i < MAX_CSTORE; i++) {  
            for (j = 0; j < MAX_COMBINATIONS; j++) {
                combinations[i].ids[j] = 0;
          	}
            combinations[i].content = 0;
        }
        next_combination = 0;
    }

    void clean_matrix(){
    	uint8_t i, j;
  	    for(i = 0; i < row; i++)
            for(j = 0; j < columns; j++)
                matrix_n[i][j] = 0;
    }

  	void mount_matrix(){
  	    uint8_t i, j, c, pos;
  	    i = j = 0;

      	for (c = 0; c < MAX_CSTORE; c++){
      		if(combinations[c].ids[0] != 0){
	            while(combinations[c].ids[j] != 0){
	            	pos = combinations[c].ids[j] - 1;
		            matrix_n[i][pos] = 1;    
		            j++;
	            }
	            matrix_content[i] = combinations[c].content;
	            i++;
	            j = 0;
	        }
        }

      	for (j = 0; j < MAX_STORE; j++){
            if(contents[j].ids[0] != 0){
            	pos = contents[j].ids[0] - 1;
                matrix_n[i][pos] = 1;
                matrix_content[i] = contents[j].content;
                i++;
            }
        }
    }

    uint8_t count_msgs(uint8_t buf[NUM_MSGS]){
        uint8_t i, count;
        count = 0;
        for(i = 0; i < NUM_MSGS; i++){
        	if(buf[i]){
        	    count = count + 1;
        	}
        }
        return count;
    }

    void fill_orig(uint8_t buf[NUM_MSGS], uint16_t value){
        uint8_t i,j, pos;
        content_t temp_msg;
        i = j = pos = 0;
        for(i = 0; i < NUM_MSGS; i++){
        	if(buf[i])
                temp_msg.ids[0] = i;
        }
        temp_msg.content = value;

        if (addContent(&temp_msg)) {
          dbg("All", "%s Stored %d\n", sim_time_string(), temp_msg.ids[0]);
          call TrickleTimer.start[temp_msg.ids[0] - 1]();
          call TrickleTimer.reset[temp_msg.ids[0] - 1]();
        } 
        else {
          dbg("All", "%s Error storing %d\n", sim_time_string(), temp_msg.ids[0]);
        }

    }

    void fill_comb(uint8_t buf[NUM_MSGS], uint16_t value){
        uint8_t i,j, pos;
        content_t temp_msg;
        i = j = pos = 0;
        for(i = 0; i < NUM_MSGS; i++){
        	if(buf[i]){
                temp_msg.ids[pos] = i + 1;
            	pos = pos + 1;
            }
        }
        temp_msg.content = value;

        if (addCombination(&temp_msg)) {
            dbg("All", "%s Stored %d+%d\n", sim_time_string(), temp_msg.ids[0], temp_msg.ids[1]);
        } 
        else {
            dbg("All", "%s Error storing %d+%d\n", sim_time_string(), temp_msg.ids[0], temp_msg.ids[1]);
        }

    }

    void fill_buffer(){
  	    uint8_t i, j, pos, k, n_ids;
  	    uint8_t buffer_ids[NUM_MSGS];
  	    i = j = k = 0;

  	    for (i = 0; i < row; i++){

  	     	for (k = 0; k < NUM_MSGS; k++){
                buffer_ids[k] = 0;
	  	    }

  	        for(j = 0; j < columns; j++){
  	      	    if(matrix_n[i][j] == 1){
  	                buffer_ids[j] = 1;
  	      	    }
  	        }
  	        n_ids = count_msgs(buffer_ids);
  	        if(n_ids == 0){
  	            break;
  	        }
  	        if(n_ids == 1){
  	            fill_orig(buffer_ids, matrix_content[i]);
  	        }
  	        else{
  	            fill_comb(buffer_ids, matrix_content[i]);
  	        }

  	    }

    }

    void gauss_jordan(){
        uint8_t c, k, a, b;
	    int8_t i, j, l;
	    uint8_t temp[columns];
	    uint16_t tempcontent;
    	
    	//Print matrix
		dbg("Matrix", "The matrix is\n");
	    for( i = 0; i < row; i++){
	        dbg("Matrix", "%d %d %d %d %d %d %d %d %d %d\n", matrix_n[i][0], matrix_n[i][1], matrix_n[i][2], matrix_n[i][3], matrix_n[i][4],
	        					                           matrix_n[i][5], matrix_n[i][6], matrix_n[i][7], matrix_n[i][8], matrix_n[i][9]);
	    }

		//GAUSS-JORDAN Change lines
		for(l = 0; l < row; l++){
		    for(c = 0; c < columns; c++){
		        a = matrix_n[l][c];
		        if(a == 1)
		        	break;
		            //Change line
		        if(a == 0){
		            for(i = l + 1; i < row; i++){
		                b = matrix_n[i][c];
		                if(b == 1){
		                    for(j = 0; j < columns; j++){
		                        temp[j] = matrix_n[l][j];
		                        matrix_n[l][j] = matrix_n[i][j];
		                        matrix_n[i][j] = temp[j];
		                    }
		                    tempcontent = matrix_content[l];
		                    matrix_content[l] = matrix_content[i];
		                    matrix_content[i] = tempcontent;
		                    l = l + 1;
		                    c = -1;
		                    break;
		                }
		            }
		        }
		    }
		}


		//GAUSS-JORDAN XOR forward
		for(c = 0; c < columns; c++){
		    for(l = 0; l < row; l++){
		        if(l > c){
		            a = matrix_n[c][c];
		            b = matrix_n[l][c];
		
		         //XOR Zero forward
		            if(matrix_n[l][c] && a == 1){ //Content 1 in column. XOR with the line
		                for(k = 0; k < columns; k++){
		                    matrix_n[l][k] = matrix_n[c][k] ^ matrix_n[l][k];
		                }
		                matrix_content[l] = matrix_content[c] ^ matrix_content[l];
		            }
		        }
		    }
		}

		//GAUSS-JORDAN XOR backward
        for(l = row - 1; l >= 0; l--){
		    for(c = 0; c < columns; c++){
		        a = matrix_n[l][c];
                    if(a == 1){
	   			        for(i = l - 1; i >= 0; i--){
		  			        b = matrix_n[i][c];
			      		    //XOR Zero backward
	 					    if(b == 1){ //Content 1 in column. XOR with the line
						        for(k = 0; k < columns; k++){
			 		                matrix_n[i][k] = matrix_n[i][k] ^ matrix_n[l][k];
							    }
							    matrix_content[i] = matrix_content[i] ^ matrix_content[l];
							}
						}               
                    }
			}
		}

		//GAUSS-JORDAN Change lines in order
		for(l = 0; l < row; l++){
		    for(c = 0; c < columns; c++){
		        a = matrix_n[l][c];
		        if(a == 1)
		        	break;
		            //Change line
		        if(a == 0){
		            for(i = l + 1; i < row; i++){
		                b = matrix_n[i][c];
		                if(b == 1){
		                    for(j = 0; j < columns; j++){
		                        temp[j] = matrix_n[l][j];
		                        matrix_n[l][j] = matrix_n[i][j];
		                        matrix_n[i][j] = temp[j];
		                    }
		                    tempcontent = matrix_content[l];
		                    matrix_content[l] = matrix_content[i];
		                    matrix_content[i] = tempcontent;		         
		                    l = l + 1;
		                    c = -1;
		                    break;
		                }
		            }
		        }
		    }
		}
		//Print matrix
	    dbg("Matrix", "The matrix after of method gauss-jordan\n");
	    for( i = 0; i < row; i++){
	        dbg("Matrix", "%d %d %d %d %d %d %d %d %d %d\n", matrix_n[i][0], matrix_n[i][1], matrix_n[i][2], matrix_n[i][3], matrix_n[i][4],
	        					                           matrix_n[i][5], matrix_n[i][6], matrix_n[i][7], matrix_n[i][8], matrix_n[i][9]);
	    }
	    dbg("Matrix", "\n\n");
    
    }

    void decode(){
        mount_matrix();
 	    clean_buffer_comb();
      	gauss_jordan();
      	fill_buffer();
      	clean_matrix();
  	}
  

    /* EVENTS */
  
    event void Boot.booted() {
    	dbg("All", "%s Booted\n", sim_time_string());
	    call AMControl.start();
	    call SerialControl.start();
	    clean_matrix();
 	}
  
  	event void AMControl.startDone(error_t error) {
    	if (error == SUCCESS) {
      		dbg("All", "%s Radio Started\n", sim_time_string());
    	} 
    	else {
      		dbg("All", "%s Error Radio Start\n", sim_time_string());
      		call AMControl.start();
    	}
  	}
  
  	event void SerialControl.startDone(error_t error) {
	    if (error != SUCCESS) {
	      	call SerialControl.start();
	    } 
	    else {
	        call Timer.startOneShot(80000U);
	    }
  	}
  
  	event void AMControl.stopDone(error_t error) {
    	dbg("All", "%s Radio Stop Done\n", sim_time_string());
  	}
  
  	event void AMSend.sendDone(message_t *msg, error_t error) {
    	dbg("All", "%s Send Done\n", sim_time_string());
  	}
  
  	event void SerialControl.stopDone(error_t error) {}
  
  	event void SerialSend.sendDone(message_t * msg, error_t error) {
    	dbg("All", "%s Uart Send Done\n", sim_time_string());
  	}
 
    event message_t* Receive.receive(message_t *msg, void *payload, uint8_t len) {
	    uint16_t randomNumber = 0;
	    uint8_t n_combs;
	    dissemination_message_t *dMsg = (dissemination_message_t*) payload;
	    content_t content = dMsg->content;
   
    	dbg("All", "%s Received %d+%d from %d\n", sim_time_string(), content.ids[0], content.ids[1], dMsg->nodeid);

    	if (!isCombination(&content)) {     
      	// Messages is original.      
      		if (!inContents(&content)) {    
        	// Do not have the message received     
		        int i;
		        content_t aux;       
		        if (addContent(&content)) {
		          dbg("All", "%s Stored %d+%d\n", sim_time_string(), content.ids[0], content.ids[1]);
		          call TrickleTimer.start[content.ids[0] - 1]();
		          call TrickleTimer.reset[content.ids[0] - 1]();
	        	} 
	        	else {
	          		dbg("All", "%s Error storing %d\n", sim_time_string(), content.ids[0]);
	        	}
	        
		        //Decode combinations.
		        decode();

      		} 
      		else {      
        	//Have already the message
        		randomNumber = call Random.rand16();
        		if (randomNumber % 100 < SUPR)
            	call TrickleTimer.incrementCounter[content.ids[0] - 1]();      
      		}
   		} 

    	else {    
      	// It is a combination.  
		    n_combs = nCombinations(&content);   
      		if (!inCombinations(&content)) {
        	// Do not have the combination
		        uint8_t i;
		        bool ok = TRUE; 

		        for (i = 0; i < MAX_COMBINATIONS; i++) {
		          if (!idInContents(content.ids[i])) {
		              ok = FALSE;
		              break;
		          }
		        }  
        	    // If you already have all the messages, out.
        	    if (ok) {
          		    return msg;
        		}

		        if (addCombination(&content)) {
		            dbg("All", "%s Stored combination of %d messages\n", sim_time_string(), n_combs);
		        } 
		        else {
		            dbg("All", "%s Error storing combination \n", sim_time_string());
		        }

        		//Decode combinations
        		dbg("Matrix", "%s Receive message combined of %d messages\n", sim_time_string(), n_combs);
        		decode();
      		}
   		}
    	return msg;
    }
  
    event void TrickleTimer.fired[uint8_t id]() {
        uint8_t rand_num = call Random.rand16();
        uint8_t n_combs = call Random.rand16() % (MAX_COMBINATIONS + 1);
        uint8_t i, j, pos, n;
        uint8_t temp_ids[n_combs + 2];
        bool stop, b_comb;
        stop = FALSE;
        b_comb = TRUE;
        n = 0;
	    dbg("All", "%s TrickleTimer %d fired.\n", sim_time_string(), id);

	    if (next_content > 0) {
	        dissemination_message_t *msg = call AMSend.getPayload(&m_buf, sizeof(dissemination_message_t));
	        msg->nodeid = TOS_NODE_ID;
	        if (rand_num % 100 >= COMB || rand_num % MAX_STORE == id || next_content < 2) {
	            msg->content = contents[id];
	        }
	        //Combine
	      	else {
	      		
	      	    if(n_combs == 0 || n_combs == 1){
	      			n_combs = 2;
	      		}

                for(i = 0; i < n_combs; i++){
                	temp_ids[i] = 0;
                }

	      		dbg("Deep", "%s Number of combined messages %d\n", sim_time_string(), n_combs);
	            while (contents[rand_num % MAX_STORE].ids[0] == 0 || id == rand_num % MAX_STORE) {
	                rand_num++;
	                n++;
	                if(n == MAX_STORE + 1){
	                  	break;
	                }
	            }
	            temp_ids[0] = id;
	            temp_ids[1] = (rand_num % MAX_STORE) + 1;
	            rand_num++;
	            pos = 2;
	            dbg("Deep", "%s Combine %d with %d\n", sim_time_string(), id, rand_num % MAX_STORE + 1);
	        	msg->content = combine(&contents[id], &contents[rand_num % MAX_STORE]);
	        	n = 0;
	        	//check if can combine more
	        	for(i = 2; i < n_combs; i++){
	        		b_comb = TRUE;
	        	    while (contents[rand_num % MAX_STORE].ids[0] == 0 || id == rand_num % MAX_STORE) {
	                    rand_num++;
	                    n++;
	                    if(n == MAX_STORE + 1){
	                    	stop = TRUE;
	                    }
	                }
	                if(!stop)
	                {
	                	for(j = 0; j < n_combs; j++){
	                		if(temp_ids[j] == rand_num % MAX_STORE){
	                			b_comb = FALSE;
	                			rand_num++;
	                			break;
	                		}
	                	}
	                	if(b_comb){
	                		b_comb = TRUE;
	                        msg->content = combine(&msg->content, &contents[rand_num % MAX_STORE]);
	                    	temp_ids[pos] = rand_num % MAX_STORE;
	                    	pos++;
						}            
	                }
	                else{
	                	break;
	                }
	            }

	        }

	      	if (call AMSend.send(AM_BROADCAST_ADDR, &m_buf, sizeof(dissemination_message_t)) == SUCCESS) {
	            sent++;
	            n_originals = count_completion();
		        dbg("All", "%s Sent %d+%d\n", sim_time_string(), msg->content.ids[0], msg->content.ids[1]);
		        dbg("Simulation", "%s Sent %d Counter %d\n", sim_time_string(), sent, n_originals);
	        
	        } 
	        else {
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
          	        call TrickleTimer.start[msgs[i].ids[0] - 1]();
          	        call TrickleTimer.reset[msgs[i].ids[0] - 1]();
                }
            }
            call Timer.startPeriodic(1000);

        } 
        else {
            sendSerial();
        }
    }
}
