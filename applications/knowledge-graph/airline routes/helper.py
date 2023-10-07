import requests
import pandas as pd
import numpy as np
from math import sin, cos, sqrt, radians, asin



def read_url(url,colmuns):
	filename = url.split("/")[-1]
	open(filename,'wb').write(requests.get(url, stream=True).content)
	df = pd.read_table(filename,header=None,sep=',')
	df.columns = colmuns
	return df
	


def read_airports(url):
	airports = read_url(url,["AirportID","Name","City","Country","IATA","ICAO","Latitude","Longitude","Altitude","Timezone","DST","Tz","Type","Source"])
	airports['node'] = airports['IATA']	
	airports['pos'] = list(zip(airports['Longitude'], airports['Latitude']))
	# Drop airports that does not have IATA code (non-commercials/Air Bases/etc)
	airports = airports[airports["IATA"]!=r"\N"]
	return airports

def read_airlines(url):
	airlines = read_url(url,["Airline ID","Airline Name","Alias","Airline IATA","ICAO","Callsign","Airline Country","Active"])
	# drop inactive airlines
	airlines = airlines[((airlines['Airline Name']!='Unknown')&(airlines['Active']=='Y'))]
	return airlines

def read_routes(url,airports,airlines):
	routes = read_url(url,["Airline","Airline ID","from","Source airport ID","to","Destination airport ID","Codeshare","Stops","Equipment"])
	# drop the routes between airports that does not exist in our dataset
	routes = routes[(routes['from'].isin(set(airports['IATA'])))&(routes['to'].isin(set(airports['IATA'])))]
	# drop routes that has stops
	routes = routes[routes['Stops']==0]
	routes.drop('Stops',axis=1,inplace=True)
	# join routes and airlines by airline IATA code
	routes = routes.merge(airlines[['Airline IATA','Airline Name','Airline Country']],left_on='Airline', right_on="Airline IATA")
	routes.drop(['Airline','Airline ID'],axis=1,inplace=True)
	return routes

def read_planes(url):
	planes = read_url(url,["Name","Plane IATA","Plane ICAO"])
	return planes

def find_great_circle_distance(lon1,lat1,lon2,lat2): 
    lon1, lat1,lon2, lat2 = map(radians,[lon1,lat1,lon2,lat2])
    a = sin((lat2 - lat1) / 2)**2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1) / 2)**2
    return 2 * 6373 * asin(sqrt(a))

def _find_rad(n):
    RAD_SCALE = 0.1
    if n <= 0:
        return []
    if n % 2 == 0:
        return [(i+0.5)*RAD_SCALE for i in range(-n//2, n//2)]
    else:
        return [i * RAD_SCALE for i in range(-n//2+1, n//2+1)]
        

def find_radius(outMatchLinks):
    from collections import Counter
    count_dict = Counter([(i,j) for i,j in outMatchLinks[['from','to']].values])
    rad_dict = {key:_find_rad(val) for key,val in count_dict.items()}
    return rad_dict

def dist(a,b):
    return np.sqrt((a[0]-b[0])**2+(a[1]-b[1])**2)

def modify_labels_pos_randomly(poses,threshold=0.7):
    dists = {}
    for key0,val0 in poses.items():
        for key1,val1 in poses.items():
            if key0<key1:
                val = dist(val0,val1)
                if val<threshold:
                    dists[(key0,key1)]=val
        
    while len(dists)!=0:
        modified = {}
        for (key0,key1),valdists in dists.items():
            if key0 not in modified:
                x,y = poses[key0]
                poses[key0] = (x+0.1*np.random.rand(),y+0.1*np.random.rand())
                modified[key0]=1
            if key1 not in modified:
                x,y = poses[key1]
                poses[key1] = (x-0.1*np.random.rand(),y-0.1*np.random.rand())
                modified[key1]=1


        dists = {}
        for key0,val0 in poses.items():
            for key1,val1 in poses.items():
                if key0<key1:
                    val = dist(val0,val1)
                    if val<threshold:
                        dists[(key0,key1)]=val
    return poses                     