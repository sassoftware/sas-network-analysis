# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0


import swat
import os
import re

def reconnect(
   host=None,
   port=None,
   session_name='mySession',
   env_path="../../../common/conf/environment.txt",
   **kwargs):
    environment_path = os.path.join(os.path.dirname(os.getcwd()), env_path)
    s = None
    if host is None or port is None:
      with open(environment_path, "r") as fin:
         env_file = fin.read()
         default_host = re.findall("CAS_SERVER_HOST=(.+)", env_file)[0]
         default_port = re.findall("CAS_SERVER_PORT=(\d+)", env_file)[0]
      if host is None:
         host = default_host
      if port is None:
         port = default_port
    s = swat.CAS(host, port, name=session_name, **kwargs)
    return s
