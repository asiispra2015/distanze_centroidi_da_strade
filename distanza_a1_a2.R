#6 marzo 2018: calcolo delle distanze dei centroidi della griglia dell'Italia dalle strade a1/a2 (OSM)
rm(list=objects())
library("rgdal")
library("raster")
library("rgeos")
library("purrr")
library("foreach")
library("doParallel")
options(error=recover,warn = 2)


STRADE<-c("roads_a1","roads_a2")[c(2)] #<-----scegliere lo shapefile


# INIZIO PROGRAMMA --------------------------------------------------------
ifelse(STRADE=="roads_a1","distanze_a1","distanze_a2")->NOMEOUT

makeCluster(5)->mycl
registerDoParallel(mycl)


tryCatch({
  readOGR("../../grid_ita_shape_centroidi_epsg32632/","GRID_ITA_centroidi")
},error=function(e){
  print("Errore lettura centroidi della griglia dell'Italia")
})->centroidi


tryCatch({
  readOGR("../../osm/subStrade_diviso_in_layers/",STRADE) 
},error=function(e){
  print("Errore lettura shapefile delle strade")
})->strade


tryCatch({
  raster("griglia.tif")
},error=function(e){
  print("Errore lettura raster griglia")
})->griglia


nrow(centroidi)->numeroCentroidi

print("INIZIO CALCOLO DISTANZE")

#calcolo delle distanze di ciascun centroide dallo shapefile delle strade
foreach(qualeCentroide=1:numeroCentroidi,.combine = "c",.inorder=TRUE,.errorhandling="remove",.packages="rgeos") %dopar% {

  gDistance(centroidi[qualeCentroide,],strade)
  
}->distanze

print("CALCOLO DISTANZE TERMIONATO")

#se numero differente vuol dire che durante il ciclo foreach qualche errore è accaduto (e .errorhandling="remove" ha rimosso l'errore)
stopifnot(length(distanze)==numeroCentroidi)

centroidi@data$distanze<-distanze  

stopCluster(cl=mycl)

#scrittura shapefile
suppressWarnings(writeOGR(centroidi,NOMEOUT,NOMEOUT,driver="ESRI Shapefile"))

#rasterizzazione e scrittura raster
rasterize(centroidi,griglia,field="distanze")->rdistanze
writeRaster(rdistanze,paste0(NOMEOUT,".tif"),overwrite=TRUE)
