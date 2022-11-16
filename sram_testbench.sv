
class  transaction;

  rand bit write,read;
  rand bit [2:0] addres;
  rand bit [7:0] data_in;
        bit [7:0] data_out;
		bit [1:0] cnt;
		
constraint wr_rd_c { write != read; }
				
				
   function void  post_randomize();
    $display("transaction::transaction Generated"); 
    $display("write=%0d-----",write);
	 $display("read=%0d-----",read);
    $display("addres=%0d--------",addres);
    $display("data_in=%0d-------",data_in);	
    $display("data_out=%0d------",data_out);	
   endfunction
   
   
   function transaction do_copy();
    transaction trans;
    trans=new();
    trans.write=this.write;
    trans.read=this.read;
    trans.addres=this.addres;
    trans.data_in=this.data_in; 
	return trans;
   endfunction
   
endclass



/////////////generator block///////////////////
class genrator;
///rand transaction class
 rand transaction trans,tr;
 ////repeat count ,to specfiy
 int  repeat_count;
 
    mailbox gen2driv;          ///Mailbox created 
  //event
  event ended;
  
   function new(mailbox gen2driv,event ended);
     this.gen2driv =gen2driv;
	  this.ended    = ended;
	 trans = new();
  endfunction
     
 task main; 

   repeat(repeat_count) 
     begin
//	 trans.randomize();
	 if(!trans.randomize())
    	 $fatal("Gen:: trans randomization failed");
          //  $display("transaction error");		
	  tr=trans.do_copy();
	        gen2driv.put(tr);
			$display("genrator :: put into mailbox");
          
    end
	 -> ended; 
 endtask
endclass






//module mailbox_ex;
//   genrator gen;
//   driver   dri;
   
//   mailbox gen2driv;
   
//initial 
 
  //  begin
   //   gen2driv=new();
     // gen =new (gen2driv);
     // dri =new (gen2driv);      
     
   // fork
     //  gen.main();
     // dri.run();
    // join
 //end 
 
 
//endmodule

///////////interface block////////////////////////////////

 interface ram_intf(input logic clk);
   logic write,read;
   logic[2:0] addres;
  logic[7:0] data_in;
  logic[7:0] data_out;
  
   clocking ram_cb @(posedge clk);
        input write,read;
       input addres;
       input data_in;
       output data_out;        
  endclocking
  
 // modport drvier_mod( clocking ram_cb,input clk );
  modport drvier_mod( input clk,write,read,addres,data_in,output data_out );
endinterface




//`define DRIV_IF ram_vif.ram_cb

///////////////DRIVER block////////////////////////////////
class driver;

  //used to count the number of transactions
  int no_transactions;
  
  virtual ram_intf ram_vif;   
  
    mailbox gen2driv;
	
	function new(virtual ram_intf ram_vif,mailbox gen2driv);
	  this.ram_vif=ram_vif;
	  this.gen2driv=gen2driv;
	  $display("drive is enterd");
	endfunction
	
	task drive;
			transaction trans;
			ram_vif.drvier_mod.write<=0;
			ram_vif.drvier_mod.read<=0;
			gen2driv.get(trans);
			$display("DRIVER-----TRSFER");
		  @(posedge ram_vif.drvier_mod.clk);
			   	 ram_vif.drvier_mod.addres <= trans.addres; 
			if(trans.write)
			  begin 
                 ram_vif.drvier_mod.write<=trans.write;
			     ram_vif.drvier_mod.data_in<=trans.data_in;
			   $display("ADDRES=%0d,DATAIN=%0d",trans.addres,trans.data_in);
			   @(posedge ram_vif.drvier_mod.clk);
			  end
			if(trans.read)
               begin
			    ram_vif.drvier_mod.read<=trans.read; 
			   //  @(posedge ram_vif.drvier_mod.clk);
			    //	 ram_vif.drvier_mod.we<=0;
				 @(posedge ram_vif.drvier_mod.clk);
			    trans.data_out=ram_vif.drvier_mod.data_out;
			    $display("addres=%0d,data_out=%0d",trans.addres,ram_vif.drvier_mod.data_out);
                end
        $display("-------------------");
		no_transactions++;
				
	endtask
	
task main;
    //forever 
	 begin
       forever
            drive();
    end
endtask	

   
endclass


//env is create memory 

// // /////////////environment/////////////////
class environment;
   
    genrator gen;
    driver  driv;
    mailbox gen2driv;
	
	//event for synchronization between generator and test
  event gen_ended;
   
   virtual ram_intf ram_vif; 
   
   
    function new(virtual ram_intf ram_vif );
	   this.ram_vif = ram_vif;
	   gen2driv =new();
	  //creating generator and driver
       gen  = new(gen2driv,gen_ended);
	   driv = new(ram_vif,gen2driv);  
    endfunction
   
   
   task test();
     fork
	  gen.main();
	  driv.main(); // need to check
	 join_any 
   endtask  
   
   
  task post_test();
    wait(gen_ended.triggered);
    wait(gen.repeat_count == driv.no_transactions);
  endtask

  //run task
  task run;
    test();
    post_test();
    $finish;
  endtask

 endclass

///////////////////TEST/////////////////


program test(ram_intf intf);

class my_trans extends transaction; 
  bit [1:0] count;    
function void pre_randomize();
      write.rand_mode(0);
      read.rand_mode(0);
      addres.rand_mode(0);          
      if(cnt %2 == 0)
    begin
        write = 1;
        read = 0;
        addres  = count;      
     end 
      else begin
        write = 0;
        read = 1;
        addres  = count;
        count++;
      end
      cnt++;
    endfunction
  endclass
  
   environment env;
  my_trans my_tr;
  initial
    begin
	 env=new(intf);
	 my_tr =new();
	     //setting the repeat count of generator as 4, means to generate 4 packets
    env.gen.repeat_count = 6;
	env.gen.trans = my_tr;
	env.run();
	
	end
  
endprogram




module tbench_top;

 bit clk;
 
 always #5 clk =~clk;
 
 ram_intf intf(clk); 
 test t1(intf);
 ram DUT ( .clk(intf.clk),
		.write(intf.write),
                     .addres(intf.addres),
                     .data_in(intf.data_in),
                     .data_out(intf.data_out));
endmodule
