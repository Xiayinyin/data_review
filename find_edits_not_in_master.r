# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Find variables where the value in the data collection form view are different
# from the value in the master view
#
# This is especially useful for high-burden countries featured in tables in the global report
#	to make sure main report tables and the country profiles are in sync.
#
# Hazim Timimi, December 2015
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# clear the decks
rm(list=ls())

# Set up the running environment ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# This depends on the person, location, machine used etc.and populates the following:
#
# scriptsfolder:      Folder containing these scripts
#
# The next is set using set_environment.r
#
# connection_string:  ODBC connection string to the global TB database
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

scriptsfolder <- getSrcDirectory(function(x) {x})  # See http://stackoverflow.com/a/30306616
setwd(scriptsfolder)

source("set_environment.r")  #particular to each person so this file is in the ignore list

# load packages ----

library(RODBC)
library(dplyr)
library(tidyr)


# Functions ----

Null_to_minus_1 <- function(x){
  # Convert a null (NA) to -1 to make comparisons possible
  x <- ifelse(is.na(x),-1,x)
  return(x)
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get the data  ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

channel <- odbcDriverConnect(connection_string)

# A. Latest data from the dcf views (dcf = data collection form)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# notifications
notifs_dcf <- sqlQuery(channel, "SELECT * FROM dcf.latest_notification",
                       stringsAsFactors = FALSE)


# treatment outcomes
outcomes_dcf <- sqlQuery(channel, "SELECT * FROM dcf.latest_outcomes",
                       stringsAsFactors = FALSE)

# mdr/xdr treatment outcomes
mdr_xdr_outcomes_dcf <- sqlQuery(channel, "SELECT * FROM dcf.latest_mdr_xdr_outcomes",
                       stringsAsFactors = FALSE)

# strategy -- just test the variables that affect profiles
strategy_dcf <- sqlQuery(channel, "SELECT country, year, iso2, prevtx_data_available, newinc_con04_prevtx, ptsurvey_newinc, ptsurvey_newinc_con04_prevtx FROM dcf.latest_strategy",
                       stringsAsFactors = FALSE)

# budget -- just test the variables that affect profiles
budget_dcf <- sqlQuery(channel, "SELECT country, year, iso2, budget_tot, cf_tot_domestic, cf_tot_gf, cf_tot_usaid, cf_tot_grnt, gap_tot FROM dcf.latest_budget_services",
                       stringsAsFactors = FALSE)

# B. Older records already in the master views (match years to dcf years)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


notifs_master <- sqlQuery(channel,
                      paste("SELECT *
                            FROM view_TME_master_notification
                            WHERE year = (SELECT MAX(year) FROM dcf.latest_notification)"),
                       stringsAsFactors = FALSE)

# dr surveillance records are in the dcf notifications view!
dr_surveillance_master <- sqlQuery(channel,
                          paste("SELECT *
                                FROM view_TME_master_dr_surveillance
                                WHERE year = (SELECT MAX(year) FROM dcf.latest_notification)"),
                           stringsAsFactors = FALSE)

outcomes_master <- sqlQuery(channel,
                      paste("SELECT *
                            FROM view_TME_master_outcomes
                            WHERE year = (SELECT MAX(year) FROM dcf.latest_outcomes)"),
                       stringsAsFactors = FALSE)

mdr_xdr_outcomes_master <- sqlQuery(channel,
                            paste("SELECT *
                                  FROM view_TME_master_outcomes
                                  WHERE year = (SELECT MAX(year) FROM dcf.latest_mdr_xdr_outcomes)"),
                             stringsAsFactors = FALSE)


strategy_master <- sqlQuery(channel, "SELECT country, year, iso2, prevtx_data_available, newinc_con04_prevtx, ptsurvey_newinc, ptsurvey_newinc_con04_prevtx
                            FROM view_TME_master_strategy
                            WHERE year = (SELECT MAX(year) FROM dcf.latest_strategy)",
                       stringsAsFactors = FALSE)

budget_master <- sqlQuery(channel, "SELECT country, year, iso2, budget_tot, cf_tot_domestic, cf_tot_gf, cf_tot_usaid, cf_tot_grnt, gap_tot
                          FROM view_TME_master_budget_expenditure
                          WHERE year = (SELECT MAX(year) FROM dcf.latest_budget_services)",
                       stringsAsFactors = FALSE)

close(channel)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Convert data to long format (Hadley Wickham's "tidy" format)  ----
# (called unpivoting in SQL-Server)
# Use iso2 in addition to variable name as row keys for DCF
# and keep country in row keys for master for ease of reading results
# Wrap it all up in a function
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

compare_views <- function(dcf_view, master_view){


  dcf_view_long <- dcf_view %>%
                    # restrict to the same variable names as in master_view
                    select(which(names(dcf_view) %in% names(master_view))) %>%
                    # drop country, year and remarks
                    select(-country, -year, -starts_with("remarks")) %>%
                    gather(key=var_name, value=value_dcf, -iso2) %>%
                    # convert nulls to -1
                    mutate(value_dcf=Null_to_minus_1(value_dcf))

  master_view_long <- master_view %>%
                      # remove un-needed variables before "tidying"
                      # so just restrict to the same variable names as in dcf_view
                      select(which(names(master_view) %in% names(dcf_view))) %>%
                      gather(key=var_name, value=value_master, -iso2, -country, -year ) %>%
                      # convert to strings to make comparisons easier, including for NAs
                      mutate(value_master=Null_to_minus_1(value_master))

  # Join the two long views and look for differences  ----
  # - - - - - - - - - - -

  views_diff <- master_view_long %>%
                inner_join(dcf_view_long) %>%
                filter( value_master != value_dcf) %>%
                arrange(country, var_name)

  return(views_diff)
}


stop("

>>>>>>>>>>>>>>

Righto, now you can look for differences interactively

<<<<<<<<<<<<<<

")


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Now do the comparisons  ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

notifs_diff <- compare_views(dcf_view = notifs_dcf, master_view = notifs_master)


# dr surveillance records are in the dcf notifications view!
dr_surveillance_diff <- compare_views(dcf_view = notifs_dcf, master_view = dr_surveillance_master)



# treatment success rates are not rounded in the outcomes dcf views, so round them now to match
# properly with master views

outcomes_dcf$c_new_tsr <- round(outcomes_dcf$c_new_tsr)
outcomes_dcf$c_ret_tsr <- round(outcomes_dcf$c_ret_tsr)
outcomes_dcf$c_tbhiv_tsr <- round(outcomes_dcf$c_tbhiv_tsr)

outcomes_diff <- compare_views(dcf_view = outcomes_dcf, master_view = outcomes_master)



mdr_xdr_outcomes_dcf$c_mdr_tsr <- round(mdr_xdr_outcomes_dcf$c_mdr_tsr)
mdr_xdr_outcomes_dcf$c_xdr_tsr <- round(mdr_xdr_outcomes_dcf$c_xdr_tsr)

mdr_xdr_outcomes_diff <- compare_views(dcf_view = mdr_xdr_outcomes_dcf, master_view = mdr_xdr_outcomes_master)


strategy_diff <- compare_views(dcf_view = strategy_dcf, master_view = strategy_master)

budget_diff <- compare_views(dcf_view = budget_dcf, master_view = budget_master)


