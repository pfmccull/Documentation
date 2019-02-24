library(rsconnect)
library(ggplot2)
library(leaflet)
library(shiny)
library(tidyverse)
library(devtools)
library(rgdal)

install.packages('rsconnect')

# Set connection
rsconnect::setAccountInfo(name='pfmccull',
                          token='8A488EE4E2B616DCCADEFB96BE23FB1D',
                          secret='qpxUwKhayjLFaJIudJkVrmVf20nTY6nqndvx5Kgl')

setwd("C:/Users/pm797c/Desktop/dash")

# Code Enforcement
enforce <- read.csv("Code_Enforcement_Cases.csv", stringsAsFactors = F)
# Fix name of first column
names(enforce)[1] <- "Case_Year"

# Limit the amount of data from 2013 onwards
enfor <- filter(enforce, Case_Year > 12 & Case_Number != "13-0039052")
enfor <- separate(enfor, col = "Date_Case_Reported___Calc", into = c("Date", "Time"), sep =  " ")
enfor$Date <- as.Date(enfor$Date, "%m/%d/%Y")
startdate <- min(enfor$Date)
enddate <- max(enfor$Date)

cc <- readOGR(dsn = ".",layer = "City_Council_Districts")

enfor_spatial <- SpatialPointsDataFrame(coords = enfor[,c("Lon", "Lat")],
                                        data = enfor[,],
                                        proj4string = CRS("+proj=longlat +datum=WGS84"))

# Set city council district colors
cc$Num <- as.numeric(cc$Num)
qpal <- colorQuantile("Pastel2", domain = cc$Num, n = 6)
pal <- ~qpal(cc$Num)

mem <- as.character(cc$Council_Me)

# Set popups for city council districts
cc$popup <- paste("<b>",cc$Dist,"</b><br>",
                                  "Council Member: ",cc$Council_Me,"<br>",
                                  "Email : ", cc$Email, sep ="")
enfor$pop <- paste("<b>", "Status: ", enfor$Case_Status_Code_Description,"</b><br>",
                    "Case Number: ",enfor$Case_Number,"<br>",
                    "Code Type: ",enfor$Case_Type_Code_Description,"<br>",
                    "Date: ",enfor$Date,"<br>",
                    "Address : ", enfor$Street_Address, sep ="")
ui <- pageWithSidebar(
    headerPanel("South Bend Code Enforcement"),
    sidebarPanel(
      checkboxGroupInput(inputId = "status", label = "Case Status",
                     choices = list("Active" = "Active", 
                                    "Closed" = "Closed"),
                     selected = c("Active", "Closed")),
      checkboxGroupInput(inputId = "code", label = "Code Type",
                     choices = list("ENVIRONMENTAL CLEANUP" = "ENVIRONMENTAL CLEANUP", 
                                    "ENVIRONMENTAL MOWING" = "ENVIRONMENTAL MOWING",
                                    "HOUSING REPAIR" = "HOUSING REPAIR",
                                    "VEHICLE-PRIVATE" = "VEHICLE-PRIVATE", 
                                    "VEHICLE-PUBLIC"= "VEHICLE-PUBLIC",
                                    "ZONING VIOLATIONS" = "ZONING VIOLATIONS"),
                     selected = c("ENVIRONMENTAL CLEANUP", "ENVIRONMENTAL MOWING", "HOUSING REPAIR",
                                  "VEHICLE-PRIVATE", "VEHICLE-PUBLIC", "ZONING VIOLATIONS")),
      dateRangeInput("date", label = "Select Date Range", start = startdate, end = enddate, min = startdate, max = enddate,
                 format = "mm-dd-yyyy")),
  mainPanel(
  leafletOutput("map")
  ))

server <- function(input, output, session) {
  output$map <- renderLeaflet({
    leaflet(data = filter(enfor, Case_Status_Code_Description %in% input$status
                          & Case_Type_Code_Description %in% input$code &
                            Date > input$date[1] &
                            Date < input$date[2])) %>%
      addProviderTiles("CartoDB.Positron")  %>%
      #addTiles() %>%
      

        addPolygons( data = cc, color = "black", opacity = .1,  fillColor = ~qpal(Num), fillOpacity = .6, group = "Show City Council Districts" ) %>%
        addLegend(position = "bottomleft", title = "City Council Member",
        labels = c("Tim Scott","Regina Williams","Sharon McBride","Jo M. Broden", "Dr. David Varner","Oliver Davis"),
        colors =  c("#B3E2CD", "#FDCDAC", "#CBD5E8", "#F4CAE4", "#E6F5C9", "#FFF2AE"), group = "Show City Council Districts")%>% 
      
      addLayersControl(overlayGroups = "Show City Council Districts", 
                       options = layersControlOptions(collapsed = F)) %>%
    addCircleMarkers(radius = .5, fillOpacity = 1,  popup = ~pop)
  })}


shinyApp(ui, server)
  