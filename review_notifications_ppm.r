# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Look at trends in number of notifications from PPM
# Hazim Timimi, June 2018
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# clear the decks
rm(list=ls())

# Set up the running environment ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# This depends on the person, location, machine used etc.and populates the following:
#
# scriptsfolder:      Folder containing these scripts
# file_name:          Name of the PDF output file
#
# The next two are set using set_environment.r
#
# outfolder:          Folder containing output subfolders for tables and figures
# connection_string:  ODBC connection string to the global TB database
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

scriptsfolder <- getSrcDirectory(function(x) {x})  # See http://stackoverflow.com/a/30306616

file_name     <- paste0("ppm_graphs_", Sys.Date(), ".pdf")

setwd(scriptsfolder)

source("set_environment.r")  #particular to each person so this file is in the ignore list


# load packages ----
library(RODBC)
library(ggplot2)
library(dplyr)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get the data  ----
#
# I prefer to do this via SQL, but could be done of course with the pure views
# and some R jiggery pokey
#
# The query combines data from the master notification view with latest data
# reported as retreived from the dcf views (dcf = data collection form)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sql <- "SELECT country, year, pub_new_dx, priv_new_dx FROM dcf.latest_strategy
                WHERE COALESCE(pub_new_dx, priv_new_dx) IS NOT NULL
                UNION ALL
                SELECT country, year, pub_new_dx, priv_new_dx FROM view_TME_master_strategy
                WHERE year BETWEEN 2011 AND (SELECT MAX(year - 1) FROM dcf.latest_strategy) AND
  					    iso2 IN (SELECT iso2 FROM dcf.latest_strategy WHERE COALESCE(pub_new_dx, priv_new_dx) IS NOT NULL)
				        ORDER BY country,year"


# Extract data from the database
channel <- odbcDriverConnect(connection_string)
data_to_plot <- sqlQuery(channel,sql)

# get list of countries
countries <- sqlQuery(channel, "SELECT country FROM dcf.latest_strategy WHERE COALESCE(pub_new_dx, priv_new_dx) IS NOT NULL ORDER BY country")

close(channel)


# Define graph layout ----
# - - - - - - - - - - -

plot_faceted <- function(df){

  # Blue line  = public-public notifications
  # Green dots = private-public notifications


graphs <- qplot(year, pub_new_dx, data=df, geom="line", colour=I("blue"), alpha=0.2) +
          geom_line(aes(year, priv_new_dx), colour=I("green"), alpha=0.5) +
          facet_wrap(~country, scales="free_y") +
          xlab("year") + ylab("Notified cases") +
          expand_limits(y=0) +
          theme_bw(base_size=8) +
          theme(legend.position="bottom")

  # note that inside a function the print() command is needed to paint to the canvass
  #(see http://stackoverflow.com/questions/19288101/r-pdf-usage-inside-a-function)
  print(graphs)

}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Plot the graphs to PDF -------
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Get Function to plot multiple graphs to multi-page PDF
source("plot_blocks_to_pdf.r")

setwd(outfolder)

plot_blocks_to_pdf(data_to_plot, countries, file_name, plot_function = plot_faceted)


# clear the decks
rm(list=ls())





