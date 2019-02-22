library(rsconnect)
library(ggplot2)
library(leaflet)
library(shiny)
library(tidyverse)
library(devtools)
library(rgdal)



#install.packages('devtools')

# Set connection to shiny server (removed sensative info). -----------------------------------------------------------
rsconnect::setAccountInfo(name='pfmccull',
                          token=,
                          secret=)


# Load, correct, and limit the code enforcment data. ----------------------------------------
code.enforcement <- read.csv("Code_Enforcement_Cases.csv", stringsAsFactors = F)
# Fix name of first column.
names(code.enforcement)[1] <- "Case_Year"

# Limit the amount of data from 2013 onwards.
code.enforcement.limit <- filter(code.enforcement, Case_Year > 12 & Case_Number != "13-0039052")
code.enforcement.limit <- separate(code.enforcement.limit, col = "Date_Case_Reported___Calc", 
                                   into = c("Date", "Time"), sep =  " ")
code.enforcement.limit$Date <- as.Date(code.enforcement.limit$Date, "%m/%d/%Y")
startdate <- min(code.enforcement.limit$Date)
enddate <- max(code.enforcement.limit$Date)

# Read in the city council district shapes and create spatial points of code enforcments. ----
cc.districts <- readOGR(dsn = ".",layer = "City_Council_Districts")
cc.districts$member <- as.character(cc.districts$Council_Me)

codes.spacial <- SpatialPointsDataFrame(coords = code.enforcement.limit[,c("Lon", "Lat")],
                                        data = code.enforcement.limit[,],
                                        proj4string = CRS("+proj=longlat +datum=WGS84"))

# Set city council district colors
cc.districts$Num <- as.numeric(cc.districts$Num)
qpal <- colorQuantile("Pastel2", domain = cc.districts$Num, n = 6)
#pal <- ~qpal(cc.districts)

#mem <- as.character(cc.districts$Council_Me)

# Set popups for the city council districs and code enforcment cases --------
cc.districts$popup <- paste("<b>",cc.districts$Dist,"</b><br>",
                                  "Council Member: ",cc.districts$Council_Me,"<br>",
                                  "Email : ", cc.districts$Email, sep ="")
code.enforcement.limit$pop <- paste("<b>", "Status: ", code.enforcement.limit$Case_Status_Code_Description,"</b><br>",
                    "Case Number: ",code.enforcement.limit$Case_Number,"<br>",
                    "Code Type: ",code.enforcement.limit$Case_Type_Code_Description,"<br>",
                    "Date: ",code.enforcement.limit$Date,"<br>",
                    "Address : ", code.enforcement.limit$Street_Address, sep ="")

# Create ui with check boxes for status, code type, date range -----
ui <- pageWithSidebar(
    headerPanel("South Bend Code Enforcement"),
    sidebarPanel(
      checkboxGroupInput(inputId = "status", label = "Case Status",
                     choices = list("Active" = "Active", 
                                    "Closed" = "Closed"),
                     selected = c("Active")),
      checkboxGroupInput(inputId = "code", label = "Code Type",
                     choices = list("ENVIRONMENTAL CLEANUP" = "ENVIRONMENTAL CLEANUP", 
                                    "ENVIRONMENTAL MOWING" = "ENVIRONMENTAL MOWING",
                                    "HOUSING REPAIR" = "HOUSING REPAIR",
                                    "VEHICLE-PRIVATE" = "VEHICLE-PRIVATE", 
                                    "VEHICLE-PUBLIC"= "VEHICLE-PUBLIC",
                                    "ZONING VIOLATIONS" = "ZONING VIOLATIONS"),
                     selected = c("ZONING VIOLATIONS")),
      dateRangeInput("date", label = "Select Date Range", start = startdate, end = enddate, min = startdate, max = enddate,
                 format = "mm-dd-yyyy")),
  mainPanel(
  leafletOutput("map")
  ))
### Set inputs the city council districts  ----
server <- function(input, output, session) {
  output$map <- renderLeaflet({
    leaflet(data = filter(code.enforcement.limit, Case_Status_Code_Description %in% input$status
                          & Case_Type_Code_Description %in% input$code &
                            Date > input$date[1] &
                            Date < input$date[2])) %>%
      addProviderTiles("CartoDB.Positron")  %>%
      addPolygons(data = cc.districts, color = "black", opacity = .1,  
                  fillColor = ~qpal(Num), fillOpacity = .6, group = "Show City Council Districts" ) %>%
      addLegend(position = "bottomleft", title = "City Council Member",
        labels = c("Tim Scott","Regina Williams","Sharon McBride","Jo M. Broden", "Dr. David Varner",
                   "Oliver Davis"),
        colors =  c("#B3E2CD", "#FDCDAC", "#CBD5E8", "#F4CAE4", "#E6F5C9", "#FFF2AE"), 
                    group = "Show City Council Districts")%>% 
      
      addLayersControl(overlayGroups = "Show City Council Districts", 
                       options = layersControlOptions(collapsed = F)) %>%
      addCircleMarkers(radius = .5, fillOpacity = 1,  popup = ~pop)
                                          }
                               )}

# Let it run ----
shinyApp(ui, server)
  