import requests

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
headers = {'Content-Type': 'application/json'}


# Get started...
session = requests.Session()
intermediate_result = None


##########################
### points_att_polygon ###
##########################
name = "points_att_polygon"
print('\nCalling %s...' % name)
url = base_url+'/processes/points-att-polygon/execution'
inputs = { 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "long_col_name": "longitude",
        "lat_col_name": "latitude",
        "points": "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx"
    } 
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['first_result']['href']
intermediate_result = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % intermediate_result)


#################
### peri_conv ###
#################
name = "peri_conv"
print('\nCalling %s...' % name)
url = base_url+'/processes/peri-conv/execution'
inputs = {
    "inputs": {
        "input_data": intermediate_result or "points_att_polygon-84f3986a-5b1f-11ef-b00a-df74de895c41.csv",
        "column": "visit_date",
        "dates": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "periods": "winter,spring,summer,autumn",
        "someBoolean": "True"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['first_result']['href']
intermediate_result = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % intermediate_result)



#####################
### mean_by_group ###
#####################
name = "mean_by_group"
print('\nCalling %s...' % name)
url = base_url+'/processes/mean-by-group/execution'
inputs = {
    "inputs": {
        "input_data": intermediate_result or "peri_conv_63349a0a-5b27-11ef-b00a-df74de895c41.csv"

    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['first_result']['href']
intermediate_result = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % intermediate_result)



##################################
### ts_selection_interpolation ###
##################################
name = "ts_selection_interpolation"
print('\nCalling %s...' % name)
url = base_url+'/processes/ts-selection-interpolation/execution'
inputs = {
    "inputs": {
        "in_data_path": intermediate_result or "mean_by_group_fa098084-5b28-11ef-b00a-df74de895c41.csv",
        "in_rel_cols": "group_labels,HELCOM_ID",
        "in_missing_threshold_percentage": "40",
        "in_year_colname": "Year_adj_generated",
        "in_value_colname": "Secchi_m_mean_annual",
        "in_min_data_point": "10"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['first_result']['href']
intermediate_result = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % intermediate_result)



#########################
### trend_analysis_mk ###
#########################
name = "trend_analysis_mk"
print('\nCalling %s...' % name)
url = base_url+'/processes/trend-analysis-mk/execution'
inputs = {
    "inputs": {
        "in_data_path": intermediate_result or "ts_selection_interpolation-22a36618-5b29-11ef-b00a-df74de895c41.csv",
        "in_rel_cols": "season,polygon_id",
        "in_time_colname": "Year_adj_generated",
        "in_value_colname": "Secchi_m_mean_annual"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['first_result']['href']
intermediate_result = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % intermediate_result)


###################
### Finally ... ###
###################
print('Final output: %s' % intermediate_result)
print('Done!')

