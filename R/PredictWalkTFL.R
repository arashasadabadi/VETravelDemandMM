#==========================
#PredictWalkTFL.R
#==========================
#
#<doc>
#
## PredictWalkTFL Module
#### January 4, 2019
#
#This module predicts Walking trip frequency and average walking trip length for households. It uses the model object in data/WalkTFLModel_df.rda and variables and coefficients therein to predict WalkTFL.
#
### Model Parameter Estimation
#
#See data-raw/WalkTFLModel_df.R.
#
### How the Module Works
#
#The user specifies the model in data-raw/WalkTFLModel_df.R and saves the estimation results in data/WalkTFLModel_df.rda. If no model re-estimation is desired, the estimation process can be skipped and the default model specification is then used. The module assigns WalkTFL to each household using variables including household characteristics, built environment, and transportation supply.
#
#</doc>

#=================================
#Packages used in code development
#=================================
#Uncomment following lines during code development. Recomment when done.
# library(visioneval)

#=============================================
#SECTION 1: ESTIMATE AND SAVE MODEL PARAMETERS
#=============================================
#See data-raw/WalkTFLModel_df.R

#================================================
#SECTION 2: DEFINE THE MODULE DATA SPECIFICATIONS
#================================================
#Define the data specifications
#------------------------------
PredictWalkTFLSpecifications <- list(
  #Level of geography module is applied at
  RunBy = "Region",

  #Specify data to be loaded from data store
  Get = items(
    item(
      NAME =
        items("HHSIZE",
              "WRKCOUNT",
              "Age65Plus"),
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "persons",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = ""
    ),
    item(
      NAME = "Income",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "currency",
      UNITS = "USD.2009",
      NAVALUE = -1,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0
    ),
    item(
      NAME = "CENSUS_R",
      #FILE = "marea_census_r.csv",
      TABLE = "Marea",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "category",
      PROHIBIT = "",
      ISELEMENTOF = c("NE", "S", "W", "MW"),
      SIZE = 2
    ),
    item(
      NAME = "TRPOPDEN",
      TABLE = "Bzone",
      GROUP = "Year",
      TYPE = "compound",
      UNITS = "PRSN/SQM",
      NAVALUE = -1,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0
    ),
    item(
      NAME = "ZeroVeh",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "none",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = ""
    )
  ),

  #Specify data to saved in the data store
  Set = items(
    item(
      NAME = "WalkTrips",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "trips",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0,
      DESCRIPTION = "Daily walking trip frequency"
    ),
    item(
      NAME = "TripDistance_Walk",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "mile",
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0,
      DESCRIPTION = "Average daily transit trip length"
    ),
    item(
      NAME = "HhId",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "integer",
      UNITS = "ID",
      NAVALUE = -1,
      PROHIBIT = c("NA", "< 0"),
      ISELEMENTOF = "",
      SIZE = 0,
      DESCRIPTION = "HouseholdID"
    ),
    item(
      NAME = "LocType",
      TABLE = "Household",
      GROUP = "Year",
      TYPE = "character",
      UNITS = "category",
      NAVALUE = "NA",
      PROHIBIT = "NA",
      ISELEMENTOF = c("Urban", "Town", "Rural"),
      SIZE = 5,
      DESCRIPTION = "Location type (Urban, Town, Rural) of the place where the household resides"
    )
  )
)

#Save the data specifications list
#---------------------------------
#' Specifications list for PredictWalkTFL module
#'
#' A list containing specifications for the PredictWalkTFL module.
#'
#' @format A list containing 4 components:
#' \describe{
#'  \item{RunBy}{the level of geography that the module is run at}
#'  \item{Inp}{scenario input data to be loaded into the datastore for this
#'  module}
#'  \item{Get}{module inputs to be read from the datastore}
#'  \item{Set}{module outputs to be written to the datastore}
#' }
"PredictWalkTFLSpecifications"
usethis::use_data(PredictWalkTFLSpecifications, overwrite = TRUE)

#=======================================================
#SECTION 3: DEFINE FUNCTIONS THAT IMPLEMENT THE SUBMODEL
#=======================================================

#Main module function that predicts Walk Trip Frequency and Length for households
#------------------------------------------------------
#' Main module function
#'
#' \code{PredictWalkTFL} predicts Walk Trip Frequency and Length (TFL) for each
#' household in the households dataset using independent variables including
#' household characteristics and 5D built environment variables.
#'
#' This function predicts WalkTFL for each hosuehold in the model region where
#' each household is assigned an WalkTFL. The model objects as a part of the
#' inputs are stored in data frame with two columns: a column for segmentation
#' (e.g., metro, non-metro) and a 'model' column for model object (list-column
#' data structure). The function "nests" the households data frame into a
#' list-column data frame by segments and applies the generic predict() function
#' for each segment to predict WalkTFL for each household. The vectors of HhId
#' and WalkTFL produced by the PredictWalkTFL function are to be stored in the
#' "Household" table.
#'
#' If this table does not exist, the function calculates a LENGTH value for
#' the table and returns that as well. The framework uses this information to
#' initialize the Households table. The function also computes the maximum
#' numbers of characters in the HhId and Azone datasets and assigns these to a
#' SIZE vector. This is necessary so that the framework can initialize these
#' datasets in the datastore. All the results are returned in a list.
#'
#' @param L A list containing the components listed in the Get specifications
#' for the module.
#' @return A list containing the components specified in the Set
#' specifications for the module along with:
#' LENGTH: A named integer vector having a single named element, "Household",
#' which identifies the length (number of rows) of the Household table to be
#' created in the datastore.
#' SIZE: A named integer vector having two elements. The first element, "Azone",
#' identifies the size of the longest Azone name. The second element, "HhId",
#' identifies the size of the longest HhId.
#' @import visioneval
#' @import dplyr
#' @import purrr
#' @import tidyr
#' @import pscl
#' @export
PredictWalkTFL <- function(L) {
  #TODO: get id_name from L or specification?
  dataset_name <- "Household"
  id_name <- "HhId"

  Bzone_df <- data.frame(L$Year[["Bzone"]])
  stopifnot("data.frame" %in% class(Bzone_df))

  Marea_df <- data.frame(L$Year[["Marea"]])
  stopifnot("data.frame" %in% class(Marea_df))

  D_df <- data.frame(L$Year[[dataset_name]])
  stopifnot("data.frame" %in% class(D_df))
  D_df <- D_df %>%
    mutate(metro=ifelse(LocType=="Urban", "metro", "non_metro"),
           LogIncome=log1p(Income),
           DrvAgePop=HhSize - Age0to14,
           VehPerDriver=ifelse(Drivers==0 || is.na(Drivers), 0, Vehicles/Drivers),
           LifeCycle = as.character(LifeCycle),
           LifeCycle = ifelse(LifeCycle=="01", "Single", LifeCycle),
           LifeCycle = ifelse(LifeCycle %in% c("02"), "Couple w/o children", LifeCycle),
           LifeCycle = ifelse(LifeCycle %in% c("00", "03", "04", "05", "06", "07", "08"), "Couple w/ children", LifeCycle),
           LifeCycle = ifelse(LifeCycle %in% c("09", "10"), "Empty Nester", LifeCycle)
    ) %>%
    left_join(Bzone_df, by="Bzone") %>%
    crossing(Marea_df)

  #D_df <- D_df %>%
  #  crossing(Marea_df, by="Marea")

  #load("data/WalkTFLModel_df.rda")
  Model_df <- WalkTFLModel_df

  # find cols used for segmenting households ("metro" by default)
  SegmentCol_vc <- setdiff(names(Model_df), c("model", "step", "post_func", "bias_adj"))

  # segmenting columns must appear in D_df
  stopifnot(all(SegmentCol_vc %in% names(D_df)))

  Preds <- DoPredictions(Model_df, D_df,
                         dataset_name, id_name, y_name, SegmentCol_vc, combine_preds=FALSE)

  # fill NA with 0s - produced with negative predictions before inversing power transformation
  Preds <- Preds %>%
    mutate(y=ifelse(is.na(y) | y < 0, 0, y))

  Out_ls <- initDataList()
  Out_ls$Year$Household <-
    list(
      WalkTrips = -1,
      WalkAvgTripDist = -1
    )
  Out_ls$Year$Household$WalkTrips       <- Preds %>% filter(step==1) %>% pull(y)
  Out_ls$Year$Household$WalkAvgTripDist <- Preds %>% filter(step==2) %>% pull(y)

  #Return the list
  Out_ls
}

#===============================================================
#SECTION 4: MODULE DOCUMENTATION AND AUXILLIARY DEVELOPMENT CODE
#===============================================================
#Run module automatic documentation
#----------------------------------
documentModule("PredictWalkTFL")

#====================
#SECTION 5: TEST CODE
#====================
# model test code is in tests/scripts/test.R
