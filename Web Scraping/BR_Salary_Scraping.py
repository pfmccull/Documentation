# -*- coding: utf-8 -*-
import pandas as pd
import requests, bs4
import re

# Functions findTables() and pullTable() are from Ben Kite's Baseball
# Reference Scraping files. 
# See https://github.com/BenKite/baseball_data/blob/master/baseballReferenceScrape.py

def findTables(url):
    res = requests.get(url)
    ## The next two lines get around the issue with comments breaking the parsing.
    comm = re.compile("<!--|-->")
    soup = bs4.BeautifulSoup(comm.sub("", res.text), 'lxml')
    divs = soup.findAll('div', id = "content")
    divs = divs[0].findAll("div", id=re.compile("^all"))
    ids = []
    for div in divs:
        searchme = str(div.findAll("table"))
        x = searchme[searchme.find("id=") + 3: searchme.find(">")]
        x = x.replace("\"", "")
        if len(x) > 0:
            ids.append(x)
    return(ids)
    
def pullTable(url, tableID):
    res = requests.get(url)
    ## Work around comments
    comm = re.compile("<!--|-->")
    soup = bs4.BeautifulSoup(comm.sub("", res.text), 'lxml')
    tables = soup.findAll('table', id = tableID)
    data_rows = tables[0].findAll('tr')
    data_header = tables[0].findAll('thead')
    data_header = data_header[0].findAll("tr")
    data_header = data_header[0].findAll("th")
    game_data = [[td.getText() for td in data_rows[i].findAll(['th','td'])]
        for i in range(len(data_rows))
        ]
    data = pd.DataFrame(game_data)
    header = []
    for i in range(len(data.columns)):
        header.append(data_header[i].getText())
    data.columns = header
    data = data.loc[data[header[0]] != header[0]]
    data = data.reset_index(drop = True)
    return(data)

#pullTable("https://www.baseball-reference.com/teams/MIA/2017.shtml", "appearances")

teams = ["LAA", "ARI", "ATL", "BAL", "BOS", "CHC", "CHW", "CIN", "CLE", "COL",
         "DET", "MIA", "HOU", "KCR", "LAD", "MIL", "MIN", "NYM", "NYY", "OAK", 
         "PHI", "PIT", "SDG", "SEA", "SFG", "STL", "TBR", "TEX", "TOR", "WSN"]



players = pd.DataFrame()

for year in range(2012, 2019):
    for teamID in teams:
        url = "https://www.baseball-reference.com/teams/" + teamID + "/" + str(year) + ".shtml"
        temp = pullTable(url, "appearances")
        players = pd.concat([players, temp])

players.to_csv('./Data/PlayerSalaries.csv')


