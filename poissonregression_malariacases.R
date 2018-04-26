####################################    Space Time Analyses PAPER   #######################################
############################  Yucatan case study: SAR, SARMA etc -PART 2  #######################################
#This script produces a prediction for the dates following the Hurricane event.       
#The script uses spatial neighbours to predict Light data values in the Hurricane Katrina New Orleans region. 
#Temporal predictions use OLS with the image of the previous time or the ARIMA method.
#AUTHORS: Benoit Parmentier                                             
#DATE CREATED: 03/09/2014 
#DATE MODIFIED: 03/16/2017
#Version: 3
#PROJECT: GLP Conference Berlin,YUCATAN CASE STUDY with Marco Millones            
#PROJECT: Workshop for William and Mary: an intro to geoprocessing with R 
#PROJECT: AAG 2015 in Chicago, with Marco Millones
#PROJECT: Geocomputation conference in Dallas with Marco Millones
#
#COMMENTS: - Testing alternative methods to eigen for spatial predictions: "Chebyshev" on new light data
#         - clean up and organize code to be more general for any dataset
#TO DO:
# - add confidence interval around reg coef: this is important!!
# - add variance around the MAE values in the accuracy assessment
# - modify parallelization so that it works both on windows and linux/macos
# - automation to call from the terminal/shell
#
#
#COMMIT: moving aggregation majority function to function script
#
#################################################################################################

###Loading R library and packages        
### poisson regression
## 9 Chattisgarh, 15 Jharkhand, 30 Uttarakhand


###Loading R library and packages                                                      

library(sp)
library(rgdal)
library(spdep)
library(BMS) #contains hex2bin and bin2hex
library(bitops)
library(gtools)
library(maptools)
library(parallel)
library(rasterVis)
library(raster)
library(zoo)  #original times series function functionalies and objects/classes
library(xts)  #extension of time series objects and functionalities
library(forecast) #arima and other time series methods
library(lubridate) #date and time handling tools
library(colorRamps) #contains matlab.like color palette
library(rgeos) #spatial analysis, topological and geometric operations e.g. interesect, union, contain etc.
library(sphet) #spatial analyis, regression eg.contains spreg for gmm estimation

###### Functions used in this script

create_dir_fun <- function(outDir,out_suffix=NULL){
  #if out_suffix is not null then append out_suffix string
  if(!is.null(out_suffix)){
    out_name <- paste("output_",out_suffix,sep="")
    outDir <- file.path(outDir,out_name)
  }
  #create if does not exists
  if(!file.exists(outDir)){
    dir.create(outDir)
  }
  return(outDir)
}

#function_spatial_regression_analyses <- "SPatial_analysis_spatial_reg_functions_04072017b.R" #PARAM 1
#script_path <- "/home/bparmentier/Google Drive/Space_beats_time/sbt_scripts"
#source(file.path(script_path,function_spatial_regression_analyses)) #source all functions used in this script 1.

#####  Parameters and argument set up ###########

#in_dir <- "/Users/neeti/Documents/neeti/TERIwork/aditi/"
in_dir <- "/home/bparmentier/Google Drive/Data/India_Research/malaria_study_by_state/data"
out_dir <- "/home/bparmentier/Google Drive/Data/India_Research/malaria_study_by_state/outputs"

#proj_modis_str <-"+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs" #CONST 1
#CRS_interp <-"+proj=longlat +ellps=WGS84 +datum=WGS84 +towgs84=0,0,0" #Station coords WGS84
CRS_WGS84 <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +towgs84=0,0,0" #Station coords WGS84 # CONST 2
#proj_str<- CRS_WGS84 
CRS_reg <- CRS_WGS84 # PARAM 4

file_format <- ".tif" #PARAM5
NA_value <- -9999 #PARAM6
NA_flag_val <- NA_value #PARAM7
out_suffix <-"malaria_india_04062017" #output suffix for the files and ouptu folder #PARAM 8
create_out_dir_param=TRUE #PARAM9

data_fname <- file.path(in_dir,"dat_reg2_var_list_NDVI_NDVI_Katrina_04102015.txt")

################# START SCRIPT ###############################

### PART I READ AND PREPARE DATA FOR REGRESSIONS #######

#set up the working directory
#Create output directory

if(is.null(out_dir)){
  out_dir <- dirname(in_dir) #output will be created in the input dir
}

out_suffix_s <- out_suffix #can modify name of output suffix
if(create_out_dir_param==TRUE){
  out_dir <- create_dir_fun(out_dir,out_suffix_s)
  setwd(out_dir)
}else{
  setwd(out_dir) #use previoulsy defined directory
}

#data_tb <-read.table(data_fname,sep=",",header=T)

#data_fname <- file.path(in_dir,"malaria_incidence_yrs.csv")
data_fname <- file.path(in_dir,"malaria_incidence_yrs_94dmi_Mjo.csv")

#mal_inc <- read.table('malaria_incidence_yrs.csv', header=TRUE, sep=',')
mal_inc <- read.table(data_fname, header=TRUE, sep=',')

#mal_inc <- read.table('malaria_incidence_yrs_94dmi_Mjo.csv', header=TRUE, sep=',')

#rain_index <- read.table('rainfall_index.csv', header=TRUE, sep=',')
rain_fall <- read.table('rainfall_data.csv', header=TRUE, sep=',')

lmp_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 6))
lmcoef_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 6))
lmstd_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 6))
lmcilow_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 6))
lmciabove_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 6))
aic_total <- array(data=NA, dim=c((ncol(rain_index)-1), 1))
#lmp_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 3))
#lmcoef_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 3))
#lmstd_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 3))
#lmcilow_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 3))
#lmciabove_arr <- array(data=NA, dim=c((ncol(rain_index)-1), 3))

#colnames(lmp_arr) <- c('intercept', 'oni', 'iod', 'ri')
#colnames(lmcoef_arr) <- c('intercept', 'oni', 'iod', 'ri')
#colnames(lmstd_arr) <- c('intercept', 'oni', 'iod', 'ri')
#colnames(lmcilow_arr) <- c('intercept', 'oni', 'iod', 'ri')
#colnames(lmciabove_arr) <- c('intercept', 'oni', 'iod', 'ri')

colnames(lmp_arr) <- c('intercept', 'oni', 'iod','mjo_djfm', 'mjo_jjas', 'ri')
colnames(lmcoef_arr) <- c('intercept', 'oni', 'iod', 'mjo_djfm', 'mjo_jjas','ri')
colnames(lmstd_arr) <- c('intercept', 'oni', 'iod','mjo_djfm', 'mjo_jjas', 'ri')
colnames(lmcilow_arr) <- c('intercept', 'oni', 'iod','mjo_djfm', 'mjo_jjas', 'ri')
colnames(lmciabove_arr) <- c('intercept', 'oni', 'iod','mjo_djfm', 'mjo_jjas', 'ri')

#colnames(lmp_arr) <- c('intercept', 'oni', 'iod',)
#colnames(lmcoef_arr) <- c('intercept', 'oni', 'iod')
#colnames(lmstd_arr) <- c('intercept', 'oni', 'iod')
#colnames(lmcilow_arr) <- c('intercept', 'oni', 'iod')
#colnames(lmciabove_arr) <- c('intercept', 'oni', 'iod')
state_names <- colnames(rain_index)
state_names <- state_names[-1]
row.names(lmp_arr) <-state_names
row.names(lmcoef_arr) <-state_names
row.names(lmstd_arr) <-state_names
row.names(lmcilow_arr) <-state_names
row.names(lmciabove_arr) <-state_names
row.names(aic_total) <-state_names
mal_inc1 <- mal_inc[-c(30, 35,36,37,38,40)]
for (i in 6:35){
  j <- i -4
#res <- glm(mal_inc1[,i] ~mal_inc1$ONI+mal_inc1$DMI+rain_index[,j], family=poisson(link=log))
  #res <- glm(mal_inc1[,i] ~mal_inc1$ONI+mal_inc1$DMI, family=poisson(link=log))
res <- glm(mal_inc1[,i] ~mal_inc1$ONI_DJF+mal_inc1$DMI_ASO+mal_inc1$MJO_DJFM+mal_inc1$MJO_JJAS + rain_fall[,j], family=poisson(link=log))
#res <- glm(mal_inc1[,i] ~mal_inc1$ONI_DJF+mal_inc1$DMI_ASO+ rain_fall[,j], family=poisson(link=log))

  #chaatisg_inc <- mal_inc1[,9]
  #chaatisg_inc <- chaatisg_inc[-c(1:6)]
  
#res <- glm(chaatisg_inc ~mal_inc1[(7:24),2]+mal_inc1[(7:24),3]+rain_fall[(7:24),6], family=poisson(link=log))

res_sum <- summary(res)
coef_res <- res_sum$coefficients[,1]
p_res <- res_sum$coefficients[,4]
stderror_coef <- res_sum$coefficients[,2]
aic_model <- res_sum$aic
aic_total[(i-5),] <- aic_model
lmp_arr[(i-5),] <- p_res
lmcoef_arr[(i-5),] <- exp(coef_res)
lmstd_arr[(i-5),] <- stderror_coef
lmcilow_arr[(i-5),] <- exp(coef_res - 1.96*stderror_coef)
lmciabove_arr[(i-5),] <- exp(coef_res + 1.96*stderror_coef)
#out <- capture.output(summary(res))

#cat("poisson regression analysis", out, file="summary_poissonregression.txt", sep="n", append=TRUE)
}
write.table(lmp_arr, 'pvalue_malpoisson_oni_iod94_rf_mjo.txt')
write.table(lmcoef_arr, 'coefvalue_malpoisson_oni_iod94_rf_mjo.txt')
write.table(lmstd_arr, 'stderror_malpoisson_oni_iod94_rf_mjo.txt')
write.table(lmcilow_arr, 'CIlow_malpoisson_oni_iod94_rf_mjo.txt')
write.table(lmciabove_arr, 'CIabove_malpoisson_oni_iod94_rf_mjo.txt')

write.table(aic_total, 'aic_malpoisson_oni_iod_rf_mjo.txt')