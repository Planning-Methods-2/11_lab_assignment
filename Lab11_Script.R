# Lab 11 Script: Spatial Analysis/Modelling
# The University of Texas at San Antonio
# URP-5393: Urban Planning Methods II


#---- Objectives ----
# In this Lab you will learn to:

# 0. Learn key concepts for spatial analysis and modeling
# 1. Learn to apply a spatial exploratory methods like the Moran's I
# 2. Learn to apply a parametric spatial regression model.


#---- 1. Spatial Exploratory analysis ----

#Global Moran's I
# downloads home values and income data from ACS for 2015-2020 and calculates growth
#source("bexar_socioeconomic.R") # use when tigris has come back

bexar_socioeconomic<-qs::qread('NC_Data/nta_2_48_029_2022_2017.qs')
bexar_socioeconomic<-st_transform(bexar_socioeconomic,crs=4326)
library(ggplot2)
library(viridis)
library(sf)
p1<-ggplot(data = bexar_socioeconomic)+
  geom_sf(aes(fill=pc_B19013_001E),color=NA)+
  scale_fill_viridis()

#checking map validity
library(sf)
table(st_is_valid(bexar_socioeconomic))

# if (!all(st_is_valid(bexar_socioeconomic))) bexar_socioeconomic <- st_make_valid(bexar_socioeconomic) # in case it is not valid


library(mapview)
mapview(bexar_socioeconomic,zcol="pc_B19013_001E")

# Defining the W matrix
#install.packages("spdep")
library(spdep)

bexar_socioeconomic<-as_Spatial(bexar_socioeconomic) # sf -> sp
# bexar_socioeconomic <- as(bexar_socioeconomic,'sf') sp -> sf

nbs<-poly2nb(bexar_socioeconomic,queen = T) # this defines neighbors

w_bexar<-nb2listw(nbs,style = "W")

plot(bexar_socioeconomic)
plot(nbs,coordinates(bexar_socioeconomic),add=T,col='blue',pch=".")

names(bexar_socioeconomic@data)

bexar_socioeconomic@data$pc_B19013_001E[is.na(bexar_socioeconomic@data$pc_B19013_001E)]<-0

bexar_socioeconomic@data$pc_B19013_001E_lag<-lag.listw(w_bexar,bexar_socioeconomic@data$pc_B19013_001E)

View(bexar_socioeconomic@data[,c("pc_B19013_001E","pc_B19013_001E_lag")])

plot(bexar_socioeconomic$pc_B19013_001E
     ,bexar_socioeconomic$pc_B19013_001E_lag)
identify(bexar_socioeconomic$pc_B19013_001E,bexar_socioeconomic$pc_B19013_001E_lag, bexar_socioeconomic$GEOID, cex = 0.6)


moran.test(bexar_socioeconomic$pc_B19013_001E,listw = w_bexar)

moran.plot(bexar_socioeconomic$pc_B19013_001E,listw = w_bexar)

# Conclusion, there is strong evidence to reject the null H0 of spatial randomness, and accept the H1 that there is a pattern of spatial clustering in the data

lm(bexar_socioeconomic@data$pc_B19013_001E_lag ~ bexar_socioeconomic@data$pc_B19013_001E)

# Local Moran

locM<-localmoran(x = bexar_socioeconomic$pc_B19013_001E,listw = w_bexar)
summary(locM)

mean_mhv20<-mean(bexar_socioeconomic@data$pc_B19013_001E)
mean_mhv20_lag<-mean(bexar_socioeconomic@data$pc_B19013_001E_lag)

abline(v=mean_mhv20,col="red")
abline(h=mean_mhv20_lag,col="blue")

bexar_socioeconomic@data$quad_sig <- 5 # not significant
bexar_socioeconomic@data[(bexar_socioeconomic@data$pc_B19013_001E >= mean_mhv20 & bexar_socioeconomic@data$estimate_mhv_20_lag >= mean_mhv20_lag) & (locM[, 5] <= 0.1), "quad_sig"] <- 1 # High-High
bexar_socioeconomic@data[(bexar_socioeconomic@data$pc_B19013_001E <= mean_mhv20 & bexar_socioeconomic@data$estimate_mhv_20_lag <= mean_mhv20_lag) & (locM[, 5] <= 0.1), "quad_sig"] <- 2 # Low-Low
bexar_socioeconomic@data[(bexar_socioeconomic@data$pc_B19013_001E >= mean_mhv20 & bexar_socioeconomic@data$estimate_mhv_20_lag <= mean_mhv20_lag) & (locM[, 5] <= 0.1), "quad_sig"] <- 3 # High-Low
bexar_socioeconomic@data[(bexar_socioeconomic@data$pc_B19013_001E >= mean_mhv20 & bexar_socioeconomic@data$estimate_mhv_20_lag <= mean_mhv20_lag) & (locM[, 5] <= 0.1), "quad_sig"] <- 4 # Low-High


# Set the breaks for the thematic map classes
breaks <- seq(1, 5, 1)

# Set the corresponding labels for the thematic map classes
labels <- c("High-High", "Low-Low", "High-Low", "Low-High", "Not Signif.")

np <- findInterval(bexar_socioeconomic$quad_sig, breaks)

# Assign colors to each map class
colors <- c("red", "blue", "lightpink", "skyblue2", "white")
plot(bexar_socioeconomic, col = colors[np])  #colors[np] manually sets the color for each county
mtext("Local Moran's I", cex = 1.5, side = 3, line = 1)
legend("topright", legend = labels, fill = colors, bty = "n",cex = 0.9)


#---- 2 Spatial Econometrics ----

#2.1 Get mean NDVI at the census level
# source: https://michaelminn.net/tutorials/r-landsat/index.html 

library(tigris)
texas_counties<-counties(state = "Texas",cb=T)
bexar<-texas_counties[texas_counties$NAME=="Bexar",]


library(raster)
#link to download red: https://www.dropbox.com/s/j8qvlrhfwz19ddh/LC08_L2SP_027040_20210906_20210915_02_T1_SR_B4.TIF?dl=0
red<-raster("../../04 Labs/large data/LC08_L2SP_027040_20210906_20210915_02_T1/LC08_L2SP_027040_20210906_20210915_02_T1_SR_B4.TIF") 
#link to download infrared: https://www.dropbox.com/s/izcco1di53c4sme/LC08_L2SP_027040_20210906_20210915_02_T1_SR_B5.TIF?dl=0 

near_infrared<-raster("../../04 Labs/large data/LC08_L2SP_027040_20210906_20210915_02_T1/LC08_L2SP_027040_20210906_20210915_02_T1_SR_B5.TIF")

plot(red)

library(sf)
bexar<-st_transform(bexar,crs=red@crs)

plot(red)
plot(bexar,add=T)

red2<-crop(red,extent(bexar))
red3<-mask(red2,bexar)
plot(red3)

near_infrared2<-crop(near_infrared,extent(bexar))
near_infrared3<-mask(near_infrared2,bexar)

ndvi <- (near_infrared3 - red3) / (near_infrared3 + red3)

plot(ndvi)

bexar_socioeconomic<-as(bexar_socioeconomic,"sf")
bexar_socioeconomic<-st_transform(bexar_socioeconomic,crs=red@crs)
bexar_socioeconomic$mean_ndvi<-extract(ndvi,as_Spatial(bexar_socioeconomic),fun=mean,na.rm=T)

#summary(bexar_socioeconomic$mean_ndvi) takes time!

plot(x=bexar_socioeconomic$estimate_mhv_20,y = bexar_socioeconomic$mean_ndvi)


library(ggplot2)
library(viridis)
library(RColorBrewer)

cdistricts<-st_read("Council_Districts/CouncilDistricts.shp")

ggplot(data = bexar_socioeconomic)+
  geom_sf(aes(fill=mean_ndvi),color=NA)+
  scale_fill_viridis(option = "D",direction = -1,name="NDVI")+
  geom_sf(data = cdistricts,aes(color=Name),fill=NA)+
  scale_color_discrete(type = brewer.pal(n=10,name = "Paired"),name="Council Distric")+
  labs(title = "2022 Vegetation Index by Census Tract")


#---- 2.2 Spatial Models ----
#Source: https://keen-swartz-3146c4.netlify.app/spatecon.html

library(spdep)
install.packages("spatialreg")
library(spatialreg)

bexar_socioeconomic$B19013_001E_2022_norm<-((bexar_socioeconomic$B19013_001E_2022-mean(bexar_socioeconomic$B19013_001E_2022))/sd(bexar_socioeconomic$B19013_001E_2022))

f1<-formula(B19013_001E_2022_norm ~ mean_ndvi)
f2<-formula(B19013_001E_2022_norm ~ mean_ndvi + B25064_001E_2022)
#OLS

m0<-lm(formula = f2,data = bexar_socioeconomic)
summary(m0)


# Lag model
m1_sar<-lagsarlm(formula = f2,data = bexar_socioeconomic,listw = w_bexar,zero.policy = T)
summary(m1_sar)

# LR (Likelihood ratio) test H0: The inclusion of the lagged term does not improve the model -> rejected
# LM tests H0: there is no spatial autocorrelation in the residuals --> rejected

# Error model
m1_sem<-spautolm(formula = f2,data = bexar_socioeconomic,listw = w_bexar,zero.policy = T,family="SAR")
summary(m1_sem)


# Lag + Error model (Spatial Autoregresive Combined - SAC)
m1_sac<-sacsarlm(formula = f2,data = bexar_socioeconomic,listw = w_bexar,zero.policy = T,Durbin = F)
summary(m1_sac)


#General Nesting Spatial (GNS) Model (H0: all spatial effects !=0)

m1_gns<-sacsarlm(formula = f2,data = bexar_socioeconomic,listw = w_bexar,zero.policy = T,Durbin = T)
summary(m1_gns)


