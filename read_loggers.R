# this will load most of what you need
library(tidyverse)

# this is for listing files and manipulating filenames
library(fs)

# for date parsing
library(lubridate)

# to cleanly reference directories within the project
library(here)

# get the base dir for the project
proj_dir <- here::here()

# I have all the csv files in a folder called "logger_files"
# you can put yours in the same place or change this to the actual location
# dir_ls will recurse through all the subfolders and find every csv file
# so if your directory tree looked like this:
# data/12012018/<a bunch of csv files>
# data/12022018/<a bunch of csv files>
# it will find them all
# the magic is the recurse=TRUE argument
csv_files <- dir_ls(path(proj_dir,"data"),glob="*.CSV",recurse = TRUE)

# this next bit may be tricky so I'll try to explain it as best as I can
# map* functions are like the base R apply* functions. They go down the list
# of csv files and applies a function to each element. 
# map_dfr is a specific variant that expects the function to return
# a data frame. It then essentially calls rbind on each data frame that gets
# returned, so you end up with one big data frame.

# Check out this small example. I call map_dfr on a sequence of 5 numbers
# For each number, I generate a small dataframe filled with that number
# All those dataframe are bound together row-wise (rbinded, essentially) into one big one
# In the function, it's optional to use return() but it makes it more legible

# run this code and check out what df looks like
# obvs uncomment it first
# df <- map_dfr(seq(5),function(num) {
#   return(
#     data.frame(number=rep(num,5),number_name=str_c("number ",rep(num,5)))
#   )
# })
# View(df)

# I should mention that str_c is like paste. It smashes character strings together.
# Unlike paste, it doesn't put spaces between them unless you tell it to.

# Ok, here we go. I use map_dfr on the list of csv files
# the function loads each files, does some transformation, 
# and returns the dataframe with an associated logger ID
# Then all those dataframes get smashed together into one big one.
# For the purposes of this example, the loggers store their ID as the first part of the data filename
# so that if the filename looks like this: XXX_YYYYYY.CSV, the XXX part is the logger ID
loggers <- map_dfr(csv_files,function(csv) {
  # let's try to get the logger id
  # we'll start with the csv filename without any leading
  # directories and without the .csv at the end
  logger_id <- path_ext_remove(path_file(csv))
  # now, let's make sure that logger id looks like this: XXXX_XXXXX
  # Regular expressions are a whole huge complicated thing, but
  # "^(.+)_" basically says: 
  # at the start of the string, do I have some characters followed by an underscore
  # the parentheses are used to "capture" those characters that come before the underscore
  # str_detect just says whether the logger id looks like we want it to
  if (str_detect(logger_id,"^(.+)_")) {
    # if it does look like we want it to, pull out just the part
    # before the underscore. str_match returns a matrix and the second column
    # contains what's between the parentheses
    # for much more detail, check out the help for str_match and str_detect
    logger_id <- str_match(logger_id,"^(.+)_")[1,2]
  }
  
  # this is where the magic happens. Tidyverse uses a thing called a "pipe" (the %>% that you see below)
  # The pipe allows you to chain together multiple functions with the result of one being "piped" into
  # the input of the next. The way pipes work is that if you have a function called do_thing that takes an argument,
  # calling do_thing(x) is the same as calling x %>% do_thing(). You can do it multiple times:
  # x %>% do_thing() %>% do_thing() %>% do_thing()
  # would be the same as do_thing(do_thing(do_thing(x)))
  # In pipes, you can use . (dot) to refer to the thing being piped in
  # so in the above example . refers to x, so x %>% do_thing() is the same as x %>% do_thing(.)
  # It'll really help to read some intro material on the tidyverse because it's very elegant and 
  # simple but it can also be very confusing
  return(
    # first we read the csv file
    read_csv(csv,
             skip = 9, # skip 9 rows
             col_names = c("scan_number","date","time","raw","calibrated"), # name our columns
             col_types = "nccnn") %>% # force it to read the columns as numeric, character, character, numeric, numeric ("nccnn"
                                      # note the %>% on the line above. That will "pipe" the csv file into the next function
      # now we trim off whitespace from our dates and times
      # mutate is used to change columns
      # across(where(is.character)) chooses just columns containing character string
      # str_trim cuts whitespace, so something like "22/12/2017 " turns into just "22/12/2017"
      mutate(across(where(is.character), str_trim)) %>% 
      # now we make a new column in POSIXct format, parsing the date and time using the two different
      # formats we might expect to see (two digit year or three digit year)
      # for this example, we assume the date and time are in Hawai‘i time. Change tz to your timezone
      # (or leave it blank for UTC), if that ends up being relevant
      # remember, str_c just smashes two strings together, so I'm smashing the date and time together with a space between them
      # we also create a factor column indicating the logger id that we determined above
      mutate(
        datetime = parse_date_time(str_c(date," ",time), orders = c("d/m/y H:M:S","d/m/Y H:M:S"),tz="HST"),
        logger = factor(str_c("logger_",logger_id))
      ) %>%
      # select just lets us pull out specific columns
      # these are the ones we want
      select(logger, datetime, raw, calibrated)
  )
  
})



# the magic here is pivot_wider
# this function takes "long" data and turns it into "wide" data
# so if you have a table like this
# fruit  count date   
# apple     22 9/22/16
# banana    96 9/22/16
# mango     12 9/22/16
# apple     10 10/4/81
# banana     6 10/4/81
# mango     66 10/4/81
# it'll make the "names_from" column into column names, using the "values_from" columns as the values
# and merging them all together by the remaining columns (unmentioned, but in this case date), so you get
# something like this:
# date    apple banana mango
# 9/22/16    22     96    12
# 10/4/81    10      6    66

# try this code for this same example:
# fruit <- tibble(fruit=rep(c("apple","banana","mango"),2), count=c(22,96,12,10,6,66),date=c(rep("9/22/16",3),rep("10/4/81",3)))
# fruit %>% pivot_wider(names_from="fruit",values_from="count")

# it's worth noting that the opposite of pivot_wider is pivot_longer
# so here, we pivot our loggers to a wide format, using the logger ID as the column names
# and the raw and calibrated counts as the values
# the date/time is left over so that's what R uses to smash them together
loggers_wide <- loggers %>%
  pivot_wider(names_from="logger",values_from = c("raw","calibrated")) %>%
  arrange(datetime) # arrange just sorts the dataframe by the column you ask it to

# note that R will try to smash them together by the total combination of the columns
# you leave out, so if you don't need the raw values, you'll want to start with a dataframe that
# doesn't have them, like this (or else you'll end up with weird results):
loggers_wide_2 <- loggers %>%
  select(-raw) %>% # get rid of the raw column
  pivot_wider(names_from="logger",values_from="calibrated") %>%
  arrange(datetime)

# save the wide version of the file to CSV
# note that the datetime column will be saved in ISO8601 format with UTC timezone
# so that if you save the file and reload it and need it to be in local time, then make sure you 
# convert it to your local timezone
write_csv(loggers_wide,path(proj_dir,"data","loggers_wide.csv"))

# example of timezone conversion:
lw <- read_csv(path(proj_dir,"data","loggers_wide.csv")) %>%
  mutate(datetime = with_tz(datetime,"HST"))





