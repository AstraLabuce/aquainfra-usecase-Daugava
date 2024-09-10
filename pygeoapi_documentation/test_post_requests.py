import requests
import time

'''
This is just a little script to test whether the OGC processing
services of the AquaINFRA project Daugava use case were properly
installed using pygeoapi and run as expected.
This does not test any edge cases, just a very basic setup. The input
data may already be on the server, so proper downloading is not 
guaranteed.

Check the repository here:
https://github.com/AstraLabuce/aquainfra-usecase-Daugava/

Merret Buurman (IGB Berlin), 2024-08-15
'''


base_url = 'https://xxx.xxx/pygeoapi'
headers_sync = {'Content-Type': 'application/json'}
headers_async = {'Content-Type': 'application/json', 'Prefer': 'respond-async'}


# Get started...
session = requests.Session()
result_points_att_polygon_url = None
result_peri_conv_url = None
result_mean_by_group_local = None
result_mean_by_group_url = None
result_trend_analysis_local = None
result_trend_analysis_url = None
result_ts_selection_interpolation_local = None
result_ts_selection_interpolation_url = None
result_map_shapefile_points_local = None
result_map_shapefile_points_url = None
result_map_trends_static_local = None
result_map_trends_static_url = None
result_barplot_trend_results_local = None
result_barplot_trend_results_url = None

# Define helper for polling for asynchronous results
def poll_for_json_result(resp201, session, seconds_polling=2, max_seconds=60*60):
    link_to_result = poll_for_links(resp201, session, 'application/json', seconds_polling, max_seconds)
    result_application_json = session.get(link_to_result)
    print('The result JSON document: %s' % result_application_json.json())
    return result_application_json.json()

def poll_for_links(resp201, session, required_type='application/json', seconds_polling=2, max_seconds=60*60):
    # Returns link to result in required_type
    
    if not resp201.status_code == 201:
        print('This should return HTTP status 201, but we got: %s' % resp201.status_code)
    
    print('Where to poll for status: %s' % resp201.headers['location'])
    print('Polling every %s seconds...' % seconds_polling)
    seconds_passed = 0
    polling_url = resp201.headers['location']
    while True:
        polling_result = session.get(resp.headers['location'])
        print('Job status: %s' % polling_result.json()['status'].lower())
        
        if not polling_result.json()['status'].lower() == 'successful':
            if seconds_passed >= max_seconds:
                print('Polled for %s seconds, giving up...' % max_seconds)
            else:
                time.sleep(seconds_polling)
                seconds_passed += seconds_polling
        
        else:
            print('Job successful after %s seconds!' % seconds_passed)
            links_to_results = polling_result.json()['links']
            print('Links to results: %s' % links_to_results)
            link_types = []
            for link in links_to_results:
                link_types.append(link['type'])
                if link['type'] == required_type:
                    print('We want this one (type %s): %s' % (required_type, link['href']))
                    link_to_result = link['href']
                    return link_to_result
                    #result_application_json = session.get(link_to_result)
                    #print('The result JSON document: %s' % result_application_json.json())
                    #return result_application_json.json()

            print('Did not find a link of type "%s"! Only: %s' % (required_type, link_types))
            return None


##########################
### points_att_polygon ###
### excel              ###
##########################
name = "points_att_polygon"
print('\nCalling %s...' % name)
url = base_url+'/processes/points-att-polygon/execution'
inputs = { 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "long_col_name": "longitude",
        "lat_col_name": "latitude",
        "points": "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx" # date format: 1998-02-14T12:30:00
    } 
}


# sync:
# Often runs into 504 Gateway Error, which is basically a timeout... Try async!
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.content)
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['points_att_polygon']['href']
result_points_att_polygon_url = href
print('Output: %s' % href)
print('Next input: %s' % result_points_att_polygon_url)


# async:
resp = session.post(url, headers=headers_async, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
#link_to_result = poll_for_links(resp, 'application/json')
#result_application_json = session.get(link_to_result)
#print('The result is a JSON document: %s' % result_application_json.json())
#link_to_actual_result = result_application_json.json()['outputs']['points_att_polygon']['href']
#print('It contains a link to our ACTUAL result: %s' % link_to_actual_result)

result_application_json = poll_for_json_result(resp, session)
print('The result is a JSON document: %s' % result_application_json)
result_points_att_polygon_url = result_application_json['outputs']['points_att_polygon']['href']
print('It contains a link to our ACTUAL result: %s' % result_points_att_polygon_url)
# Check out result itself:
#final_result = session.get(result_points_att_polygon_url)
#print('Final result: %s...' % str(final_result.content)[0:200])
print('Next input: %s' % result_points_att_polygon_url)



#################
### peri_conv ###
### excel     ###
#################
name = "peri_conv"
print('\nCalling %s...' % name)
url = base_url+'/processes/peri-conv/execution'
inputs = {
    "inputs": {
        "input_data": result_points_att_polygon_url or "https://aqua.igb-berlin.de/download/testinputs/points_att_polygon.csv",
        "date_col_name": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "group_labels": "winter,spring,summer,autumn",
        "year_starts_at_Dec1": "True",
        "date_format": "%Y-%m-%d"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['peri_conv']['href']
result_peri_conv_local = href.split('/')[-1] # TODO: At the moment, mean by group expects data on server, not URL!
result_peri_conv_url = href
print('Output: %s' % href)
print('Next input: %s' % result_peri_conv_url)



##########################
### points_att_polygon ###
### csv from ddas      ###
##########################
name = "points_att_polygon"
print('\nCalling %s...' % name)
url = base_url+'/processes/points-att-polygon/execution'
inputs = { 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "long_col_name": "longitude",
        "lat_col_name": "latitude",
        "points": "https://vm4412.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=csv&limit=3000" # date format: 1998/02/14 12:30:00.000
    } 
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.content)
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['points_att_polygon']['href']
result_points_att_polygon_url = href
print('Output: %s' % href)
print('Next input: %s' % result_points_att_polygon_url)


#####################
### peri_conv     ###
### csv from ddas ###
#####################
name = "peri_conv"
print('\nCalling %s...' % name)
url = base_url+'/processes/peri-conv/execution'
inputs = {
    "inputs": {
        "input_data": result_points_att_polygon_url or "https://aqua.igb-berlin.de/download/testinputs/points_att_polygon.csv",
        "date_col_name": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "group_labels": "winter,spring,summer,autumn",
        "year_starts_at_Dec1": "True",
        "date_format": "%Y/%m/%d"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['peri_conv']['href']
result_peri_conv_url = href
print('Output: %s' % href)
print('Next input: %s' % result_peri_conv_url)



#####################
### mean_by_group ###
#####################
name = "mean_by_group"
print('\nCalling %s...' % name)
url = base_url+'/processes/mean-by-group/execution'
inputs = {
    "inputs": {
        "input_data": result_peri_conv_url or "https://aqua.igb-berlin.de/download/testinputs/peri_conv.csv"

    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['mean_by_group']['href']
result_mean_by_group_local = href.split('/')[-1]
result_mean_by_group_url = href
print('Output: %s' % href)
print('Next input: %s' % result_mean_by_group_url)



##################################
### ts_selection_interpolation ###
##################################
name = "ts_selection_interpolation"
print('\nCalling %s...' % name)
url = base_url+'/processes/ts-selection-interpolation/execution'
inputs = {
    "inputs": {
        #"input_data": result_mean_by_group_url or "https://aqua.igb-berlin.de/download/testinputs/mean_by_group.csv",
        "input_data": result_mean_by_group_local or "testinputs/mean_by_group.csv",
        "rel_cols": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "year_colname": "Year_adj_generated",
        "value_colname": "Secchi_m_mean_annual",
        "min_data_point": "10"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['ts_selection_interpolation']['href']
result_ts_selection_interpolation_local = href.split('/')[-1]
result_ts_selection_interpolation_url = href  # TODO: At the moment, ts_selection expects data on server, not URL!
print('Output: %s' % href)
print('Next input: %s' % result_ts_selection_interpolation_url)



#########################
### trend_analysis_mk ###
#########################
name = "trend_analysis_mk"
print('\nCalling %s...' % name)
url = base_url+'/processes/trend-analysis-mk/execution'
inputs = {
    "inputs": {
        #"input_data": result_ts_selection_interpolation_url or "https://aqua.igb-berlin.de/download/testinputs/ts_selection_interpolation.csv",
        "input_data": result_ts_selection_interpolation_local or "testinputs/ts_selection_interpolation.csv",
        "rel_cols": "season,polygon_id",
        "time_colname": "Year_adj_generated",
        "value_colname": "Secchi_m_mean_annual"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['trend_analysis_mk']['href']
result_trend_analysis_local = href.split('/')[-1]
result_trend_analysis_url = href #  # TODO: At the moment, mean by group expects data on server, not URL!
print('Output: %s' % href)
print('Next input: %s' % result_trend_analysis_url)



############################
### map_shapefile_points ### 6.1
############################
name = "map_shapefile_points"
print('\nCalling %s...' % name)
url = base_url+'/processes/map-shapefile-points/execution'
inputs = {
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "long_col_name": "longitude",
        "lat_col_name": "latitude",
        "points": result_points_att_polygon_url or "https://aqua.igb-berlin.de/download/testinputs/points_att_polygon.csv",
        "value_name": "transparency_m",
        "region_col_name": "HELCOM_ID"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['map_shapefile_points']['href']
result_map_shapefile_points_local = href.split('/')[-1]
result_map_shapefile_points_url = href
print('Output: %s' % href)
print('Next input: %s' % result_map_shapefile_points_url)


#############################
### barplot_trend_results ### 6.2
#############################
name = "barplot_trend_results"
print('\nCalling %s...' % name)
url = base_url+'/processes/barplot-trend-results/execution'
inputs = {
    "inputs": {
        "data": result_trend_analysis_url or "https://aqua.igb-berlin.de/download/testinputs/trend_analysis_mk.csv",
        "id_col": "polygon_id",
        "test_value": "Tau_Value",
        "p_value": "P_Value",
        "p_value_threshold": "0.05",
        "group": "season"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['batplot_trend_results']['href']
result_barplot_trend_results_local = href.split('/')[-1]
result_barplot_trend_results_url = href
print('Output: %s' % href)
print('Next input: %s' % result_barplot_trend_results_url)


##############################
### map_trends_interactive ### 6.3
##############################

## Not implemented!

#########################
### map_trends_static ### 6.4
#########################
name = "map_trends_static"
print('\nCalling %s...' % name)
url = base_url+'/processes/map-trends-static/execution'
inputs = {
    "inputs": {
        "shp_url": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "trend_results_path": result_trend_analysis_url or "https://aqua.igb-berlin.de/download/testinputs/trend_analysis_mk.csv",
        "id_trend_col": "polygon_id",
        "id_shp_col": "HELCOM_ID",
        "group": "season",
        "p_value_threshold": "0.05",
        "p_value": "P_Value"
    }
}
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['map_trends_static']['href']
result_map_trends_static_local = href.split('/')[-1]
result_map_trends_static_url = href
print('Output: %s' % href)
print('Next input: %s' % result_map_trends_static_url)


###################
### Finally ... ###
###################
print('Done!')

