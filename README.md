# FPGA VR Robot Avatar (3D Video Generator on FPGA) @Make Faire Tokyo 2015

Maker Faire Tokyo 2015 http://makezine.jp/event/mft2015/  


## Directory Structure  
 /cores/      Cores library, with Verilog sources, test benches and documentation.  
 /boards/     Top-level design files, constraint files and Makefiles  
              for supported FPGA boards.  
 /doc/        Documentation.  

## Support Boards  
Digilent Atlys Boards

## Building tools
You will need:
 - Xilinx ISE 14.7


## How to build
    $ cd boards/atlys/synthesis
    $ make

## DEMO VR Robot
### OUTPUT1 : Head Mounted Display by printed 3D printer
![demo1](http://web.sfc.wide.ad.jp/~aom/img/mfaires15_demo2.JPG)
### OUTPUT2 : Sharp LL-151D (Naked Eye Stereoscopic Display)
![demo2](http://web.sfc.wide.ad.jp/~aom/img/mfaires15_demo.JPG)

## Documentation
[Slides in Japanese](http://www.slideshare.net/aomtoku/maker-faire-tokyo-2015-51527099)

## Contact
Email : aom at sfc.wide.ad.jp
