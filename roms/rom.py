import sys
import binascii
import math

def main(args):
   rom=[]
   width = 8
   addrwidth=15
   namearray=args[0].split('.')
   romfile = open(namearray[0]+".v", "w")  
   romfile.write("module "+namearray[0]+"\n")
   romfile.write("(\n")
   romfile.write("input clk,\n")
   romfile.write("input ["+str(addrwidth-1)+":0] addr,\n")
   romfile.write("output ["+str(width-1)+":0] dout,\n")
   romfile.write("input cs );\n")
   romfile.write("reg ["+str(width-1)+":0] q;\n")
   romfile.write("always @(posedge clk) \n");
   romfile.write("begin \n");
   romfile.write("case (addr) \n");
   cnt=0
   with open(args[0],mode="rb") as f:
    byte = f.read(1)
    while byte:
         addr=hex(cnt)
         print(byte)
         data=binascii.b2a_hex(byte)
         print(data)
         addr=addr[2:]
         outline="\t"+str(addrwidth)+"'h"+addr+": q<="+str(width)+"'b"+data+";\n"
         #print(outline)
         romfile.write(outline)
         #        8'h00: d = 4'b0000;
         cnt=cnt+1
         # Do stuff with byte.
         byte = f.read(1)
   romfile.write("endcase\n");
   romfile.write("end\n");
   romfile.write("assign dout=q;\n")
   romfile.write("endmodule\n")
   romfile.close()
if __name__ == "__main__":
   main(sys.argv[1:])

