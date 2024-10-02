import requests
import time
import sys

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
result_mean_by_group_url = None
result_trend_analysis_url = None
result_ts_selection_interpolation_url = None
result_map_shapefile_points_url = None
result_map_trends_static_url = None
result_barplot_trend_results_url = None


force_async = False

# Define helper for polling for asynchronous results
def poll_for_json_result(resp201, session, seconds_polling=2, max_seconds=60*60):
    link_to_result = poll_for_links(resp201, session, 'application/json', seconds_polling, max_seconds)
    result_application_json = session.get(link_to_result)
    #print('The result JSON document: %s' % result_application_json.json())
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
        job_status = polling_result.json()['status'].lower()
        print('Job status: %s' % job_status)
        
        if job_status == 'accepted' or job_status == 'running':
            if seconds_passed >= max_seconds:
                print('Polled for %s seconds, giving up...' % max_seconds)
            else:
                time.sleep(seconds_polling)
                seconds_passed += seconds_polling

        elif job_status == 'failed':
            print('Job failed after %s seconds!' % seconds_passed)
            print('Debug info: %s' % polling_result.json())
            print('Stopping.')
            sys.exit(1)

        elif job_status == 'successful':
            print('Job successful after %s seconds!' % seconds_passed)
            links_to_results = polling_result.json()['links']
            #print('Links to results: %s' % links_to_results)
            print('Picking the "%s"-type link from %s links to results.' % (required_type, len(links_to_results)))
            link_types = []
            for link in links_to_results:
                link_types.append(link['type'])
                if link['type'] == required_type:
                    #print('We pick this one (type %s): %s' % (required_type, link['href']))
                    link_to_result = link['href']
                    return link_to_result

            print('Did not find a link of type "%s"! Only: %s' % (required_type, link_types))
            print('Stopping.')
            sys.exit(1)

        else:
            print('Could not understand job status: %s' % polling_result.json()['status'].lower())
            print('Stopping.')
            sys.exit(1)

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
        "colname_lon": "longitude",
        "colname_lat": "latitude",
        "input_data": "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx" # date format: 1998-02-14T12:30:00
    } 
}


# sync:
# Often runs into 504 Gateway Error, which is basically a timeout... Try async!
print('synchronous... (with excel inputs)')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 200
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous... (with excel inputs)')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['data_merged_with_regions']['href']
result_points_att_polygon_url = href
print('It contains a link to our ACTUAL result: %s' % result_points_att_polygon_url)
# Check out result itself:
final_result = session.get(result_points_att_polygon_url)
print('Result content: %s...' % str(final_result.content)[0:200])


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
        "colname_date": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "group_labels": "winter,spring,summer,autumn",
        "year_starts_at_Dec1": "True",
        "date_format": "%Y-%m-%d" # correct for excel inputs!
    }
}

# sync:
print('synchronous... (based on excel inputs)')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous... (based on excel inputs)')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['data_grouped_by_date']['href']
result_peri_conv_url = href
print('It contains a link to our ACTUAL result: %s' % result_peri_conv_url)
# Check out result itself:
final_result = session.get(result_peri_conv_url)
print('Result content: %s...' % str(final_result.content)[0:200])



##########################
### points_att_polygon ###
### csv from ddas      ###
##########################
# TODO: Can we use CSV data from https://vm4412.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=csv ?
# For points_att_polygon, it is no problem, but later ts_selection_interpolation will fail!
'''
name = "points_att_polygon"
print('\nCalling %s...' % name)
url = base_url+'/processes/points-att-polygon/execution'
inputs = { 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "colname_lon": "longitude",
        "colname_lat": "latitude",
        "input_data": "https://vm4412.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=csv&limit=3000" # date format: 1998/02/14 12:30:00.000
    } 
}

# sync:
# Often runs into 504 Gateway Error, which is basically a timeout... Try async!
print('synchronous... (with DDAS CSV inputs)')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 200
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous... (with DDAS CSV inputs)')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['data_merged_with_regions']['href']
result_points_att_polygon_url = href
print('It contains a link to our ACTUAL result: %s' % result_points_att_polygon_url)
# Check out result itself:
final_result = session.get(result_points_att_polygon_url)
print('Result content: %s...' % str(final_result.content)[0:200])
'''

#####################
### peri_conv     ###
### csv from ddas ###
#####################
# TODO: Can we use CSV data from https://vm4412.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=csv ?
# For peri_conv, it is no problem, if we specify the date format, but later ts_selection_interpolation will fail!
'''
name = "peri_conv"
print('\nCalling %s...' % name)
url = base_url+'/processes/peri-conv/execution'
inputs = {
    "inputs": {
        "input_data": result_points_att_polygon_url or "https://aqua.igb-berlin.de/download/testinputs/points_att_polygon.csv",
        "colname_date": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "group_labels": "winter,spring,summer,autumn",
        "year_starts_at_Dec1": "True",
        "date_format": "%Y/%m/%d" # correct for DDAS csv inputs
    }
}

# sync:
print('synchronous... (based on DDAS CSV inputs)')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous... (based on DDAS CSV inputs)')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['data_grouped_by_date']['href']
result_peri_conv_url = href
print('It contains a link to our ACTUAL result: %s' % result_peri_conv_url)
# Check out result itself:
final_result = session.get(result_peri_conv_url)
print('Result content: %s...' % str(final_result.content)[0:200])
'''


#####################
### mean_by_group ###
#####################
name = "mean_by_group"
print('\nCalling %s...' % name)
url = base_url+'/processes/mean-by-group/execution'
inputs = {
    "inputs": {
        "input_data": result_peri_conv_url or "https://aqua.igb-berlin.de/download/testinputs/peri_conv.csv",
        "colnames_to_group_by": "longitude, latitude, Year_adj_generated, group_labels, HELCOM_ID",
        "colname_value": "transparency_m"
    }
}


# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['mean_by_group']['href']
result_mean_by_group_url = href
print('It contains a link to our ACTUAL result: %s' % result_mean_by_group_url)
# Check out result itself:
final_result = session.get(result_mean_by_group_url)
print('Result content: %s...' % str(final_result.content)[0:200])



##################################
### ts_selection_interpolation ###
##################################
name = "ts_selection_interpolation"
print('\nCalling %s...' % name)
url = base_url+'/processes/ts-selection-interpolation/execution'
inputs = {
    "inputs": {
        "input_data": result_mean_by_group_url or "https://aqua.igb-berlin.de/download/testinputs/mean_by_group.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "colname_year": "Year_adj_generated",
        "colname_value": "transparency_m", # not in the result: "Secchi_m_mean_annual",
        "min_data_point": "10"
    }
}


# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['interpolated_time_series']['href']
result_ts_selection_interpolation_url = href
print('It contains a link to our ACTUAL result: %s' % result_ts_selection_interpolation_url)
# Check out result itself:
final_result = session.get(result_ts_selection_interpolation_url)
print('Result content: %s...' % str(final_result.content)[0:200])



#########################
### trend_analysis_mk ###
#########################
name = "trend_analysis_mk"
print('\nCalling %s...' % name)
url = base_url+'/processes/trend-analysis-mk/execution'
inputs = {
    "inputs": {
        "input_data": result_ts_selection_interpolation_url or "https://aqua.igb-berlin.de/download/testinputs/interpolated_time_series.csv",
        #"colnames_relevant": "season,polygon_id",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "colname_time": "Year_adj_generated",
        "colname_value": "transparency_m", # "Secchi_m_mean_annual"
    }
}

# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
href = result_application_json['outputs']['trend_analysis_results']['href']
result_trend_analysis_url = href
print('It contains a link to our ACTUAL result: %s' % result_trend_analysis_url)
# Check out result itself:
final_result = session.get(result_trend_analysis_url)
print('Result content: %s...' % str(final_result.content)[0:200])


############################
### map_shapefile_points ### 6.1
############################
name = "map_shapefile_points"
print('\nCalling %s...' % name)
url = base_url+'/processes/map-shapefile-points/execution'
inputs = {
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "colname_long": "longitude",
        "colname_lat": "latitude",
        "points": result_points_att_polygon_url or "https://aqua.igb-berlin.de/download/testinputs/points_att_polygon.csv",
        "colname_value_name": "transparency_m",
        "colname_region_id": "HELCOM_ID"
    }
}

# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
print('Result (JSON document): %s' % result_application_json)
href = result_application_json['outputs']['interactive_map']['href']
result_map_shapefile_points_url = href
print('It contains a link to our ACTUAL result: %s' % result_map_shapefile_points_url)
# Check out result itself:
final_result = session.get(result_map_shapefile_points_url)
print('Result content: %s...' % str(final_result.content)[0:200])


#############################
### barplot_trend_results ### 6.2
#############################
name = "barplot_trend_results"
print('\nCalling %s...' % name)
url = base_url+'/processes/barplot-trend-results/execution'
inputs = {
    "inputs": {
        "input_data": result_trend_analysis_url or "https://aqua.igb-berlin.de/download/testinputs/trend_analysis_results.csv",
        "colname_id": "HELCOM_ID", # "polygon_id",
        "colname_test_value": "Tau_Value",
        "colname_p_value": "P_Value",
        "p_value_threshold": "0.05",
        "colname_group": "period", # "season"
    }
}

# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
print('Result (JSON document): %s' % result_application_json)
href = result_application_json['outputs']['barplot_image']['href']
result_barplot_trend_results_url = href
print('It contains a link to our ACTUAL result: %s' % result_barplot_trend_results_url)
# Check out result itself:
final_result = session.get(result_barplot_trend_results_url)
print('Result content: %s...' % str(final_result.content)[0:200])



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
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "input_data": result_trend_analysis_url or "https://aqua.igb-berlin.de/download/testinputs/trend_analysis_mk.csv",
        "colname_id_trend": "HELCOM_ID", # "polygon_id",
        "colname_region_id": "HELCOM_ID",
        "colname_group": "period", # "season"
        "p_value_threshold": "0.05",
        "colname_p_value": "P_Value"
    }
}

# sync:
print('synchronous...')
resp = session.post(url, headers=headers_sync, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
if resp.status_code == 200:
    result_application_json = resp.json()
    print('Result (JSON document): %s' % result_application_json)

# or async:
if not resp.status_code == 200 or force_async:
    print('asynchronous...')
    resp = session.post(url, headers=headers_async, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
    result_application_json = poll_for_json_result(resp, session)
    print('Result (JSON document): %s' % result_application_json)

# Results (sync / async, does not matter):
print('Result (JSON document): %s' % result_application_json)
href = result_application_json['outputs']['trend_map']['href']
result_map_trends_static_url = href
print('It contains a link to our ACTUAL result: %s' % result_map_trends_static_url)
# Check out result itself:
final_result = session.get(result_map_trends_static_url)
print('Result content: %s...' % str(final_result.content)[0:200])



###################
### Finally ... ###
###################
print('Done!')

