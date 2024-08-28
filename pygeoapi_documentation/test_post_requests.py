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
result_points_att_polygon = None
result_peri_conv = None
result_mean_by_group = None
result_trend_analysis = None
result_ts_selection_interpolation = None


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
        #"points": "https://vm4412.kaj.pouta.csc.fi/ddas/oapif/collections/lva_secchi/items?f=csv&limit=3000" # this has wrong date format!
    } 
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.content)
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['points_att_polygon']['href']
result_points_att_polygon = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % result_points_att_polygon)


#################
### peri_conv ###
#################
name = "peri_conv"
print('\nCalling %s...' % name)
url = base_url+'/processes/peri-conv/execution'
inputs = {
    "inputs": {
        "input_data": result_points_att_polygon or "https://aqua.igb-berlin.de/download/points_att_polygon-84f3986a-5b1f-11ef-b00a-df74de895c41.csv",
        "date_col_name": "visit_date",
        "group_to_periods": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "group_labels": "winter,spring,summer,autumn",
        "year_starts_at_Dec1": "True"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['peri_conv']['href']
result_peri_conv = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % result_peri_conv)



#####################
### mean_by_group ###
#####################
name = "mean_by_group"
print('\nCalling %s...' % name)
url = base_url+'/processes/mean-by-group/execution'
inputs = {
    "inputs": {
        "input_data": result_peri_conv or "https://aqua.igb-berlin.de/download/peri_conv_63349a0a-5b27-11ef-b00a-df74de895c41.csv"

    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['mean_by_group']['href']
result_mean_by_group = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % result_mean_by_group)



##################################
### ts_selection_interpolation ###
##################################
name = "ts_selection_interpolation"
print('\nCalling %s...' % name)
url = base_url+'/processes/ts-selection-interpolation/execution'
inputs = {
    "inputs": {
        "input_data": result_mean_by_group or "https://aqua.igb-berlin.de/download/mean_by_group_fa098084-5b28-11ef-b00a-df74de895c41.csv",
        "rel_cols": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "year_colname": "Year_adj_generated",
        "value_colname": "Secchi_m_mean_annual",
        "min_data_point": "10"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['ts_selection_interpolation']['href']
result_ts_selection_interpolation = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % result_ts_selection_interpolation)



#########################
### trend_analysis_mk ###
#########################
name = "trend_analysis_mk"
print('\nCalling %s...' % name)
url = base_url+'/processes/trend-analysis-mk/execution'
inputs = {
    "inputs": {
        "input_data": result_ts_selection_interpolation or "https://aqua.igb-berlin.de/download/ts_selection_interpolation-22a36618-5b29-11ef-b00a-df74de895c41.csv",
        "rel_cols": "season,polygon_id",
        "time_colname": "Year_adj_generated",
        "value_colname": "Secchi_m_mean_annual"
    }
}
resp = session.post(url, headers=headers, json=inputs)
print('Calling %s... done. HTTP %s' % (name, resp.status_code))
print('Result: %s' % resp.json())

# Get input for next from output of last
href = resp.json()['outputs']['trend_analysis_mk']['href']
result_trend_analysis = href.split('/')[-1]
print('Output: %s' % href)
print('Next input: %s' % result_trend_analysis)



###################
### Finally ... ###
###################
print('Final output: %s' % result_trend_analysis)
print('Done!')

