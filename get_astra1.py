# =================================================================
#
# Authors: Tom Kralidis <tomkralidis@gmail.com>
#          Francesco Martinelli <francesco.martinelli@ingv.it>
#
# Copyright (c) 2022 Tom Kralidis
# Copyright (c) 2024 Francesco Martinelli
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# =================================================================

import logging
import subprocess
import json
import os

from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

# Curl with input reference url:
URL1="https://aqua.igb-berlin.de/download/testinputs/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp"
URL2="https://aqua.igb-berlin.de/download/testinputs/in_situ_example.xlsx"
curl -X POST "https://aqua.igb-berlin.de/pygeoapi-dev/processes/get-astra1/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"regions\": ${URL1}}}"

curl -X POST "https://aqua.igb-berlin.de/pygeoapi-dev/processes/get-astra1/execution" -H "Content-Type: application/json" -d "{ \"inputs\": { \"regions\": \"https://aqua.igb-berlin.de/download/testinputs/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp\" } }"

TODO: R needs dependency "sf", "units", "dplyr", "janitor"
'''


LOGGER = logging.getLogger(__name__)


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class Astra1Processor(BaseProcessor):

    def __init__(self, processor_def):

        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def execute(self, data, outputs=None):

        # Some contents
        DOWNLOAD_DIR = '/var/www/nginx/download/'
        OWN_URL = 'https://aqua.igb-berlin.de/download/'
        R_SCRIPT_DIR = '/opt/pyg_upstream_dev/pygeoapi/pygeoapi/process/'
        # TODO: Not hardcode that directory!
        # TODO: Not hardcode that URL! Get from my config file, or can I even get it from pygeoapi config?


        # Get inputs args
        in_long_col_name = data.get('long_col_name', 'longitude')
        in_lat_col_name = data.get('lat_col_name', 'latitude')
        in_regions = data.get('regions', DOWNLOAD_DIR+'testinputs/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022.shp') # TODO FOR NOW
        in_dpoints = data.get('points', DOWNLOAD_DIR+'testinputs/in_situ_example.xlsx') # TODO FOR NOW


        # Get local path for input data
        in_shp_path = None
        if in_regions.startswith('http'):
            LOGGER.error('THIS IS A URL: %s' % in_regions)
            if OWN_URL in in_regions:
                LOGGER.error('Apparently the data is on our own computer!')
                in_shp_path = in_regions.replace(OWN_URL, DOWNLOAD_DIR)

            else:
                LOGGER.error('Apparently the data is NOT on our own computer!')
                # TODO! Fuck, shapefile is various files so we need it zipped!!
                LOGGER.debug('Reading shapefile from URL: %s' % in_regions)
                inputfilename = 'astra-inputs-%s.csv' % self.my_job_id
                in_shp_path = DOWNLOAD_DIR.rstrip('/')+os.sep+inputfilename

                resp = requests.get(in_regions, stream=True)
                if resp.ok:
                    LOGGER.error("Saving to", os.path.abspath(in_shp_path))
                    with open(in_shp_path, 'wb') as myfile:
                        for chunk in resp.iter_content(chunk_size=1024 * 8):
                            if chunk:
                                myfile.write(chunk)
                                myfile.flush()
                                os.fsync(myfile.fileno())
                    LOGGER.error('We got this content (http %s): %s' % (resp, str(in_shp_path)[:100]))
    
                else:  # HTTP status code 4XX/5XX
                    LOGGER.error("Download failed: status code {}\n{}".format(resp.status_code, resp.text))


        # Where to store output data
        downloadfilename = 'astra-%s.csv' % self.my_job_id
        downloadfilepath = DOWNLOAD_DIR.rstrip('/')+os.sep+downloadfilename
        # TODO: Carefully consider permissions of that directory!

        # Call R script, result gets stored to downloadfilepath
        R_SCRIPT_NAME = 'get_astra1.R'
        r_args = [in_shp_path, in_dpoints, in_long_col_name, in_lat_col_name, downloadfilepath]

        LOGGER.error('RUN R SCRIPT AND STORE TO %s!!!' % downloadfilepath)
        LOGGER.error('R ARGS %s' % r_args)
        exit_code, err_msg = call_r_script('1', LOGGER, R_SCRIPT_NAME, R_SCRIPT_DIR, r_args)
        LOGGER.error('RUN R SCRIPT DONE: CODE %s, MSG %s' % (exit_code, err_msg))

        if not exit_code == 0:
            LOGGER.error(err_msg)
            raise ProcessorExecuteError(user_msg="R script failed with exit code %s" % exit_code)

        else:
            LOGGER.error('CODE 0 SUCCESS!')

            # Create download link:
            downloadlink = OWN_URL.rstrip('/')+os.sep+downloadfilename
            # TODO: Again, carefully consider permissions of that directory!

            # Return link to file:
            response_object = {
                "outputs": {
                    "first_result": {
                        "title": "Astras and Natalijas First Result",
                        "description": "must ask astra what this is",
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<Astra1Processor> {self.name}'


def call_r_script(num, LOGGER, r_file_name, path_rscripts, r_args):

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
        err_and_out = 'R stdour:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout = stdouttext, n = num)
        LOGGER.info(err_and_out)
    return p.returncode, err_and_out

