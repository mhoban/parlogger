# An example of how to merge and reformat data files produced by a hobo(?) PAR logger

In this project, I show you how to combine the log files produced by hobo PAR loggers into a single file for easier analysis.
Each logger produces multiple CSV files in the format `XXX_YYYY.CSV` where `XXX` is the identifier (ID) of that particular logger.

Here's an example first-few-lines from one such file:
```
Site Name 	MARIAHO			
Site Number 	3			
Logger 	Integrating Light Sensor			
Logger Serial Number 	10957			
				
				
Scan No 	Date and Time	       Integrating Light	        	
        	          RAW VALUE 	CALIBRATED VALUE	
				
1           4/12/17	  14:15:00	1251  1251
2	        4/12/17	  14:30:00	794	   794
3	        4/12/17	  14:45:00	936	   936
4       	4/12/17	  15:00:00	739	   739
5	        4/12/17	  15:15:00	477	   477
```

Note that the data doesn't actually begin until the 10th line, and that it doesn't have headers (this is relevant for when we load it). In order to analyze this data, we'd like to have one big file that contains the data from all our loggers, with rows designating date/time and columns designating PAR readings for each sensor, like this:

| datetime            | logger_1 | logger_2 | logger_3 |
|---------------------|----------|----------|----------|
| 2010-10-04 00:15:22 | 123      | 181      | 20       |
| 2010-10-17 17:04:00 | 923      | 19       | 181      |

This project contains R code to do exactly that. The file `read_loggers.R` is commented to hell and back, so I suggest just popping that open and giving it a whirl.

### Running the code
There's one thing you have to do before you run the code. The packages you'll need are baked into this RStudio project using something called renv. In order to install the packages you need, just go into the console and run:
```R
renv::restore()
```
After that, you should be able to run the code just fine!