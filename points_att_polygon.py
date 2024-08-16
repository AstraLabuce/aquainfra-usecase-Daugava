import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
curl --location 'http://localhost:5000/processes/points-att-polygon/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "long_col_name": "longitude",
        "lat_col_name": "latitude",
        "points": "https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class PointsAttPolygonProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        r_script_dir = configJSON["r_script_dir"]

        # Get user inputs
        in_long_col_name = data.get('long_col_name', 'longitude')
        in_lat_col_name = data.get('lat_col_name', 'latitude')
        in_regions_url = data.get('regions', 'https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip')
        in_dpoints_url = data.get('points', 'https://raw.githubusercontent.com/AstraLabuce/aquainfra-usecase-Daugava/main/in_situ_data/in_situ_example.xlsx')

        # Where to store output data
        downloadfilename = 'points_att_polygon-%s.csv' % self.my_job_id
        downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        # Run the R script:
        R_SCRIPT_NAME = 'points_att_polygon_wrapper.R'
        r_args = [in_regions_url, in_dpoints_url, in_long_col_name, in_lat_col_name, downloadfilepath]
        LOGGER.info('Run R script and store result to %s!' % downloadfilepath)
        LOGGER.debug('R args: %s' % r_args)
        exit_code, err_msg = call_r_script('1', LOGGER, R_SCRIPT_NAME, r_script_dir, r_args)
        LOGGER.info('Running R script done: Exit code %s, msg %s' % (exit_code, err_msg))

        if not exit_code == 0:
            LOGGER.error(err_msg)
            raise ProcessorExecuteError(user_msg="R script failed with exit code %s" % exit_code)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "points_att_polygon": {
                        "title": "point_att_polygon result table",
                        "description": "TODO must ask astra what this is",
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<PointsAttPolygonProcessor> {self.name}'


def call_r_script(num, LOGGER, r_file_name, path_rscripts, r_args):
    # TODO: Move function to some module, same in all processes

    LOGGER.debug('Now calling bash which calls R: %s' % r_file_name)
    r_file = path_rscripts.rstrip('/')+os.sep+r_file_name
    cmd = ["/usr/bin/Rscript", "--vanilla", r_file] + r_args
    LOGGER.info(cmd)
    LOGGER.debug('Running command... (Output will be shown once finished)')
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    stdoutdata, stderrdata = p.communicate()
    LOGGER.debug("Done running command! Exit code from bash: %s" % p.returncode)

    ### Print stdout and stderr
    stdouttext = stdoutdata.decode()
    stderrtext = stderrdata.decode()
    if len(stderrdata) > 0:
        err_and_out = 'R stdout and stderr:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n{stderr}   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout= stdouttext, stderr=stderrtext, n=num)
        LOGGER.error(err_and_out)
    else:
        err_and_out = 'R stdout:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout = stdouttext, n = num)
        LOGGER.info(err_and_out)
    return p.returncode, err_and_out
